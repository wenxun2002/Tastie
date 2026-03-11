import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:step_progress/step_progress.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/constants/ingredient_units.dart';
import 'package:tastie/models/create_post_data.dart';
import 'package:tastie/models/tag_item.dart';
import 'package:tastie/pages/home_page/home_controller.dart';
import 'package:tastie/pages/index_page/index_controller.dart';
import 'package:tastie/repositories/firestore_tag_repository.dart';
import 'package:tastie/services/create_recipe_service.dart';
import 'package:tastie/widgets/photo_upload_row.dart';
import 'package:tastie/widgets/primary_button.dart';
import 'package:tastie/widgets/smart_generate_button.dart';
import 'package:tastie/widgets/tag_list_scroll.dart';

enum CreatePostStep { post, ingredients, procedures }

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  static const int _maxPhotos = 6;
  // Reuse the unit definitions from a single source of truth.
  static const List<String> _specialUnits = IngredientUnits.specialUnits;
  static const List<String> _unitOptions = IngredientUnits.allUnits;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FirestoreTagRepository _tagRepository = FirestoreTagRepository();

  List<TagItem> _tags = const [];
  bool _isLoadingTags = false;
  String? _tagError;
  List<XFile> _photos = const [];
  late final StepProgressController _stepProgressController;

  bool _isSubmitting = false;
  String? _submitProgress;
  String? _submitError;

  CreatePostStep _currentStep = CreatePostStep.post;
  int _stepTransitionDirection = 1;
  List<_IngredientEntry> _ingredientEntries = [];
  List<_ProcedureEntry> _procedureEntries = [];
  NutritionData _nutrition = NutritionData.initial();

  int _ingredientIdSeed = 0;
  int _procedureIdSeed = 0;

  @override
  void initState() {
    super.initState();
    _loadTags();
    _initFormData();
    _stepProgressController = StepProgressController(
      totalSteps: CreatePostStep.values.length,
      initialStep: _currentStep.index,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _stepProgressController.dispose();
    super.dispose();
  }

  void _initFormData() {
    _ingredientEntries = [
      _IngredientEntry(
        id: _nextIngredientId(),
        data: IngredientData(name: '', amount: 0, unit: _unitOptions.first),
      ),
    ];
    _procedureEntries = [
      _ProcedureEntry(id: _nextProcedureId(), description: ''),
    ];
  }

  String _nextIngredientId() => 'ingredient-${_ingredientIdSeed++}';

  String _nextProcedureId() => 'procedure-${_procedureIdSeed++}';

  Future<void> _loadTags() async {
    setState(() {
      _isLoadingTags = true;
      _tagError = null;
    });
    try {
      final tags = await _tagRepository.getAll();
      setState(() {
        _tags = tags;
        _isLoadingTags = false;
      });
    } catch (e) {
      setState(() {
        _tagError = 'Failed to load tags';
        _isLoadingTags = false;
      });
    }
  }

  void _toggleTag(int index) {
    setState(() {
      final TagItem updated = _tags[index].copyWith(
        isEnabled: !_tags[index].isEnabled,
      );
      _tags = List<TagItem>.from(_tags)..[index] = updated;
    });
  }

  void _handlePhotoChanged(List<XFile> photos) {
    setState(() => _photos = photos);
  }

  void _handleSmartGenerate() {
    // TODO: integrate smart generate flow.
    _goToStep(CreatePostStep.ingredients);
  }

  void _handleNextPressed() {
    switch (_currentStep) {
      case CreatePostStep.post:
        if (_titleController.text.trim().isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Title is required')));
          return;
        }
        _goToStep(CreatePostStep.ingredients);
        break;
      case CreatePostStep.ingredients:
        final hasEmptyIngredient = _ingredientEntries.any(
          (e) => e.data.name.trim().isEmpty,
        );
        if (hasEmptyIngredient) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All ingredients are required')),
          );
          return;
        }
        _goToStep(CreatePostStep.procedures);
        break;
      case CreatePostStep.procedures:
        final hasEmptyProcedure = _procedureEntries.any(
          (e) => e.description.trim().isEmpty,
        );
        if (hasEmptyProcedure) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All procedures are required')),
          );
          return;
        }
        _submit();
        break;
    }
  }

  void _handleBackPressed() {
    switch (_currentStep) {
      case CreatePostStep.post:
        Get.back<void>();
        break;
      case CreatePostStep.ingredients:
        _goToStep(CreatePostStep.post);
        break;
      case CreatePostStep.procedures:
        _goToStep(CreatePostStep.ingredients);
        break;
    }
  }

  void _goToStep(CreatePostStep step) {
    setState(() {
      _stepTransitionDirection = step.index > _currentStep.index ? 1 : -1;
      _currentStep = step;
    });
    _stepProgressController.setCurrentStep(step.index);
  }

  Future<void> _submit() async {
    // 1. 本地校验（不触发网络）
    final data = _buildCreatePostData();
    if (data.title.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a title')),
        );
      }
      return;
    }

    // 2. 进入提交状态
    setState(() {
      _isSubmitting = true;
      _submitError = null;
      _submitProgress = 'Preparing...';
    });

    try {
      final service = CreateRecipeService();

      await service.createRecipe(
        data,
        onProgress: (message) {
          if (!mounted) return;
          setState(() => _submitProgress = message);
        },
      );

      if (!context.mounted) return;

      // 提交成功：先返回上一页（Home / Me），并给上一页一个 result
      Navigator.pop(context, true);

      // 回到 Home 后刷新 feed（不阻塞当前页面关闭）
      Future.microtask(() async {
        try {
          // 确保切到 Home tab
          final home = Get.find<HomeController>();
          home.onChangePage(0);
        } catch (_) {}

        try {
          final index = Get.find<IndexController>();
          await index.refreshPosts();
        } catch (_) {}

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe published successfully')),
          );
        }
      });
    } catch (e, st) {
      // ignore: avoid_print
      print('CreateRecipe error: $e\n$st');
      if (context.mounted) {
        final message =
            e is CreateRecipeException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish: $message'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitProgress = null;
        });
      }
    }
  }

  CreatePostData _buildCreatePostData() {
    return CreatePostData(
      photos: _photos.map((file) => file.path).toList(),
      title: _titleController.text,
      content: _contentController.text,
      tags: _tags
          .where((element) => element.isEnabled)
          .map((e) => e.label)
          .toList(),
      ingredients: _ingredientEntries.map((entry) => entry.data).toList(),
      nutrition: _nutrition,
      procedures: _procedureEntries.map((entry) => entry.description).toList(),
    );
  }

  void _addIngredient() {
    setState(() {
      _ingredientEntries = List<_IngredientEntry>.from(_ingredientEntries)
        ..add(
          _IngredientEntry(
            id: _nextIngredientId(),
            data: IngredientData(unit: _unitOptions.first),
          ),
        );
    });
  }

  void _removeIngredient(String id) {
    setState(() {
      _ingredientEntries = List<_IngredientEntry>.from(_ingredientEntries)
        ..removeWhere((element) => element.id == id);
      if (_ingredientEntries.isEmpty) {
        _addIngredient();
      }
    });
  }

  void _updateIngredient(
    String id, {
    String? name,
    double? amount,
    String? unit,
  }) {
    setState(() {
      _ingredientEntries = _ingredientEntries
          .map(
            (entry) => entry.id == id
                ? entry.copyWith(
                    data: entry.data.copyWith(
                      name: name ?? entry.data.name,
                      amount: amount ?? entry.data.amount,
                      unit: unit ?? entry.data.unit,
                    ),
                  )
                : entry,
          )
          .toList(growable: false);
    });
  }

  void _onIngredientReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final entry = _ingredientEntries.removeAt(oldIndex);
      _ingredientEntries.insert(newIndex, entry);
    });
  }

  void _addProcedure() {
    setState(() {
      _procedureEntries = List<_ProcedureEntry>.from(_procedureEntries)
        ..add(_ProcedureEntry(id: _nextProcedureId(), description: ''));
    });
  }

  void _removeProcedure(String id) {
    setState(() {
      _procedureEntries = List<_ProcedureEntry>.from(_procedureEntries)
        ..removeWhere((element) => element.id == id);
      if (_procedureEntries.isEmpty) {
        _addProcedure();
      }
    });
  }

  void _updateProcedure(String id, String description) {
    setState(() {
      _procedureEntries = _procedureEntries
          .map(
            (entry) => entry.id == id
                ? entry.copyWith(description: description)
                : entry,
          )
          .toList(growable: false);
    });
  }

  void _onProcedureReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final entry = _procedureEntries.removeAt(oldIndex);
      _procedureEntries.insert(newIndex, entry);
    });
  }

  void _updateNutritionField(String fieldKey, double value) {
    setState(() {
      switch (fieldKey) {
        case 'calories':
          _nutrition = _nutrition.copyWith(calories: value);
          break;
        case 'protein':
          _nutrition = _nutrition.copyWith(protein: value);
          break;
        case 'carbs':
          _nutrition = _nutrition.copyWith(carbs: value);
          break;
        case 'fat':
          _nutrition = _nutrition.copyWith(fat: value);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isLastStep = _currentStep == CreatePostStep.procedures;

    final overlay = _isSubmitting
        ? Container(
            color: Colors.black26,
            child: Center(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _submitProgress ?? 'Please wait...',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _handleBackPressed,
                      ),
                      PrimaryButton(
                        text: isLastStep ? 'Submit' : 'Next',
                        onPressed: _isSubmitting ? null : _handleNextPressed,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _StepProgressBar(
                    currentStep: _currentStep,
                    controller: _stepProgressController,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) {
                      final direction = _stepTransitionDirection;
                      final offsetAnimation =
                          Tween<Offset>(
                            begin: Offset(0.1 * direction, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          );
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        ),
                      );
                    },
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_currentStep),
                      child: _buildStepContent(theme),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        overlay,
      ],
    );
  }

  Widget _buildStepContent(ThemeData theme) {
    switch (_currentStep) {
      case CreatePostStep.post:
        return _buildPostStep(theme);
      case CreatePostStep.ingredients:
        return _buildIngredientStep(theme);
      case CreatePostStep.procedures:
        return _buildProcedureStep(theme);
    }
  }

  Widget _buildPostStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PhotoUploadRow(
            maxPhotos: _maxPhotos,
            initialPhotos: _photos,
            onChanged: _handlePhotoChanged,
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_photos.length}/$_maxPhotos',
              style:
                  theme.textTheme.bodySmall?.copyWith(
                    color: ColorPlate.textTertiary,
                  ) ??
                  const TextStyle(fontSize: 12, color: Color(0xff999999)),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            maxLines: 1,
            decoration: _underlineInputDecoration('Title (required)'),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _contentController,
            maxLines: 5,
            decoration: _underlineInputDecoration(
              'Description (optional)',
            ).copyWith(alignLabelWithHint: true),
          ),
          const SizedBox(height: 24),
          _buildTagSection(theme),
          const SizedBox(height: 16),
          SmartGenerateButton(onTap: _handleSmartGenerate),
        ],
      ),
    );
  }

  Widget _buildIngredientStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ingredients',
            style: theme.textTheme.titleLarge ?? ColorPlate.heading2,
          ),
          const SizedBox(height: 12),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _ingredientEntries.length,
            onReorder: _onIngredientReorder,
            buildDefaultDragHandles: false,
            itemBuilder: (context, index) {
              final entry = _ingredientEntries[index];
              final bool hideAmount = _specialUnits.contains(entry.data.unit);
              return Dismissible(
                key: ValueKey(entry.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _removeIngredient(entry.id),
                background: _buildDismissBackground(),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _IngredientRow(
                      index: index,
                      entry: entry,
                      hideAmountField: hideAmount,
                      units: _unitOptions,
                      onNameChanged: (value) =>
                          _updateIngredient(entry.id, name: value),
                      onAmountChanged: (value) => _updateIngredient(
                        entry.id,
                        amount: double.tryParse(value) ?? 0,
                      ),
                      onUnitChanged: (value) {
                        final bool isSpecial = _specialUnits.contains(value);
                        _updateIngredient(entry.id, unit: value);
                        // When switching to a special unit, we don't need amount;
                        // store 0 internally and hide the input. The payload that
                        // is printed on submit will convert this to `null`.
                        if (isSpecial) {
                          _updateIngredient(entry.id, amount: 0);
                        }
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _AddRowButton(label: 'Add Ingredient', onTap: _addIngredient),
          const SizedBox(height: 24),
          Text(
            'Nutrition',
            style: theme.textTheme.titleLarge ?? ColorPlate.heading2,
          ),
          const SizedBox(height: 12),
          _buildNutritionList(),
        ],
      ),
    );
  }

  Widget _buildProcedureStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Procedures',
            style: theme.textTheme.titleLarge ?? ColorPlate.heading2,
          ),
          const SizedBox(height: 12),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _procedureEntries.length,
            onReorder: _onProcedureReorder,
            buildDefaultDragHandles: false,
            itemBuilder: (context, index) {
              final entry = _procedureEntries[index];
              return Dismissible(
                key: ValueKey(entry.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _removeProcedure(entry.id),
                background: _buildDismissBackground(),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ProcedureRow(
                      index: index,
                      entry: entry,
                      onChanged: (value) => _updateProcedure(entry.id, value),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _AddRowButton(label: 'Add Procedure', onTap: _addProcedure),
        ],
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Icon(Icons.delete_outline, color: Colors.redAccent),
    );
  }

  Widget _buildNutritionList() {
    final nutritionItems = [
      _NutritionField(label: 'Calories', unit: 'kcal', fieldKey: 'calories'),
      _NutritionField(label: 'Protein', unit: 'g', fieldKey: 'protein'),
      _NutritionField(label: 'Carbohydrates', unit: 'g', fieldKey: 'carbs'),
      _NutritionField(label: 'Fat', unit: 'g', fieldKey: 'fat'),
    ];

    double _valueForField(String key) {
      switch (key) {
        case 'calories':
          return _nutrition.calories;
        case 'protein':
          return _nutrition.protein;
        case 'carbs':
          return _nutrition.carbs;
        case 'fat':
          return _nutrition.fat;
        default:
          return 0;
      }
    }

    return Column(
      children: nutritionItems
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      key: ValueKey(item.fieldKey),
                      initialValue: _valueForField(item.fieldKey) == 0
                          ? ''
                          : _valueForField(item.fieldKey).toString(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _underlineInputDecoration('0'),
                      onChanged: (value) => _updateNutritionField(
                        item.fieldKey,
                        double.tryParse(value) ?? 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.unit,
                    style: const TextStyle(color: ColorPlate.textSecondary),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  InputDecoration _underlineInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xffD9D9D9)),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xffD9D9D9)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: ColorPlate.primary),
      ),
      isDense: true,
    );
  }

  Widget _buildTagSection(ThemeData theme) {
    if (_isLoadingTags) {
      return const SizedBox(
        height: 32,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_tagError != null) {
      return Text(
        _tagError!,
        style:
            theme.textTheme.bodySmall?.copyWith(color: Colors.red) ??
            const TextStyle(color: Colors.red, fontSize: 12),
      );
    }

    return TagListScroll(tags: _tags, onTagTap: _toggleTag);
  }
}

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({required this.currentStep, required this.controller});

  final CreatePostStep currentStep;
  final StepProgressController controller;

  @override
  Widget build(BuildContext context) {
    final labels = ['Post', 'Ingredients', 'Procedures'];
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 110,
      child: StepProgress(
        totalSteps: labels.length,
        controller: controller,
        currentStep: currentStep.index,
        nodeTitles: labels,
        stepNodeSize: 38,
        nodeIconBuilder: (index, completedStep) {
          final bool isCompleted = index < completedStep;
          final bool isCurrent = index == completedStep;
          final Color backgroundColor = isCompleted
              ? ColorPlate.secondary
              : isCurrent
              ? ColorPlate.primary
              : Colors.white;
          final Color borderColor = isCompleted || isCurrent
              ? ColorPlate.primary
              : ColorPlate.disabled;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 2),
            ),
            alignment: Alignment.center,
            child: isCompleted
                ? const Icon(Icons.check, size: 18, color: ColorPlate.primary)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isCurrent
                          ? Colors.white
                          : ColorPlate.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          );
        },
        theme: StepProgressThemeData(
          defaultForegroundColor: Colors.transparent,
          activeForegroundColor: Colors.transparent,
          nodeLabelAlignment: StepLabelAlignment.topBottom,
          stepLineSpacing: 2,
          nodeLabelStyle: StepLabelStyle(
            activeColor: ColorPlate.primary,
            defualtColor: ColorPlate.textTertiary,
            maxWidth: 90,
            titleStyle: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          stepLineStyle: const StepLineStyle(
            lineThickness: 2,
            foregroundColor: ColorPlate.disabled,
            activeColor: ColorPlate.primary,
          ),
          stepNodeStyle: const StepNodeStyle(
            decoration: BoxDecoration(color: Colors.transparent),
            activeDecoration: BoxDecoration(color: Colors.transparent),
            enableRippleEffect: false,
          ),
        ),
        highlightOptions:
            StepProgressHighlightOptions.highlightCompletedNodesAndLines,
        visibilityOptions: StepProgressVisibilityOptions.nodeThenLine,
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.index,
    required this.entry,
    required this.hideAmountField,
    required this.units,
    required this.onNameChanged,
    required this.onAmountChanged,
    required this.onUnitChanged,
  });

  final int index;
  final _IngredientEntry entry;
  final bool hideAmountField;
  final List<String> units;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<String> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: TextFormField(
                      initialValue: entry.data.name,
                      decoration: const InputDecoration(
                        hintText: 'Ingredient Name',
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xffD9D9D9)),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xffD9D9D9)),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: ColorPlate.primary),
                        ),
                      ),
                      onChanged: onNameChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!hideAmountField)
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: entry.data.amount == 0
                            ? ''
                            : entry.data.amount.toString(),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Amount',
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xffD9D9D9)),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xffD9D9D9)),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: ColorPlate.primary),
                          ),
                        ),
                        onChanged: onAmountChanged,
                      ),
                    ),
                  if (!hideAmountField) const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: entry.data.unit,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: units
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) onUnitChanged(value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Icon(
                  Icons.drag_indicator,
                  color: ColorPlate.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(color: Color(0xffD9D9D9), height: 1),
      ],
    );
  }
}

class _ProcedureRow extends StatelessWidget {
  const _ProcedureRow({
    required this.index,
    required this.entry,
    required this.onChanged,
  });

  final int index;
  final _ProcedureEntry entry;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}.',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: ColorPlate.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: entry.description,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Describe this step...',
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xffD9D9D9)),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xffD9D9D9)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: ColorPlate.primary),
                  ),
                ),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(top: 6.0),
                child: Icon(
                  Icons.drag_indicator,
                  color: ColorPlate.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(color: Color(0xffD9D9D9), height: 1),
      ],
    );
  }
}

class _AddRowButton extends StatelessWidget {
  const _AddRowButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, color: ColorPlate.primary),
      label: Text(
        label,
        style: const TextStyle(
          color: ColorPlate.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: ColorPlate.primary),
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _IngredientEntry {
  _IngredientEntry({required this.id, required this.data});

  final String id;
  final IngredientData data;

  _IngredientEntry copyWith({IngredientData? data}) {
    return _IngredientEntry(id: id, data: data ?? this.data);
  }
}

class _ProcedureEntry {
  _ProcedureEntry({required this.id, required this.description});

  final String id;
  final String description;

  _ProcedureEntry copyWith({String? description}) {
    return _ProcedureEntry(
      id: id,
      description: description ?? this.description,
    );
  }
}

class _NutritionField {
  const _NutritionField({
    required this.label,
    required this.unit,
    required this.fieldKey,
  });

  final String label;
  final String unit;
  final String fieldKey;
}

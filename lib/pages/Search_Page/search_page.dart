import 'package:flutter/material.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/pages/Search_Page/search_models.dart';
import 'package:tastie/pages/Search_Page/search_result_page.dart';
import 'package:tastie/pages/Search_Page/widgets/animated_matching_ingredient_chips.dart';
import 'package:tastie/repositories/firestore_search_ingredient_repository.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.initialCriteria,
    this.editorMode = false,
  });

  final SearchCriteria? initialCriteria;
  final bool editorMode;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const Duration _softTransitionDuration = Duration(milliseconds: 320);
  static const double _calorieMin = 0;
  static const double _calorieMax = 1000;
  static const int _ingredientPreviewCount = 10;
  static const int _maxIngredientSuggestions = 8;

  final FirestoreSearchIngredientRepository _ingredientRepository =
      FirestoreSearchIngredientRepository();

  final List<String> _tags = const [
    '#Comfort',
    '#Cooling',
    '#Hydrating',
    '#Light',
    '#Energy',
    '#Warming',
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final Set<String> _selectedIngredients = {};
  final Set<String> _selectedTags = {};

  List<String> _allIngredients = [];
  bool _ingredientsLoading = true;
  bool _usingFallbackIngredients = false;

  bool _showAllIngredients = false;
  bool _matchingPanelWasOpen = false;
  bool _animateMatchingPanelSize = false;
  bool _isCalorieFilterEnabled = false;
  bool _includeHighCalorieMeals = false;
  RangeValues _calorieRange = const RangeValues(200, 600);
  CaloriePreset _activeCaloriePreset = CaloriePreset.balanced;

  @override
  void initState() {
    super.initState();
    _hydrateInitialCriteria();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    setState(() => _ingredientsLoading = true);
    try {
      final names = await _ingredientRepository.fetchActiveIngredientNames();
      if (!mounted) return;
      setState(() {
        if (names.isNotEmpty) {
          _allIngredients = names;
          _usingFallbackIngredients = false;
        } else {
          _allIngredients = _ingredientRepository.fallbackNames();
          _usingFallbackIngredients = true;
        }
        _ingredientsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allIngredients = _ingredientRepository.fallbackNames();
        _usingFallbackIngredients = true;
        _ingredientsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  Color get _designPrimaryColor => ColorPlate.primary;
  Color get _designDisabledColor => ColorPlate.disabled;

  bool get _canExpandIngredients =>
      _allIngredients.length > _ingredientPreviewCount;

  List<String> get _visibleIngredients {
    if (_allIngredients.isEmpty) return const [];
    if (_showAllIngredients) return _allIngredients;
    return _allIngredients.take(_ingredientPreviewCount).toList();
  }

  List<String> get _queryIngredientSuggestions {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return const [];

    return _allIngredients
        .where(
          (name) =>
              !_selectedIngredients.contains(name) &&
              name.toLowerCase().contains(query),
        )
        .take(_maxIngredientSuggestions)
        .toList();
  }

  List<String> get _selectedFiltersInOrder {
    return [
      ..._selectedIngredients,
      ..._selectedTags,
    ];
  }

  void _toggleIngredient(String ingredient) {
    setState(() {
      if (_selectedIngredients.contains(ingredient)) {
        _selectedIngredients.remove(ingredient);
      } else {
        _selectedIngredients.add(ingredient);
      }
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _removeFilterChip(String label) {
    setState(() {
      _selectedIngredients.remove(label);
      _selectedTags.remove(label);
    });
  }

  bool get _hasFilterCriteria =>
      _selectedIngredients.isNotEmpty ||
      _selectedTags.isNotEmpty ||
      _isCalorieFilterEnabled;

  bool _validateBeforeSearch() {
    final query = _searchController.text.trim();
    if (_hasFilterCriteria || query.length >= 2) return true;

    final message = query.isEmpty
        ? 'Enter at least 2 characters, or pick an ingredient, tag, or calorie filter.'
        : 'Enter at least 2 characters to search by title.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    return false;
  }

  Future<void> _onSearchPressed() async {
    if (!_validateBeforeSearch()) return;

    final criteria = SearchCriteria(
      query: _searchController.text.trim(),
      selectedIngredients: _selectedIngredients.toList(),
      selectedTags: _selectedTags.toList(),
      isCalorieFilterEnabled: _isCalorieFilterEnabled,
      calorieMin: _calorieRange.start.round(),
      calorieMax: _calorieRange.end.round(),
      includeHighCalorieMeals: _includeHighCalorieMeals,
    );

    if (widget.editorMode) {
      Navigator.of(context).pop(criteria);
      return;
    }

    final latest = await Navigator.of(context).push<SearchCriteria>(
      MaterialPageRoute<SearchCriteria>(
        builder: (_) => SearchResultPage(initialCriteria: criteria),
      ),
    );
    if (!mounted || latest == null) return;
    _applyCriteria(latest);
  }

  void _hydrateInitialCriteria() {
    final criteria = widget.initialCriteria;
    if (criteria == null) return;
    _applyCriteria(criteria, rebuild: false);
  }

  void _applyCriteria(SearchCriteria criteria, {bool rebuild = true}) {
    _searchController.text = criteria.query;
    _selectedIngredients
      ..clear()
      ..addAll(criteria.selectedIngredients);
    _selectedTags
      ..clear()
      ..addAll(criteria.selectedTags);
    _isCalorieFilterEnabled = criteria.isCalorieFilterEnabled;
    _includeHighCalorieMeals = criteria.includeHighCalorieMeals;
    _calorieRange =
        RangeValues(criteria.calorieMin.toDouble(), criteria.calorieMax.toDouble());

    if (criteria.calorieMin == 0 && criteria.calorieMax == 299) {
      _activeCaloriePreset = CaloriePreset.low;
    } else if (criteria.calorieMin == 300 && criteria.calorieMax == 600) {
      _activeCaloriePreset = CaloriePreset.balanced;
    } else if (criteria.calorieMin == 601 && criteria.calorieMax == _calorieMax) {
      _activeCaloriePreset = CaloriePreset.high;
    } else {
      _activeCaloriePreset = CaloriePreset.custom;
    }
    if (rebuild) setState(() {});
  }

  void _applyCaloriePreset(CaloriePreset preset) {
    setState(() {
      _activeCaloriePreset = preset;
      switch (preset) {
        case CaloriePreset.low:
          _calorieRange = const RangeValues(0, 299);
          break;
        case CaloriePreset.balanced:
          _calorieRange = const RangeValues(300, 600);
          break;
        case CaloriePreset.high:
          _calorieRange = const RangeValues(601, _calorieMax);
          break;
        case CaloriePreset.custom:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnimatedIngredientSuggestions(),
                    _buildIngredientsSection(),
                    const SizedBox(height: 24),
                    _buildTagsSection(),
                    const SizedBox(height: 24),
                    _buildCaloriesSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          Expanded(child: _buildSearchInputArea()),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.search),
            color: _designPrimaryColor,
            onPressed: _onSearchPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInputArea() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _designDisabledColor,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.search,
                  size: 20,
                  color: _designDisabledColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildSearchTextField(),
                ),
              ],
            ),
            if (_selectedFiltersInOrder.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedFiltersInOrder
                    .map(
                      (label) => _SelectedFilterChip(
                        label: label,
                        onRemove: () => _removeFilterChip(label),
                        primaryColor: _designPrimaryColor,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTextField() {
    final hasText = _searchController.text.isNotEmpty;

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        if (!hasText)
          IgnorePointer(
            child: Text(
              'Search something...',
              style: TextStyle(
                color: _designDisabledColor,
                fontSize: 14,
              ),
            ),
          ),
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            fontSize: 14,
          ),
          cursorColor: _designPrimaryColor,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (_) {
            final open = _queryIngredientSuggestions.isNotEmpty;
            setState(() {
              _animateMatchingPanelSize = open != _matchingPanelWasOpen;
              _matchingPanelWasOpen = open;
            });
          },
          onSubmitted: (_) => _onSearchPressed(),
        ),
      ],
    );
  }

  Widget _buildAnimatedIngredientSuggestions() {
    final suggestions = _queryIngredientSuggestions;
    final show = suggestions.isNotEmpty;

    final chipsPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Matching ingredients',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _designPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: _softTransitionDuration,
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topLeft,
          child: AnimatedMatchingIngredientChips(
            suggestions: suggestions,
            duration: _softTransitionDuration,
            onSelected: _toggleIngredient,
          ),
        ),
      ],
    );

    final panel = Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: chipsPanel,
    );

    // Only animate height when the panel opens or closes — not on each keystroke.
    if (_animateMatchingPanelSize) {
      return AnimatedSize(
        duration: _softTransitionDuration,
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topLeft,
        child: show ? panel : const SizedBox(width: double.infinity),
      );
    }

    if (!show) {
      return const SizedBox.shrink();
    }

    return panel;
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ingredients',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_canExpandIngredients)
              TextButton(
              onPressed: _ingredientsLoading
                  ? null
                  : () {
                      setState(() {
                        _showAllIngredients = !_showAllIngredients;
                      });
                    },
              child: AnimatedSwitcher(
                duration: _softTransitionDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: child,
                    ),
                  );
                },
                child: Text(
                  _showAllIngredients ? 'Collapse <-' : 'See all ->',
                  key: ValueKey(_showAllIngredients),
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_usingFallbackIngredients && !_ingredientsLoading) ...[
          const SizedBox(height: 4),
          Text(
            'Showing offline ingredient list.',
            style: TextStyle(fontSize: 11, color: _designDisabledColor),
          ),
        ],
        const SizedBox(height: 8),
        if (_ingredientsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_allIngredients.isEmpty)
          Text(
            'No ingredients available.',
            style: TextStyle(fontSize: 13, color: _designDisabledColor),
          )
        else
          AnimatedSize(
            duration: _softTransitionDuration,
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _visibleIngredients
                  .map(
                    (ingredient) => FilterToggleChip(
                      label: ingredient,
                      isSelected: _selectedIngredients.contains(ingredient),
                      primaryColor: _designPrimaryColor,
                      onTap: () => _toggleIngredient(ingredient),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _tags
              .map(
                (tag) => FilterToggleChip(
                  label: tag,
                  isSelected: _selectedTags.contains(tag),
                  primaryColor: _designPrimaryColor,
                  onTap: () => _toggleTag(tag),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCaloriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Calories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorPlate.borderGrey.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                value: _isCalorieFilterEnabled,
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: _designPrimaryColor,
                title: const Text(
                  'Filter by Calories',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onChanged: (value) {
                  setState(() {
                    _isCalorieFilterEnabled = value ?? false;
                  });
                },
              ),
              AnimatedCrossFade(
                duration: _softTransitionDuration,
                firstCurve: Curves.easeOutCubic,
                secondCurve: Curves.easeInCubic,
                crossFadeState: _isCalorieFilterEnabled
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: _buildCalorieControls(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalorieControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _CaloriePresetButton(
              label: 'Low (<300 kcal)',
              isSelected: _activeCaloriePreset == CaloriePreset.low,
              primaryColor: _designPrimaryColor,
              onTap: () => _applyCaloriePreset(CaloriePreset.low),
            ),
            _CaloriePresetButton(
              label: 'Balanced (300-600 kcal)',
              isSelected: _activeCaloriePreset == CaloriePreset.balanced,
              primaryColor: _designPrimaryColor,
              onTap: () => _applyCaloriePreset(CaloriePreset.balanced),
            ),
            _CaloriePresetButton(
              label: 'High (>600 kcal)',
              isSelected: _activeCaloriePreset == CaloriePreset.high,
              primaryColor: _designPrimaryColor,
              onTap: () => _applyCaloriePreset(CaloriePreset.high),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '${_calorieRange.start.round()} kcal - ${_calorieRange.end.round()} kcal',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _designPrimaryColor,
            inactiveTrackColor: _designPrimaryColor.withOpacity(0.25),
            thumbColor: _designPrimaryColor,
            overlayColor: _designPrimaryColor.withOpacity(0.12),
            rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
          ),
          child: RangeSlider(
            min: _calorieMin,
            max: _calorieMax,
            divisions: 100,
            values: _calorieRange,
            labels: RangeLabels(
              '${_calorieRange.start.round()}',
              '${_calorieRange.end.round()}',
            ),
            onChanged: (values) {
              setState(() {
                _calorieRange = values;
                _activeCaloriePreset = CaloriePreset.custom;
              });
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_calorieRange.start.round()} kcal',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ColorPlate.textSecondary,
              ),
            ),
            Text(
              '${_calorieRange.end.round()} kcal',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ColorPlate.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _includeHighCalorieMeals,
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: _designPrimaryColor,
          title: const Text(
            'Include high-calorie meals (>1000 kcal)',
            style: TextStyle(fontSize: 14),
          ),
          onChanged: (value) {
            setState(() {
              _includeHighCalorieMeals = value ?? false;
            });
          },
        ),
      ],
    );
  }
}

enum CaloriePreset { low, balanced, high, custom }

class FilterToggleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;

  const FilterToggleChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? primaryColor : Colors.transparent;
    final borderColor = primaryColor;
    final textColor = isSelected ? Colors.white : primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _SearchPageState._softTransitionDuration,
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: AnimatedDefaultTextStyle(
          duration: _SearchPageState._softTransitionDuration,
          curve: Curves.easeInOutCubic,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _SelectedFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final Color primaryColor;

  const _SelectedFilterChip({
    required this.label,
    required this.onRemove,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: primaryColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 16,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaloriePresetButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;

  const _CaloriePresetButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor =
        isSelected ? primaryColor : primaryColor.withOpacity(0.06);
    final Color textColor = isSelected ? Colors.white : primaryColor;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: _SearchPageState._softTransitionDuration,
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primaryColor, width: 1),
        ),
        child: AnimatedDefaultTextStyle(
          duration: _SearchPageState._softTransitionDuration,
          curve: Curves.easeInOutCubic,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/models/tag_item.dart';
import 'package:tastie/repositories/mock_tag_repository.dart';
import 'package:tastie/widgets/photo_upload_row.dart';
import 'package:tastie/widgets/primary_button.dart';
import 'package:tastie/widgets/tag_list_scroll.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  static const int _maxPhotos = 6;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final List<IngredientItem> _ingredients = const [
    IngredientItem(name: 'Sugar', amount: '200', unit: 'g'),
    IngredientItem(name: 'Butter', amount: '500', unit: 'g'),
    IngredientItem(name: 'Egg', amount: '1', unit: 'pcs'),
  ];

  final MockTagRepository _tagRepository = const MockTagRepository();
  List<TagItem> _tags = const [];
  bool _isLoadingTags = false;
  String? _tagError;

  List<XFile> _photos = const [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Get.back<void>(),
                  ),
                  PrimaryButton(
                    text: 'Post',
                    onPressed: () {
                      // TODO: integrate submit logic
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post Coming Soon')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PhotoUploadRow(
                    maxPhotos: _maxPhotos,
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
                          const TextStyle(
                            fontSize: 12,
                            color: Color(0xff999999),
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                maxLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Placeholder for Title',
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xffD9D9D9)),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xffD9D9D9)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: ColorPlate.primary),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _contentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Placeholder for Content',
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xffD9D9D9)),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xffD9D9D9)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: ColorPlate.primary),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              _buildTagSection(theme),
              const SizedBox(height: 32),
              Text(
                'Ingredients',
                style:
                    theme.textTheme.titleMedium ??
                    ColorPlate.heading2.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),
              _buildIngredientList(theme),
            ],
          ),
        ),
      ),
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

  Widget _buildIngredientList(ThemeData theme) {
    return Column(
      children: _ingredients
          .map(
            (item) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style:
                            theme.textTheme.bodyMedium ??
                            ColorPlate.bodyText.copyWith(fontSize: 16),
                      ),
                    ),
                    Text(
                      '${item.amount} ${item.unit}',
                      style:
                          theme.textTheme.bodyMedium ??
                          ColorPlate.bodyText.copyWith(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xffD9D9D9), height: 1),
                const SizedBox(height: 8),
              ],
            ),
          )
          .toList(),
    );
  }
}

class IngredientItem {
  final String name;
  final String amount;
  final String unit;

  const IngredientItem({
    required this.name,
    required this.amount,
    required this.unit,
  });
}

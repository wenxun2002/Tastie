import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tastie/constants/color_plate.dart';

class PhotoUploadRow extends StatefulWidget {
  final int maxPhotos;
  final List<XFile> initialPhotos;
  final ValueChanged<List<XFile>>? onChanged;

  const PhotoUploadRow({
    super.key,
    this.maxPhotos = 6,
    this.initialPhotos = const [],
    this.onChanged,
  });

  @override
  State<PhotoUploadRow> createState() => _PhotoUploadRowState();
}

class _PhotoUploadRowState extends State<PhotoUploadRow> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];

  @override
  void initState() {
    super.initState();
    _photos
      ..clear()
      ..addAll(widget.initialPhotos);
  }

  @override
  void didUpdateWidget(covariant PhotoUploadRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep in sync with parent-controlled state.
    if (!listEquals(oldWidget.initialPhotos, widget.initialPhotos)) {
      _photos
        ..clear()
        ..addAll(widget.initialPhotos);
    }
  }

  Future<void> _pickImages() async {
    if (_photos.length >= widget.maxPhotos) return;
    final remaining = widget.maxPhotos - _photos.length;
    final List<XFile> images = await _picker.pickMultiImage(
      imageQuality: 85,
    );
    if (images.isEmpty) return;
    final picked = images.take(remaining).toList(growable: false);
    if (!mounted) return;
    setState(() => _photos.addAll(picked));
    widget.onChanged?.call(List.unmodifiable(_photos));
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [
      for (final entry in _photos.asMap().entries) ...[
        GestureDetector(
          onTap: () => _showPhotoOptions(entry.key),
          child: PhotoUploadButton(image: entry.value),
        ),
        const SizedBox(width: 12),
      ],
      if (_photos.length < widget.maxPhotos)
        PhotoUploadButton(
          onTap: _pickImages,
        ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }

  Future<void> _showPhotoOptions(int index) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Replace Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _replacePhoto(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto(index);
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  Future<void> _replacePhoto(int index) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null && mounted) {
      setState(() => _photos[index] = image);
      widget.onChanged?.call(List.unmodifiable(_photos));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
    widget.onChanged?.call(List.unmodifiable(_photos));
  }
}

class PhotoUploadButton extends StatefulWidget {
  final XFile? image;
  final VoidCallback? onTap;
  final double size;

  const PhotoUploadButton({
    super.key,
    this.image,
    this.onTap,
    this.size = 80,
  });

  @override
  State<PhotoUploadButton> createState() => _PhotoUploadButtonState();
}

class _PhotoUploadButtonState extends State<PhotoUploadButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (widget.image != null) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.image != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _buildImage(widget.image!),
      );
    }

    final Color backgroundColor =
        _isPressed ? ColorPlate.secondary : Colors.white;
    final Color iconColor =
        _isPressed ? Colors.white : ColorPlate.primary;
    final BoxBorder? border = _isPressed
        ? null
        : Border.all(color: ColorPlate.primary, width: 1);

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        child: Icon(
          Icons.add,
          color: iconColor,
          size: widget.size * 0.4,
        ),
      ),
    );
  }

  Widget _buildImage(XFile file) {
    final double dimension = widget.size;
    if (kIsWeb) {
      return Image.network(
        file.path,
        width: dimension,
        height: dimension,
        fit: BoxFit.cover,
      );
    }
    return Image.file(
      File(file.path),
      width: dimension,
      height: dimension,
      fit: BoxFit.cover,
    );
  }
}


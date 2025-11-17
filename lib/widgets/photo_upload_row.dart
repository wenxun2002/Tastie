import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tastie/constants/color_plate.dart';

class PhotoUploadRow extends StatefulWidget {
  final int maxPhotos;
  final ValueChanged<List<XFile>>? onChanged;

  const PhotoUploadRow({
    super.key,
    this.maxPhotos = 6,
    this.onChanged,
  });

  @override
  State<PhotoUploadRow> createState() => _PhotoUploadRowState();
}

class _PhotoUploadRowState extends State<PhotoUploadRow> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];

  Future<void> _pickImage() async {
    if (_photos.length >= widget.maxPhotos) return;
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _photos.add(image));
      widget.onChanged?.call(List.unmodifiable(_photos));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [
      for (final photo in _photos) ...[
        PhotoUploadButton(image: photo),
        const SizedBox(width: 12),
      ],
      if (_photos.length < widget.maxPhotos)
        PhotoUploadButton(
          onTap: _pickImage,
        ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
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


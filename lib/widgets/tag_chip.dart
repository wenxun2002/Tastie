import 'package:flutter/material.dart';
import 'package:tastie/constants/color_plate.dart';

class TagChip extends StatelessWidget {
  final String label;
  final bool isEnabled;
  final VoidCallback? onTap;

  const TagChip({
    super.key,
    required this.label,
    this.isEnabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = isEnabled;
    final Color backgroundColor =
        enabled ? ColorPlate.secondary : const Color(0xffBDBDBD);
    final Color textColor = enabled ? ColorPlate.primary : Colors.white;
    final BoxBorder? border =
        enabled ? Border.all(color: ColorPlate.primary, width: 1) : null;

    final TextStyle baseStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle(fontSize: 14);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        child: Text(
          '#$label',
          style: baseStyle.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}


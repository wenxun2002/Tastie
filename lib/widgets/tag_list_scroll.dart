import 'package:flutter/material.dart';
import 'package:tastie/models/tag_item.dart';

import 'tag_chip.dart';

class TagListScroll extends StatelessWidget {
  final List<TagItem> tags;
  final ValueChanged<int>? onTagTap;
  final double spacing;

  const TagListScroll({
    super.key,
    required this.tags,
    this.onTagTap,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < tags.length; i++) ...[
            TagChip(
              label: tags[i].label,
              isEnabled: tags[i].isEnabled,
              onTap: onTagTap == null ? null : () => onTagTap!(i),
            ),
            if (i != tags.length - 1) SizedBox(width: spacing),
          ],
        ],
      ),
    );
  }
}

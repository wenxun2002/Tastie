import 'package:fade_shimmer/fade_shimmer.dart';
import 'package:flutter/material.dart';

class CardItemSkeleton extends StatelessWidget {
  const CardItemSkeleton({super.key, this.millisecondsDelay = 0});

  final int millisecondsDelay;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                // approximate cover height for waterfall card
                final h = w * 0.9;
                return ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                  child: FadeShimmer(
                    width: w,
                    height: h,
                    radius: 0,
                    fadeTheme: FadeTheme.light,
                    millisecondsDelay: millisecondsDelay,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeShimmer(
                    width: 120,
                    height: 10,
                    radius: 4,
                    fadeTheme: FadeTheme.light,
                    millisecondsDelay: millisecondsDelay + 150,
                  ),
                  const SizedBox(height: 6),
                  FadeShimmer(
                    width: 80,
                    height: 10,
                    radius: 4,
                    fadeTheme: FadeTheme.light,
                    millisecondsDelay: millisecondsDelay + 300,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Row(
                children: [
                  FadeShimmer.round(
                    size: 20,
                    fadeTheme: FadeTheme.light,
                    millisecondsDelay: millisecondsDelay + 450,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FadeShimmer(
                      width: double.infinity,
                      height: 10,
                      radius: 4,
                      fadeTheme: FadeTheme.light,
                      millisecondsDelay: millisecondsDelay + 600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FadeShimmer(
                    width: 18,
                    height: 10,
                    radius: 4,
                    fadeTheme: FadeTheme.light,
                    millisecondsDelay: millisecondsDelay + 750,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


import 'package:fade_shimmer/fade_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:tastie/constants/color_plate.dart';

class IndexDetailSkeleton extends StatelessWidget {
  const IndexDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPlate.backgroundWhite,
      appBar: AppBar(
        title: Row(
          children: [
            FadeShimmer.round(
              size: 38,
              fadeTheme: FadeTheme.light,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FadeShimmer(
                width: double.infinity,
                height: 12,
                radius: 4,
                fadeTheme: FadeTheme.light,
                millisecondsDelay: 150,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FadeShimmer(
              width: 64,
              height: 24,
              radius: 20,
              fadeTheme: FadeTheme.light,
              millisecondsDelay: 300,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image area skeleton
                  AspectRatio(
                    aspectRatio: 3 / 4,
                    child: FadeShimmer(
                      width: double.infinity,
                      height: double.infinity,
                      radius: 0,
                      fadeTheme: FadeTheme.light,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeShimmer(
                          width: 180,
                          height: 14,
                          radius: 4,
                          fadeTheme: FadeTheme.light,
                          millisecondsDelay: 150,
                        ),
                        const SizedBox(height: 8),
                        FadeShimmer(
                          width: double.infinity,
                          height: 10,
                          radius: 4,
                          fadeTheme: FadeTheme.light,
                          millisecondsDelay: 250,
                        ),
                        const SizedBox(height: 6),
                        FadeShimmer(
                          width: double.infinity,
                          height: 10,
                          radius: 4,
                          fadeTheme: FadeTheme.light,
                          millisecondsDelay: 350,
                        ),
                        const SizedBox(height: 6),
                        FadeShimmer(
                          width: 140,
                          height: 10,
                          radius: 4,
                          fadeTheme: FadeTheme.light,
                          millisecondsDelay: 450,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(
                            4,
                            (index) => FadeShimmer(
                              width: 70,
                              height: 20,
                              radius: 10,
                              fadeTheme: FadeTheme.light,
                              millisecondsDelay: 500 + index * 80,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeShimmer(
                          width: 200,
                          height: 10,
                          radius: 4,
                          fadeTheme: FadeTheme.light,
                          millisecondsDelay: 600,
                        ),
                      ],
                    ),
                  ),
                  // Use fixed space instead of Spacer - Spacer requires bounded height
                  // (Column is inside SingleChildScrollView which has unbounded height)
                  const SizedBox(height: 24),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FadeShimmer(
                            width: 200,
                            height: 36,
                            radius: 20,
                            fadeTheme: FadeTheme.light,
                            millisecondsDelay: 700,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


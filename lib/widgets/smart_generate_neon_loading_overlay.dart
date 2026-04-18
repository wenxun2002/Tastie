import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen dim scrim + soft ambient rainbow edge glow.
class SmartGenerateNeonLoadingOverlay extends StatefulWidget {
  const SmartGenerateNeonLoadingOverlay({
    super.key,
    required this.centerChild,
  });

  final Widget centerChild;

  @override
  State<SmartGenerateNeonLoadingOverlay> createState() =>
      _SmartGenerateNeonLoadingOverlayState();
}

class _SmartGenerateNeonLoadingOverlayState
    extends State<SmartGenerateNeonLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.black.withValues(alpha: 0.42)),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _NeonAuraPainter(_controller.value),
                child: const SizedBox.expand(),
              );
            },
          ),
          Center(child: widget.centerChild),
        ],
      ),
    );
  }
}

class _NeonAuraPainter extends CustomPainter {
  _NeonAuraPainter(this.t);
  final double t;

  static const List<Color> _colors = [
    Color(0xFF00F5FF),
    Color(0xFF7B2CBF),
    Color(0xFFFF006E),
    Color(0xFFFFBE0B),
    Color(0xFF00F5FF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final breath = 0.5 + 0.5 * math.sin(t * math.pi * 2);
    final drift = 0.5 + 0.5 * math.sin(t * math.pi * 2 + 0.9);

    // Push the ring close to screen edge; render with heavy blur so it feels
    // like ambient light bleeding out from the device, not a hard border.
    final inset = -6.0 + 3.0 * drift;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - 2 * inset,
      size.height - 2 * inset,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(38));

    final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
    final sweep = SweepGradient(
      colors: _colors,
      stops: const [0.0, 0.22, 0.48, 0.72, 1.0],
      transform: GradientRotation(t * math.pi * 2),
    ).createShader(bounds);

    final outerGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 46 + 14 * breath
      ..shader = sweep
      ..color = Colors.white.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);

    final innerMist = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24 + 8 * drift
      ..shader = sweep
      ..color = Colors.white.withValues(alpha: 0.11)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);

    canvas.drawRRect(rrect, outerGlow);
    canvas.drawRRect(rrect, innerMist);
  }

  @override
  bool shouldRepaint(covariant _NeonAuraPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

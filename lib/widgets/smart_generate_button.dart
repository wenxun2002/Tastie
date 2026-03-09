import 'package:flutter/material.dart';

class SmartGenerateButton extends StatelessWidget {
  const SmartGenerateButton({
    super.key,
    this.onTap,
    this.text = 'Smart Generate',
  });

  final VoidCallback? onTap;
  final String text;

  @override
  Widget build(BuildContext context) {
    final Gradient gradient = const LinearGradient(
      colors: [
        Color(0xff8B5CF6),
        Color(0xffEC4899),
        Color(0xffF59E0B),
        Color(0xff22D3EE),
      ],
    );
return Align(
  alignment: Alignment.centerRight,
  child: GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.5),
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => gradient.createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Text(
                text,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ) ??
                    const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}


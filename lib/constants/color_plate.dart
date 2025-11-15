import 'package:flutter/material.dart';

class ColorPlate {
  // Primary color - Main brand color
  static const Color primary = Color(0xffE23E3E);

  // Secondary color - Light variant of primary
  static const Color secondary = Color(0xffF9D8D8);

  // Disabled color - For disabled states
  static const Color disabled = Color(0xffD9D9D9);

  // Text colors
  static const Color textPrimary = Color(0xff333333); // 主要文字颜色
  static const Color textSecondary = Color(0xff666666); // 次要文字颜色
  static const Color textTertiary = Color(0xff999999); // 第三级文字颜色（如日期、地址）
  static const Color textGrey = Color(0xffd3d3d3); // 灰色文字

  // Background colors
  static const Color background = Color(0xfff3f3f3); // 背景色
  static const Color backgroundWhite = Colors.white; // 白色背景

  // Border colors
  static const Color borderGrey = Color(0xffd3d3d3); // 边框灰色

  // Text Styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );

  static const TextStyle bodyTextSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textTertiary,
  );

  static const TextStyle tagText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: primary,
  );
}

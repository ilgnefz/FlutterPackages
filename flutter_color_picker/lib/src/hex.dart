import 'package:material_ui/material_ui.dart';

/// hex 文本的两种写法。
///
/// 面板只处理不透明的颜色，两种写法都不带 alpha 变化。
enum ColorHexFormat {
  /// `#RRGGBB`：设计稿、CSS 的习惯写法（默认）。
  hashRgb,

  /// `0xFFRRGGBB`：Flutter 代码里的 ARGB 字面量，可以直接粘进 `Color(...)`。
  flutterArgb,
}

/// 把颜色转成 hex 文本（丢掉 alpha）。
///
/// ```dart
/// colorToHex(const Color(0xFF2B7FFF));                                    // #2B7FFF
/// colorToHex(const Color(0xFF2B7FFF), format: ColorHexFormat.flutterArgb); // 0xFF2B7FFF
/// ```
String colorToHex(
  Color color, {
  ColorHexFormat format = ColorHexFormat.hashRgb,
}) {
  final int rgb = color.toARGB32() & 0xFFFFFF;
  final String hex = rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
  return switch (format) {
    ColorHexFormat.hashRgb => '#$hex',
    ColorHexFormat.flutterArgb => '0xFF$hex',
  };
}

/// 解析 hex 文本；不合法返回 `null`。
///
/// 支持：
/// * `#RGB`、`#RRGGBB`、`RRGGBB`、`#RRGGBBAA`（CSS 写法，八位按 RGBA 理解）；
/// * `0xRRGGBB`、`0xAARRGGBB`（Flutter 字面量，`0x` 前缀可有可无大小写）。
///
/// 面板里没有 alpha 通道，所以任何写法都**只取 RGB**、统一按不透明处理。
Color? parseHexColor(String raw) {
  String text = raw.trim();
  if (text.isEmpty) return null;

  // Flutter 写法：0xAARRGGBB / 0xRRGGBB。alpha 直接丢掉。
  if (text.length > 2 && (text.startsWith('0x') || text.startsWith('0X'))) {
    text = text.substring(2);
    if (text.length != 6 && text.length != 8) return null;
    final int? value = int.tryParse(text, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | (value & 0xFFFFFF));
  }

  if (text.startsWith('#')) text = text.substring(1);
  if (text.isEmpty) return null;
  if (text.length == 3) {
    // #RGB 也是合法的三位写法，展开成六位。
    text = text.split('').map((String ch) => '$ch$ch').join();
  }
  if (text.length != 6 && text.length != 8) return null;
  final int? value = int.tryParse(text, radix: 16);
  if (value == null) return null;
  // 八位写法按 CSS 的 #RRGGBBAA 理解；面板没有透明度，只取它的 RGB。
  final int rgb = text.length == 8 ? value >> 8 : value;
  return Color(0xFF000000 | rgb);
}

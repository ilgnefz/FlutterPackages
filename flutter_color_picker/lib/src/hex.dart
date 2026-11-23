import 'package:material_ui/material_ui.dart';

/// hex 文本的两种写法。
///
/// 带 alpha 时两种写法各自沿用自己那套约定：CSS 的 `#RRGGBBAA` 把 alpha 放在
/// **末尾**，Flutter 字面量 `0xAARRGGBB` 放在**开头**。
enum ColorHexFormat {
  /// `#RRGGBB`：设计稿、CSS 的习惯写法（默认）；带 alpha 时是 `#RRGGBBAA`。
  hashRgb,

  /// `0xFFRRGGBB`：Flutter 代码里的 ARGB 字面量，可以直接粘进 `Color(...)`；
  /// 带 alpha 时是 `0xAARRGGBB`。
  flutterArgb,
}

/// 把颜色转成 hex 文本。
///
/// 默认**丢掉 alpha**（面板默认不处理透明度），[includeAlpha] 为 true 时按各自
/// 格式的约定把 alpha 写进去。
///
/// ```dart
/// colorToHex(const Color(0x802B7FFF));                        // #2B7FFF
/// colorToHex(const Color(0x802B7FFF), includeAlpha: true);     // #2B7FFF80
/// colorToHex(
///   const Color(0x802B7FFF),
///   includeAlpha: true,
///   format: ColorHexFormat.flutterArgb,
/// );                                                          // 0x802B7FFF
/// ```
String colorToHex(
  Color color, {
  ColorHexFormat format = ColorHexFormat.hashRgb,
  bool includeAlpha = false,
}) {
  final int argb = color.toARGB32();
  final String rgb = (argb & 0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0')
      .toUpperCase();
  final String alpha = ((argb >> 24) & 0xFF)
      .toRadixString(16)
      .padLeft(2, '0')
      .toUpperCase();
  return switch (format) {
    ColorHexFormat.hashRgb => includeAlpha ? '#$rgb$alpha' : '#$rgb',
    ColorHexFormat.flutterArgb => '0x${includeAlpha ? alpha : 'FF'}$rgb',
  };
}

/// 解析 hex 文本；不合法返回 `null`。
///
/// 支持：
/// * `#RGB`、`#RRGGBB`、`RRGGBB`、`#RRGGBBAA`（CSS 写法，八位按 RGBA 理解）；
/// * `0xRRGGBB`、`0xAARRGGBB`（Flutter 字面量，`0x` 前缀可有可无大小写）。
///
/// 默认（[includeAlpha] 为 false）只取 RGB、统一按不透明处理——面板默认没有
/// 透明度概念。传 `includeAlpha: true` 时保留输入里写的 alpha（六位 / 三位
/// 写法本身不带 alpha，仍按不透明处理）。
///
/// ```dart
/// parseHexColor('#2B7FFF80');                        // 0xFF2B7FFF（丢掉 alpha）
/// parseHexColor('#2B7FFF80', includeAlpha: true);     // 0x802B7FFF
/// parseHexColor('0x802B7FFF', includeAlpha: true);    // 0x802B7FFF
/// ```
Color? parseHexColor(String raw, {bool includeAlpha = false}) {
  String text = raw.trim();
  if (text.isEmpty) return null;

  // Flutter 写法：0xAARRGGBB / 0xRRGGBB。
  if (text.length > 2 && (text.startsWith('0x') || text.startsWith('0X'))) {
    text = text.substring(2);
    if (text.length != 6 && text.length != 8) return null;
    final int? value = int.tryParse(text, radix: 16);
    if (value == null) return null;
    // 六位没有 alpha 位，按不透明；八位是 AARRGGBB。
    if (text.length == 6) return Color(0xFF000000 | value);
    return includeAlpha ? Color(value) : Color(0xFF000000 | (value & 0xFFFFFF));
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
  if (text.length == 6) return Color(0xFF000000 | value);
  // 八位写法按 CSS 的 #RRGGBBAA 理解：alpha 在末尾。
  final int rgb = value >> 8;
  if (!includeAlpha) return Color(0xFF000000 | rgb);
  return Color(((value & 0xFF) << 24) | rgb);
}

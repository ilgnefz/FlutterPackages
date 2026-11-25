import 'package:material_ui/material_ui.dart';

/// 展开箭头在行里的位置。
///
/// * [leading] —— 经典树：箭头在最左边，靠缩进体现层级（`TreeView` 默认）；
/// * [trailing] —— 勾选树：左边是 checkbox，箭头靠右（`TreeView.checkbox`
///   默认），父级一眼看过去就是「checkbox + 文字 …… 箭头」。
enum TreeArrowPlacement { leading, trailing }

/// 树的全部外观。
///
/// 不传时 [TreeView] 取 [TreeViewStyle.of]，按 [ThemeData.brightness] 在
/// 浅 / 深配色之间自动切换；只改几项用 [copyWith]：
///
/// ```dart
/// TreeView(nodes: nodes, style: TreeViewStyle.of(context).copyWith(
///   rowHeight: 28,
///   indent: 14,
///   arrowPlacement: TreeArrowPlacement.trailing,
/// ))
/// ```
@immutable
class TreeViewStyle {
  const TreeViewStyle({
    this.rowHeight = 30.0,
    this.indent = 16.0,
    this.panelRadius = 12.0,
    this.radius = 6.0,
    this.padding = const EdgeInsets.all(4.0),
    this.rowPadding = const EdgeInsets.symmetric(horizontal: 6.0),
    this.fontSize = 13.0,
    this.arrowSize = 16.0,
    this.arrowGap = 2.0,
    this.checkboxSize = 14.0,
    this.checkboxRadius = 4.0,
    this.checkboxGap = 8.0,
    this.iconSize = 15.0,
    this.iconGap = 6.0,
    this.borderWidth = 1.0,
    this.arrowIcon = Icons.chevron_right,
    this.checkIcon = Icons.check,
    this.backgroundColor,
    this.borderColor,
    this.hoverColor = const Color(0xFFF4F4F5),
    this.selectedColor = const Color(0xFFE8F0FF),
    this.foreground = const Color(0xFF18181B),
    this.muted = const Color(0xFFA1A1AA),
    this.disabledColor = const Color(0xFFA1A1AA),
    this.accent = const Color(0xFF2B7FFF),
    this.onAccent = Colors.white,
    this.checkboxBorderColor = const Color(0xFFC4C4CC),
    this.scrollbarThickness = 4.0,
    this.textStyle,
  });

  /// 浅色配色（默认）。
  static TreeViewStyle light() => const TreeViewStyle();

  /// 深色配色。
  static TreeViewStyle dark() => const TreeViewStyle(
    backgroundColor: null,
    borderColor: Color(0xFF49454F),
    hoverColor: Color(0xFF2A2830),
    selectedColor: Color(0xFF243A5E),
    foreground: Color(0xFFE6E1E5),
    muted: Color(0xFF8E8B96),
    disabledColor: Color(0xFF6B6875),
    accent: Color(0xFF6BA6FF),
    onAccent: Color(0xFF0B1B33),
    checkboxBorderColor: Color(0xFF5C5866),
  );

  /// 按当前 [ThemeData.brightness] 取浅 / 深配色。
  static TreeViewStyle of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark() : light();

  TreeViewStyle copyWith({
    double? rowHeight,
    double? indent,
    double? panelRadius,
    double? radius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? rowPadding,
    double? fontSize,
    double? arrowSize,
    double? arrowGap,
    double? checkboxSize,
    double? checkboxRadius,
    double? checkboxGap,
    double? iconSize,
    double? iconGap,
    double? borderWidth,
    IconData? arrowIcon,
    IconData? checkIcon,
    Color? backgroundColor,
    Color? borderColor,
    Color? hoverColor,
    Color? selectedColor,
    Color? foreground,
    Color? muted,
    Color? disabledColor,
    Color? accent,
    Color? onAccent,
    Color? checkboxBorderColor,
    double? scrollbarThickness,
    TextStyle? textStyle,
  }) => TreeViewStyle(
    rowHeight: rowHeight ?? this.rowHeight,
    indent: indent ?? this.indent,
    panelRadius: panelRadius ?? this.panelRadius,
    radius: radius ?? this.radius,
    padding: padding ?? this.padding,
    rowPadding: rowPadding ?? this.rowPadding,
    fontSize: fontSize ?? this.fontSize,
    arrowSize: arrowSize ?? this.arrowSize,
    arrowGap: arrowGap ?? this.arrowGap,
    checkboxSize: checkboxSize ?? this.checkboxSize,
    checkboxRadius: checkboxRadius ?? this.checkboxRadius,
    checkboxGap: checkboxGap ?? this.checkboxGap,
    iconSize: iconSize ?? this.iconSize,
    iconGap: iconGap ?? this.iconGap,
    borderWidth: borderWidth ?? this.borderWidth,
    arrowIcon: arrowIcon ?? this.arrowIcon,
    checkIcon: checkIcon ?? this.checkIcon,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    borderColor: borderColor ?? this.borderColor,
    hoverColor: hoverColor ?? this.hoverColor,
    selectedColor: selectedColor ?? this.selectedColor,
    foreground: foreground ?? this.foreground,
    muted: muted ?? this.muted,
    disabledColor: disabledColor ?? this.disabledColor,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    checkboxBorderColor: checkboxBorderColor ?? this.checkboxBorderColor,
    scrollbarThickness: scrollbarThickness ?? this.scrollbarThickness,
    textStyle: textStyle ?? this.textStyle,
  );

  /// 行高。
  final double rowHeight;

  /// 每层缩进宽度。
  final double indent;

  /// 外层容器的圆角（配了 [backgroundColor] / [borderColor] 时才看得出来）。
  final double panelRadius;

  /// 行高亮圆角。
  final double radius;

  /// 行列表到容器边缘的内边距。
  final EdgeInsetsGeometry padding;

  /// 行内容到行外框的内边距。
  final EdgeInsetsGeometry rowPadding;

  /// 行文字字号；[textStyle] 里给了就用 [textStyle] 的。
  final double fontSize;

  /// 展开箭头大小。
  final double arrowSize;

  /// 箭头与相邻内容的间距。箭头占位恒为 `arrowSize + arrowGap`，叶子行不会
  /// 因此错位。
  final double arrowGap;

  /// checkbox 边长。
  final double checkboxSize;

  /// checkbox 圆角。
  final double checkboxRadius;

  /// checkbox 与文字之间的距离。
  final double checkboxGap;

  /// 行首图标（[TreeNode.leading]）的尺寸与右边距。
  final double iconSize;
  final double iconGap;

  /// 容器边框宽度。
  final double borderWidth;

  /// 展开箭头图标与勾选图标。箭头靠 [AnimatedRotation] 转 90° 表示展开。
  final IconData arrowIcon;
  final IconData checkIcon;

  /// 容器背景；为 null 时不铺底色（放进下拉面板时用，面板自己已经有底色）。
  final Color? backgroundColor;

  /// 容器边框颜色；为 null 时不画边框。
  final Color? borderColor;

  /// 鼠标悬停时的行底色。
  final Color hoverColor;

  /// 单选模式下选中行的底色。
  final Color selectedColor;

  /// 正文 / 箭头颜色。
  final Color foreground;

  /// 次要色：展开箭头、未勾选的 checkbox 边框。
  final Color muted;

  /// 禁用行文字色。
  final Color disabledColor;

  /// 勾选态主色：勾选后的 checkbox 底色。
  final Color accent;

  /// 勾选后勾 / 横线的颜色。
  final Color onAccent;

  /// 未勾选时 checkbox 的边框色。
  final Color checkboxBorderColor;

  /// 滚动条厚度。桌面 / Web 上 [Scrollbar] 默认是 8，离行尾箭头太近容易
  /// 误触，这里默认收窄到 4。
  ///
  /// 想再拉开一点距离，可以配合加大 [rowPadding] 的 right。
  final double scrollbarThickness;

  /// 行文字样式；为 null 时用 `fontSize + foreground`。给了颜色就以这里为准。
  final TextStyle? textStyle;
}

part of 'anchored_dropdown.dart';

// ── 公开类型 ──────────────────────────────────────────────────────────────

/// 下拉列表相对触发组件的**水平**对齐方式。
///
/// [left] / [center] / [right] 是物理方向；[start] / [end] 会按当前
/// [Directionality] 解析成物理方向（RTL 下自动镜像）。垂直方向始终由
/// 剩余空间自动决定（下方不够就翻到上方），不在这里配置。
enum DropdownAlignment {
  /// 列表左边缘与触发器左边缘对齐。
  left,

  /// 列表水平中心与触发器水平中心对齐。
  center,

  /// 列表右边缘与触发器右边缘对齐。
  right,

  /// LTR 等价于 [left]，RTL 等价于 [right]。
  start,

  /// LTR 等价于 [right]，RTL 等价于 [left]。
  end,
}

/// 列表的揭示动画。三种都基于同一个进度值 p，且都用「完整圆角外框 ∩
/// 可见区域」求交，所以四个圆角在任何一帧都保持 [DropdownStyle.radius]。
enum DropdownReveal {
  /// 原版：从贴着触发器的一条薄边开始，沿垂直方向把列表揭开。
  /// 下方展开时从上往下，翻到上方时从下往上。
  unfold,

  /// 从左上角沿对角线向右下角扫开（斜向擦除）。
  topLeftToBottomRight,

  /// 从右上角沿对角线向左下角扫开（斜向擦除）。
  topRightToBottomLeft,
}

/// 下拉列表的宽度策略。触发组件与列表宽度可以不同。
///
/// ```dart
/// const DropdownWidth.matchTrigger()   // 与触发器同宽（默认）
/// const DropdownWidth.fixed(280)       // 固定宽度
/// ```
@immutable
class DropdownWidth {
  /// 与触发组件保持一致；宽度由运行时测量触发组件得到。
  const DropdownWidth.matchTrigger() : _fixed = null;

  /// 固定宽度，与触发组件宽度无关。
  const DropdownWidth.fixed(double width)
    : assert(width > 0, 'DropdownWidth.fixed: width must be > 0'),
      _fixed = width;

  final double? _fixed;

  /// 是否是「与触发器同宽」模式。
  bool get matchesTrigger => _fixed == null;

  /// 配置的固定宽度；[matchesTrigger] 为 true 时是 null。
  double? get fixedWidth => _fixed;

  /// 由触发组件宽度解析出最终列表宽度。触发组件还没完成布局时给一个
  /// 兜底宽度，避免第一帧出现 0 宽的面板。
  double resolve(double triggerWidth) =>
      _fixed ?? (triggerWidth > 0 ? triggerWidth : kDropdownFallbackWidth);

  @override
  bool operator ==(Object other) =>
      other is DropdownWidth && other._fixed == _fixed;

  @override
  int get hashCode => _fixed.hashCode;

  @override
  String toString() => _fixed == null
      ? 'DropdownWidth.matchTrigger()'
      : 'DropdownWidth.fixed($_fixed)';
}

/// 一个选项。`child` 与 [label] 二选一，都没有时退化为 `value.toString()`。
///
/// `child` 可以是任意 Widget —— Icon、Image、Row 等都能直接放进来。
///
/// 纯动作菜单（筛选、工具面板）没有「选中值」，用
/// [AnchoredDropdownItem.action] 构造即可，不用为每一项编一个占位值。
@immutable
class AnchoredDropdownItem<T extends Object> {
  const AnchoredDropdownItem(
    this.value, {
    this.label,
    this.child,
    this.enabled = true,
    this.onTap,
    this.closeOnTap = true,
  }) : assert(
         value != null || onTap != null,
         'No value to select: build the item with '
         'AnchoredDropdownItem.action instead.',
       );

  /// 动作项：点击只执行 [onTap]，没有值。
  ///
  /// 它不参与选中态、不回传 [AnchoredDropdown.onChanged]，所以整份列表都是
  /// 动作项时，`items` 的类型参数、`AnchoredDropdown.value` 都可以不写：
  ///
  /// ```dart
  /// AnchoredDropdown(
  ///   trigger: const Icon(Icons.filter_list_alt),
  ///   items: <AnchoredDropdownItem<Object>>[
  ///     AnchoredDropdownItem.action(
  ///       label: '只看已勾选',
  ///       closeOnTap: false, // 多选筛选：点完不收起
  ///       onTap: () => toggle(Filter.checked),
  ///     ),
  ///   ],
  /// )
  /// ```
  ///
  /// 泛型参数只用来和值项对齐类型，本身不参与运行；一份动作项列表用
  /// `AnchoredDropdownItem<Object>` 声明即可，不要为它编枚举或占位值。
  const AnchoredDropdownItem.action({
    required this.onTap,
    this.label,
    this.child,
    this.enabled = true,
    this.closeOnTap = true,
  }) : value = null,
       assert(onTap != null, 'AnchoredDropdownItem.action needs an onTap.');

  /// 选中时回传给 [AnchoredDropdown.onChanged] 的值。
  ///
  /// 只有值项有值；动作项（[AnchoredDropdownItem.action]）恒为 null —— 点击
  /// 时走 [onTap]，不经过 `onChanged`。
  final T? value;

  /// 默认渲染用的文字；[child] 为空时生效。
  final String? label;

  /// 自定义行内容，优先于 [label]。
  final Widget? child;

  /// 是否可点。
  final bool enabled;

  /// 这一项被点击时执行的动作。提供后本项成为「动作项」：
  ///
  /// - 点击只执行 [onTap]，不再回传 [AnchoredDropdown.onChanged]、也不切换
  ///   选中值，且不显示选中勾；
  /// - 点完是否收起面板由 [closeOnTap] 决定。
  ///
  /// 不提供时是普通「选择项」：点击回传 value 并收起面板。两种项可在同一个
  /// `items` 列表里混用，例如普通值项 + 打开子菜单 / 弹窗的级联项。
  ///
  /// `context` 是门面自身在主树里的 context（不是浮层 context），可直接用于
  /// showDialog / Navigator 以及读取 InheritedWidget（如 Riverpod 的 ref）。
  final void Function(BuildContext context)? onTap;

  /// 动作项点击后是否收起面板，默认 true。仅 [onTap] 非空时生效。
  /// 级联场景希望点父项后保留面板、就地展开子级时设为 false。
  final bool closeOnTap;
}

/// 触发器（显示在外面的字段）外观。**只有内置字段的 [TextDropdown] 需要**；
///
/// [AnchoredDropdown] 的触发器是外部传入的任意 Widget，长什么样由调用方自己
/// 负责，所以它没有也不需要这一类样式。想用统一的字段外观，可以拿它去配
/// [AnchoredDropdownField]。
///
/// 不传 `fieldStyle` 时取 [DropdownFieldStyle.of]，按明暗主题切换配色；改其中
/// 几项用 `DropdownFieldStyle.of(context).copyWith(...)`。
@immutable
class DropdownFieldStyle {
  const DropdownFieldStyle({
    this.width = 220.0,
    this.height = 40.0,
    this.radius = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFD4D4D8),
    this.foreground = const Color(0xFF18181B),
    this.muted = const Color(0xFF71717A),
    this.textStyle,
  });

  static DropdownFieldStyle light() => const DropdownFieldStyle();

  static DropdownFieldStyle dark() => DropdownFieldStyle(
    backgroundColor: const Color(0xFF211F26),
    borderColor: const Color(0xFF49454F),
    foreground: const Color(0xFFE6E1E5),
    muted: const Color(0xFF938F99),
  );

  static DropdownFieldStyle of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark() : light();

  DropdownFieldStyle copyWith({
    double? width,
    double? height,
    double? radius,
    EdgeInsetsGeometry? padding,
    Color? backgroundColor,
    Color? borderColor,
    Color? foreground,
    Color? muted,
    TextStyle? textStyle,
  }) => DropdownFieldStyle(
    width: width ?? this.width,
    height: height ?? this.height,
    radius: radius ?? this.radius,
    padding: padding ?? this.padding,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    borderColor: borderColor ?? this.borderColor,
    foreground: foreground ?? this.foreground,
    muted: muted ?? this.muted,
    textStyle: textStyle ?? this.textStyle,
  );

  /// 字段宽度；[TextDropdown] 的下拉面板与它等宽。
  final double width;

  /// 字段高度。
  final double height;

  /// 字段四角圆角半径，全程恒定。
  final double radius;

  /// 文字 / 箭头到字段边框的距离。
  final EdgeInsetsGeometry padding;

  final Color backgroundColor;
  final Color borderColor;

  /// 选中值的文字色。
  final Color foreground;

  /// 占位文案 / 箭头 / 禁用态的文字色。
  final Color muted;

  /// 字段文字样式（未给 color 时按状态补 [foreground] / [muted]）。
  final TextStyle? textStyle;
}

/// 下拉面板 + 选项行的外观。[TextDropdown] 与 [AnchoredDropdown] 共用。
///
/// 面板宽度、最大高度、与触发器的间距、揭示动画、阴影，以及所有选项行的
/// 几何与颜色，都收在这里。两个门面只有这一套样式入口，不再有散参数覆盖。
/// 不传 `itemStyle` 时取 [DropdownItemStyle.of]，改几项用 `.copyWith(...)`。
@immutable
class DropdownItemStyle {
  const DropdownItemStyle({
    this.width = const DropdownWidth.matchTrigger(),
    this.maxHeight = 240.0,
    this.radius = 12.0,
    this.itemRadius = 8.0,
    this.gap = 8.0,
    this.lip = 8.0,
    this.padding = 4.0,
    this.itemHeight = 36.0,
    this.itemGap = 0.0,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 10),
    this.scrollbarThickness = 4.0,
    this.shadowOpacity = 0.10,
    this.shadowBlurRadius = 12.0,
    this.shadowOffset = const Offset(0, 6),
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFD4D4D8),
    this.selectedColor = const Color(0xFFF4F4F5),
    this.shadowColor = Colors.black,
    this.foreground = const Color(0xFF18181B),
    this.muted = const Color(0xFF71717A),
    this.disabledColor = const Color(0xFFA1A1AA),
    this.textStyle,
    this.showCheck = true,
    this.checkIcon = Icons.check,
    this.checkSize = 14.0,
  });

  static DropdownItemStyle light() => const DropdownItemStyle();

  static DropdownItemStyle dark() => DropdownItemStyle(
    backgroundColor: const Color(0xFF211F26),
    borderColor: const Color(0xFF49454F),
    foreground: const Color(0xFFE6E1E5),
    muted: const Color(0xFF938F99),
    disabledColor: const Color(0xFF938F99).withValues(alpha: 0.6),
    selectedColor: const Color(0xFF36343B),
    shadowColor: Colors.black,
    shadowOpacity: 0.30,
  );

  static DropdownItemStyle of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark() : light();

  DropdownItemStyle copyWith({
    DropdownWidth? width,
    double? maxHeight,
    double? radius,
    double? itemRadius,
    double? gap,
    double? lip,
    double? padding,
    double? itemHeight,
    double? itemGap,
    EdgeInsetsGeometry? itemPadding,
    double? scrollbarThickness,
    double? shadowOpacity,
    double? shadowBlurRadius,
    Offset? shadowOffset,
    Color? backgroundColor,
    Color? borderColor,
    Color? selectedColor,
    Color? shadowColor,
    Color? foreground,
    Color? muted,
    Color? disabledColor,
    TextStyle? textStyle,
    bool? showCheck,
    IconData? checkIcon,
    double? checkSize,
  }) => DropdownItemStyle(
    width: width ?? this.width,
    maxHeight: maxHeight ?? this.maxHeight,
    radius: radius ?? this.radius,
    itemRadius: itemRadius ?? this.itemRadius,
    gap: gap ?? this.gap,
    lip: lip ?? this.lip,
    padding: padding ?? this.padding,
    itemHeight: itemHeight ?? this.itemHeight,
    itemGap: itemGap ?? this.itemGap,
    itemPadding: itemPadding ?? this.itemPadding,
    scrollbarThickness: scrollbarThickness ?? this.scrollbarThickness,
    shadowOpacity: shadowOpacity ?? this.shadowOpacity,
    shadowBlurRadius: shadowBlurRadius ?? this.shadowBlurRadius,
    shadowOffset: shadowOffset ?? this.shadowOffset,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    borderColor: borderColor ?? this.borderColor,
    selectedColor: selectedColor ?? this.selectedColor,
    shadowColor: shadowColor ?? this.shadowColor,
    foreground: foreground ?? this.foreground,
    muted: muted ?? this.muted,
    disabledColor: disabledColor ?? this.disabledColor,
    textStyle: textStyle ?? this.textStyle,
    showCheck: showCheck ?? this.showCheck,
    checkIcon: checkIcon ?? this.checkIcon,
    checkSize: checkSize ?? this.checkSize,
  );

  /// 面板宽度策略。[AnchoredDropdown] 用它；[TextDropdown] 面板与字段等宽，忽略。
  final DropdownWidth width;

  /// 面板最大高度，超出后内部滚动。
  final double maxHeight;

  /// 面板四角圆角半径，全程恒定、不参与动画。
  final double radius;

  /// 选项行圆角半径。
  final double itemRadius;

  /// 展开完成后列表与触发器之间的间距。
  final double gap;

  /// [DropdownReveal.unfold] 起始薄边厚度 / 斜向揭示的起始可见量。
  final double lip;

  /// 列表内边距：选项行外框到面板边框的距离。
  final double padding;

  /// 选项行高。
  final double itemHeight;

  /// 相邻选项之间的间距。
  final double itemGap;

  /// 选项行内边距：行内内容到选项行外框的距离。
  final EdgeInsetsGeometry itemPadding;

  /// 滚动条厚度。桌面 / Web 上 [Scrollbar] 默认 8，离行尾箭头太近容易
  /// 误触，这里收到 4。
  final double scrollbarThickness;

  /// 阴影最大不透明度，实际值随展开进度渐强。
  final double shadowOpacity;

  final double shadowBlurRadius;
  final Offset shadowOffset;

  final Color backgroundColor;
  final Color borderColor;
  final Color selectedColor;
  final Color shadowColor;
  final Color foreground;
  final Color muted;
  final Color disabledColor;

  /// 选项文字样式（未给 color 时按状态补色）。
  final TextStyle? textStyle;

  /// 选中项是否显示打勾图标（仅在默认行渲染时生效）。
  final bool showCheck;
  final IconData checkIcon;
  final double checkSize;
}

// ── 公开常量 / 调试定位键 ────────────────────────────────────────────────

/// 默认展开时长。收起自动取 3/4；减弱动效时统一 120ms。
const Duration kDropdownOpenDuration = Duration(milliseconds: 260);

/// 减弱动效时长。
const Duration kDropdownReduceDuration = Duration(milliseconds: 120);

/// 触发组件尚未完成布局时的兜底列表宽度。
const double kDropdownFallbackWidth = 200.0;

/// 列表宽度容器（便于测试与外部定位）。
const ValueKey<String> kDropdownMenuBoxKey = ValueKey<String>(
  'dropdown.menu_box',
);

/// 裁切层。p = 1 或减弱动效时不在树里。
const ValueKey<String> kDropdownClipKey = ValueKey<String>(
  'dropdown.reveal_clip',
);

const ValueKey<String> kDropdownBodyKey = ValueKey<String>(
  'dropdown.panel_body',
);

const ValueKey<String> kDropdownShadowKey = ValueKey<String>(
  'dropdown.panel_shadow',
);

// ── 内部常量与派生量 ─────────────────────────────────────────────────────

/// 展开曲线：全程稳定推进、收尾柔和、无过冲。收起是它的时间镜像。
const Cubic _kRevealCurve = Cubic(0.25, 0.46, 0.45, 0.94);

/// 分离位移用的对称缓动。
const Cubic _kSoftCurve = Cubic(0.4, 0.0, 0.2, 1.0);

/// 淡入 / 行内容 / 阴影的短缓出。
const Cubic _kEaseOut = Cubic(0.16, 1.0, 0.3, 1.0);

/// 一帧里由同一个 p 推导出的全部参数。
@immutable
class _Frame {
  const _Frame({
    required this.p,
    required this.offsetY,
    required this.opacity,
    required this.shadow,
    required this.rowsOpacity,
    required this.rowsOffsetY,
    required this.placedAbove,
    required this.reduce,
  });

  /// 已 clamp 的主线进度 0 → 1。
  final double p;
  final double offsetY;
  final double opacity;
  final double shadow;
  final double rowsOpacity;
  final double rowsOffsetY;
  final bool placedAbove;
  final bool reduce;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// `useTransform(v, [from, to], [0, 1])`，两端 clamp。
double _remap(double v, double from, double to) =>
    ((v - from) / (to - from)).clamp(0.0, 1.0);

/// 把逻辑对齐解析成 [Alignment.x]（-1 左 / 0 中 / 1 右）。
double _alignmentX(DropdownAlignment alignment, TextDirection? direction) {
  final bool rtl = direction == TextDirection.rtl;
  return switch (alignment) {
    DropdownAlignment.left => -1.0,
    DropdownAlignment.center => 0.0,
    DropdownAlignment.right => 1.0,
    DropdownAlignment.start => rtl ? 1.0 : -1.0,
    DropdownAlignment.end => rtl ? -1.0 : 1.0,
  };
}

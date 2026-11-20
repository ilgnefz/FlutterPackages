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
@immutable
class AnchoredDropdownItem<T extends Object> {
  const AnchoredDropdownItem(
    this.value, {
    this.label,
    this.child,
    this.enabled = true,
  });

  /// 选中时回传给 [AnchoredDropdown.onChanged] 的值。
  final T value;

  /// 默认渲染用的文字；[child] 为空时生效。
  final String? label;

  /// 自定义行内容，优先于 [label]。
  final Widget? child;

  /// 是否可点。
  final bool enabled;
}

/// 下拉框外观，TextDropdown 与 [AnchoredDropdown] 共用。
///
/// 不传 `style` 时两个门面都会用 [DropdownStyle.of] 按当前明暗主题取配色；
/// 想改其中几项，用 `DropdownStyle.of(context).copyWith(...)`，别直接
/// `DropdownStyle(...)` —— 裸构造走的是浅色默认值。
///
/// 所有字段都是 const 默认值；几何字段（radius / gap / lip / padding /
/// fieldPadding / itemPadding / itemHeight / 阴影参数）与颜色字段一样，在两个门面里都生效。
@immutable
class DropdownStyle {
  const DropdownStyle({
    this.radius = 12.0,
    this.itemRadius = 8.0,
    this.gap = 8.0,
    this.lip = 8.0,
    this.padding = 4.0,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 10),
    this.fieldPadding = const EdgeInsets.symmetric(horizontal: 12),
    this.itemHeight = 36.0,
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
    this.showCheck = true,
    this.checkIcon = Icons.check,
    this.checkSize = 14.0,
  });

  /// 浅色配色：中性灰表面 + 深灰文字，即构造函数的 const 默认值。
  static DropdownStyle light() => const DropdownStyle();

  /// 深色配色：Material 3 深色基线的那组表面色 —— 面板
  /// `surfaceContainer` `#211F26`、选中行 `surfaceContainerHighest`
  /// `#36343B`、描边 `outline` `#49454F`、文字 `onSurface` `#E6E1E5`、
  /// 次级文字 `onSurfaceVariant` `#938F99`。
  ///
  /// 写成字面量而不是读 `ColorScheme`：组件默认外观不该被宿主 App 的主题
  /// 牵着走，想跟主题走就显式传 `style:`（或者
  /// `DropdownStyle.of(context).copyWith(...)`）。
  static DropdownStyle dark() => DropdownStyle(
    backgroundColor: const Color(0xFF211F26),
    borderColor: const Color(0xFF49454F),
    foreground: const Color(0xFFE6E1E5),
    muted: const Color(0xFF938F99),
    disabledColor: const Color(0xFF938F99).withValues(alpha: 0.6),
    selectedColor: const Color(0xFF36343B),
    shadowColor: Colors.black,
    shadowOpacity: 0.30,
  );

  /// 跟随 [ThemeData.brightness] 的默认外观。
  static DropdownStyle of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark() : light();

  DropdownStyle copyWith({
    double? radius,
    double? itemRadius,
    double? gap,
    double? lip,
    double? padding,
    EdgeInsetsGeometry? itemPadding,
    EdgeInsetsGeometry? fieldPadding,
    double? itemHeight,
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
    bool? showCheck,
    IconData? checkIcon,
    double? checkSize,
  }) => DropdownStyle(
    radius: radius ?? this.radius,
    itemRadius: itemRadius ?? this.itemRadius,
    gap: gap ?? this.gap,
    lip: lip ?? this.lip,
    padding: padding ?? this.padding,
    itemPadding: itemPadding ?? this.itemPadding,
    fieldPadding: fieldPadding ?? this.fieldPadding,
    itemHeight: itemHeight ?? this.itemHeight,
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
    showCheck: showCheck ?? this.showCheck,
    checkIcon: checkIcon ?? this.checkIcon,
    checkSize: checkSize ?? this.checkSize,
  );

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

  /// 选项行内边距：行内文字 / 打勾图标到选项行外框的距离。
  ///
  /// 默认水平 10；[TextDropdown] 与 [AnchoredDropdown] 的默认行渲染都用它。
  /// 和 [fieldPadding]（触发器）是不同的两层。
  final EdgeInsetsGeometry itemPadding;

  /// 触发器内显示文字 / 箭头到边框的距离。
  ///
  /// [TextDropdown] 的内置字段和 [AnchoredDropdownField] 都用它，默认水平 12；
  /// [AnchoredDropdownField.padding] 显式传值时优先于这里。
  final EdgeInsetsGeometry fieldPadding;

  /// 默认选项行高。
  final double itemHeight;

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

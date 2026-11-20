part of '../flutter_anchored_overlay.dart';

// ── 公开常量 ──────────────────────────────────────────────────────────────

/// 气泡外框（含箭头）的定位 key，测量 / 测试时用。
const Key kPopoverBubbleKey = ValueKey<String>('popover.bubble');

/// 内容区的 key（在气泡箭头留白 + [PopoverStyle.padding] 之内）。
const Key kPopoverContentKey = ValueKey<String>('popover.content');

/// 模态遮罩的 key；只有 [Popover.barrierColor] 非 null 时存在。
const Key kPopoverBarrierKey = ValueKey<String>('popover.barrier');

/// 默认展开时长；收起时长自动取它的 3/4。
const Duration kPopoverOpenDuration = Duration(milliseconds: 190);

/// 减弱动效下的时长（只淡入淡出）。
const Duration kPopoverReduceDuration = Duration(milliseconds: 110);

/// 按下到抬起之间允许的最大位移；超过就当成拖动，不切换开关。
const double kPopoverPressSlop = 8.0;

// ── 公开枚举 ──────────────────────────────────────────────────────────────

/// 气泡出现在触发组件的哪一侧。这是**首选**方向：开了 [Popover.autoFlip]
/// 且这一侧空间不够时，会自动翻到对称一侧。
///
/// 四个值都是物理方向，与 [Directionality] 无关；要按阅读方向起止对齐，
/// 用 [PopoverAlign.start] / [PopoverAlign.end]。
enum PopoverPlacement {
  /// 触发器上方。
  top,

  /// 触发器下方（默认）。
  bottom,

  /// 触发器左侧。
  left,

  /// 触发器右侧。
  right,
}

/// 气泡在**交叉轴**上如何对齐触发器。
///
/// 主轴是上下时（[PopoverPlacement.top] / [PopoverPlacement.bottom]），
/// 交叉轴是水平方向；主轴是左右时则反之。[start] / [end] 在水平交叉轴上
/// 会按 [Directionality] 镜像，在垂直交叉轴上分别是上、下。
enum PopoverAlign { start, center, end }

/// 打开方式。
enum PopoverTriggerMode {
  /// 点击触发器切换开 / 关（默认）。
  tap,

  /// 鼠标进入触发器即打开，离开后延迟 [Popover.hoverCloseDelay] 关闭；
  /// 鼠标移进气泡里会取消关闭计时，方便在气泡上操作。
  hover,

  /// 触发器完全不响应，只由 [PopoverController] 控制。
  manual,
}

/// 箭头长在气泡的哪条边上。由最终显示方向反推，不用自己传。
enum PopoverArrowSide {
  top,
  bottom,
  left,
  right,

  /// 不画箭头（[PopoverStyle.showArrow] 为 false）。
  none,
}

// ── 位置解算结果 ────────────────────────────────────────────────────────────

/// 一次布局解算的结果。一般不用关心，但 [Popover.onPositionChanged] 会把它
/// 抛出来，方便做「气泡里再放一个跟着箭头走的装饰」这类高级定制。
@immutable
class PopoverPosition {
  const PopoverPosition({
    required this.placement,
    required this.arrowSide,
    required this.offset,
    required this.arrowOffset,
    required this.shift,
    required this.flipped,
  });

  /// 最终方向（可能已经翻转过）。
  final PopoverPlacement placement;

  /// 箭头所在边。
  final PopoverArrowSide arrowSide;

  /// 气泡左上角相对触发器左上角的位移，直接喂给
  /// [CompositedTransformFollower.offset]。
  final Offset offset;

  /// 箭头中心在气泡局部坐标里的位置：上下边时是 x，左右边时是 y。
  final double arrowOffset;

  /// 贴边夹取造成的额外位移；没有夹取时是 [Offset.zero]。
  final Offset shift;

  /// 是否因为空间不足翻转到了对称方向。
  final bool flipped;

  @override
  bool operator ==(Object other) =>
      other is PopoverPosition &&
      other.placement == placement &&
      other.arrowSide == arrowSide &&
      other.offset == offset &&
      other.arrowOffset == arrowOffset &&
      other.shift == shift &&
      other.flipped == flipped;

  @override
  int get hashCode => Object.hash(
    placement,
    arrowSide,
    offset,
    arrowOffset,
    shift,
    flipped,
  );

  @override
  String toString() =>
      'PopoverPosition($placement, arrow: $arrowSide @ $arrowOffset, '
      'offset: $offset, shift: $shift, flipped: $flipped)';
}

// ── 外观配置 ──────────────────────────────────────────────────────────────

/// 气泡外观。颜色传 null 时跟随当前 [ThemeData.colorScheme]，所以亮 / 暗
/// 主题都能直接用；其余是 const 默认值，按需覆盖即可。
@immutable
class PopoverStyle {
  const PopoverStyle({
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.shadowColor,
    this.borderWidth = 1.0,
    this.radius = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.gap = 8.0,
    this.showArrow = true,
    this.arrowWidth = 14.0,
    this.arrowHeight = 7.0,
    this.minWidth = 0.0,
    this.maxWidth = 320.0,
    this.maxHeight = 320.0,
    this.shadowOpacity = 0.16,
    this.shadowBlurRadius = 16.0,
    this.shadowOffset = const Offset(0, 6),
    this.duration = kPopoverOpenDuration,
    this.curve = Curves.easeOutCubic,
    this.scaleBegin = 0.92,
    this.slideDistance = 6.0,
  });

  /// 气泡填充；null 时取 `colorScheme.surfaceContainerHighest`。
  final Color? backgroundColor;

  /// 默认文字色；null 时取 `colorScheme.onSurface`。内容里自己写了
  /// [TextStyle] 的以内容为准。
  final Color? foregroundColor;

  /// 描边色；null 时取 `colorScheme.outline` 的 35% 透明度。
  /// [borderWidth] 为 0 时完全不描边。
  final Color? borderColor;

  /// 阴影色；null 时取 `colorScheme.shadow`。
  final Color? shadowColor;

  /// 描边宽度；0 表示不画边框。
  final double borderWidth;

  /// 圆角半径。
  final double radius;

  /// 内容内边距（箭头那一侧会自动再加 [arrowHeight]）。
  final EdgeInsetsGeometry padding;

  /// 触发器到**箭头尖端**的距离；没有箭头时就是到气泡边缘的距离。
  final double gap;

  /// 是否画指向触发器的小三角。
  final bool showArrow;

  /// 箭头底边宽度。
  final double arrowWidth;

  /// 箭头高度（也是气泡在这一侧额外让出的空间）。
  final double arrowHeight;

  /// 气泡最小宽度。
  final double minWidth;

  /// 气泡最大宽度；实际还会被「视口宽 - 2 × edgePadding」再夹一次。
  final double maxWidth;

  /// 气泡最大高度；内容超过时请自行放可滚动组件。
  final double maxHeight;

  /// 阴影不透明度（叠在 [shadowColor] 上）。
  final double shadowOpacity;

  /// 阴影模糊半径。
  final double shadowBlurRadius;

  /// 阴影偏移。
  final Offset shadowOffset;

  /// 展开时长；收起自动取 3/4，减弱动效时统一 [kPopoverReduceDuration]。
  final Duration duration;

  /// 主进度曲线；收起用它的时间镜像 [FlippedCurve]。
  final Curve curve;

  /// 进场起始缩放（1 表示不缩放）。
  final double scaleBegin;

  /// 进场起始位移，方向朝触发器。
  final double slideDistance;

  PopoverStyle copyWith({
    Color? backgroundColor,
    Color? foregroundColor,
    Color? borderColor,
    Color? shadowColor,
    double? borderWidth,
    double? radius,
    EdgeInsetsGeometry? padding,
    double? gap,
    bool? showArrow,
    double? arrowWidth,
    double? arrowHeight,
    double? minWidth,
    double? maxWidth,
    double? maxHeight,
    double? shadowOpacity,
    double? shadowBlurRadius,
    Offset? shadowOffset,
    Duration? duration,
    Curve? curve,
    double? scaleBegin,
    double? slideDistance,
  }) {
    return PopoverStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      borderColor: borderColor ?? this.borderColor,
      shadowColor: shadowColor ?? this.shadowColor,
      borderWidth: borderWidth ?? this.borderWidth,
      radius: radius ?? this.radius,
      padding: padding ?? this.padding,
      gap: gap ?? this.gap,
      showArrow: showArrow ?? this.showArrow,
      arrowWidth: arrowWidth ?? this.arrowWidth,
      arrowHeight: arrowHeight ?? this.arrowHeight,
      minWidth: minWidth ?? this.minWidth,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight ?? this.maxHeight,
      shadowOpacity: shadowOpacity ?? this.shadowOpacity,
      shadowBlurRadius: shadowBlurRadius ?? this.shadowBlurRadius,
      shadowOffset: shadowOffset ?? this.shadowOffset,
      duration: duration ?? this.duration,
      curve: curve ?? this.curve,
      scaleBegin: scaleBegin ?? this.scaleBegin,
      slideDistance: slideDistance ?? this.slideDistance,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PopoverStyle &&
      other.backgroundColor == backgroundColor &&
      other.foregroundColor == foregroundColor &&
      other.borderColor == borderColor &&
      other.shadowColor == shadowColor &&
      other.borderWidth == borderWidth &&
      other.radius == radius &&
      other.padding == padding &&
      other.gap == gap &&
      other.showArrow == showArrow &&
      other.arrowWidth == arrowWidth &&
      other.arrowHeight == arrowHeight &&
      other.minWidth == minWidth &&
      other.maxWidth == maxWidth &&
      other.maxHeight == maxHeight &&
      other.shadowOpacity == shadowOpacity &&
      other.shadowBlurRadius == shadowBlurRadius &&
      other.shadowOffset == shadowOffset &&
      other.duration == duration &&
      other.curve == curve &&
      other.scaleBegin == scaleBegin &&
      other.slideDistance == slideDistance;

  @override
  int get hashCode => Object.hash(
    Object.hash(
      backgroundColor,
      foregroundColor,
      borderColor,
      shadowColor,
      borderWidth,
      radius,
      padding,
      gap,
      showArrow,
      arrowWidth,
    ),
    Object.hash(
      arrowHeight,
      minWidth,
      maxWidth,
      maxHeight,
      shadowOpacity,
      shadowBlurRadius,
      shadowOffset,
      duration,
      curve,
      scaleBegin,
      slideDistance,
    ),
  );
}

// ── 控制器 ────────────────────────────────────────────────────────────────

/// 气泡开关的**唯一数据源**：组件内部点击、外部点击、Esc 都会写回它，
/// 外部调用 [show] / [hide] / [toggle] 也会立刻反映到界面上。
///
/// ```dart
/// final PopoverController c = PopoverController();
/// Popover(child: const Icon(Icons.info_outline), content: const Text('说明'), controller: c);
/// c.show();
/// print(c.isOpen); // true
/// ```
class PopoverController extends ChangeNotifier {
  // ignore: prefer_initializing_formals
  PopoverController({bool open = false}) : _open = open;

  bool _open;

  /// 当前是否展开。
  bool get isOpen => _open;

  /// 展开（已经展开时不重复通知）。
  void show() => _set(true);

  /// 收起（已经收起时不重复通知）。
  void hide() => _set(false);

  /// 切换。
  void toggle() => _set(!_open);

  void _set(bool next) {
    if (next == _open) return;
    _open = next;
    notifyListeners();
  }

  @override
  String toString() => 'PopoverController(isOpen: $_open)';
}

part of '../flutter_anchored_overlay.dart';

// ── Tooltip 门面的兼容类型 ─────────────────────────────────────────────────

/// 气泡相对目标组件的方向（气泡出现在目标的哪一侧）。
///
/// 和 [PopoverPlacement] 一一对应，保留旧名字是为了让原 Tooltip 的调用点
/// 不用改：`up → top`、`down → bottom`，左右同名。
enum TooltipDirection { up, down, left, right }

/// 气泡在侧轴（与方向垂直的那条轴）上的对齐方式。
enum TooltipAlign { start, center, end }

/// 定位结果：气泡左上角在 Overlay 坐标系中的位置 + 箭头沿边的偏移量。
@immutable
class TooltipPlacement {
  const TooltipPlacement({
    required this.direction,
    required this.offset,
    required this.arrowOffset,
    required this.flipped,
  });

  /// 最终生效的方向（可能与期望方向相反，即发生了翻转）。
  final TooltipDirection direction;

  /// 气泡左上角坐标（Overlay 坐标系）。
  final Offset offset;

  /// 箭头尖端中心，沿「箭头所在的那条边」方向、距气泡左上角的距离。
  /// 上下方向时为 x 偏移；左右方向时为 y 偏移。
  final double arrowOffset;

  /// 是否发生翻转。
  final bool flipped;

  @override
  String toString() =>
      'TooltipPlacement(${direction.name}, offset: $offset, '
      'arrow: $arrowOffset, flipped: $flipped)';
}

PopoverPlacement _placementOf(TooltipDirection d) {
  switch (d) {
    case TooltipDirection.up:
      return PopoverPlacement.top;
    case TooltipDirection.down:
      return PopoverPlacement.bottom;
    case TooltipDirection.left:
      return PopoverPlacement.left;
    case TooltipDirection.right:
      return PopoverPlacement.right;
  }
}

TooltipDirection _tooltipDirectionOf(PopoverPlacement p) {
  switch (p) {
    case PopoverPlacement.top:
      return TooltipDirection.up;
    case PopoverPlacement.bottom:
      return TooltipDirection.down;
    case PopoverPlacement.left:
      return TooltipDirection.left;
    case PopoverPlacement.right:
      return TooltipDirection.right;
  }
}

PopoverAlign _alignOf(TooltipAlign a) {
  switch (a) {
    case TooltipAlign.start:
      return PopoverAlign.start;
    case TooltipAlign.center:
      return PopoverAlign.center;
    case TooltipAlign.end:
      return PopoverAlign.end;
  }
}

/// 纯函数：Tooltip 版定位（Overlay 绝对坐标），可直接写单测。
///
/// 和 [resolvePopoverPosition] 共用同一份 [_resolveCore]，只是坐标系不同：
/// 这里入参直接是目标在 Overlay 里的矩形 [target]，返回的
/// [TooltipPlacement.offset] 也是 Overlay 绝对坐标。
TooltipPlacement computeTooltipPlacement({
  required Rect target,
  required Size bubble,
  required Size viewport,
  required TooltipDirection preferred,
  required TooltipAlign align,
  required double gap,
  required double arrowWidth,
  required double radius,
  required double viewportPadding,
}) {
  final _BubbleLayout layout = _resolveCore(
    target: target,
    bubble: bubble,
    viewport: viewport,
    placement: _placementOf(preferred),
    align: _alignOf(align),
    autoFlip: true,
    showArrow: true,
    constrainToViewport: true,
    gap: gap,
    arrowWidth: arrowWidth,
    radius: radius,
    edgePadding: viewportPadding,
    direction: TextDirection.ltr,
  );
  return TooltipPlacement(
    direction: _tooltipDirectionOf(layout.placement),
    offset: layout.offset,
    arrowOffset: layout.arrowOffset,
    flipped: layout.flipped,
  );
}

/// 手动控制 Tooltip 显隐。
///
/// 它就是 [PopoverController] 的子类，所以**同一个控制器可以同时驱动
/// [Popover] 和 [SmartTooltip]**；[isVisible] 是 [PopoverController.isOpen]
/// 的别名，保留给原来的调用点。
class SmartTooltipController extends PopoverController {
  SmartTooltipController({super.open});

  bool get isVisible => isOpen;
}

// ── Tooltip 门面 ──────────────────────────────────────────────────────────

/// 轻量提示气泡：[Popover] 的 Tooltip 预设。
///
/// 不是另写一套浮层，而是把 Tooltip 的参数翻译成 [Popover] 的配置，因此
/// 定位、箭头、翻转、夹取、动画全部与 [Popover] 共用同一份实现。默认：
///
/// * hover 悬停 200ms 显示、离开 120ms 收起（另有长按供移动端使用）；
/// * 气泡对鼠标**透明**（[Popover.interactive] = false），点击目标立刻收起；
/// * 白色底、13 号黑字、圆角 6、箭头 12×7、320 宽上限；
/// * 不抢焦点、不响应 Esc、不铺遮罩。
///
/// ```dart
/// SmartTooltip(
///   message: '这是一段提示',
///   placement: TooltipDirection.down,
///   child: const Text('悬停我'),
/// );
/// ```
///
/// 想让气泡里能放按钮 / 链接，把 [interactive] 打开即可（此时鼠标移进气泡
/// 也不会收起）。更多能力（tap 打开、外部点击 / Esc 关闭、模态遮罩、任意
/// 方向组合、`contentBuilder`）直接用 [Popover]。
class SmartTooltip extends StatelessWidget {
  const SmartTooltip({
    super.key,
    this.message,
    this.richMessage,
    required this.child,
    this.controller,
    this.placement = TooltipDirection.down,
    this.align = TooltipAlign.center,
    this.gap = 8,
    this.viewportPadding = 8,
    this.waitDuration = const Duration(milliseconds: 200),
    this.exitDelay = const Duration(milliseconds: 120),
    this.showDuration,
    this.interactive = false,
    this.enableLongPress = true,
    this.hideOnTap = true,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.textStyle,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    this.radius = 6,
    this.arrowWidth = 12,
    this.arrowHeight = 7,
    this.borderColor,
    this.borderWidth = 1,
    this.elevation = 4,
    this.maxWidth = 320,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 130),
    this.onShow,
    this.onHide,
  }) : assert(
         message != null || richMessage != null,
         'message 和 richMessage 至少提供一个',
       );

  /// 纯文本提示内容。
  final String? message;

  /// 自定义内容（与 [message] 二选一，优先使用）。
  final Widget? richMessage;

  /// 触发组件。
  final Widget child;

  /// 外部控制器。因为 [SmartTooltipController] 是 [PopoverController] 的子类，
  /// 这里也可以直接传 [PopoverController]，两个门面共用同一个开关状态。
  final PopoverController? controller;

  /// 期望方向；空间不足会自动翻转。
  final TooltipDirection placement;

  /// 侧轴对齐方式。
  final TooltipAlign align;

  /// 箭头尖端到目标组件边缘的距离。
  final double gap;

  /// 气泡与视口边缘的安全距离。
  final double viewportPadding;

  /// 鼠标悬停多久后显示；传一个很大的值即可「永不自动显示」。
  final Duration waitDuration;

  /// 鼠标移出多久后隐藏；null 表示立刻隐藏。
  final Duration? exitDelay;

  /// 显示后自动隐藏的时长；null 表示不自动隐藏。
  final Duration? showDuration;

  /// 气泡是否接收鼠标事件（鼠标可移入气泡而不消失，气泡内可放链接 / 按钮）。
  final bool interactive;

  /// 是否支持长按触发（移动端）。
  final bool enableLongPress;

  /// 点击目标组件时是否立刻隐藏气泡。
  final bool hideOnTap;

  final Color backgroundColor;
  final TextStyle? textStyle;
  final EdgeInsets contentPadding;
  final double radius;
  final double arrowWidth;
  final double arrowHeight;
  final Color? borderColor;
  final double borderWidth;
  final double elevation;
  final double maxWidth;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final VoidCallback? onShow;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    final TextStyle effectiveStyle =
        textStyle ??
        const TextStyle(
          fontSize: 13,
          height: 1.45,
          color: Color(0xFF000000),
          fontWeight: FontWeight.normal,
          decoration: TextDecoration.none,
        );
    final Widget content = DefaultTextStyle(
      style: effectiveStyle,
      child: richMessage ?? Text(message ?? '', style: effectiveStyle),
    );

    // Tooltip 的 borderColor 为 null 时**不描边**；Popover 默认会取主题色，
    // 所以这里用 borderWidth: 0 明确关掉。elevation 换算成 BoxShadow。
    final PopoverStyle style = PopoverStyle(
      backgroundColor: backgroundColor,
      foregroundColor: effectiveStyle.color,
      borderColor: borderColor,
      borderWidth: borderColor == null ? 0 : borderWidth,
      radius: radius,
      padding: contentPadding,
      gap: gap,
      showArrow: true,
      arrowWidth: arrowWidth,
      arrowHeight: arrowHeight,
      maxWidth: maxWidth,
      maxHeight: double.infinity,
      shadowColor: const Color(0xFF000000),
      shadowOpacity: elevation > 0 ? 0.25 : 0,
      shadowBlurRadius: elevation * 1.2,
      shadowOffset: Offset(0, elevation * 0.2),
      duration: animationDuration,
      curve: Curves.easeOutCubic,
      scaleBegin: 0.92,
      slideDistance: 0,
    );

    return Popover(
      controller: controller,
      placement: _placementOf(placement),
      align: _alignOf(align),
      autoFlip: true,
      constrainToViewport: true,
      triggerMode: PopoverTriggerMode.hover,
      dismissOnOutsideTap: false,
      dismissOnEscape: false,
      initialOpen: false,
      enabled: true,
      reduceMotion: false,
      style: style,
      edgePadding: viewportPadding,
      semanticsTooltip: message,
      semanticsButton: false,
      excludeFromSemantics: excludeFromSemantics,
      hoverCloseDelay: exitDelay ?? Duration.zero,
      waitDuration: waitDuration,
      showDuration: showDuration,
      interactive: interactive,
      enableLongPress: enableLongPress,
      hideOnTap: hideOnTap,
      onOpenChange: (bool open) {
        if (open) {
          onShow?.call();
        } else {
          onHide?.call();
        }
      },
      content: content,
      child: child,
    );
  }
}

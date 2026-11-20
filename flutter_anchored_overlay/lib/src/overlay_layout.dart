part of '../flutter_anchored_overlay.dart';

// ── 方向工具 ──────────────────────────────────────────────────────────────

bool _isVertical(PopoverPlacement p) =>
    p == PopoverPlacement.top || p == PopoverPlacement.bottom;

PopoverPlacement _opposite(PopoverPlacement p) {
  switch (p) {
    case PopoverPlacement.top:
      return PopoverPlacement.bottom;
    case PopoverPlacement.bottom:
      return PopoverPlacement.top;
    case PopoverPlacement.left:
      return PopoverPlacement.right;
    case PopoverPlacement.right:
      return PopoverPlacement.left;
  }
}

PopoverArrowSide _arrowSideFor(PopoverPlacement p, bool showArrow) {
  if (!showArrow) return PopoverArrowSide.none;
  switch (p) {
    case PopoverPlacement.bottom:
      return PopoverArrowSide.top;
    case PopoverPlacement.top:
      return PopoverArrowSide.bottom;
    case PopoverPlacement.right:
      return PopoverArrowSide.left;
    case PopoverPlacement.left:
      return PopoverArrowSide.right;
  }
}

/// 上界小于下界时直接取下界（气泡比视口还大时优先保证左上角可见）。
double _clamp(double v, double lo, double hi) =>
    hi < lo ? lo : (v < lo ? lo : (v > hi ? hi : v));

/// 某个方向上、目标矩形边缘到视口边缘还剩多少空间（已扣掉安全边距）。
///
/// 注意这里**不减 gap**：翻转判定统一用 `spaceOf < 气泡尺寸 + gap`，
/// 这样 Tooltip 与 Popover 两套公开函数共用同一份判定，不会各算一套。
double _spaceOf(
  PopoverPlacement p, {
  required Rect target,
  required Size viewport,
  required double pad,
}) {
  switch (p) {
    case PopoverPlacement.bottom:
      return viewport.height - pad - target.bottom;
    case PopoverPlacement.top:
      return target.top - pad;
    case PopoverPlacement.right:
      return viewport.width - pad - target.right;
    case PopoverPlacement.left:
      return target.left - pad;
  }
}

// ── 唯一的定位内核 ────────────────────────────────────────────────────────

/// 统一内核的解算结果，`offset` 是 **Overlay 绝对坐标**（气泡整体左上角）。
@immutable
class _BubbleLayout {
  const _BubbleLayout({
    required this.placement,
    required this.arrowSide,
    required this.offset,
    required this.arrowOffset,
    required this.shift,
    required this.flipped,
  });

  final PopoverPlacement placement;
  final PopoverArrowSide arrowSide;
  final Offset offset;
  final double arrowOffset;
  final Offset shift;
  final bool flipped;
}

/// Popover 与 SmartTooltip 共用的**唯一**定位算法。
///
/// 坐标系刻意选 Tooltip 那套：`target` 是目标组件在 Overlay 坐标系里的矩形，
/// 返回的 [Popover.offset] 也是 Overlay 绝对坐标。原因是这套写法不依赖
/// `CompositedTransformFollower`，纯粹是几何运算，直接就能单测；Popover 再
/// 把绝对坐标减掉 `triggerOrigin` 换成 Follower 需要的相对位移即可。
///
/// 顺序：flip（主轴向空间不够翻到对侧）→ 按方向 / 对齐算自然位置 →
/// 贴边夹取 → 最后把箭头挪回正对目标中心（夹取平移后要反向补偿）。
_BubbleLayout _resolveCore({
  required Rect target,
  required Size bubble,
  required Size viewport,
  required PopoverPlacement placement,
  required PopoverAlign align,
  required bool autoFlip,
  required bool showArrow,
  required bool constrainToViewport,
  required double gap,
  required double arrowWidth,
  required double radius,
  required double edgePadding,
  required TextDirection direction,
}) {
  final bool vertical = _isVertical(placement);
  final double popupMain = vertical ? bubble.height : bubble.width;
  final double pad = edgePadding;
  final double need = popupMain + gap;

  // ── 1. 主轴向空间不够就翻到对称方向 ──
  PopoverPlacement actual = placement;
  bool flipped = false;
  if (autoFlip &&
      popupMain > 0 &&
      viewport.width > 0 &&
      viewport.height > 0) {
    final double here = _spaceOf(
      placement,
      target: target,
      viewport: viewport,
      pad: pad,
    );
    if (here < need) {
      final PopoverPlacement other = _opposite(placement);
      final double there = _spaceOf(
        other,
        target: target,
        viewport: viewport,
        pad: pad,
      );
      if (there > here) {
        actual = other;
        flipped = true;
      }
    }
  }

  final bool actualVertical = _isVertical(actual);

  // ── 2. 主轴 + 交叉轴：算出自然位置（绝对坐标）──
  double left = 0;
  double top = 0;
  if (actualVertical) {
    top = actual == PopoverPlacement.bottom
        ? target.bottom + gap
        : target.top - gap - bubble.height;
    switch (align) {
      case PopoverAlign.start:
        left = direction == TextDirection.rtl
            ? target.right - bubble.width
            : target.left;
        break;
      case PopoverAlign.center:
        left = target.center.dx - bubble.width / 2.0;
        break;
      case PopoverAlign.end:
        left = direction == TextDirection.rtl
            ? target.left
            : target.right - bubble.width;
        break;
    }
  } else {
    left = actual == PopoverPlacement.right
        ? target.right + gap
        : target.left - gap - bubble.width;
    switch (align) {
      case PopoverAlign.start:
        top = target.top;
        break;
      case PopoverAlign.center:
        top = target.center.dy - bubble.height / 2.0;
        break;
      case PopoverAlign.end:
        top = target.bottom - bubble.height;
        break;
    }
  }

  // ── 3. 贴边夹取：保证整个气泡都在视口内 ──
  Offset shift = Offset.zero;
  if (constrainToViewport &&
      viewport.width > 0 &&
      viewport.height > 0 &&
      bubble.width > 0 &&
      bubble.height > 0) {
    final double maxLeft = math.max(pad, viewport.width - bubble.width - pad);
    final double maxTop = math.max(pad, viewport.height - bubble.height - pad);
    final double clampedLeft = _clamp(left, pad, maxLeft);
    final double clampedTop = _clamp(top, pad, maxTop);
    shift = Offset(clampedLeft - left, clampedTop - top);
    left = clampedLeft;
    top = clampedTop;
  }

  // ── 4. 箭头对准目标中心，且不能顶到圆角上 ──
  final PopoverArrowSide arrowSide = _arrowSideFor(actual, showArrow);
  double arrowOffset = 0.0;
  if (arrowSide != PopoverArrowSide.none &&
      bubble.width > 0 &&
      bubble.height > 0) {
    final bool horizontalEdge =
        arrowSide == PopoverArrowSide.top ||
        arrowSide == PopoverArrowSide.bottom;
    // 目标中心在气泡局部坐标里的投影。用**夹取后**的 left / top，
    // 箭头才不会因为贴边平移而跑偏。
    final double raw = horizontalEdge
        ? target.center.dx - left
        : target.center.dy - top;
    final double extent = horizontalEdge ? bubble.width : bubble.height;
    final double inset = radius + arrowWidth / 2.0 + 2.0;
    final double lo = math.min(inset, extent / 2.0);
    final double hi = math.max(lo, extent - inset);
    arrowOffset = _clamp(raw, lo, hi);
  }

  return _BubbleLayout(
    placement: actual,
    arrowSide: arrowSide,
    offset: Offset(left, top),
    arrowOffset: arrowOffset,
    shift: shift,
    flipped: flipped,
  );
}

// ── 公开纯函数：Popover 版（相对触发器坐标）─────────────────────────────────

/// 把「首选方向 + 对齐 + 真实尺寸」解算成一个 [PopoverPosition]。
///
/// 返回的 [PopoverPosition.offset] 是**气泡整体（含箭头）左上角相对触发器
/// 左上角的位移**，正好喂给 `CompositedTransformFollower.offset`；页面滚动
/// 由 LayerLink 自动跟随，不需要每帧重算。
///
/// 底层和 [computeTooltipPlacement] 是同一份 [_resolveCore]，只是坐标系不同。
PopoverPosition resolvePopoverPosition({
  required PopoverPlacement placement,
  required PopoverAlign align,
  required bool autoFlip,
  required bool showArrow,
  required Size triggerSize,
  required Size popupSize,
  required Offset triggerOrigin,
  required Size viewport,
  required double gap,
  required double arrowWidth,
  required double arrowHeight,
  required double radius,
  required double edgePadding,
  required TextDirection direction,
  required bool constrainToViewport,
}) {
  final _BubbleLayout layout = _resolveCore(
    target: triggerOrigin & triggerSize,
    bubble: popupSize,
    viewport: viewport,
    placement: placement,
    align: align,
    autoFlip: autoFlip,
    showArrow: showArrow,
    constrainToViewport: constrainToViewport,
    gap: gap,
    arrowWidth: arrowWidth,
    radius: radius,
    edgePadding: edgePadding,
    direction: direction,
  );
  return PopoverPosition(
    placement: layout.placement,
    arrowSide: layout.arrowSide,
    offset: layout.offset - triggerOrigin,
    arrowOffset: layout.arrowOffset,
    shift: layout.shift,
    flipped: layout.flipped,
  );
}

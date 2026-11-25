part of '../flutter_context_menu.dart';

// ── 尺寸与位置：纯函数，方便单独验证 ──────────────────────────────────────

/// 某一级菜单在 Overlay 坐标系里的最终位置，以及是否发生了翻转。
@immutable
class ContextMenuPlacement {
  const ContextMenuPlacement({
    required this.origin,
    required this.size,
    required this.flippedX,
    required this.flippedY,
  });

  /// 菜单左上角。
  final Offset origin;

  final Size size;
  final bool flippedX;
  final bool flippedY;

  Rect get rect => origin & size;

  /// 缩放动画的锚点：菜单被翻到锚点左侧 / 上方时，从右下角展开，
  /// 视觉上始终像是从鼠标位置 / 父级行长出来。
  Alignment get growthAlignment =>
      Alignment(flippedX ? 1.0 : -1.0, flippedY ? 1.0 : -1.0);
}

double _entryHeight<T extends Object>(
  ContextMenuItem<T> item,
  ContextMenuStyle style,
) => switch (item.kind) {
  ContextMenuEntryKind.action => style.itemHeight,
  ContextMenuEntryKind.header => style.headerHeight,
  ContextMenuEntryKind.divider => style.dividerHeight,
};

/// 行高固定，所以总高度可以在插入浮层前精确算出。
///
/// [width] 覆盖 [ContextMenuStyle.width]：子菜单父项可以用自己的
/// [ContextMenuItem.width] 让下一级单独变宽 / 变窄。
Size measureContextMenu<T extends Object>(
  List<ContextMenuItem<T>> items,
  ContextMenuStyle style, {
  double? width,
}) {
  double height = style.padding * 2;
  for (final ContextMenuItem<T> item in items) {
    height += _entryHeight(item, style);
  }
  return Size(width ?? style.width, height);
}

/// 第 [index] 行的顶边相对面板顶边的偏移（含面板内边距）。
/// 子菜单要跟这一行对齐，但不方便在插入浮层前量 widget 尺寸，
/// 由于行高固定，直接累加前面各行的高度即可。
double contextMenuItemTop<T extends Object>(
  List<ContextMenuItem<T>> items,
  int index,
  ContextMenuStyle style,
) {
  double y = style.padding;
  for (int i = 0; i < index && i < items.length; i++) {
    y += _entryHeight(items[i], style);
  }
  return y;
}

double _clampToViewport(
  double value,
  double viewportExtent,
  double menuExtent,
  double edgePadding,
) {
  final double lower = edgePadding;
  final double upper = math.max(
    lower,
    viewportExtent - menuExtent - edgePadding,
  );
  return value.clamp(lower, upper);
}

/// 把点击点解析成根菜单左上角：右下空间不够就翻到左 / 上，最后再夹进
/// 可视区域（菜单比屏幕还大时左上角至少要落在 [edgePadding] 上）。
ContextMenuPlacement resolveContextMenuPlacement({
  required Offset anchor,
  required Size viewport,
  required Size menuSize,
  required double edgePadding,
}) {
  bool flippedX = false;
  bool flippedY = false;
  double x = anchor.dx;
  double y = anchor.dy;

  if (x + menuSize.width > viewport.width - edgePadding) {
    final double left = x - menuSize.width;
    if (left >= edgePadding) {
      x = left;
      flippedX = true;
    }
  }
  if (y + menuSize.height > viewport.height - edgePadding) {
    final double above = y - menuSize.height;
    if (above >= edgePadding) {
      y = above;
      flippedY = true;
    }
  }

  return ContextMenuPlacement(
    origin: Offset(
      _clampToViewport(x, viewport.width, menuSize.width, edgePadding),
      _clampToViewport(y, viewport.height, menuSize.height, edgePadding),
    ),
    size: menuSize,
    flippedX: flippedX,
    flippedY: flippedY,
  );
}

/// 子菜单位置：优先贴在父菜单**右侧**，右边放不下就翻到**左侧**；
/// 垂直方向尽量让子菜单首行与父级那一行对齐，底部溢出时整体上移，
/// 最后统一夹进可视区。
ContextMenuPlacement resolveSubmenuPlacement({
  required Rect parentRect,
  required double itemTop,
  required Size menuSize,
  required Size viewport,
  required double edgePadding,
  required double panelPadding,
  required double overlap,
}) {
  bool flippedX = false;
  double x = parentRect.right - overlap;
  if (x + menuSize.width > viewport.width - edgePadding) {
    final double left = parentRect.left - menuSize.width + overlap;
    if (left >= edgePadding) {
      x = left;
      flippedX = true;
    }
  }

  // itemTop 含面板 padding；子菜单自己也有 padding，减掉后两级首行才齐平。
  final double desiredY = parentRect.top + itemTop - panelPadding;
  final double maxY = math.max(
    edgePadding,
    viewport.height - menuSize.height - edgePadding,
  );
  final bool flippedY = desiredY > maxY;

  return ContextMenuPlacement(
    origin: Offset(
      _clampToViewport(x, viewport.width, menuSize.width, edgePadding),
      _clampToViewport(desiredY, viewport.height, menuSize.height, edgePadding),
    ),
    size: menuSize,
    flippedX: flippedX,
    flippedY: flippedY,
  );
}

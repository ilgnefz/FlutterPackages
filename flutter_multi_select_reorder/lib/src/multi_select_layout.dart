part of '../flutter_multi_select_reorder.dart';

// ── 布局：把「槽位下标」和「像素坐标」互相换算 ──────────────────────────

enum _LayoutKind { list, grid }

/// 两个形态共用的布局参数。内部类型，不暴露给调用方。
///
/// list 只有一个 [spacing]（行间距）；grid 拆成 [mainAxisSpacing]（行间距）和
/// [crossAxisSpacing]（列间距），与官方 `GridView` / `SliverGridDelegate` 对齐。
@immutable
class _LayoutSpec {
  const _LayoutSpec.list({this.itemExtent = 48, this.spacing = 0.0})
    : kind = _LayoutKind.list,
      crossAxisCount = null,
      maxCellWidth = 120,
      aspectRatio = 1,
      mainAxisExtent = null,
      mainAxisSpacing = 0,
      crossAxisSpacing = 0;

  const _LayoutSpec.grid({
    this.crossAxisCount,
    this.maxCellWidth = 120,
    this.aspectRatio = 1,
    this.mainAxisExtent,
    this.mainAxisSpacing = 4,
    this.crossAxisSpacing = 4,
  }) : kind = _LayoutKind.grid,
       itemExtent = 48,
       spacing = 0;

  final _LayoutKind kind;

  /// list：每行固定高度。
  final double itemExtent;

  /// list：行间距（主轴方向）。
  final double spacing;

  /// grid：固定列数；为 null 时按 [maxCellWidth] 自适应。
  final int? crossAxisCount;
  final double maxCellWidth;
  final double aspectRatio;
  final double? mainAxisExtent;

  /// grid：行间距 / 列间距。
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  MultiSelectLayout compute(double maxWidth, EdgeInsets padding) {
    final double contentWidth = math.max(0.0, maxWidth - padding.horizontal);
    if (kind == _LayoutKind.list) {
      return _ListLayout(
        cellWidth: math.max(1.0, contentWidth),
        cellHeight: itemExtent,
        mainAxisSpacing: spacing,
        padding: padding,
      );
    }
    final int cols = crossAxisCount != null
        ? math.max(1, crossAxisCount!)
        : math.max(
            1,
            (contentWidth / math.max(1.0, maxCellWidth + crossAxisSpacing))
                .ceil(),
          );
    final double cellWidth = math.max(
      1.0,
      (contentWidth - crossAxisSpacing * (cols - 1)) / cols,
    );
    return _GridLayout(
      cols: cols,
      cellWidth: cellWidth,
      cellHeight: mainAxisExtent ?? cellWidth / math.max(0.01, aspectRatio),
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      padding: padding,
    );
  }
}

/// 纯布局计算：ListView 是一列，GridView 是 N 列，其余逻辑完全一致。
@immutable
abstract class MultiSelectLayout {
  const MultiSelectLayout({
    required this.cellWidth,
    required this.cellHeight,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
    required this.padding,
  });

  final double cellWidth;
  final double cellHeight;

  /// 主轴（纵向）间距：list 的行距 / grid 的行距。
  final double mainAxisSpacing;

  /// 交叉轴（横向）间距：只有 grid 用到，list 恒为 0。
  final double crossAxisSpacing;

  final EdgeInsets padding;

  int get columns;

  /// 纵向 step：格高 + 行距。
  double get stepY => cellHeight + mainAxisSpacing;

  /// 第 [slot] 个槽位左上角相对内容区的坐标。
  Offset offsetOf(int slot);

  /// 内容区总高度（按**条目总数**算，不按拖动时的槽位数算，
  /// 否则在底部拖动时滚动位置会被 clamp 一下，出现跳动）。
  double extentFor(int count);

  /// 指针坐标 → 插入槽位，clamp 到 `[0, maxSlot]`。
  int slotAt(Offset local, int maxSlot);
}

class _ListLayout extends MultiSelectLayout {
  const _ListLayout({
    required super.cellWidth,
    required super.cellHeight,
    required super.mainAxisSpacing,
    required super.padding,
  }) : super(crossAxisSpacing: 0);

  @override
  int get columns => 1;

  @override
  Offset offsetOf(int slot) => Offset(padding.left, padding.top + slot * stepY);

  @override
  double extentFor(int count) => count <= 0
      ? padding.vertical
      : count * cellHeight + (count - 1) * mainAxisSpacing + padding.vertical;

  @override
  int slotAt(Offset local, int maxSlot) {
    final int row = ((local.dy - padding.top) / math.max(1.0, stepY)).floor();
    return _clampInt(row, 0, maxSlot);
  }
}

class _GridLayout extends MultiSelectLayout {
  const _GridLayout({
    required this.cols,
    required super.cellWidth,
    required super.cellHeight,
    required super.mainAxisSpacing,
    required super.crossAxisSpacing,
    required super.padding,
  });

  final int cols;

  @override
  int get columns => cols;

  double get stepX => cellWidth + crossAxisSpacing;

  @override
  Offset offsetOf(int slot) => Offset(
    padding.left + (slot % cols) * stepX,
    padding.top + (slot ~/ cols) * stepY,
  );

  @override
  double extentFor(int count) {
    if (count <= 0) return padding.vertical;
    final int rows = (count + cols - 1) ~/ cols;
    return rows * cellHeight + (rows - 1) * mainAxisSpacing + padding.vertical;
  }

  @override
  int slotAt(Offset local, int maxSlot) {
    final double x = local.dx - padding.left;
    final double y = local.dy - padding.top;
    final int col = _clampInt((x / math.max(1.0, stepX)).floor(), 0, cols - 1);
    final int row = math.max(0, (y / math.max(1.0, stepY)).floor());
    return _clampInt(row * cols + col, 0, maxSlot);
  }
}

int _clampInt(int value, int min, int max) =>
    value < min ? min : (value > max ? max : value);

double _clampDouble(double value, double min, double max) =>
    value < min ? min : (value > max ? max : value);

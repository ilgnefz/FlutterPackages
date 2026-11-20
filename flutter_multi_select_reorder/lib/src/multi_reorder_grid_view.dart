part of '../flutter_multi_select_reorder.dart';

// ── 内部实现：多列 GridView ──────────────────────────────────────────────

/// 支持多选 + 整组拖动排序的网格，行为与 `MultiSelectReorder.list` 完全一致，
/// 只是把布局换成 N 列。
///
/// [crossAxisCount] 不传时按 [maxCellWidth] 自适应列数；[mainAxisExtent]
/// 不传时按 [aspectRatio] 换算格子高度。
class _MultiReorderGridView extends MultiSelectReorder {
  const _MultiReorderGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.style = const MultiSelectStyle(),
    this.crossAxisCount,
    this.maxCellWidth = 120,
    this.aspectRatio = 1,
    this.mainAxisExtent,
    this.mainAxisSpacing = 4,
    this.crossAxisSpacing = 4,
    this.padding,
    this.scrollController,
    this.itemKeyBuilder,
    this.proxyDecorator,
    this.itemId,
    this.initialSelectedIndices = const <int>[],
    this.onDoubleTap,
    this.onSecondaryTap,
    this.onSelectionChanged,
    this.onReorder,
  });

  /// 条目总数。数据由调用方持有，这里只用它算槽位。
  final int itemCount;

  final MultiSelectItemBuilder itemBuilder;

  /// 外部控制器：读取 / 程序化修改选中下标。不传则内部自建。
  final MultiSelectController? controller;

  final MultiSelectStyle style;

  /// 固定列数；为 null 时按 [maxCellWidth] 自适应。
  final int? crossAxisCount;

  /// 自适应列数时单格最大宽度。
  final double maxCellWidth;

  /// 单格宽高比（宽 / 高）；[mainAxisExtent] 不为 null 时忽略。
  final double aspectRatio;

  /// 固定单格高度。
  final double? mainAxisExtent;

  /// 行间距（主轴方向）。
  final double mainAxisSpacing;

  /// 列间距（交叉轴方向）。
  final double crossAxisSpacing;

  /// 内容区内边距；null 时无内边距。
  final EdgeInsets? padding;

  final ScrollController? scrollController;

  /// 条目 key 的显式来源，通常不用传：给 `itemBuilder` 返回的根 widget
  /// 加个业务 key，组件会自己读；这里传了则以它为准。
  final MultiSelectKeyBuilder? itemKeyBuilder;

  /// 自定义拖动预览，签名与官方 `ReorderItemProxyDecorator` 一致，多选时
  /// 逐层调用；默认按点选顺序叠加每一项，外面加不透明背景与阴影。
  final MultiSelectProxyDecorator? proxyDecorator;

  /// 下标 → 稳定 id；不传时 id 就是下标。见 [MultiSelectItemId]。
  final MultiSelectItemId? itemId;

  /// 初始选中的下标（仅在没有外部 controller、且它还没选中任何项时生效）。
  final List<int> initialSelectedIndices;

  /// 双击回调，参数是被双击条目的原下标。
  ///
  /// 传了它之后单击与双击要区分：默认（`MultiSelectStyle.doubleTapMode ==
  /// .delay`）单击会挂起一个双击间隔（300ms）再提交选中，双击则**完全不改
  /// 选中**、只调这个回调。想单击零延迟就用 `.revert`（双击时选中会先亮一下
  /// 再回滚）。不传时没有任何延迟，行为与以前一样。
  final void Function(int index)? onDoubleTap;

  /// 右键（二级点击）回调，参数是条目下标与右键按下处的全局坐标。
  /// 不改变选中，右键菜单里要「先选中它」请自己调 controller。
  final MultiSelectSecondaryTapCallback? onSecondaryTap;

  /// 选中集合变化时回调，参数是按点选顺序排列的下标。
  final ValueChanged<List<int>>? onSelectionChanged;

  /// 拖拽结束回调，参数是一一对应的被拖条目原下标与新下标。
  final MultiSelectReorderCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    return _MultiSelectDragView(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      layout: _LayoutSpec.grid(
        crossAxisCount: crossAxisCount,
        maxCellWidth: maxCellWidth,
        aspectRatio: aspectRatio,
        mainAxisExtent: mainAxisExtent,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
      ),
      style: style,
      padding: padding ?? EdgeInsets.zero,
      controller: controller,
      itemKeyBuilder: itemKeyBuilder,
      proxyDecorator: proxyDecorator,
      itemId: itemId,
      initialSelectedIndices: initialSelectedIndices,
      scrollController: scrollController,
      onDoubleTap: onDoubleTap,
      onSecondaryTap: onSecondaryTap,
      onSelectionChanged: onSelectionChanged,
      onReorder: onReorder,
    );
  }
}

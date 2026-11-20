/// 多选 + 整组拖动排序的列表 / 网格。
///
/// 组件**不持有业务数据**：只接收 `itemCount` 和按坐标取数的 `itemBuilder`，
/// 内部维护选中下标与拖动顺序；松手后 `onReorder` 回传一一对应的
/// `oldIndex` / `newIndex`（只含被拖条目，不回传整份顺序），父组件据此重排自己的数据。
///
/// 公开参数名尽量与 Material 的 `ReorderableListView` / `GridView` 对齐：
/// `itemCount`、`itemBuilder`、`itemExtent`、`padding`、`scrollController`、
/// `proxyDecorator`、`onReorder` 含义一致；
/// list 用 `spacing`，grid 用 `mainAxisSpacing` / `crossAxisSpacing`。
///
/// ```dart
/// MultiSelectReorder.list(
///   itemCount: items.length,
///   itemBuilder: (context, index, selected) => ListTile(title: Text(items[index])),
///   style: MultiSelectStyle(
///     // 选中样式放这里：只在选中时调用，也不会串到拖动浮层上。
///     selectedBuilder: (child, index, selectedIndex, selectedCount) =>
///         ColoredBox(color: Colors.blue.shade50, child: child),
///   ),
///   onReorder: (oldIndex, newIndex) => setState(() {
///     items = applyMultiReorder(items, oldIndex, newIndex);
///   }),
/// )
///
/// MultiSelectReorder.grid(
///   itemCount: photos.length,
///   crossAxisCount: 4,
///   mainAxisSpacing: 8,
///   crossAxisSpacing: 8,
///   itemBuilder: (context, index, selected) => PhotoTile(photo: photos[index]),
///   onReorder: (old, next) => setState(() => photos = applyMultiReorder(photos, old, next)),
/// )
/// ```
///
/// 命名构造器 `.list` / `.grid` 已经说明形态，所以类名后不加 `ListView` /
/// `GridView`。`Multi` 指整组，`Select` 指多选，`Reorder` 指拖动排序。
///
/// ## 拿选中项
///
/// 选中集合的**唯一真值**在 [MultiSelectController] 里（按点选顺序），组件不
/// 接受外部再传一份数组：
///
/// ```dart
/// final MultiSelectController controller = MultiSelectController();
/// MultiSelectReorder.list(
///   controller: controller,
///   itemCount: items.length,
///   itemId: (int i) => items[i].id,           // 稳定 id，跨过滤视图也不丢
///   itemBuilder: (context, index, selected) => Text(items[index]),
/// );
/// final List<int> picked = controller.selectedIndices;   // 当前视图可见的下标
/// final List<Object> ids = controller.selectedIds;       // 全部选中的 id
/// controller.setIds(<Object>['a1', 'b2']);               // 从外部改选中
/// ```
///
/// 别的组件要跟着选中变化刷新，包一层 `ListenableBuilder` 监听同一个
/// controller 就行；**不要**在外面再存一份选中数组（两份真值迟早会不一致）。
/// 没有外部 controller 时，也可以用 `onSelectionChanged` 拿选中下标。
///
/// ## 交互
///
/// 单击选中这一项（清空其它），再点同一个条目取消选中；Ctrl / Cmd 切换，
/// Shift 从锚点追加一段范围；按住已选中的项再拖，整组一起搬走。需要「点别的
/// 条目也能叠加选中」的旧行为时，可显式传
/// `style: MultiSelectStyle(mode: MultiSelectMode.multiple)`。
/// 拖动预览默认按点选顺序把整组叠成几张卡片，落点占位框、拖动阴影等可在
/// [MultiSelectStyle] 里定制。样式分三处管：`itemBuilder` 只管默认样式、
/// `style.selectedBuilder` 管选中样式、`style.proxyDecorator` 管拖动样式——
/// 拖动浮层恒按「未选中」构建，所以选中底色不会跟着卡片飞起来。想让条目带
/// 圆角，只传一个 `style.borderRadius` 即可：内容裁剪、hover 高亮、拖动预览
/// 会一起变成同一个圆角，不必在每个 `itemBuilder` 里各画一遍。
///
/// 让位动画对齐官方 `ReorderableListView`：用 `Transform.translate` 做位移、
/// 打断时从当前位置续接，连续跨格拖动也平滑，不会一顿一顿。松手后被拖条目会
/// 从落点滑进自己的槽位，其它条目同时后移让出这一整组的位置。
///
/// 外部数据增删条目时想让后续项平滑移动到新槽位，只要给 `itemBuilder` 返回的
/// 根 widget 加个业务 key（`key: ValueKey(item.id)`，和普通 [ListView] 一样），
/// 组件会直接读它；也可以用 `itemKeyBuilder` 显式指定。两处都没有时按 index
/// 生成 key，元素会原地换内容，没有位移动画。
///
/// ## 布局要求
///
/// 两种形态都需要**有界的主轴尺寸**（如 [SizedBox] / [Expanded]），因为让位
/// 动画要用确定的槽位坐标；[MultiSelectReorder.grid] 支持固定列数
/// `crossAxisCount` 或按 `maxCellWidth` 自适应列数。
library;

import 'dart:async';
import 'dart:collection' show LinkedHashSet;
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

part 'src/multi_select_types.dart';
part 'src/multi_select_controller.dart';
part 'src/multi_select_layout.dart';
part 'src/multi_select_drag_view.dart';
part 'src/multi_reorder_list_view.dart';
part 'src/multi_reorder_grid_view.dart';

/// 多选 + 整组拖动排序的列表 / 网格。
///
/// 用 [MultiSelectReorder.list] 得到单列列表，[MultiSelectReorder.grid]
/// 得到网格；两者共用同一套选中、拖动、动画和回调实现。
abstract class MultiSelectReorder extends StatelessWidget {
  /// 抽象类，不能被直接实例化；只由内部的两种形态继承。
  const MultiSelectReorder({super.key});

  /// 单列列表：行高固定为 `itemExtent`。
  factory MultiSelectReorder.list({
    Key? key,
    required int itemCount,
    required MultiSelectItemBuilder itemBuilder,
    MultiSelectController? controller,
    MultiSelectStyle style = const MultiSelectStyle(),
    double itemExtent = 48,
    double spacing = 0.0,
    EdgeInsets? padding,
    ScrollController? scrollController,
    MultiSelectKeyBuilder? itemKeyBuilder,
    MultiSelectProxyDecorator? proxyDecorator,
    MultiSelectItemId? itemId,
    List<int> initialSelectedIndices = const <int>[],
    void Function(int index)? onDoubleTap,
    MultiSelectSecondaryTapCallback? onSecondaryTap,
    ValueChanged<List<int>>? onSelectionChanged,
    MultiSelectReorderCallback? onReorder,
  }) {
    return _MultiReorderListView(
      key: key,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      controller: controller,
      style: style,
      itemExtent: itemExtent,
      spacing: spacing,
      padding: padding,
      scrollController: scrollController,
      itemKeyBuilder: itemKeyBuilder,
      proxyDecorator: proxyDecorator,
      itemId: itemId,
      initialSelectedIndices: initialSelectedIndices,
      onDoubleTap: onDoubleTap,
      onSecondaryTap: onSecondaryTap,
      onSelectionChanged: onSelectionChanged,
      onReorder: onReorder,
    );
  }

  /// 多列网格：`crossAxisCount` 不传时按 `maxCellWidth` 自适应列数。
  factory MultiSelectReorder.grid({
    Key? key,
    required int itemCount,
    required MultiSelectItemBuilder itemBuilder,
    MultiSelectController? controller,
    MultiSelectStyle style = const MultiSelectStyle(),
    int? crossAxisCount,
    double maxCellWidth = 120,
    double aspectRatio = 1,
    double? mainAxisExtent,
    double mainAxisSpacing = 4,
    double crossAxisSpacing = 4,
    EdgeInsets? padding,
    ScrollController? scrollController,
    MultiSelectKeyBuilder? itemKeyBuilder,
    MultiSelectProxyDecorator? proxyDecorator,
    MultiSelectItemId? itemId,
    List<int> initialSelectedIndices = const <int>[],
    void Function(int index)? onDoubleTap,
    MultiSelectSecondaryTapCallback? onSecondaryTap,
    ValueChanged<List<int>>? onSelectionChanged,
    MultiSelectReorderCallback? onReorder,
  }) {
    return _MultiReorderGridView(
      key: key,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      controller: controller,
      style: style,
      crossAxisCount: crossAxisCount,
      maxCellWidth: maxCellWidth,
      aspectRatio: aspectRatio,
      mainAxisExtent: mainAxisExtent,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      padding: padding,
      scrollController: scrollController,
      itemKeyBuilder: itemKeyBuilder,
      proxyDecorator: proxyDecorator,
      itemId: itemId,
      initialSelectedIndices: initialSelectedIndices,
      onDoubleTap: onDoubleTap,
      onSecondaryTap: onSecondaryTap,
      onSelectionChanged: onSelectionChanged,
      onReorder: onReorder,
    );
  }
}

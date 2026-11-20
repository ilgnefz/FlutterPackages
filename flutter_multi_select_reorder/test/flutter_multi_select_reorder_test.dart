import 'package:flutter_multi_select_reorder/flutter_multi_select_reorder.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
// 本地 fork 的 Flutter 会提示改用 material_ui；包本身要兼容官方 Flutter。
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _items = <String>['A', 'B', 'C', 'D', 'E'];

ValueKey<String> tile(String item) => ValueKey<String>('tile-$item');

Finder tileFinder(String item) => find.byKey(tile(item));

/// 条目当前是否处于选中态（harness 用底色区分）。
bool _selectedOf(WidgetTester tester, String item) {
  final Container box = tester.widget<Container>(tileFinder(item));
  return box.color == const Color(0xFFBBDEFB);
}

Finder get _feedback =>
    find.byKey(const ValueKey<String>('multi-select-feedback'));

Finder get _feedbackItem =>
    find.byKey(const ValueKey<String>('multi-select-feedback-item'));

/// 记录 onReorder 的两组下标，方便断言一一对应关系。
class _Moves {
  final List<List<int>> oldIndex = <List<int>>[];
  final List<List<int>> newIndex = <List<int>>[];

  void call(List<int> old, List<int> next) {
    oldIndex.add(old);
    newIndex.add(next);
  }
}

/// 包一个固定尺寸的视口；`onReorder` 会按新顺序换掉数据。
class _Harness extends StatefulWidget {
  const _Harness({
    required this.items,
    this.controller,
    this.grid = false,
    this.show = true,
    this.style = const MultiSelectStyle(),
    this.proxyDecorator,
    this.initialSelectedIndices = const <int>[],
    this.itemKeyBuilder,
    this.itemId,
    this.spacing = 0,
    this.mainAxisSpacing = 4,
    this.crossAxisSpacing = 4,
    this.padding,
    this.keyOnContent = true,
    this.onSelectionChanged,
    this.onDoubleTap,
    this.onSecondaryTap,
    this.onBuildItem,
    this.onReorder,
  });

  final List<String> items;
  final MultiSelectController? controller;
  final bool grid;

  /// 置 false 时只把拖动视图摘掉、保留外层 MaterialApp / Overlay。
  final bool show;

  final MultiSelectStyle style;
  final MultiSelectProxyDecorator? proxyDecorator;
  final List<int> initialSelectedIndices;
  final MultiSelectKeyBuilder? itemKeyBuilder;
  final MultiSelectItemId? itemId;
  final double spacing;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsets? padding;

  /// itemBuilder 返回的根 widget 是否带业务 key（`tile(item)`）。
  final bool keyOnContent;
  final ValueChanged<List<int>>? onSelectionChanged;

  final void Function(int index)? onDoubleTap;
  final MultiSelectSecondaryTapCallback? onSecondaryTap;
  final void Function(String item)? onBuildItem;
  final MultiSelectReorderCallback? onReorder;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late List<String> _items = widget.items;

  @override
  void didUpdateWidget(covariant _Harness oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) _items = widget.items;
  }

  Widget _itemBuilder(BuildContext context, int index, bool selected) {
    final String item = _items[index];
    widget.onBuildItem?.call(item);
    return Container(
      key: widget.keyOnContent ? tile(item) : null,
      color: selected ? const Color(0xFFBBDEFB) : const Color(0xFFEEEEEE),
      alignment: Alignment.center,
      child: Text(item),
    );
  }

  void _handleReorder(List<int> oldIndex, List<int> newIndex) {
    setState(() => _items = applyMultiReorder(_items, oldIndex, newIndex));
    widget.onReorder?.call(oldIndex, newIndex);
  }

  Widget _buildView() {
    final MultiSelectItemId? itemId = widget.itemId;
    if (widget.grid) {
      return MultiSelectReorder.grid(
        itemCount: _items.length,
        controller: widget.controller,
        style: widget.style,
        proxyDecorator: widget.proxyDecorator,
        crossAxisCount: 2,
        mainAxisExtent: 48,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
        padding: widget.padding,
        itemBuilder: _itemBuilder,
        itemKeyBuilder: widget.itemKeyBuilder,
        itemId: itemId,
        initialSelectedIndices: widget.initialSelectedIndices,
        onSelectionChanged: widget.onSelectionChanged,
        onSecondaryTap: widget.onSecondaryTap,
        onReorder: _handleReorder,
      );
    }
    return MultiSelectReorder.list(
      itemCount: _items.length,
      controller: widget.controller,
      style: widget.style,
      proxyDecorator: widget.proxyDecorator,
      spacing: widget.spacing,
      padding: widget.padding,
      itemBuilder: _itemBuilder,
      itemKeyBuilder: widget.itemKeyBuilder,
      itemId: itemId,
      initialSelectedIndices: widget.initialSelectedIndices,
      onSelectionChanged: widget.onSelectionChanged,
      onDoubleTap: widget.onDoubleTap,
      onSecondaryTap: widget.onSecondaryTap,
      onReorder: _handleReorder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 320,
            child: widget.show ? _buildView() : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// 从 [from] 按下、越过 dragSlop 后拖到 [to] 再松手。
Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final TestGesture gesture = await tester.startGesture(
    from,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );
  await gesture.moveTo(from + const Offset(0, 12));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// 从 [start] 按下并越过 dragSlop，停在「拖动中」状态供断言。
Future<TestGesture> _beginDragGesture(WidgetTester tester, Offset start) async {
  final TestGesture gesture = await tester.startGesture(
    start,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );
  await gesture.moveTo(start + const Offset(0, 12));
  await tester.pump();
  return gesture;
}

/// 内容区左上角（第 0 行）在屏幕上的位置。
Offset _listTopLeft(WidgetTester tester) => tester.getTopLeft(tileFinder('A'));

void main() {
  testWidgets('列表渲染全部条目，单击只选中一个并回调选中下标', (tester) async {
    final List<List<int>> picked = <List<int>>[];
    await tester.pumpWidget(
      _Harness(items: _items, onSelectionChanged: picked.add),
    );
    for (final String item in _items) {
      expect(tileFinder(item), findsOneWidget);
    }

    await tester.tap(tileFinder('B'));
    await tester.pump();
    expect(picked.last, <int>[1]);

    await tester.tap(tileFinder('D'));
    await tester.pump();
    expect(picked.last, <int>[3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同一项点第一次选中，再点一次取消选中', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    final List<List<int>> picked = <List<int>>[];
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        onSelectionChanged: picked.add,
      ),
    );

    await tester.tap(tileFinder('C'));
    await tester.pump();
    expect(controller.selectedIndices, <int>[2]);

    // 再点同一个条目 = 取消选中，不需要按修饰键。
    await tester.tap(tileFinder('C'));
    await tester.pump();
    expect(controller.selectedIndices, isEmpty);
    expect(picked.last, isEmpty);

    // 第三次点回来依旧是选中；点到别的条目仍然是单选（清掉其它）。
    await tester.tap(tileFinder('C'));
    await tester.pump();
    await tester.tap(tileFinder('D'));
    await tester.pump();
    expect(controller.selectedIndices, <int>[3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动期间条目不再参与命中测试，邻居不会闪 hover 高亮', (tester) async {
    await tester.pumpWidget(_Harness(items: _items));
    await tester.pump();

    bool ignoringFor(String label) {
      // 条目外层就是拖动引擎包的那层 IgnorePointer（最近的祖先）。
      final Finder ignore = find
          .ancestor(of: tileFinder(label), matching: find.byType(IgnorePointer))
          .first;
      return tester.widget<IgnorePointer>(ignore).ignoring;
    }

    // 静止时条目正常接收鼠标，hover 高亮可用。
    expect(ignoringFor('A'), isFalse);

    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('B')),
    );
    // 拖动中：鼠标一直悬在列表上，条目整层摘出命中测试，被顶到指针底下的
    // 邻居不会再亮起 hover 高亮。
    expect(ignoringFor('A'), isTrue);
    expect(ignoringFor('C'), isTrue);
    // 指针样式由跟随指针的浮层提供（拖动期间条目不参与命中测试），
    // 拖动前后光标保持一致。
    expect(
      tester
          .widget<MouseRegion>(
            find
                .descendant(of: _feedback, matching: find.byType(MouseRegion))
                .first,
          )
          .cursor,
      SystemMouseCursors.basic,
    );

    await gesture.up();
    await tester.pumpAndSettle();
    // 松手后恢复。
    expect(ignoringFor('A'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl 多选按点选顺序记录下标，再次 Ctrl 点击可取消', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(_Harness(items: _items, controller: controller));

    await tester.tap(tileFinder('D')); // 单选：只留下 D
    await tester.pump();
    expect(controller.selectedIndices, <int>[3]);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(tileFinder('B'));
    await tester.pump();
    await tester.tap(tileFinder('A'));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(controller.selectedIndices, <int>[3, 1, 0]);
    expect(controller.getSelectedIndices(), <int>[3, 1, 0]);
    expect(controller.selectedCount, 3);
    expect(controller.isSelected(1), isTrue);
    expect(controller.isSelected(2), isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(tileFinder('B'));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(controller.selectedIndices, <int>[3, 0]);

    // 不按修饰键再点一次，清掉其它项。
    await tester.tap(tileFinder('C'));
    await tester.pump();
    expect(controller.selectedIndices, <int>[2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shift 从锚点追加一段范围', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(_Harness(items: _items, controller: controller));

    await tester.tap(tileFinder('B')); // 锚点 = 1
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(tileFinder('D'));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(controller.selectedIndices, <int>[1, 2, 3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除中间项后，itemKeyBuilder 让后面项带动画上移', (tester) async {
    const List<String> before = <String>['A', 'B', 'C', 'D', 'E'];
    const List<String> after = <String>['A', 'C', 'D', 'E'];
    await tester.pumpWidget(
      _Harness(
        items: before,
        itemKeyBuilder: (int index) => ValueKey<String>(before[index]),
      ),
    );
    await tester.pump();

    final double cBefore = tester.getTopLeft(tileFinder('C')).dy;
    await tester.pumpWidget(
      _Harness(
        items: after,
        itemKeyBuilder: (int index) => ValueKey<String>(after[index]),
      ),
    );
    // 动画起点：后面项还停在旧位置。
    await tester.pump();
    expect(tester.getTopLeft(tileFinder('C')).dy, closeTo(cBefore, 1));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(tileFinder('C')).dy, lessThan(cBefore - 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('只给 itemBuilder 结果加 key，也能让后面项带动画上移', (tester) async {
    const List<String> before = <String>['A', 'B', 'C', 'D', 'E'];
    const List<String> after = <String>['A', 'C', 'D', 'E'];
    // 不传 itemKeyBuilder，只用 itemBuilder 返回的 widget 自带的业务 key。
    await tester.pumpWidget(_Harness(items: before));
    await tester.pump();

    final double cBefore = tester.getTopLeft(tileFinder('C')).dy;
    await tester.pumpWidget(_Harness(items: after));
    // 动画起点：后面项还停在旧位置（元素跟着业务 key 走了）。
    await tester.pump();
    expect(tester.getTopLeft(tileFinder('C')).dy, closeTo(cBefore, 1));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(tileFinder('C')).dy, lessThan(cBefore - 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('两处都没给 key 时按下标复用，删除后不播位移动画', (tester) async {
    const List<String> before = <String>['A', 'B', 'C', 'D', 'E'];
    const List<String> after = <String>['A', 'C', 'D', 'E'];
    await tester.pumpWidget(_Harness(items: before, keyOnContent: false));
    await tester.pump();

    final double cBefore = tester.getTopLeft(find.text('C')).dy;
    await tester.pumpWidget(_Harness(items: after, keyOnContent: false));
    // 按下标复用：第 1 格直接换成 C 的内容，第一帧就已经在新位置。
    await tester.pump();
    expect(tester.getTopLeft(find.text('C')).dy, lessThan(cBefore - 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('程序化选择 / 全选 / 清空 / 初始选中都生效', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    final List<List<int>> picked = <List<int>>[];
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        onSelectionChanged: picked.add,
      ),
    );

    controller.select(2);
    await tester.pump();
    expect(controller.selectedIndices, <int>[2]);

    controller.selectAll();
    await tester.pump();
    expect(controller.selectedCount, 5);

    controller.clear();
    await tester.pump();
    expect(controller.hasSelection, isFalse);

    controller.setSelection(<int>[4, 0]);
    await tester.pump();
    expect(controller.selectedIndices, <int>[4, 0]);
    expect(picked.last, <int>[4, 0]);

    controller.deselect(4);
    await tester.pump();
    expect(controller.selectedIndices, <int>[0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('initialSelectedIndices 在首次挂载时生效并回调一次', (tester) async {
    final List<List<int>> picked = <List<int>>[];
    await tester.pumpWidget(
      _Harness(
        items: _items,
        initialSelectedIndices: const <int>[1, 3],
        onSelectionChanged: picked.add,
      ),
    );
    await tester.pump();
    expect(picked, <List<int>>[
      <int>[1, 3],
    ]);
    expect(
      tester.widget<Container>(tileFinder('B')).color,
      const Color(0xFFBBDEFB),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('运行时替换 controller 会摘掉旧监听，选中状态干净切换', (tester) async {
    final MultiSelectController first = MultiSelectController();
    final MultiSelectController second = MultiSelectController();
    await tester.pumpWidget(_Harness(items: _items, controller: first));
    await tester.tap(tileFinder('A'));
    await tester.pump();
    expect(first.selectedIndices, <int>[0]);

    await tester.pumpWidget(_Harness(items: _items, controller: second));
    await tester.pump();
    await tester.tap(tileFinder('C'));
    await tester.pump();
    expect(second.selectedIndices, <int>[2]);

    first.select(4);
    await tester.pump();
    expect(second.selectedIndices, <int>[2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动已选中的整组：onReorder 返回一一对应的 old/new 下标', (tester) async {
    final _Moves moves = _Moves();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        initialSelectedIndices: const <int>[3, 1],
        onReorder: moves.call,
      ),
    );
    await tester.pump();

    // B 在第 1 行，按点选顺序整组是 [D(3), B(1)]；拖到第 0 行顶部。
    final Offset start = tester.getCenter(tileFinder('B'));
    await _drag(tester, start, _listTopLeft(tester) + const Offset(20, 6));

    // D、B 从原下标 3、1 移到新下标 0、1；只回传这 2 个数，不是整份顺序。
    expect(moves.oldIndex, <List<int>>[
      <int>[3, 1],
    ]);
    expect(moves.newIndex, <List<int>>[
      <int>[0, 1],
    ]);
    // Harness 按新顺序换数据：D、B 在最前。
    expect(tileFinder('D'), findsOneWidget);
    expect(
      tester.getTopLeft(tileFinder('D')).dy,
      lessThan(tester.getTopLeft(tileFinder('A')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动过程中只出现一个占位框', (tester) async {
    await tester.pumpWidget(
      _Harness(items: _items, initialSelectedIndices: const <int>[0, 2, 4]),
    );
    await tester.pump();

    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('C')),
    );

    expect(
      find.byKey(const ValueKey<String>('multi-select-placeholder')),
      findsOneWidget,
    );
    // 让位容器已从 AnimatedPositioned 换成 Transform.translate；占位框仍唯一。
    // （被拖条目在拖动浮层里也会出现，故不按整树计数条目。）
    expect(tileFinder('B'), findsOneWidget);
    expect(tileFinder('D'), findsOneWidget);
    expect(find.byType(Transform), findsWidgets);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('multi-select-placeholder')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('原地放下不回调，拖动未选中项只拖它自己', (tester) async {
    final _Moves moves = _Moves();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        initialSelectedIndices: const <int>[0],
        onReorder: moves.call,
      ),
    );
    await tester.pump();

    final Offset b = tester.getCenter(tileFinder('B'));
    final TestGesture noop = await tester.startGesture(
      b,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await noop.moveTo(b + const Offset(0, 10));
    await tester.pump();
    await noop.up();
    await tester.pumpAndSettle();
    expect(moves.oldIndex, isEmpty);

    await _drag(
      tester,
      tester.getCenter(tileFinder('C')),
      _listTopLeft(tester) + const Offset(20, 6),
    );
    // C 从下标 2 移到 0。
    expect(moves.oldIndex.single, <int>[2]);
    expect(moves.newIndex.single, <int>[0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('整组拖回原位：组内改成点选顺序，不是退回原样', (tester) async {
    final _Moves moves = _Moves();
    const List<String> items = <String>['1', '2', '3', '4', '5', '6'];
    await tester.pumpWidget(
      _Harness(
        items: items,
        // 点选顺序 2、4、3：与下标升序 1、2、3 不同。
        initialSelectedIndices: const <int>[1, 3, 2],
        onReorder: moves.call,
      ),
    );
    await tester.pump();

    // 按住「2」原地拖一下再放回同一格：落点没变，但组内次序该变成 2、4、3。
    final Offset start = tester.getCenter(tileFinder('2'));
    await _drag(tester, start, start);

    expect(moves.oldIndex, <List<int>>[
      <int>[1, 3, 2],
    ]);
    expect(moves.newIndex, <List<int>>[
      <int>[1, 2, 3],
    ]);
    // 期望顺序 1、2、4、3、5、6。
    final List<double> tops = <double>[
      for (final String item in <String>['1', '2', '4', '3', '5', '6'])
        tester.getTopLeft(tileFinder(item)).dy,
    ];
    expect(tops, orderedEquals(<double>[...tops]..sort()));
    expect(moves.oldIndex.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('重排后父组件按新顺序换数据，选中下标跟着重算', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        initialSelectedIndices: const <int>[1, 3],
      ),
    );
    await tester.pump();
    expect(controller.selectedIndices, <int>[1, 3]);

    await _drag(
      tester,
      tester.getCenter(tileFinder('B')),
      _listTopLeft(tester) + const Offset(20, 6),
    );

    expect(controller.selectedIndices, <int>[0, 1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GridView 按行列计算落点，也能整组拖动', (tester) async {
    final _Moves moves = _Moves();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        grid: true,
        initialSelectedIndices: const <int>[2, 3],
        onReorder: moves.call,
      ),
    );
    await tester.pump();

    // 2 列：C 在第 1 行第 0 列；拖到 A 的格子 → C、D 移到最前。
    await _drag(
      tester,
      tester.getCenter(tileFinder('C')),
      _listTopLeft(tester) + const Offset(20, 6),
    );

    expect(moves.oldIndex.single, <int>[2, 3]);
    expect(moves.newIndex.single, <int>[0, 1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enableDrag=false 时仍可多选，但不响应拖动', (tester) async {
    final _Moves moves = _Moves();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        style: const MultiSelectStyle(enableDrag: false),
        onReorder: moves.call,
        onSelectionChanged: (List<int> _) {},
      ),
    );

    await _drag(
      tester,
      tester.getCenter(tileFinder('B')),
      _listTopLeft(tester) + const Offset(20, 6),
    );
    expect(moves.oldIndex, isEmpty);
    // 单击仍然生效。
    await tester.tap(tileFinder('B'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('门面 .list / .grid 两种形态都能正常挂载', (tester) async {
    await tester.pumpWidget(_Harness(items: _items));
    await tester.pump();
    expect(
      find.byWidgetPredicate((Widget w) => w is MultiSelectReorder),
      findsOneWidget,
    );

    await tester.pumpWidget(_Harness(items: _items, grid: true));
    await tester.pump();
    expect(
      find.byWidgetPredicate((Widget w) => w is MultiSelectReorder),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('浮层插入后同帧松手：Overlay 还没 build 也要移除', (tester) async {
    await tester.pumpWidget(_Harness(items: _items));
    final Offset start = tester.getCenter(tileFinder('A'));
    final TestGesture gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await gesture.moveTo(start + const Offset(0, 12));
    await tester.pump();
    expect(_feedback, findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(_feedback, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('全选后补选不残留：拖完整组浮层只有一份', (tester) async {
    await tester.pumpWidget(
      _Harness(items: const <String>['A', 'B', 'C', 'D', 'E', 'F']),
    );
    await tester.tap(tileFinder('A'));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    for (final String item in <String>['B', 'C', 'D', 'E', 'F']) {
      await tester.tap(tileFinder(item));
      await tester.pump();
    }
    // Ctrl 点 F 取消，再 Ctrl 点 F 加回来。
    await tester.tap(tileFinder('F'));
    await tester.pump();
    await tester.tap(tileFinder('F'));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('F')),
    );
    expect(_feedback, findsOneWidget);
    expect(_feedbackItem, findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_feedback, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('浮层插入后同帧 cancel 也要移除', (tester) async {
    await tester.pumpWidget(_Harness(items: _items));
    final Offset start = tester.getCenter(tileFinder('A'));
    final TestGesture gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await gesture.moveTo(start + const Offset(0, 12));
    await tester.pump();
    await gesture.cancel();
    await tester.pump();
    expect(_feedback, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('上一次 up 丢失后，新的按下会清掉残留的拖动状态', (tester) async {
    await tester.pumpWidget(_Harness(items: _items));
    final Offset a = tester.getCenter(tileFinder('A'));
    final TestGesture lost = await tester.startGesture(
      a,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await lost.moveTo(a + const Offset(0, 12));
    await tester.pump();
    expect(_feedback, findsOneWidget);

    // 不发 up，直接开新的一次按下。
    final TestGesture next = await tester.startGesture(
      tester.getCenter(tileFinder('C')),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump();
    expect(_feedback, findsNothing);
    await next.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动中视图被卸载，浮层随 deactivate 一起消失', (tester) async {
    await tester.pumpWidget(_Harness(items: _items));
    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('A')),
    );
    expect(_feedback, findsOneWidget);

    await tester.pumpWidget(_Harness(items: _items, show: false));
    await tester.pump();
    expect(_feedback, findsNothing);
    await gesture.up();
    expect(tester.takeException(), isNull);
  });

  testWidgets('只摘掉视图、Overlay 仍在，浮层也要收走', (tester) async {
    await tester.pumpWidget(_Harness(items: _items));
    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('A')),
    );
    expect(_feedback, findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(_feedback, findsNothing);
    await gesture.up();
    expect(tester.takeException(), isNull);
  });

  testWidgets('默认预览按点选顺序叠卡，最上层是第一个选中的项', (tester) async {
    await tester.pumpWidget(
      _Harness(items: _items, initialSelectedIndices: const <int>[3, 1]),
    );
    await tester.pump();

    // 从组内第二项 B 起拖：叠卡顺序不变，D 仍是最上面那张。
    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('B')),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('multi-select-feedback-layer-0')),
        matching: find.text('D'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('multi-select-feedback-layer-1')),
        matching: find.text('B'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _feedback, matching: find.text('B')),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('自定义 proxyDecorator 与官方同签名：收到 child/index/animation', (
    tester,
  ) async {
    final List<int> seenIndices = <int>[];
    Animation<double>? seenAnimation;
    await tester.pumpWidget(
      _Harness(
        items: _items,
        initialSelectedIndices: const <int>[3, 1],
        proxyDecorator: (Widget child, int index, Animation<double> animation) {
          seenIndices.add(index);
          seenAnimation = animation;
          return SizedBox(width: 40, height: 40, child: child);
        },
      ),
    );
    await tester.pump();

    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('B')),
    );
    // 逐层调用：D 是第 0 层（最上层），B 是第 1 层。
    expect(seenIndices, <int>[3, 1]);
    expect(seenAnimation, isNotNull);
    // 调用瞬间值是 0；pump 需要带时长，动画时钟才会前进。
    await tester.pump(const Duration(milliseconds: 100));
    expect(seenAnimation!.value, greaterThan(0));
    expect(
      find.descendant(of: _feedback, matching: find.text('D')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _feedback, matching: find.text('B')),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('默认预览最多叠 4 层卡，每层背景不透明', (tester) async {
    await tester.pumpWidget(
      _Harness(
        items: _items,
        initialSelectedIndices: const <int>[0, 1, 2, 3, 4],
      ),
    );
    await tester.pump();

    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('C')),
    );
    expect(_feedbackItem, findsOneWidget);
    // 5 项选中、最多画 4 层。
    expect(
      find.byKey(const ValueKey<String>('multi-select-feedback-layer-4')),
      findsNothing,
    );
    for (int layer = 0; layer < 4; layer++) {
      final Finder layerFinder = find.byKey(
        ValueKey<String>('multi-select-feedback-layer-$layer'),
      );
      expect(layerFinder, findsOneWidget);
      // 每层背景都不透明，不能透出下面列表里原来的那一行。
      // 只查叠卡层自己的 Material——角标那层是透明的，不在这里断言。
      final Material material = tester.widget<Material>(
        find.descendant(of: layerFinder, matching: find.byType(Material)),
      );
      expect(material.color, isNotNull);
      expect(material.color, isNot(Colors.transparent));
    }
    // 第 5 项超出默认上限，不画在浮层里。
    expect(
      find.descendant(of: _feedback, matching: find.text('E')),
      findsNothing,
    );
    // 超出的项用右下角 +N 交代总数：5 项选中、画 4 层 → +1。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('multi-select-feedback-badge')),
        matching: find.text('+1'),
      ),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('没超出叠卡上限时不显示 +N 角标', (tester) async {
    await tester.pumpWidget(
      _Harness(items: _items, initialSelectedIndices: const <int>[0, 1, 2]),
    );
    await tester.pump();

    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('C')),
    );
    expect(_feedbackItem, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('multi-select-feedback-badge')),
      findsNothing,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('placeholderBuilder 自定义占位框，松手后消失', (tester) async {
    await tester.pumpWidget(
      _Harness(
        items: _items,
        initialSelectedIndices: const <int>[0],
        style: MultiSelectStyle(
          placeholderBuilder: (BuildContext context) =>
              const Center(child: Text('落点')),
        ),
      ),
    );
    await tester.pump();

    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('A')),
    );
    expect(find.text('落点'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('落点'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('list 的 spacing 默认为 0.0', (tester) async {
    await tester.pumpWidget(_Harness(items: _items));
    await tester.pump();

    final Rect a = tester.getRect(tileFinder('A'));
    final Rect b = tester.getRect(tileFinder('B'));
    expect(b.top - a.bottom, closeTo(0, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('list 的 spacing 只改行距，不改行高', (tester) async {
    await tester.pumpWidget(_Harness(items: _items, spacing: 20));
    await tester.pump();

    final Rect a = tester.getRect(tileFinder('A'));
    final Rect b = tester.getRect(tileFinder('B'));
    expect(a.height, closeTo(48, 0.01));
    expect(b.top - a.bottom, closeTo(20, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid 的 mainAxisSpacing / crossAxisSpacing 分控行距列距', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        items: _items,
        grid: true,
        mainAxisSpacing: 18,
        crossAxisSpacing: 24,
      ),
    );
    await tester.pump();

    final Rect a = tester.getRect(tileFinder('A'));
    final Rect b = tester.getRect(tileFinder('B'));
    final Rect c = tester.getRect(tileFinder('C'));
    // 2 列：A / B 同一行，C 在下一行。
    expect(a.height, closeTo(48, 0.01));
    expect(b.left - a.right, closeTo(24, 0.01));
    expect(b.top, closeTo(a.top, 0.01));
    expect(c.top - a.bottom, closeTo(18, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('padding 把内容整体推到内边距处', (tester) async {
    await tester.pumpWidget(
      _Harness(items: _items, padding: const EdgeInsets.all(12)),
    );
    await tester.pump();

    final Rect viewport = tester.getRect(
      find.ancestor(of: tileFinder('A'), matching: find.byType(SizedBox)).last,
    );
    final Rect a = tester.getRect(tileFinder('A'));
    expect(a.left - viewport.left, closeTo(12, 0.01));
    expect(a.top - viewport.top, closeTo(12, 0.01));
    expect(tester.takeException(), isNull);
  });

  test('applyMultiReorder 按 old/new 下标整组重排，非法输入原样返回', () {
    final List<String> items = <String>['A', 'B', 'C', 'D'];
    // C(2)、A(0) 整组搬到下标 1、2 → B 退到末尾。
    expect(applyMultiReorder(items, <int>[2, 0], <int>[1, 2]), <String>[
      'B',
      'C',
      'A',
      'D',
    ]);
    // 两组长度不等 / 重复 / 越界都视为非法。
    expect(applyMultiReorder(items, <int>[0, 1], <int>[1]), same(items));
    expect(applyMultiReorder(items, <int>[0, 0], <int>[1, 2]), same(items));
    expect(applyMultiReorder(items, <int>[0, 1], <int>[1, 9]), same(items));
    expect(applyMultiReorder(items, const <int>[], const <int>[]), same(items));
  });

  testWidgets('不传 borderRadius 时保持直角，不加裁剪层', (tester) async {
    await tester.pumpWidget(_Harness(items: _items));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('multi-select-item-clip')),
      findsNothing,
    );
    final List<InkWell> wells = tester
        .widgetList<InkWell>(find.byType(InkWell))
        .toList();
    expect(wells, isNotEmpty);
    expect(wells.every((InkWell w) => w.borderRadius == null), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selectedBuilder 只在选中项上叠角标，未选中不调用', (tester) async {
    final List<int> built = <int>[];
    await tester.pumpWidget(
      _Harness(
        items: _items,
        style: MultiSelectStyle(
          selectedBuilder:
              (Widget child, int index, int selectedIndex, int selectedCount) {
                built.add(index);
                return Stack(
                  key: ValueKey<String>('sel-badge-$index'),
                  children: <Widget>[
                    child,
                    const Positioned(top: 0, left: 0, child: Text('标')),
                  ],
                );
              },
        ),
      ),
    );
    await tester.pump();
    // 初始无选中：builder 不调用。
    expect(built, isEmpty);
    expect(find.text('标'), findsNothing);

    await tester.tap(tileFinder('C'));
    await tester.pump();
    // 只有 index 2（C）被装饰。
    expect(built, <int>[2]);
    expect(find.byKey(const ValueKey<String>('sel-badge-2')), findsOneWidget);
    expect(find.text('标'), findsOneWidget);

    await tester.tap(tileFinder('A'));
    await tester.pump();
    // 单击单选：C 取消、A 选中，一次重建里只为选中的 A 调一次。
    expect(built.last, 0);
    expect(find.byKey(const ValueKey<String>('sel-badge-2')), findsNothing);
    expect(find.byKey(const ValueKey<String>('sel-badge-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selectedBuilder 不作用于拖动浮层', (tester) async {
    final List<int> built = <int>[];
    await tester.pumpWidget(
      _Harness(
        items: _items,
        initialSelectedIndices: const <int>[1],
        style: MultiSelectStyle(
          selectedBuilder:
              (Widget child, int index, int selectedIndex, int selectedCount) {
                built.add(index);
                return child;
              },
        ),
      ),
    );
    await tester.pump();
    built.clear();

    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('B')),
    );
    // 拖起后浮层里的 B 走 itemBuilder，不走 selectedBuilder。
    expect(built, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动浮层按未选中构建：卡片不带选中底色', (tester) async {
    await tester.pumpWidget(
      _Harness(items: _items, initialSelectedIndices: const <int>[1]),
    );
    await tester.pump();

    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('B')),
    );
    await gesture.moveTo(tester.getCenter(tileFinder('D')));
    await tester.pump();

    // 浮层里的 B 是「未选中」那一版：普通底色，不是选中色。
    final Container ghost = tester.widget<Container>(
      find.descendant(of: _feedbackItem, matching: tileFinder('B')),
    );
    expect(ghost.color, const Color(0xFFEEEEEE));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('selectedBuilder 的 selectedIndex 是选中顺序里的位置（0 起）', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    final Map<int, int> ordinals = <int, int>{};
    final List<int> counts = <int>[];
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        style: MultiSelectStyle(
          selectedBuilder:
              (Widget child, int index, int selectedIndex, int selectedCount) {
                ordinals[index] = selectedIndex;
                counts.add(selectedCount);
                return child;
              },
        ),
      ),
    );

    // 点选顺序 D → B → E，序号应分别是 0 / 1 / 2。
    controller.setSelection(<int>[3, 1, 4]);
    await tester.pump();
    expect(ordinals[3], 0);
    expect(ordinals[1], 1);
    expect(ordinals[4], 2);
    expect(ordinals.containsKey(0), isFalse);
    expect(counts, <int>[3, 3, 3], reason: '第 4 个参数是总选中数，不是序号');

    // 取消第一个选中项后，后面两项的序号整体前移。
    controller.setSelection(<int>[1, 4]);
    await tester.pump();
    expect(ordinals[1], 0);
    expect(ordinals[4], 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('连续两次拖动不会重复创建 ticker（TickerProviderStateMixin）', (tester) async {
    // 第一次拖动的让位动画跑完后，条目内部的 AnimationController 会被销毁，
    // 第二次拖动会再建一个。用 SingleTickerProviderStateMixin 时这里会直接
    // 断言「multiple tickers were created」，必须用 TickerProviderStateMixin。
    final _Moves moves = _Moves();
    await tester.pumpWidget(_Harness(items: _items, onReorder: moves.call));
    await tester.pump();

    await _drag(
      tester,
      tester.getCenter(tileFinder('C')),
      _listTopLeft(tester) + const Offset(20, 6),
    );
    expect(tester.takeException(), isNull);

    await _drag(
      tester,
      tester.getCenter(tileFinder('E')),
      _listTopLeft(tester) + const Offset(20, 6),
    );
    expect(tester.takeException(), isNull);
    expect(moves.oldIndex.length, 2);
  });

  testWidgets('松手后卡片落位与其余条目后移同时进行', (tester) async {
    await tester.pumpWidget(
      _Harness(items: _items, initialSelectedIndices: const <int>[3, 1]),
    );
    await tester.pump();

    final Offset top = _listTopLeft(tester);
    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('B')),
    );
    await gesture.moveTo(top + const Offset(20, 6));
    await tester.pump();
    // 等让位动画跑完（默认 250ms，留点余量）：占位区只占 1 格，A 让到第 1 格。
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(tileFinder('A')).dy, closeTo(top.dy + 48, 0.5));

    await gesture.up();
    // 落位第一帧：被拖的条目还画在松手的位置（比它的槽位靠上），
    // 而不是瞬间出现在槽位里；其余条目也还没开始动。
    await tester.pump();
    expect(tester.getTopLeft(tileFinder('B')).dy, lessThan(top.dy + 48 - 2));
    expect(tester.getTopLeft(tileFinder('A')).dy, closeTo(top.dy + 48, 0.5));

    // 中途：卡片往下落、A 同时往下让，两者都在动（默认 250ms + easeInOut，
    // 采样点取 120ms，正好落在 easeInOut 的中段）。
    await tester.pump(const Duration(milliseconds: 120));
    final double bMid = tester.getTopLeft(tileFinder('B')).dy;
    final double aMid = tester.getTopLeft(tileFinder('A')).dy;
    expect(bMid, greaterThan(top.dy - 2));
    expect(bMid, lessThan(top.dy + 48));
    expect(aMid, greaterThan(top.dy + 48));
    expect(aMid, lessThan(top.dy + 96));

    // 动画跑完：D、B（整组按点选顺序）落在第 0、1 格，A 让到第 2 格。
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(tileFinder('D')).dy, closeTo(top.dy, 0.5));
    expect(tester.getTopLeft(tileFinder('B')).dy, closeTo(top.dy + 48, 0.5));
    expect(tester.getTopLeft(tileFinder('A')).dy, closeTo(top.dy + 96, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('duration 为零时松手直接落位，不做落位动画', (tester) async {
    await tester.pumpWidget(
      _Harness(
        items: _items,
        style: const MultiSelectStyle(duration: Duration.zero),
      ),
    );
    await tester.pump();

    final Offset top = _listTopLeft(tester);
    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('C')),
    );
    await gesture.moveTo(top + const Offset(20, 6));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(tester.getTopLeft(tileFinder('C')).dy, closeTo(top.dy, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('多选很多项快速来回拖动也能收尾，不残留浮层', (tester) async {
    final List<String> many = <String>[for (int i = 0; i < 120; i++) 'm$i'];
    final _Moves moves = _Moves();
    await tester.pumpWidget(
      SizedBox(
        width: 300,
        height: 320,
        child: MaterialApp(
          home: Scaffold(
            body: MultiSelectReorder.list(
              itemCount: many.length,
              itemBuilder: (BuildContext context, int index, bool selected) =>
                  Container(
                    key: ValueKey<String>('m$index'),
                    height: 48,
                    alignment: Alignment.center,
                    child: Text(many[index]),
                  ),
              initialSelectedIndices: <int>[for (int i = 0; i < 40; i++) i],
              onReorder: moves.call,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 视口只构建可见槽位，取当前可见的 m2 作为按下项。
    final Offset start = tester.getCenter(
      find.byKey(const ValueKey<String>('m2')),
    );
    final TestGesture gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await gesture.moveTo(start + const Offset(0, 12));
    await tester.pump();
    for (final double dy in <double>[200, 20, 300, 60, 260]) {
      await gesture.moveTo(Offset(start.dx, dy));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_feedback, findsNothing);
    expect(moves.oldIndex, hasLength(1));
    expect(moves.oldIndex.single, hasLength(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('大列表拖动：onReorder 只回传被拖的少数下标', (tester) async {
    final List<String> many = <String>[for (int i = 0; i < 500; i++) 'item$i'];
    final _Moves moves = _Moves();
    await tester.pumpWidget(
      SizedBox(
        width: 300,
        height: 320,
        child: MaterialApp(
          home: Scaffold(
            body: MultiSelectReorder.list(
              itemCount: many.length,
              itemBuilder: (BuildContext context, int index, bool selected) =>
                  Container(
                    key: ValueKey<String>('m$index'),
                    height: 48,
                    alignment: Alignment.center,
                    child: Text(many[index]),
                  ),
              initialSelectedIndices: const <int>[2, 5, 9],
              onReorder: moves.call,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Offset start = tester.getCenter(
      find.byKey(const ValueKey<String>('m5')),
    );
    final TestGesture gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await gesture.moveTo(start + const Offset(0, 12));
    await tester.pump();
    await gesture.moveTo(
      tester.getTopLeft(find.byKey(const ValueKey<String>('m0'))) +
          const Offset(20, 6),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // onReorder 只调用一次，两组各含 3 个下标（被拖条目数），不是 500 个。
    expect(moves.oldIndex, hasLength(1));
    expect(moves.oldIndex.single, <int>[2, 5, 9]);
    expect(moves.newIndex.single, hasLength(3));
    expect(moves.newIndex.single, isNot(hasLength(500)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('落位动画期间再点击：先把重排提交掉，点击不被吃掉', (tester) async {
    final _Moves moves = _Moves();
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        initialSelectedIndices: const <int>[3, 1],
        onReorder: moves.call,
      ),
    );
    await tester.pump();

    final Offset top = _listTopLeft(tester);
    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('B')),
    );
    await gesture.moveTo(top + const Offset(20, 6));
    await tester.pump();
    await gesture.up();
    // 落位动画的第一帧：数据还是旧的，onReorder 也还没发。
    await tester.pump();
    expect(moves.oldIndex, isEmpty);

    // 动画还没播完就点 A：这次点击不能被「落位中」吃掉。
    await tester.tap(tileFinder('A'));
    await tester.pump();

    // 重排已经补交：D、B 换到 0、1；A 落到下标 2，点击也落在它身上。
    expect(moves.oldIndex.single, <int>[3, 1]);
    expect(moves.newIndex.single, <int>[0, 1]);
    expect(controller.selectedIndices, <int>[2]);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('浮层跟手：每一帧都贴在指针上，没有任何插值 / 阻尼', (tester) async {
    // 这条是契约测试：浮层位置 = 指针 - 抓取偏移，中间不存在补间、缓动或
    // 「延迟一帧」。以后想加平滑效果，先来把这里改掉。
    await tester.pumpWidget(_Harness(items: _items));
    final Offset start = tester.getCenter(tileFinder('B'));
    final Offset slotTopLeft = tester.getTopLeft(tileFinder('B'));
    final TestGesture gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    Offset pointer = start + const Offset(0, 12);
    await gesture.moveTo(pointer);
    await tester.pump();
    // 拾起时浮层正好盖住原来那一格：抓取偏移按按下位置算，不是「原地跳一下」。
    expect(tester.getTopLeft(_feedbackItem), slotTopLeft);
    final Offset grab = pointer - tester.getTopLeft(_feedbackItem);
    expect(grab, const Offset(150, 36));

    // 小步、大步混合，跨行拖动（落点会变，列表会重建）。
    for (final Offset step in const <Offset>[
      Offset(0, 6),
      Offset(0, 6),
      Offset(0, 30),
      Offset(4, 2),
      Offset(0, 48),
    ]) {
      pointer += step;
      await gesture.moveTo(pointer);
      await tester.pump();
      expect(
        tester.getTopLeft(_feedbackItem),
        pointer - grab,
        reason: '一步移动 $step 之后浮层必须和指针完全重合',
      );
    }

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('浮层跟手：grid 逐帧同样 0 偏差', (tester) async {
    await tester.pumpWidget(_Harness(items: _items, grid: true));
    final Offset start = tester.getCenter(tileFinder('A'));
    final TestGesture gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    Offset pointer = start + const Offset(0, 12);
    await gesture.moveTo(pointer);
    await tester.pump();
    final Offset grab = pointer - tester.getTopLeft(_feedbackItem);

    for (int i = 0; i < 6; i++) {
      pointer += const Offset(20, 10);
      await gesture.moveTo(pointer);
      await tester.pump();
      expect(tester.getTopLeft(_feedbackItem), pointer - grab);
    }

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('浮层坐标按 Overlay 原点换算：嵌套 Overlay 偏移时仍贴着指针', (tester) async {
    // `OverlayEntry` 里的 Positioned 用的是 Overlay 自己的坐标系，指针事件给
    // 的是全局坐标。Overlay 不在屏幕原点时必须减掉它的原点，否则浮层整体偏移
    // 一段（官方 `_overlayOrigin` 同款修正）。
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned(
                left: 80,
                top: 60,
                child: SizedBox(
                  width: 300,
                  height: 320,
                  child: Overlay(
                    initialEntries: <OverlayEntry>[
                      OverlayEntry(
                        builder: (BuildContext context) => Positioned.fill(
                          child: MultiSelectReorder.list(
                            itemCount: _items.length,
                            style: const MultiSelectStyle(
                              useRootOverlay: false,
                            ),
                            itemBuilder:
                                (
                                  BuildContext context,
                                  int index,
                                  bool selected,
                                ) => Container(
                                  key: tile(_items[index]),
                                  color: const Color(0xFFEEEEEE),
                                  alignment: Alignment.center,
                                  child: Text(_items[index]),
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final Offset start = tester.getCenter(tileFinder('B'));
    final Offset slotTopLeft = tester.getTopLeft(tileFinder('B'));
    final TestGesture gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    Offset pointer = start + const Offset(0, 12);
    await gesture.moveTo(pointer);
    await tester.pump();
    // Overlay 在 (80, 60)，浮层必须仍然盖住原来那一格 —— 少减一次原点就会
    // 整体偏移 (80, 60)。
    expect(tester.getTopLeft(_feedbackItem), slotTopLeft);
    final Offset grab = pointer - tester.getTopLeft(_feedbackItem);

    for (int i = 0; i < 4; i++) {
      pointer += const Offset(0, 10);
      await gesture.moveTo(pointer);
      await tester.pump();
      expect(tester.getTopLeft(_feedbackItem), pointer - grab);
    }

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // ── 单击 / 双击 ──────────────────────────────────────────────────────────

  testWidgets('双击只回调 onDoubleTap：选中不动', (tester) async {
    final List<int> doubles = <int>[];
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(items: _items, controller: controller, onDoubleTap: doubles.add),
    );

    await tester.tap(tileFinder('B'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(tileFinder('B'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(doubles, <int>[1]);
    expect(controller.selectedIndices, isEmpty, reason: '双击不改选中');
    expect(tester.takeException(), isNull);
  });

  testWidgets('delay 模式：单击要等过双击间隔才提交选中', (tester) async {
    final List<List<int>> changes = <List<int>>[];
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        onSelectionChanged: changes.add,
        onDoubleTap: (_) {},
      ),
    );

    await tester.tap(tileFinder('B'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.selectedIndices, isEmpty, reason: '窗口内还不能提交');
    expect(changes, isEmpty, reason: '还没提交，不该有选中变化通知');

    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.selectedIndices, <int>[1]);
    expect(changes.single, <int>[1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delay 模式：双击不同条目算两次单击，各按顺序落地', (tester) async {
    final List<int> doubles = <int>[];
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(items: _items, controller: controller, onDoubleTap: doubles.add),
    );

    await tester.tap(tileFinder('A'));
    await tester.pump(const Duration(milliseconds: 60));
    // 第二次点在别的条目：前一次单击立刻落地，不会被当成双击。
    await tester.tap(tileFinder('C'));
    await tester.pump();
    expect(controller.selectedIndices, <int>[0]);

    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.selectedIndices, <int>[2]);
    expect(doubles, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revert 模式：单击立刻生效，双击把选中回滚', (tester) async {
    final List<int> doubles = <int>[];
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        initialSelectedIndices: const <int>[3, 1],
        style: const MultiSelectStyle(
          doubleTapMode: MultiSelectDoubleTapMode.revert,
        ),
        onDoubleTap: doubles.add,
      ),
    );
    await tester.pump();
    expect(controller.selectedIndices, <int>[3, 1]);

    // 第一下：立刻选中 A（单选语义，清掉其它）。
    await tester.tap(tileFinder('A'));
    await tester.pump();
    expect(controller.selectedIndices, <int>[0]);

    // 第二下：回滚成双击之前的选中，再回调 onDoubleTap。
    await tester.tap(tileFinder('A'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.selectedIndices, <int>[3, 1]);
    expect(doubles, <int>[0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('第二次按住超过双击间隔，松手仍算双击', (tester) async {
    final List<int> doubles = <int>[];
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(items: _items, controller: controller, onDoubleTap: doubles.add),
    );

    await tester.tap(tileFinder('B'));
    await tester.pump(const Duration(milliseconds: 50));
    // 第二次按下后按住不放：计时器要冻住，不能先把第一下提交了。
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(tileFinder('B')),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.selectedIndices, isEmpty);

    await gesture.up();
    await tester.pump();
    expect(doubles, <int>[1]);
    expect(controller.selectedIndices, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('单击后立刻起拖：挂起的单击先落地', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(items: _items, controller: controller, onDoubleTap: (_) {}),
    );

    await tester.tap(tileFinder('A'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.selectedIndices, isEmpty);

    // 起拖就说明不是双击的第二下：A 的单击立刻落地。
    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('C')),
    );
    expect(controller.selectedIndices, <int>[0]);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // ── itemBuilder 缓存 ────────────────────────────────────────────────────

  testWidgets('拖动与落位的多帧重建不重复调用 itemBuilder', (tester) async {
    final Map<String, int> builds = <String, int>{};
    void record(String item) => builds[item] = (builds[item] ?? 0) + 1;
    await tester.pumpWidget(_Harness(items: _items, onBuildItem: record));
    builds.clear();

    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('B')),
    );
    Offset pointer = tester.getCenter(tileFinder('B'));
    for (int i = 0; i < 4; i++) {
      pointer += const Offset(0, 48);
      await gesture.moveTo(pointer);
      // 让位动画的每一帧都会重建可见条目。
      await tester.pump(const Duration(milliseconds: 40));
    }
    await gesture.up();
    // 落位动画期间也不能重调 itemBuilder。
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      builds.values.every((int n) => n <= 1),
      isTrue,
      reason: '拖动期间每个条目最多构建一次，缓存命中，builds=$builds',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('选中态变化后对应条目重新构建', (tester) async {
    final Map<String, int> builds = <String, int>{};
    void record(String item) => builds[item] = (builds[item] ?? 0) + 1;
    await tester.pumpWidget(_Harness(items: _items, onBuildItem: record));
    builds.clear();

    await tester.tap(tileFinder('B'));
    await tester.pump();

    expect(builds, <String, int>{'B': 1});
    expect(tester.takeException(), isNull);
  });

  testWidgets('数据变化后缓存清空，条目按新数据重建', (tester) async {
    final Map<String, int> builds = <String, int>{};
    void record(String item) => builds[item] = (builds[item] ?? 0) + 1;
    await tester.pumpWidget(_Harness(items: _items, onBuildItem: record));
    builds.clear();

    // 父组件给了新数据：A 被移除，B 的下标前移。
    await tester.pumpWidget(
      _Harness(items: const <String>['B', 'C', 'D', 'E'], onBuildItem: record),
    );
    await tester.pump();

    expect(builds['B'], 1, reason: '数据变了，B 的下标前移，必须重新构建');
    expect(tester.takeException(), isNull);
  });

  testWidgets('immediate 模式：单击零延迟，双击不改选中也不回滚', (tester) async {
    final List<int> doubles = <int>[];
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        style: const MultiSelectStyle(
          doubleTapMode: MultiSelectDoubleTapMode.immediate,
        ),
        onDoubleTap: doubles.add,
      ),
    );

    // 第一下立刻选中，不等 300ms。
    await tester.tap(tileFinder('B'));
    await tester.pump();
    expect(controller.selectedIndices, <int>[1]);

    // 第二下：双击只回调，选中保持第一次单击的结果（不回滚成空）。
    await tester.tap(tileFinder('B'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(doubles, <int>[1]);
    expect(controller.selectedIndices, <int>[1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('immediate 模式：双击保留第一下单击的结果，不回滚', (tester) async {
    final List<int> doubles = <int>[];
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        initialSelectedIndices: const <int>[3],
        style: const MultiSelectStyle(
          doubleTapMode: MultiSelectDoubleTapMode.immediate,
        ),
        onDoubleTap: doubles.add,
      ),
    );
    await tester.pump();
    expect(controller.selectedIndices, <int>[3]);

    // 双击已选中的 D：第一下按单选语义「再点取消」清掉选中，第二下是双击，
    // immediate 不回滚 → 停在「第一下的结果」= 空。
    await tester.tap(tileFinder('D'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(tileFinder('D'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(doubles, <int>[3]);
    expect(
      controller.selectedIndices,
      isEmpty,
      reason: '保留第一下的取消结果，不像 revert 那样回滚',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('让位动画的多帧重建不会重复调用 selectedBuilder', (tester) async {
    final Map<String, int> builds = <String, int>{};
    final MultiSelectController controller = MultiSelectController();
    void record(String item) => builds[item] = (builds[item] ?? 0) + 1;
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        initialSelectedIndices: const <int>[1],
        style: MultiSelectStyle(
          selectedBuilder:
              (Widget child, int index, int selectedIndex, int selectedCount) {
                record(_items[index]);
                return child;
              },
        ),
      ),
    );
    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('D')),
    );
    // 起拖那一帧 _dragging 翻转，外壳要重建一次以打开 IgnorePointer。
    builds.clear();

    Offset pointer = tester.getCenter(tileFinder('D'));
    for (int i = 0; i < 4; i++) {
      pointer += const Offset(0, 48);
      await gesture.moveTo(pointer);
      await tester.pump(const Duration(milliseconds: 40));
    }
    // 只断言拖动进行中的连续帧：起拖翻转 _dragging、松手恢复各会重搭一次，
    // 但中间 N 帧的让位动画必须复用同一外壳实例。
    expect(
      builds,
      isEmpty,
      reason: '拖动动画帧复用同一外壳实例，selectedBuilder 不再重调，builds=$builds',
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selectOnly 模式：双击只留被双击项选中，不把其它项选回来', (tester) async {
    final List<int> doubles = <int>[];
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        initialSelectedIndices: const <int>[3, 1],
        style: const MultiSelectStyle(
          doubleTapMode: MultiSelectDoubleTapMode.selectOnly,
        ),
        onDoubleTap: doubles.add,
      ),
    );
    await tester.pump();
    expect(controller.selectedIndices, <int>[3, 1]);

    // 第一下：单选语义清掉 D/B，选中 A。
    await tester.tap(tileFinder('A'));
    await tester.pump();
    expect(controller.selectedIndices, <int>[0]);

    // 第二下：不再回滚成 [3,1]，A 保持唯一选中。
    await tester.tap(tileFinder('A'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.selectedIndices, <int>[0]);
    expect(doubles, <int>[0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selectOnly 模式：双击已选中项不会把自己取消', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        initialSelectedIndices: const <int>[1],
        style: const MultiSelectStyle(
          doubleTapMode: MultiSelectDoubleTapMode.selectOnly,
        ),
        onDoubleTap: (_) {},
      ),
    );
    await tester.pump();

    // 第一下按「再点取消」清掉 B，第二下强制只留 B。
    await tester.tap(tileFinder('B'));
    await tester.pump(const Duration(milliseconds: 60));
    expect(controller.selectedIndices, isEmpty);

    await tester.tap(tileFinder('B'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.selectedIndices, <int>[1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selectOnly 模式：单击仍是零延迟', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        style: const MultiSelectStyle(
          doubleTapMode: MultiSelectDoubleTapMode.selectOnly,
        ),
        onDoubleTap: (_) {},
      ),
    );

    await tester.tap(tileFinder('C'));
    await tester.pump();
    expect(controller.selectedIndices, <int>[2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('外部 controller 跨 list→grid 切换保留选中', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(_Harness(items: _items, controller: controller));
    await tester.tap(tileFinder('B'));
    await tester.pump();
    expect(controller.selectedIndices, <int>[1]);

    // 模拟切换视图：旧形态被整棵摘掉（show:false），controller 活在外面。
    await tester.pumpWidget(
      _Harness(items: _items, controller: controller, show: false),
    );
    await tester.pump();
    expect(controller.selectedIndices, <int>[1]);

    // 换成 grid 重新挂上，同一个 controller 的选中必须还在。
    await tester.pumpWidget(
      _Harness(items: _items, controller: controller, grid: true),
    );
    await tester.pump();
    expect(controller.selectedIndices, <int>[1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('itemId：切换过滤视图后选中按 id 归位，过滤掉的不丢', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    // 全量视图 A~E，选中 B、D（字符串本身作 id）。
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        itemId: (int index) => _items[index],
        initialSelectedIndices: const <int>[1, 3],
      ),
    );
    await tester.pump();
    expect(controller.selectedIndices, <int>[1, 3]);

    // 过滤视图只留 D、B，顺序调换了：同一批 id 归到新下标，但保持点选
    // 顺序（B 先于 D），所以是 [1, 0] 而不是按下标排的 [0, 1]。
    await tester.pumpWidget(
      _Harness(
        items: const <String>['D', 'B'],
        controller: controller,
        grid: true,
        itemId: (int index) => const <String>['D', 'B'][index],
      ),
    );
    await tester.pump();
    expect(controller.selectedIndices, <int>[1, 0]);
    expect(controller.selectedIds, <Object>{'B', 'D'});

    // 切回全量视图，选中回到原下标。
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        itemId: (int index) => _items[index],
      ),
    );
    await tester.pump();
    expect(controller.selectedIndices, <int>[1, 3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('itemId：过滤掉的选中项保留在 controller 里', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        itemId: (int index) => _items[index],
        initialSelectedIndices: const <int>[0, 2, 4],
      ),
    );
    await tester.pump();

    // 过滤视图只剩 C（原下标 2），A、E 的选中不能因为看不见就被清掉。
    await tester.pumpWidget(
      _Harness(
        items: const <String>['C'],
        controller: controller,
        itemId: (int index) => 'C',
      ),
    );
    await tester.pump();
    expect(controller.selectedIndices, <int>[0]);
    expect(controller.allSelectedCount, 3);
    expect(controller.selectedIds, <Object>{'A', 'C', 'E'});
    expect(tester.takeException(), isNull);
  });

  // ── 选中真值只在 controller 里 ──────────────────────────────────────────

  testWidgets('controller.setIds：外部改 controller，条目跟着变且顺序保留', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        itemId: (int index) => _items[index],
      ),
    );
    await tester.pump();
    expect(_selectedOf(tester, 'C'), isFalse);

    // 顺序 = 传进来的顺序（先 C 后 A），不是下标升序。
    controller.setIds(<Object>['C', 'A']);
    await tester.pump();
    expect(_selectedOf(tester, 'C'), isTrue);
    expect(_selectedOf(tester, 'A'), isTrue);
    expect(controller.selectedIndices, <int>[2, 0]);
    expect(controller.selectedIds, <Object>['C', 'A']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('controller.setIds：重复 id 只留一份，看不见的 id 也保留', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        itemId: (int index) => _items[index],
      ),
    );
    await tester.pump();

    controller.setIds(<Object>['C', 'C', 'hidden']);
    await tester.pump();
    expect(controller.selectedIds, <Object>['C', 'hidden']);
    // 当前视图看得见的只有 C；hidden 留到能看见它的视图再出现。
    expect(controller.selectedIndices, <int>[2]);
    expect(controller.allSelectedCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('borderRadius 同时作用于内容裁剪与 hover 高亮', (tester) async {
    const BorderRadius radius = BorderRadius.all(Radius.circular(8));
    await tester.pumpWidget(
      _Harness(
        items: _items,
        style: const MultiSelectStyle(borderRadius: radius),
      ),
    );
    // 内容被裁成同一个圆角。
    expect(
      find.byKey(const ValueKey<String>('multi-select-item-clip')),
      findsNWidgets(_items.length),
    );
    // hover / ripple 也用同一个圆角。
    final List<InkWell> wells = tester
        .widgetList<InkWell>(find.byType(InkWell))
        .toList();
    expect(wells.length, _items.length);
    expect(wells.every((InkWell w) => w.borderRadius == radius), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid 选中后条目仍撑满格子，不会缩回固有尺寸', (tester) async {
    await tester.pumpWidget(
      _Harness(
        items: _items,
        grid: true,
        style: MultiSelectStyle(
          selectedBuilder: (
            Widget child,
            int index,
            int selectedIndex,
            int count,
          ) => Stack(fit: StackFit.expand, children: <Widget>[child]),
        ),
      ),
    );
    await tester.pump();
    final Size before = tester.getSize(tileFinder('A'));

    await tester.tap(tileFinder('A'));
    await tester.pump();
    final Size after = tester.getSize(tileFinder('A'));

    expect(after, before, reason: '选中不能让格子缩小');
    expect(after.height, greaterThan(40), reason: '没缩成内容固有高度');
    expect(tester.takeException(), isNull);
  });

  // ── 指针：cursor 与右键 ──────────────────────────────────────────────────

  testWidgets('style.mouseCursor 作用在条目 InkWell 上，默认不覆盖', (tester) async {
    await tester.pumpWidget(
      _Harness(
        items: _items,
        style: const MultiSelectStyle(mouseCursor: SystemMouseCursors.grab),
      ),
    );
    await tester.pump();

    InkWell inkWellOf(String item) => tester.widget<InkWell>(
      find.ancestor(of: tileFinder(item), matching: find.byType(InkWell)).first,
    );
    expect(inkWellOf('B').mouseCursor, SystemMouseCursors.grab);

    // 默认（不传）交给 InkWell 自己决定，组件不插一手。
    await tester.pumpWidget(_Harness(items: _items));
    await tester.pump();
    expect(inkWellOf('B').mouseCursor, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动浮层沿用 style.mouseCursor，不会一拖就变回箭头', (tester) async {
    await tester.pumpWidget(
      _Harness(
        items: _items,
        style: const MultiSelectStyle(mouseCursor: SystemMouseCursors.grab),
      ),
    );
    await tester.pump();

    final TestGesture gesture = await _beginDragGesture(
      tester,
      tester.getCenter(tileFinder('B')),
    );
    expect(_feedbackItem, findsOneWidget);
    final MouseRegion region = tester.widget<MouseRegion>(
      find.byKey(const ValueKey<String>('multi-select-feedback-cursor')),
    );
    expect(region.cursor, SystemMouseCursors.grab);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('onSecondaryTap：右键点一下带下标与按下位置，不改选中', (tester) async {
    final MultiSelectController controller = MultiSelectController();
    final List<(int, Offset)> calls = <(int, Offset)>[];
    await tester.pumpWidget(
      _Harness(
        items: _items,
        controller: controller,
        onSecondaryTap: (int index, Offset at) => calls.add((index, at)),
      ),
    );
    await tester.pump();
    await tester.tap(tileFinder('B'));
    await tester.pump();
    expect(controller.selectedIndices, <int>[1]);

    final Offset target = tester.getCenter(tileFinder('C'));
    final TestGesture gesture = await tester.startGesture(
      target,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(calls.length, 1);
    expect(calls.single.$1, 2);
    expect(calls.single.$2, target);
    // 右键不参与选中：还是 B，C 没被选中。
    expect(controller.selectedIndices, <int>[1]);
    expect(_selectedOf(tester, 'C'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onSecondaryTap：不传时不注册右键手势，不会抛异常', (tester) async {
    await tester.pumpWidget(_Harness(items: _items));
    await tester.pump();

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(tileFinder('B')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

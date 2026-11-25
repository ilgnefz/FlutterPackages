import 'package:flutter/gestures.dart' show kSecondaryButton, PointerDeviceKind;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const List<ContextMenuItem<String>> _items = <ContextMenuItem<String>>[
  ContextMenuItem<String>('copy', label: '复制'),
  ContextMenuItem<String>.divider(),
  ContextMenuItem<String>.header('导出为'),
  ContextMenuItem<String>.submenu(
    '格式',
    children: <ContextMenuItem<String>>[
      ContextMenuItem<String>('pdf', label: 'PDF'),
      ContextMenuItem<String>.submenu(
        '图片',
        children: <ContextMenuItem<String>>[
          ContextMenuItem<String>('png', label: 'PNG'),
        ],
      ),
    ],
  ),
  ContextMenuItem<String>('delete', label: '删除', danger: true),
];

Widget _app({
  List<ContextMenuItem<String>>? items,
  ValueChanged<String>? onSelected,
  ValueChanged<bool>? onOpenChange,
  bool enabled = true,
  Widget Function(BuildContext, ContextMenuItem<String>)? itemBuilder,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 300,
        height: 200,
        child: CascadeContextMenu<String>(
          items: items ?? _items,
          onSelected: onSelected,
          onOpenChange: onOpenChange,
          enabled: enabled,
          itemBuilder: itemBuilder,
          child: const Text('target'),
        ),
      ),
    ),
  ),
);

/// 右键触发：onSecondaryTapUp 需要显式的 secondary button。
Future<void> _rightClick(WidgetTester tester, Finder finder) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(finder),
    buttons: kSecondaryButton,
  );
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Flutter 3.50 移除了 WidgetTester.hover，用鼠标手势的 moveTo 代替。
Future<void> _hover(WidgetTester tester, Finder finder) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(finder),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveTo(tester.getCenter(finder));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('右键弹出与关闭', () {
    testWidgets('右键在 target 上弹出根面板', (tester) async {
      await tester.pumpWidget(_app());
      await _rightClick(tester, find.text('target'));

      expect(find.byKey(kContextMenuPanelKey), findsOneWidget);
      expect(find.byKey(kContextMenuBarrierKey), findsOneWidget);
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('PDF'), findsNothing); // 子级还没展开
    });

    testWidgets('点击叶子项回调 value 并收起全部层级', (tester) async {
      final List<String> selected = <String>[];
      final List<bool> opened = <bool>[];
      await tester.pumpWidget(
        _app(onSelected: selected.add, onOpenChange: opened.add),
      );
      await _rightClick(tester, find.text('target'));
      await tester.tap(find.byKey(contextMenuItemKey(0)));
      await tester.pumpAndSettle();

      expect(selected, <String>['copy']);
      expect(opened, <bool>[true, false]);
      expect(find.byKey(kContextMenuPanelKey), findsNothing);
    });

    testWidgets('点菜单外收起，且不穿透下层', (tester) async {
      await tester.pumpWidget(_app());
      await _rightClick(tester, find.text('target'));
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byKey(kContextMenuPanelKey), findsNothing);
    });

    testWidgets('enabled=false 不弹出', (tester) async {
      await tester.pumpWidget(_app(enabled: false));
      await _rightClick(tester, find.text('target'));

      expect(find.byKey(kContextMenuPanelKey), findsNothing);
    });

    testWidgets('菜单开着时再次右键重播进场，onOpenChange 不重复', (tester) async {
      final List<bool> opened = <bool>[];
      await tester.pumpWidget(_app(onOpenChange: opened.add));
      await _rightClick(tester, find.text('target'));
      await _rightClick(tester, find.text('target'));

      expect(opened, <bool>[true]);
      expect(find.byKey(kContextMenuPanelKey), findsOneWidget);
    });
  });

  group('级联', () {
    testWidgets('hover 父项展开子级与孙级，换到别的行会收起更深层级', (tester) async {
      await tester.pumpWidget(_app());
      await _rightClick(tester, find.text('target'));

      await _hover(tester, find.byKey(contextMenuItemKey(3)));
      await tester.pumpAndSettle();
      expect(find.byKey(contextMenuPanelKey(1)), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);

      await _hover(tester, find.byKey(contextMenuItemKey(1, 1)));
      await tester.pumpAndSettle();
      expect(find.byKey(contextMenuPanelKey(2)), findsOneWidget);
      expect(find.text('PNG'), findsOneWidget);

      await _hover(tester, find.byKey(contextMenuItemKey(4)));
      await tester.pumpAndSettle();
      expect(find.byKey(contextMenuPanelKey(1)), findsNothing);
      expect(find.byKey(contextMenuPanelKey(2)), findsNothing);
    });

    testWidgets('点父项只展开，不回调 onSelected', (tester) async {
      final List<String> selected = <String>[];
      await tester.pumpWidget(_app(onSelected: selected.add));
      await _rightClick(tester, find.text('target'));
      await tester.tap(find.byKey(contextMenuItemKey(3)));
      await tester.pumpAndSettle();

      expect(selected, isEmpty);
      expect(find.byKey(contextMenuPanelKey(1)), findsOneWidget);
    });
  });

  group('键盘', () {
    testWidgets('↓ / Enter 选中高亮项，Esc 收起', (tester) async {
      final List<String> selected = <String>[];
      await tester.pumpWidget(_app(onSelected: selected.add));
      await _rightClick(tester, find.text('target'));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, <String>['copy']);

      await _rightClick(tester, find.text('target'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(kContextMenuPanelKey), findsNothing);
    });

    testWidgets('→ 展开高亮父项的子菜单，← 收起', (tester) async {
      await tester.pumpWidget(_app());
      await _rightClick(tester, find.text('target'));

      // 可选项顺序：0 copy、3 格式、4 delete
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.byKey(contextMenuPanelKey(1)), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.byKey(contextMenuPanelKey(1)), findsNothing);
    });
  });

  group('自定义行', () {
    testWidgets('itemBuilder 替换默认内容，但仍能点击选中', (tester) async {
      final List<String> selected = <String>[];
      await tester.pumpWidget(
        _app(
          items: const <ContextMenuItem<String>>[
            ContextMenuItem<String>('a', label: 'A'),
          ],
          onSelected: selected.add,
          itemBuilder: (_, item) => Text('custom-${item.value}'),
        ),
      );
      await _rightClick(tester, find.text('target'));

      expect(find.text('custom-a'), findsOneWidget);
      expect(find.text('A'), findsNothing);
      await tester.tap(find.byKey(contextMenuItemKey(0)));
      await tester.pumpAndSettle();
      expect(selected, <String>['a']);
    });
  });

  group('纯函数', () {
    const ContextMenuStyle style = ContextMenuStyle();
    const Size viewport = Size(800, 600);

    test('measureContextMenu 按行高累加，含两侧 padding', () {
      final Size size = measureContextMenu<String>(_items, style);
      // action 36 + divider 9 + header 28 + submenu 36 + action 36 = 145
      expect(size, Size(220, 145 + 12));
    });

    test('contextMenuItemTop 累加前面各行高度', () {
      expect(contextMenuItemTop<String>(_items, 0, style), 6);
      expect(contextMenuItemTop<String>(_items, 1, style), 6 + 36);
      expect(contextMenuItemTop<String>(_items, 2, style), 6 + 36 + 9);
    });

    test('根菜单右侧 / 底部空间不足时翻转', () {
      final ContextMenuPlacement placement = resolveContextMenuPlacement(
        anchor: const Offset(780, 590),
        viewport: viewport,
        menuSize: const Size(220, 160),
        edgePadding: 8,
      );
      expect(placement.flippedX, isTrue);
      expect(placement.flippedY, isTrue);
      expect(placement.rect.right, lessThanOrEqualTo(viewport.width - 8));
      expect(placement.rect.bottom, lessThanOrEqualTo(viewport.height - 8));
    });

    test('揭示起点随落位镜像', () {
      ContextMenuRevealOrigin originFor(bool x, bool y) =>
          resolveContextMenuRevealOrigin(
            ContextMenuReveal.corner,
            ContextMenuPlacement(
              origin: Offset.zero,
              size: const Size(10, 10),
              flippedX: x,
              flippedY: y,
            ),
          );
      expect(originFor(false, false), ContextMenuRevealOrigin.topLeft);
      expect(originFor(true, false), ContextMenuRevealOrigin.topRight);
      expect(originFor(false, true), ContextMenuRevealOrigin.bottomLeft);
      expect(originFor(true, true), ContextMenuRevealOrigin.bottomRight);
    });
  });
}

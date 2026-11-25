import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const List<ContextMenuItem<String>> _items = <ContextMenuItem<String>>[
  ContextMenuItem<String>.header('编辑'),
  ContextMenuItem<String>(
    'copy',
    label: '复制',
    icon: Icons.copy,
    shortcut: 'Ctrl+C',
  ),
  ContextMenuItem<String>('paste', label: '粘贴', icon: Icons.paste),
  ContextMenuItem<String>.divider(),
  ContextMenuItem<String>('delete', label: '删除', danger: true),
  ContextMenuItem<String>('locked', label: '禁用', enabled: false),
];

/// 根 → 子 → 孙三级，外加第二个子菜单用于验证 hover 切换。
const List<ContextMenuItem<String>> _nested = <ContextMenuItem<String>>[
  ContextMenuItem<String>('copy', label: '复制'),
  ContextMenuItem<String>.submenu(
    '导出为',
    children: <ContextMenuItem<String>>[
      ContextMenuItem<String>('pdf', label: 'PDF'),
      ContextMenuItem<String>.submenu(
        '图片',
        children: <ContextMenuItem<String>>[
          ContextMenuItem<String>('png', label: 'PNG'),
          ContextMenuItem<String>('jpg', label: 'JPEG'),
        ],
      ),
    ],
  ),
  ContextMenuItem<String>.submenu(
    '更多',
    children: <ContextMenuItem<String>>[
      ContextMenuItem<String>('option', label: '选项A'),
    ],
  ),
  ContextMenuItem<String>('delete', label: '删除'),
];

/// 子菜单比根菜单还高，用来测底部夹紧。
const List<ContextMenuItem<String>> _tall = <ContextMenuItem<String>>[
  ContextMenuItem<String>('a', label: 'A'),
  ContextMenuItem<String>.submenu(
    '高子菜单',
    children: <ContextMenuItem<String>>[
      ContextMenuItem<String>('c1', label: 'C1'),
      ContextMenuItem<String>('c2', label: 'C2'),
      ContextMenuItem<String>('c3', label: 'C3'),
      ContextMenuItem<String>('c4', label: 'C4'),
      ContextMenuItem<String>('c5', label: 'C5'),
      ContextMenuItem<String>('c6', label: 'C6'),
    ],
  ),
];

Widget _wrap({
  List<ContextMenuItem<String>> items = _items,
  ValueChanged<String>? onSelected,
  ValueChanged<bool>? onOpenChange,
  bool enabled = true,
  bool longPressEnabled = true,
  bool fullScreenTarget = false,
  bool withMenu = true,
  ContextMenuStyle style = const ContextMenuStyle(),
  Widget Function(BuildContext, ContextMenuItem<String>)? itemBuilder,
  ThemeData? theme,
}) {
  final Widget target = fullScreenTarget
      ? const SizedBox.expand(child: ColoredBox(color: Color(0xFFEEEEEE)))
      : const SizedBox(
          width: 160,
          height: 80,
          child: ColoredBox(
            color: Color(0xFFEEEEEE),
            child: Center(child: Text('target')),
          ),
        );
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Center(
        child: withMenu
            ? CascadeContextMenu<String>(
                items: items,
                onSelected: onSelected,
                onOpenChange: onOpenChange,
                enabled: enabled,
                longPressEnabled: longPressEnabled,
                style: style,
                itemBuilder: itemBuilder,
                child: target,
              )
            : const Text('gone'),
      ),
    ),
  );
}

/// 命令式入口：右键位置直接交给 [showContextMenu]。
Widget _showWrap({
  List<ContextMenuItem<String>> items = _items,
  ValueChanged<String>? onSelected,
  ValueChanged<bool>? onOpenChange,
  ContextMenuStyle style = const ContextMenuStyle(),
  void Function(ContextMenuHandle handle)? onHandle,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: (TapDownDetails details) {
            final ContextMenuHandle handle = showContextMenu<String>(
              context,
              position: details.globalPosition,
              items: items,
              onSelected: onSelected,
              onOpenChange: onOpenChange,
              style: style,
            );
            onHandle?.call(handle);
          },
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

Future<void> _rightClick(WidgetTester tester, Offset at) async {
  final TestGesture gesture = await tester.startGesture(
    at,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.up();
  await tester.pumpAndSettle();
}

Finder get _panel => find.byKey(kContextMenuPanelKey);

Finder _levelPanel(int level) => find.byKey(contextMenuPanelKey(level));

/// 停在动画中段：右键后只 pump 一点时间，方便检查逐帧状态。
Future<void> _openPaused(WidgetTester tester, Offset at, {int ms = 70}) async {
  final TestGesture gesture = await tester.startGesture(
    at,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.up();
  await tester.pump(); // 让 TweenAnimationBuilder 起跑（首帧不计时间）
  await tester.pump(Duration(milliseconds: ms));
}

/// 只发一次右键并 pump 首帧，停在动画中途，不自动 settle。
Future<void> _rightClickStart(WidgetTester tester, Offset at) async {
  final TestGesture gesture = await tester.startGesture(
    at,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.up();
  await tester.pump();
}

ContextMenuRevealClipper _clipOf(WidgetTester tester, int level) {
  final ClipPath clip = tester.widget<ClipPath>(
    find.byKey(contextMenuClipKey(level)),
  );
  return clip.clipper! as ContextMenuRevealClipper;
}

Duration _levelAnimationDuration(WidgetTester tester) => tester
    .widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>),
    )
    .duration;

// 泛型类要带上类型参数，裸类型 ContextMenuPanel 等价于 <dynamic> 匹配不到。
Finder get _allPanels => find.byType(ContextMenuPanel<String>);

/// 用鼠标移动触发 hover（不是点按）。
Future<TestGesture> _hover(WidgetTester tester, Finder finder) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pumpAndSettle();
  return gesture;
}

void main() {
  testWidgets('右键在指针位置打开菜单，条目与快捷键都渲染', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(_panel, findsNothing);

    const Offset at = Offset(410, 300);
    await _rightClick(tester, at);

    expect(_panel, findsOneWidget);
    final Rect rect = tester.getRect(_panel);
    expect(rect.topLeft.dx, closeTo(at.dx, 1.0));
    expect(rect.topLeft.dy, closeTo(at.dy, 1.0));
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('Ctrl+C'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击操作项回调并自动收起，onOpenChange 成对触发', (tester) async {
    final List<String> selected = <String>[];
    final List<bool> openStates = <bool>[];
    await tester.pumpWidget(
      _wrap(onSelected: selected.add, onOpenChange: openStates.add),
    );

    await _rightClick(tester, const Offset(400, 300));
    expect(openStates, <bool>[true]);

    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(selected, <String>['copy']);
    expect(openStates, <bool>[true, false]);
    expect(_panel, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('禁用项、标题、分隔线不可选，点了菜单也不收起', (tester) async {
    final List<String> selected = <String>[];
    await tester.pumpWidget(_wrap(onSelected: selected.add));
    await _rightClick(tester, const Offset(400, 300));

    await tester.tap(find.text('禁用'));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(_panel, findsOneWidget);

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(_panel, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击菜单外与 Esc 都能关闭', (tester) async {
    await tester.pumpWidget(_wrap());
    await _rightClick(tester, const Offset(400, 300));

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);

    await _rightClick(tester, const Offset(400, 300));
    expect(_panel, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('靠近右下角时翻转到点击点左上方', (tester) async {
    await tester.pumpWidget(_wrap(fullScreenTarget: true));
    final Size viewport =
        tester.view.physicalSize / tester.view.devicePixelRatio;
    final Offset at = Offset(viewport.width - 20, viewport.height - 20);

    await _rightClick(tester, at);

    final Rect rect = tester.getRect(_panel);
    expect(rect.right, lessThanOrEqualTo(at.dx + 0.01));
    expect(rect.bottom, lessThanOrEqualTo(at.dy + 0.01));
    expect(rect.right, lessThanOrEqualTo(viewport.width - 8 + 0.01));
    expect(rect.bottom, lessThanOrEqualTo(viewport.height - 8 + 0.01));
    expect(rect.left, greaterThanOrEqualTo(8 - 0.01));
    expect(rect.top, greaterThanOrEqualTo(8 - 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('长按同样能打开，可单独关掉；enabled=false 完全不响应', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.longPressAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);

    // 换配置前先收起：同一位置的 StatefulWidget 会复用 State，菜单不会自己关。
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);

    await tester.pumpWidget(_wrap(longPressEnabled: false));
    await tester.longPressAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);

    await tester.pumpWidget(_wrap(enabled: false));
    await _rightClick(tester, const Offset(400, 300));
    expect(_panel, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('键盘上下 + Enter 选中，跳过禁用项', (tester) async {
    final List<String> selected = <String>[];
    await tester.pumpWidget(_wrap(onSelected: selected.add));
    await _rightClick(tester, const Offset(400, 300));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(selected, <String>['paste']);
    expect(_panel, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('面板尺寸精确等于预估值，分隔线与标题也带行 key', (tester) async {
    await tester.pumpWidget(_wrap());
    await _rightClick(tester, const Offset(400, 300));

    final Size expected = measureContextMenu<String>(
      _items,
      const ContextMenuStyle(),
    );
    expect(tester.getSize(_panel).width, closeTo(expected.width, 0.01));
    expect(tester.getSize(_panel).height, closeTo(expected.height, 0.01));
    expect(find.byKey(contextMenuItemKey(0)), findsOneWidget); // header
    expect(find.byKey(contextMenuItemKey(3)), findsOneWidget); // divider
    expect(find.byKey(kContextMenuListKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prefix 顶替 icon 槽位，同级其它行仍然预留图标宽度', (tester) async {
    const ValueKey<String> dot = ValueKey<String>('dot');
    await tester.pumpWidget(
      _wrap(
        items: <ContextMenuItem<String>>[
          ContextMenuItem<String>(
            'copy',
            label: '复制',
            // 同时给 icon 与 prefix：prefix 优先。
            icon: Icons.copy,
            prefix: const SizedBox(
              key: dot,
              width: 8,
              height: 8,
              child: ColoredBox(color: Color(0xFFFF0000)),
            ),
          ),
          ContextMenuItem<String>('paste', label: '粘贴'),
        ],
      ),
    );
    await _rightClick(tester, const Offset(400, 300));

    expect(find.byKey(dot), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsNothing);

    // 没有图标 / prefix 的行同样从图标槽位之后开始：6(padding) +
    // 10(itemPadding) + 18(iconSize) + 8(iconGap)。
    const ContextMenuStyle style = ContextMenuStyle();
    final double rowLeft =
        tester.getRect(_panel).left + style.padding + style.itemPadding;
    expect(
      tester.getTopLeft(find.text('粘贴')).dx,
      closeTo(rowLeft + style.iconSize + style.iconGap, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('color 单独指定行前景色：优先 danger，图标同色，禁用仍置灰', (tester) async {
    const Color teal = Color(0xFF00897B);
    await tester.pumpWidget(
      _wrap(
        items: <ContextMenuItem<String>>[
          ContextMenuItem<String>(
            'a',
            label: '自定义色',
            icon: Icons.copy,
            color: teal,
          ),
          ContextMenuItem<String>(
            'b',
            label: '自定义色+危险',
            icon: Icons.delete,
            color: teal,
            danger: true,
          ),
          ContextMenuItem<String>(
            'c',
            label: '危险',
            icon: Icons.warning,
            danger: true,
          ),
          ContextMenuItem<String>(
            'd',
            label: '禁用带色',
            icon: Icons.lock,
            color: teal,
            enabled: false,
          ),
        ],
      ),
    );
    await _rightClick(tester, const Offset(400, 300));

    final ThemeData theme = Theme.of(tester.element(find.text('自定义色')));
    expect(tester.widget<Text>(find.text('自定义色')).style?.color, teal);
    expect(tester.widget<Icon>(find.byIcon(Icons.copy)).color, teal);
    // danger 被显式 color 压过。
    expect(tester.widget<Text>(find.text('自定义色+危险')).style?.color, teal);
    expect(tester.widget<Icon>(find.byIcon(Icons.delete)).color, teal);
    // 只有 danger 时仍走 dangerColor。
    expect(
      tester.widget<Text>(find.text('危险')).style?.color,
      theme.colorScheme.error,
    );
    // 禁用优先级最高，color 不生效。
    expect(
      tester.widget<Text>(find.text('禁用带色')).style?.color,
      theme.colorScheme.onSurface.withAlpha(100),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('行光标默认手型，可按 style 改；禁用行回落箭头', (tester) async {
    const List<ContextMenuItem<String>> items = <ContextMenuItem<String>>[
      ContextMenuItem<String>('a', label: '复制'),
      ContextMenuItem<String>('b', label: '禁用', enabled: false),
    ];
    InkWell rowInk(int index) => tester.widget<InkWell>(
      find.ancestor(
        of: find.byKey(contextMenuItemKey(index)),
        matching: find.byType(InkWell),
      ),
    );

    await tester.pumpWidget(_wrap(items: items));
    await _rightClick(tester, const Offset(400, 300));
    expect(rowInk(0).mouseCursor, SystemMouseCursors.click);
    expect(rowInk(1).mouseCursor, MouseCursor.defer);

    // 换光标：可点行跟着 style 走，禁用行仍然是默认箭头。
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _wrap(
        items: items,
        style: const ContextMenuStyle(mouseCursor: SystemMouseCursors.basic),
      ),
    );
    await _rightClick(tester, const Offset(400, 300));
    expect(rowInk(0).mouseCursor, SystemMouseCursors.basic);
    expect(rowInk(1).mouseCursor, MouseCursor.defer);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iconGap 可调整行首图标与文案的间距（预留槽位同步）', (tester) async {
    await tester.pumpWidget(
      _wrap(
        items: <ContextMenuItem<String>>[
          ContextMenuItem<String>('copy', label: '复制', icon: Icons.copy),
          ContextMenuItem<String>('paste', label: '粘贴'),
        ],
        style: const ContextMenuStyle(iconGap: 14),
      ),
    );
    await _rightClick(tester, const Offset(400, 300));

    const ContextMenuStyle style = ContextMenuStyle(iconGap: 14);
    final double rowLeft =
        tester.getRect(_panel).left + style.padding + style.itemPadding;
    expect(
      tester.getTopLeft(find.text('粘贴')).dx,
      closeTo(rowLeft + style.iconSize + 14, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('itemPadding 调行内左右留白，操作项与标题一起缩进', (tester) async {
    await tester.pumpWidget(
      _wrap(
        items: <ContextMenuItem<String>>[
          ContextMenuItem<String>.header('分组'),
          ContextMenuItem<String>('copy', label: '复制', icon: Icons.copy),
          ContextMenuItem<String>('paste', label: '粘贴'),
        ],
        style: const ContextMenuStyle(padding: 4, itemPadding: 18),
      ),
    );
    await _rightClick(tester, const Offset(400, 300));

    const ContextMenuStyle style = ContextMenuStyle(
      padding: 4,
      itemPadding: 18,
    );
    final double rowLeft =
        tester.getRect(_panel).left + style.padding + style.itemPadding;
    // 有 / 没图标的行都在同一个图标槽位之后；标题跟着同样的缩进。
    expect(
      tester.getTopLeft(find.text('复制')).dx,
      closeTo(rowLeft + 18 + 8, 0.01),
    );
    expect(
      tester.getTopLeft(find.text('粘贴')).dx,
      closeTo(rowLeft + 18 + 8, 0.01),
    );
    expect(tester.getTopLeft(find.text('分组')).dx, closeTo(rowLeft, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('itemBuilder 与自定义 style 生效', (tester) async {
    await tester.pumpWidget(
      _wrap(
        style: const ContextMenuStyle(width: 260, itemHeight: 44),
        itemBuilder: (BuildContext context, ContextMenuItem<String> item) =>
            Center(child: Text('自定义-${item.label}')),
      ),
    );
    await _rightClick(tester, const Offset(400, 300));

    expect(find.text('自定义-复制'), findsOneWidget);
    expect(find.text('复制'), findsNothing);
    final Size size = tester.getSize(_panel);
    expect(size.width, closeTo(260, 0.01));
    expect(
      size.height,
      closeTo(
        measureContextMenu<String>(
          _items,
          const ContextMenuStyle(width: 260, itemHeight: 44),
        ).height,
        0.01,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('再次右键收起后重开；页面销毁后浮层不残留', (tester) async {
    await tester.pumpWidget(_wrap(fullScreenTarget: true));
    await _rightClick(tester, const Offset(300, 200));
    final Rect first = tester.getRect(_panel);

    // 点在菜单外：全屏拦截层会把这次右键转成「重定位」，菜单不收起。
    await _rightClick(tester, const Offset(540, 420));
    final Rect second = tester.getRect(_panel);
    expect(second.topLeft, isNot(first.topLeft));
    expect(_panel, findsOneWidget);

    // 在同一路由里把组件换掉（换 home 不会替换已存在的 route），
    // 这样才能真正走到 State.dispose，验证浮层被摘干净。
    await tester.pumpWidget(_wrap(fullScreenTarget: true, withMenu: false));
    await tester.pump();
    expect(find.text('gone'), findsOneWidget);
    expect(_panel, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('空 items 不弹菜单', (tester) async {
    await tester.pumpWidget(_wrap(items: const <ContextMenuItem<String>>[]));
    await _rightClick(tester, const Offset(400, 300));
    expect(_panel, findsNothing);
    expect(tester.takeException(), isNull);
  });

  // ── 多级子菜单 ──────────────────────────────────────────────────────────

  testWidgets('子 / 孙菜单逐级展开，父项有箭头且不触发 onSelected', (tester) async {
    final List<String> selected = <String>[];
    await tester.pumpWidget(
      _wrap(items: _nested, fullScreenTarget: true, onSelected: selected.add),
    );
    await _rightClick(tester, const Offset(200, 200));

    expect(find.byIcon(Icons.chevron_right), findsWidgets); // 父项箭头
    await tester.tap(find.text('导出为'));
    await tester.pumpAndSettle();
    expect(selected, isEmpty); // 父项只展开，不算选中
    expect(_levelPanel(1), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('图片'), findsOneWidget);

    await tester.tap(find.text('图片'));
    await tester.pumpAndSettle();
    expect(_levelPanel(2), findsOneWidget);
    expect(find.text('PNG'), findsOneWidget);
    expect(_allPanels, findsNWidgets(3));

    await tester.tap(find.text('PNG'));
    await tester.pumpAndSettle();
    expect(selected, <String>['png']);
    expect(_allPanels, findsNothing); // 所有层级一起收起
    expect(tester.takeException(), isNull);
  });

  testWidgets('子菜单优先显示在右侧，右边空间不够时翻到左侧', (tester) async {
    final Size viewport =
        tester.view.physicalSize / tester.view.devicePixelRatio;

    // 左侧点击：子菜单应贴在根菜单右边。
    await tester.pumpWidget(_wrap(items: _nested, fullScreenTarget: true));
    await _rightClick(tester, const Offset(200, 200));
    await tester.tap(find.text('导出为'));
    await tester.pumpAndSettle();
    final Rect rootRight = tester.getRect(_levelPanel(0));
    final Rect childRight = tester.getRect(_levelPanel(1));
    expect(childRight.left, greaterThanOrEqualTo(rootRight.right - 4.01));
    expect(childRight.left, greaterThan(rootRight.left));

    // 收起，换到靠右边缘再开：子菜单应翻到根菜单左边。
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await _rightClick(tester, Offset(viewport.width - 240, 200));
    final Rect root = tester.getRect(_levelPanel(0));
    await tester.tap(find.text('导出为'));
    await tester.pumpAndSettle();
    final Rect childLeft = tester.getRect(_levelPanel(1));
    expect(childLeft.right, lessThanOrEqualTo(root.left + 4.01));
    expect(childLeft.left, lessThan(root.left));
    expect(childLeft.left, greaterThanOrEqualTo(8 - 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('子菜单底部溢出时整体上移并夹进视口', (tester) async {
    final Size viewport =
        tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.pumpWidget(_wrap(items: _tall, fullScreenTarget: true));
    await _rightClick(tester, Offset(200, viewport.height - 10));
    await tester.tap(find.text('高子菜单'));
    await tester.pumpAndSettle();

    final Rect child = tester.getRect(_levelPanel(1));
    expect(child.bottom, lessThanOrEqualTo(viewport.height - 8 + 0.01));
    expect(child.top, greaterThanOrEqualTo(8 - 0.01));
    expect(child.left, greaterThanOrEqualTo(8 - 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('子菜单可按父项的 width 单独设定宽度，孙级仍跟随 style', (tester) async {
    await tester.pumpWidget(
      _wrap(
        items: <ContextMenuItem<String>>[
          ContextMenuItem<String>('copy', label: '复制'),
          ContextMenuItem<String>.submenu(
            '宽子菜单',
            width: 300,
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
        ],
        fullScreenTarget: true,
      ),
    );
    await _rightClick(tester, const Offset(120, 200));
    expect(tester.getSize(_levelPanel(0)).width, closeTo(220, 0.01));

    await tester.tap(find.text('宽子菜单'));
    await tester.pumpAndSettle();
    expect(tester.getSize(_levelPanel(1)).width, closeTo(300, 0.01));
    // 变宽后面板仍然贴着根菜单右边，没有被挤回屏幕里。
    expect(
      tester.getRect(_levelPanel(1)).left,
      greaterThanOrEqualTo(tester.getRect(_levelPanel(0)).right - 4.01),
    );

    await tester.tap(find.text('图片'));
    await tester.pumpAndSettle();
    expect(tester.getSize(_levelPanel(2)).width, closeTo(220, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hover 切换子菜单，hover 叶子项收起所有子级', (tester) async {
    await tester.pumpWidget(_wrap(items: _nested, fullScreenTarget: true));
    await _rightClick(tester, const Offset(200, 200));

    final TestGesture mouse = await _hover(tester, find.text('导出为'));
    expect(_levelPanel(1), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);

    await mouse.moveTo(tester.getCenter(find.text('更多')));
    await tester.pumpAndSettle();
    expect(_levelPanel(1), findsOneWidget);
    expect(find.text('选项A'), findsOneWidget);
    expect(find.text('PDF'), findsNothing);

    await mouse.moveTo(tester.getCenter(find.text('复制')));
    await tester.pumpAndSettle();
    expect(_levelPanel(1), findsNothing);
    expect(_allPanels, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('键盘 → 展开、← 返回、Enter 在孙级选中', (tester) async {
    final List<String> selected = <String>[];
    await tester.pumpWidget(
      _wrap(items: _nested, fullScreenTarget: true, onSelected: selected.add),
    );
    await _rightClick(tester, const Offset(200, 200));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_levelPanel(1), findsOneWidget);

    // ← 收掉子级，再重新展开。
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_levelPanel(1), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_levelPanel(1), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_levelPanel(2), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, <String>['png']);
    expect(_allPanels, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点菜单外一次收起全部层级', (tester) async {
    await tester.pumpWidget(_wrap(items: _nested, fullScreenTarget: true));
    await _rightClick(tester, const Offset(200, 200));
    await tester.tap(find.text('导出为'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('图片'));
    await tester.pumpAndSettle();
    expect(_allPanels, findsNWidgets(3));

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(_allPanels, findsNothing);
    expect(tester.takeException(), isNull);
  });

  // ── Material / 主题 ────────────────────────────────────────────────────

  testWidgets('面板由 Material 包裹，文字与配色跟随主题', (tester) async {
    await tester.pumpWidget(
      _wrap(
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'MenuFont'),
      ),
    );
    await _rightClick(tester, const Offset(400, 300));

    final Finder materialFinder = find.descendant(
      of: _panel,
      matching: find.byType(Material),
    );
    expect(materialFinder, findsOneWidget);
    final Material material = tester.widget<Material>(materialFinder);
    final ThemeData theme = Theme.of(tester.element(_panel));
    expect(theme.brightness, Brightness.dark);
    expect(material.color, theme.colorScheme.surface);
    expect(material.textStyle?.fontFamily, 'MenuFont');

    final Text label = tester.widget<Text>(find.text('复制'));
    expect(label.style?.fontFamily, 'MenuFont');
    expect(label.style?.color, theme.colorScheme.onSurface);
    // 不再是硬编码的浅色主题前景色。
    expect(label.style?.color, isNot(const Color(0xFF18181B)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('textStyle 可覆盖主题文字的字号', (tester) async {
    await tester.pumpWidget(
      _wrap(
        style: const ContextMenuStyle(
          textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
    await _rightClick(tester, const Offset(400, 300));
    final Text label = tester.widget<Text>(find.text('复制'));
    expect(label.style?.fontSize, 18);
    expect(label.style?.fontWeight, FontWeight.w700);
    expect(tester.takeException(), isNull);
  });

  // ── 纯函数定位 ──────────────────────────────────────────────────────────

  test('contextMenuItemTop 按行高累加（含面板 padding）', () {
    const ContextMenuStyle style = ContextMenuStyle();
    expect(contextMenuItemTop<String>(_items, 0, style), style.padding);
    expect(
      contextMenuItemTop<String>(_items, 3, style),
      style.padding + style.headerHeight + 2 * style.itemHeight,
    );
  });

  test('resolveSubmenuPlacement 右侧优先 / 左侧翻转 / 底部夹紧', () {
    const ContextMenuStyle style = ContextMenuStyle();
    const Size viewport = Size(800, 600);
    final Size child = measureContextMenu<String>(_tall[1].children!, style);

    final ContextMenuPlacement right = resolveSubmenuPlacement(
      parentRect: const Rect.fromLTWH(200, 200, 220, 84),
      itemTop: 42,
      menuSize: child,
      viewport: viewport,
      edgePadding: 8,
      panelPadding: style.padding,
      overlap: style.submenuOverlap,
    );
    expect(right.flippedX, isFalse);
    expect(right.origin.dx, 420 - style.submenuOverlap);

    final ContextMenuPlacement left = resolveSubmenuPlacement(
      parentRect: const Rect.fromLTWH(560, 200, 220, 84),
      itemTop: 42,
      menuSize: child,
      viewport: viewport,
      edgePadding: 8,
      panelPadding: style.padding,
      overlap: style.submenuOverlap,
    );
    expect(left.flippedX, isTrue);
    expect(left.origin.dx + left.size.width, 560 + style.submenuOverlap);

    final ContextMenuPlacement bottom = resolveSubmenuPlacement(
      parentRect: const Rect.fromLTWH(200, 540, 220, 84),
      itemTop: 42,
      menuSize: child,
      viewport: viewport,
      edgePadding: 8,
      panelPadding: style.padding,
      overlap: style.submenuOverlap,
    );
    expect(bottom.flippedY, isTrue);
    expect(bottom.rect.bottom, lessThanOrEqualTo(viewport.height - 8 + 0.01));
    expect(bottom.rect.top, greaterThanOrEqualTo(8 - 0.01));
  });

  // ── 显示 / 隐藏动画 ────────────────────────────────────────────────────

  test('resolveContextMenuRevealOrigin 按落位把起点角镜像', () {
    const Size size = Size(220, 160);
    ContextMenuPlacement at(bool x, bool y) => ContextMenuPlacement(
      origin: Offset.zero,
      size: size,
      flippedX: x,
      flippedY: y,
    );

    expect(
      resolveContextMenuRevealOrigin(
        ContextMenuReveal.corner,
        at(false, false),
      ),
      ContextMenuRevealOrigin.topLeft,
    );
    expect(
      resolveContextMenuRevealOrigin(ContextMenuReveal.corner, at(true, false)),
      ContextMenuRevealOrigin.topRight,
    );
    expect(
      resolveContextMenuRevealOrigin(ContextMenuReveal.corner, at(false, true)),
      ContextMenuRevealOrigin.bottomLeft,
    );
    expect(
      resolveContextMenuRevealOrigin(ContextMenuReveal.corner, at(true, true)),
      ContextMenuRevealOrigin.bottomRight,
    );

    // unfold（贴边揭开）：只沿垂直轴推进，横向翻转不改变方向。
    // 右下（默认）→ 上边往下揭，与 TextDropdown 在触发器下方展开时一致。
    expect(
      resolveContextMenuRevealOrigin(
        ContextMenuReveal.unfold,
        at(false, false),
      ),
      ContextMenuRevealOrigin.top,
    );
    // 翻到上方 → 下边往上揭。
    expect(
      resolveContextMenuRevealOrigin(ContextMenuReveal.unfold, at(false, true)),
      ContextMenuRevealOrigin.bottom,
    );
    // 翻到左侧（贴在屏幕右边缘右键）→ 仍然是往下揭，不是左右滑。
    expect(
      resolveContextMenuRevealOrigin(ContextMenuReveal.unfold, at(true, false)),
      ContextMenuRevealOrigin.top,
    );
    // 两个轴都翻 → 跟着纵向走，从下边往上揭。
    expect(
      resolveContextMenuRevealOrigin(ContextMenuReveal.unfold, at(true, true)),
      ContextMenuRevealOrigin.bottom,
    );

    // 四个固定方向忽略落位。
    const List<ContextMenuReveal> fixed = <ContextMenuReveal>[
      ContextMenuReveal.topLeftToBottomRight,
      ContextMenuReveal.topRightToBottomLeft,
      ContextMenuReveal.bottomLeftToTopRight,
      ContextMenuReveal.bottomRightToTopLeft,
    ];
    const List<ContextMenuRevealOrigin> corners = <ContextMenuRevealOrigin>[
      ContextMenuRevealOrigin.topLeft,
      ContextMenuRevealOrigin.topRight,
      ContextMenuRevealOrigin.bottomLeft,
      ContextMenuRevealOrigin.bottomRight,
    ];
    for (int i = 0; i < fixed.length; i++) {
      for (final ContextMenuPlacement placement in <ContextMenuPlacement>[
        at(false, false),
        at(true, true),
      ]) {
        expect(resolveContextMenuRevealOrigin(fixed[i], placement), corners[i]);
      }
    }
  });

  test('ContextMenuRevealClipper 从起点角 / 边扫向对角', () {
    const Size size = Size(220, 160);
    const double w = 220;
    const double h = 160;
    // 离角 24px，避开圆角；p 取中段，起点侧可见、对角侧不可见。
    const Map<ContextMenuRevealOrigin, Offset> near =
        <ContextMenuRevealOrigin, Offset>{
          ContextMenuRevealOrigin.topLeft: Offset(24, 24),
          ContextMenuRevealOrigin.topRight: Offset(w - 24, 24),
          ContextMenuRevealOrigin.bottomLeft: Offset(24, h - 24),
          ContextMenuRevealOrigin.bottomRight: Offset(w - 24, h - 24),
        };
    const Map<ContextMenuRevealOrigin, Offset> far =
        <ContextMenuRevealOrigin, Offset>{
          ContextMenuRevealOrigin.topLeft: Offset(w - 24, h - 24),
          ContextMenuRevealOrigin.topRight: Offset(24, h - 24),
          ContextMenuRevealOrigin.bottomLeft: Offset(w - 24, 24),
          ContextMenuRevealOrigin.bottomRight: Offset(24, 24),
        };
    for (final MapEntry<ContextMenuRevealOrigin, Offset> entry
        in near.entries) {
      final ContextMenuRevealOrigin origin = entry.key;
      final Path path = ContextMenuRevealClipper(
        progress: 0.45,
        origin: origin,
        radius: 10,
        lip: 8,
      ).getClip(size);
      expect(path.contains(entry.value), isTrue, reason: '$origin 起点侧');
      expect(path.contains(far[origin]!), isFalse, reason: '$origin 对角侧');
    }

    // 轴向揭示：只沿垂直轴从上边 / 下边推进。
    const Map<ContextMenuRevealOrigin, Offset> nearEdge =
        <ContextMenuRevealOrigin, Offset>{
          ContextMenuRevealOrigin.top: Offset(w / 2, 20),
          ContextMenuRevealOrigin.bottom: Offset(w / 2, h - 20),
        };
    for (final MapEntry<ContextMenuRevealOrigin, Offset> entry
        in nearEdge.entries) {
      final Path path = ContextMenuRevealClipper(
        progress: 0.45,
        origin: entry.key,
        radius: 10,
        lip: 8,
      ).getClip(size);
      expect(path.contains(entry.value), isTrue, reason: '${entry.key} 起始边');
      final Offset opposite = switch (entry.key) {
        ContextMenuRevealOrigin.top => Offset(w / 2, h - 20),
        ContextMenuRevealOrigin.bottom => const Offset(w / 2, 20),
        _ => Offset.zero,
      };
      expect(path.contains(opposite), isFalse, reason: '${entry.key} 远边');
    }

    // p = 1 时是完整圆角外框：两侧都可见，但圆角外的角点不可见。
    final Path full = const ContextMenuRevealClipper(
      progress: 1,
      origin: ContextMenuRevealOrigin.topLeft,
      radius: 10,
    ).getClip(size);
    expect(full.contains(const Offset(24, 24)), isTrue);
    expect(full.contains(const Offset(w - 24, h - 24)), isTrue);
    expect(full.contains(const Offset(1, 1)), isFalse);
  });

  testWidgets('进场动画：揭示裁切逐帧推进，投影在裁切之外，结束后移除裁切', (tester) async {
    await tester.pumpWidget(_wrap());
    await _openPaused(tester, const Offset(400, 300));

    expect(find.byKey(contextMenuClipKey(0)), findsOneWidget);
    final ContextMenuRevealClipper mid = _clipOf(tester, 0);
    expect(mid.progress, greaterThan(0));
    expect(mid.progress, lessThan(1));
    expect(mid.origin, ContextMenuRevealOrigin.topLeft);
    expect(_levelAnimationDuration(tester), const Duration(milliseconds: 220));
    expect(
      find.ancestor(
        of: find.byKey(contextMenuClipKey(0)),
        matching: find.byKey(contextMenuShadowKey(0)),
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byKey(contextMenuClipKey(0)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('收起动画：裁切线退回起点角，时长为进场的 3/4，最后移除浮层', (tester) async {
    await tester.pumpWidget(_wrap());
    await _rightClick(tester, const Offset(400, 300));
    expect(find.byKey(contextMenuClipKey(0)), findsNothing);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(_panel, findsOneWidget);
    expect(find.byKey(contextMenuClipKey(0)), findsOneWidget);
    final double first = _clipOf(tester, 0).progress;
    expect(first, greaterThan(0));
    expect(first, lessThan(1));
    expect(_levelAnimationDuration(tester), const Duration(milliseconds: 165));

    await tester.pump(const Duration(milliseconds: 40));
    expect(_clipOf(tester, 0).progress, lessThan(first));

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(_panel, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('菜单翻到左上方时，揭示起点自动变成右下角', (tester) async {
    await tester.pumpWidget(_wrap(fullScreenTarget: true));
    final Size viewport =
        tester.view.physicalSize / tester.view.devicePixelRatio;
    await _openPaused(
      tester,
      Offset(viewport.width - 20, viewport.height - 20),
    );

    expect(_clipOf(tester, 0).origin, ContextMenuRevealOrigin.bottomRight);
    final Rect rect = tester.getRect(_panel);
    expect(rect.right, lessThanOrEqualTo(viewport.width - 8 + 0.01));
    expect(rect.bottom, lessThanOrEqualTo(viewport.height - 8 + 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('子菜单翻到左侧时起点变成右上角', (tester) async {
    final Size viewport =
        tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.pumpWidget(_wrap(items: _nested, fullScreenTarget: true));
    await _rightClick(tester, Offset(viewport.width - 240, 200));

    await tester.tap(find.text('导出为'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(find.byKey(contextMenuClipKey(1)), findsOneWidget);
    expect(_clipOf(tester, 1).origin, ContextMenuRevealOrigin.topRight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unfold 模式：根菜单与子菜单都往下揭，翻到上方才往上揭', (tester) async {
    await tester.pumpWidget(
      _wrap(
        items: _nested,
        fullScreenTarget: true,
        style: const ContextMenuStyle(reveal: ContextMenuReveal.unfold),
      ),
    );

    // 默认落位（菜单在锚点右下方）→ 从上边往下揭，和 TextDropdown 在触发器
    // 下方展开时完全一致。
    await _openPaused(tester, const Offset(200, 200));
    expect(_clipOf(tester, 0).origin, ContextMenuRevealOrigin.top);

    // 子菜单贴着父级右侧：轴不变，仍然是往下揭，不是左右滑。
    await tester.tap(find.text('导出为'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(_clipOf(tester, 1).origin, ContextMenuRevealOrigin.top);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unfold 模式：贴着屏幕右边右键、菜单翻到左侧时仍然往下揭', (tester) async {
    await tester.pumpWidget(
      _wrap(
        fullScreenTarget: true,
        style: const ContextMenuStyle(reveal: ContextMenuReveal.unfold),
      ),
    );
    // 靠近右边缘右键 → 菜单放不下，翻到指针左侧。
    await _openPaused(tester, const Offset(700, 200));
    expect(_clipOf(tester, 0).origin, ContextMenuRevealOrigin.top);
    // 横向翻转只改位置：右边缘贴着指针，尺寸与最终值一致（不位移、不缩放）。
    final Rect rect = tester.getRect(_panel);
    expect(rect.right, closeTo(700, 0.01));
    expect(
      rect.size,
      measureContextMenu<String>(_items, const ContextMenuStyle()),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('固定方向模式忽略落位', (tester) async {
    await tester.pumpWidget(
      _wrap(
        fullScreenTarget: true,
        style: const ContextMenuStyle(
          reveal: ContextMenuReveal.bottomRightToTopLeft,
        ),
      ),
    );
    await _openPaused(tester, const Offset(200, 200));
    expect(_clipOf(tester, 0).origin, ContextMenuRevealOrigin.bottomRight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduceMotion 时不做揭示裁切', (tester) async {
    await tester.pumpWidget(
      _wrap(style: const ContextMenuStyle(reduceMotion: true)),
    );
    await _openPaused(tester, const Offset(400, 300));
    expect(find.byKey(contextMenuClipKey(0)), findsNothing);
    expect(_panel, findsOneWidget);
    expect(_levelAnimationDuration(tester), const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);
  });

  // ── 菜单未隐藏时的二次右键 ──────────────────────────────────────────────

  testWidgets('菜单未隐藏时再次右键：先收起再在新位置重播揭示', (tester) async {
    final List<bool> openStates = <bool>[];
    await tester.pumpWidget(
      _wrap(fullScreenTarget: true, onOpenChange: openStates.add),
    );
    await _rightClick(tester, const Offset(250, 200));
    expect(find.byKey(contextMenuClipKey(0)), findsNothing);

    // 二次右键：退场中段应该重新出现裁切，且时长是重开专用的 1/2。
    await _rightClickStart(tester, const Offset(500, 150));
    await tester.pump(const Duration(milliseconds: 40));
    expect(_panel, findsOneWidget);
    expect(find.byKey(contextMenuClipKey(0)), findsOneWidget);
    expect(_levelAnimationDuration(tester), const Duration(milliseconds: 110));
    final double exitProgress = _clipOf(tester, 0).progress;
    expect(exitProgress, greaterThan(0));
    expect(exitProgress, lessThan(1));

    // 退场结束后换锚点，进场动画再播一遍。
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(find.byKey(contextMenuClipKey(0)), findsOneWidget);
    final double enterProgress = _clipOf(tester, 0).progress;
    expect(enterProgress, greaterThan(0));
    expect(enterProgress, lessThan(1));
    expect(_clipOf(tester, 0).origin, ContextMenuRevealOrigin.topLeft);
    expect(_levelAnimationDuration(tester), const Duration(milliseconds: 220));

    await tester.pumpAndSettle();
    expect(find.byKey(contextMenuClipKey(0)), findsNothing);
    final Rect rect = tester.getRect(_panel);
    expect(rect.topLeft.dx, closeTo(500, 1.0));
    expect(rect.topLeft.dy, closeTo(150, 1.0));
    // 重开不算一次新的开关，回调不重复。
    expect(openStates, <bool>[true]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('重开后落位翻转时，揭示起点随新锚点重新解析', (tester) async {
    await tester.pumpWidget(_wrap(fullScreenTarget: true));
    final Size viewport =
        tester.view.physicalSize / tester.view.devicePixelRatio;
    await _rightClick(tester, const Offset(200, 200));

    // 换到右下角：菜单翻到锚点左上方，起点角应从左下角开始。
    await _rightClickStart(
      tester,
      Offset(viewport.width - 20, viewport.height - 20),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(find.byKey(contextMenuClipKey(0)), findsOneWidget);
    expect(_clipOf(tester, 0).origin, ContextMenuRevealOrigin.bottomRight);

    await tester.pumpAndSettle();
    final Rect rect = tester.getRect(_panel);
    expect(rect.right, lessThanOrEqualTo(viewport.width - 8 + 0.01));
    expect(rect.bottom, lessThanOrEqualTo(viewport.height - 8 + 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('二次右键落在菜单内部也会重播动画', (tester) async {
    await tester.pumpWidget(_wrap(fullScreenTarget: true));
    await _rightClick(tester, const Offset(250, 200));
    final Offset inside = tester.getRect(_panel).center;

    await _rightClickStart(tester, inside);
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byKey(contextMenuClipKey(0)), findsOneWidget);
    expect(_clipOf(tester, 0).progress, lessThan(1));

    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
    expect(tester.getRect(_panel).topLeft.dx, closeTo(inside.dx, 1.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('二次右键带开的子级：所有层级一起收起，重开后只剩根级', (tester) async {
    await tester.pumpWidget(_wrap(items: _nested, fullScreenTarget: true));
    await _rightClick(tester, const Offset(200, 200));
    await tester.tap(find.text('导出为'));
    await tester.pumpAndSettle();
    expect(_allPanels, findsNWidgets(2));

    await _rightClickStart(tester, const Offset(500, 380));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byKey(contextMenuClipKey(0)), findsOneWidget);
    expect(find.byKey(contextMenuClipKey(1)), findsOneWidget);

    await tester.pumpAndSettle();
    expect(_allPanels, findsOneWidget);
    expect(tester.getRect(_levelPanel(0)).topLeft.dx, closeTo(500, 1.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('重开中途按 Esc 取消重开，按正常收起结束', (tester) async {
    final List<bool> openStates = <bool>[];
    await tester.pumpWidget(
      _wrap(fullScreenTarget: true, onOpenChange: openStates.add),
    );
    await _rightClick(tester, const Offset(250, 200));

    await _rightClickStart(tester, const Offset(520, 400));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byKey(contextMenuClipKey(0)), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
    expect(openStates, <bool>[true, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('收起动画途中右键会重新打开，并补一次 onOpenChange(true)', (tester) async {
    final List<bool> openStates = <bool>[];
    await tester.pumpWidget(
      _wrap(fullScreenTarget: true, onOpenChange: openStates.add),
    );
    await _rightClick(tester, const Offset(250, 200));

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(openStates, <bool>[true, false]);

    await _rightClick(tester, const Offset(470, 320));
    expect(_panel, findsOneWidget);
    expect(tester.getRect(_panel).topLeft.dx, closeTo(470, 1.0));
    expect(openStates, <bool>[true, false, true]);
    expect(tester.takeException(), isNull);
  });

  // ── unfold 是另一套运动 ────────────────────────────────────────────────

  testWidgets('corner 从起点角轻微放大，unfold 全程不缩放不位移', (tester) async {
    // corner：动画途中面板还没到最终尺寸（0.94 → 1）。
    await tester.pumpWidget(_wrap(fullScreenTarget: true));
    await _openPaused(tester, const Offset(200, 200), ms: 30);
    expect(find.byKey(contextMenuClipKey(0)), findsOneWidget);
    // 220 × 0.94 ≈ 207 起步，在这里还没涨回 220。
    expect(tester.getRect(_panel).width, lessThan(215));

    await tester.pumpAndSettle();
    expect(tester.getRect(_panel).width, closeTo(220, 0.01));

    // 先关掉再换风格：同一个 State 复用，菜单开着时换 style 走的是重开动画。
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);

    // unfold：裁切在推进，但面板尺寸 / 位置从头到尾就是最终值。
    await tester.pumpWidget(
      _wrap(
        fullScreenTarget: true,
        style: const ContextMenuStyle(reveal: ContextMenuReveal.unfold),
      ),
    );
    await tester.pumpAndSettle();
    await _openPaused(tester, const Offset(200, 200), ms: 30);
    final ContextMenuRevealClipper clip = _clipOf(tester, 0);
    expect(clip.progress, greaterThan(0));
    expect(clip.progress, lessThan(1));
    expect(clip.origin, ContextMenuRevealOrigin.top);
    final Rect rect = tester.getRect(_panel);
    expect(rect.width, closeTo(220, 0.01));
    expect(rect.topLeft.dx, closeTo(200, 0.01));
    expect(rect.topLeft.dy, closeTo(200, 0.01));
    expect(tester.takeException(), isNull);
  });

  // ── 命令式入口 ─────────────────────────────────────────────────────────

  testWidgets('showContextMenu 在指定坐标弹出，选中后收起并回调', (tester) async {
    final List<String> selected = <String>[];
    final List<bool> openStates = <bool>[];
    await tester.pumpWidget(
      _showWrap(onSelected: selected.add, onOpenChange: openStates.add),
    );
    expect(_panel, findsNothing);

    await _rightClick(tester, const Offset(400, 300));
    expect(_panel, findsOneWidget);
    expect(openStates, <bool>[true]);
    final Rect rect = tester.getRect(_panel);
    expect(rect.topLeft.dx, closeTo(400, 1.0));
    expect(rect.topLeft.dy, closeTo(300, 1.0));
    expect(find.text('复制'), findsOneWidget);

    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(selected, <String>['copy']);
    expect(openStates, <bool>[true, false]);
    expect(_panel, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showContextMenu 返回的 handle 能提前收起', (tester) async {
    late ContextMenuHandle handle;
    await tester.pumpWidget(
      _showWrap(onHandle: (ContextMenuHandle h) => handle = h),
    );

    await _rightClick(tester, const Offset(400, 300));
    expect(handle.isOpen, isTrue);

    handle.close();
    await tester.pumpAndSettle();
    expect(handle.isOpen, isFalse);
    expect(_panel, findsNothing);

    // 已经收掉之后再关一次是幂等的。
    handle.close();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('showContextMenu 与组件共用子菜单 / 键盘 / 点击外部行为', (tester) async {
    final List<String> selected = <String>[];
    await tester.pumpWidget(
      _showWrap(items: _nested, onSelected: selected.add),
    );
    await _rightClick(tester, const Offset(200, 200));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_levelPanel(1), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_allPanels, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('命令式菜单：在别处右键先收起，再右键才在新位置弹出', (tester) async {
    await tester.pumpWidget(_showWrap());
    await _rightClick(tester, const Offset(300, 200));
    expect(_panel, findsOneWidget);

    // 拦截层在菜单开着时吞掉二次右键：命令式菜单拿不到新位置该用哪份
    // items，所以只收起，不在原地重开。
    await _rightClick(tester, const Offset(560, 420));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);

    await _rightClick(tester, const Offset(560, 420));
    expect(_panel, findsOneWidget);
    expect(tester.getRect(_panel).topLeft.dx, closeTo(560, 1.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('连续调用 showContextMenu 只保留最后一个菜单', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            ctx = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    showContextMenu<String>(
      ctx,
      position: const Offset(200, 200),
      items: _items,
    );
    await tester.pump();
    expect(_allPanels, findsOneWidget);

    showContextMenu<String>(
      ctx,
      position: const Offset(560, 320),
      items: _items,
    );
    await tester.pumpAndSettle();
    expect(_allPanels, findsOneWidget);
    expect(tester.getRect(_panel).topLeft.dx, closeTo(560, 1.0));
    expect(tester.takeException(), isNull);
  });
}

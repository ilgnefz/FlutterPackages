import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_dropdown/flutter_dropdown.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: Center(child: child)),
  );
}

/// [TextDropdown] 面板本体的 key（组件内私有，这里按同值匹配）。
const Key _textBodyKey = ValueKey<String>('text_dropdown_panel_body');

List<TextDropdownItem<String>> _manyTextItems() => <TextDropdownItem<String>>[
  for (int i = 0; i < 12; i++) TextDropdownItem<String>('$i', label: 'Item $i'),
];

List<AnchoredDropdownItem<int>> _manyAnchoredItems() =>
    <AnchoredDropdownItem<int>>[
      for (int i = 0; i < 12; i++)
        AnchoredDropdownItem<int>(i, label: 'Item $i'),
    ];

/// 列表外面那条滚动条的矩形。
Rect _scrollbarRect(WidgetTester tester) =>
    tester.getRect(find.byType(Scrollbar));

void main() {
  group('TextDropdown', () {
    testWidgets('点开显示全部选项，选中后回调并收起', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _wrap(
          TextDropdown<String>(
            items: const <TextDropdownItem<String>>[
              TextDropdownItem<String>('a', label: 'Apple'),
              TextDropdownItem<String>('b', label: 'Banana'),
            ],
            onChanged: (String value) => picked = value,
          ),
        ),
      );

      // 没选值时显示 hint，面板还没出现。
      expect(find.text('Select'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);

      await tester.tap(find.byType(TextDropdown<String>));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);

      await tester.tap(find.text('Banana'));
      await tester.pumpAndSettle();
      expect(picked, 'b');
      // 收起草稿：面板摘掉，行文字不再可见。
      expect(find.text('Apple'), findsNothing);
    });

    testWidgets('value 非空时触发器显示选中项文案', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TextDropdown<String>(
            items: <TextDropdownItem<String>>[
              TextDropdownItem<String>('a', label: 'Apple'),
              TextDropdownItem<String>('b', label: 'Banana'),
            ],
            value: 'b',
          ),
        ),
      );

      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('Select'), findsNothing);
    });

    testWidgets('fieldStyle.padding 控制文字 / 箭头到边框的距离', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TextDropdown<String>(
            items: const <TextDropdownItem<String>>[
              TextDropdownItem<String>('a', label: 'Apple'),
            ],
            fieldStyle: DropdownFieldStyle.light().copyWith(
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Padding &&
              w.padding == const EdgeInsets.symmetric(horizontal: 24),
        ),
        findsOneWidget,
      );
    });

    testWidgets('itemStyle.itemPadding 控制选项文字到行外框的距离', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TextDropdown<String>(
            items: const <TextDropdownItem<String>>[
              TextDropdownItem<String>('a', label: 'Apple'),
            ],
            itemStyle: DropdownItemStyle.light().copyWith(
              itemPadding: const EdgeInsets.symmetric(horizontal: 30),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextDropdown<String>));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Padding &&
              w.padding == const EdgeInsets.symmetric(horizontal: 30),
        ),
        findsOneWidget,
      );
    });

    testWidgets('disabled 时不展开', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TextDropdown<String>(
            items: <TextDropdownItem<String>>[
              TextDropdownItem<String>('a', label: 'Apple'),
            ],
            disabled: true,
          ),
        ),
      );

      await tester.tap(find.byType(TextDropdown<String>));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsNothing);
    });

    testWidgets('onOpenChange 跟着展开 / 收起走', (tester) async {
      final List<bool> states = <bool>[];
      await tester.pumpWidget(
        _wrap(
          TextDropdown<String>(
            items: const <TextDropdownItem<String>>[
              TextDropdownItem<String>('a', label: 'Apple'),
            ],
            onOpenChange: states.add,
          ),
        ),
      );

      await tester.tap(find.byType(TextDropdown<String>));
      await tester.pumpAndSettle();
      expect(states, <bool>[true]);

      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();
      expect(states, <bool>[true, false]);
    });
  });

  group('AnchoredDropdown', () {
    testWidgets('任意 Widget 当触发器；禁用项不回调也不收起', (tester) async {
      int? picked;
      await tester.pumpWidget(
        _wrap(
          AnchoredDropdown<int>(
            trigger: const Text('open'),
            items: const <AnchoredDropdownItem<int>>[
              AnchoredDropdownItem<int>(1, label: 'One'),
              AnchoredDropdownItem<int>(2, label: 'Two', enabled: false),
            ],
            onChanged: (int value) => picked = value,
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(picked, isNull);
      expect(find.text('One'), findsOneWidget, reason: '面板应该还开着');

      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(picked, 1);
      expect(find.text('One'), findsNothing);
    });

    testWidgets('initialOpen 一上来就展开', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AnchoredDropdown<int>(
            trigger: const Text('open'),
            initialOpen: true,
            items: const <AnchoredDropdownItem<int>>[
              AnchoredDropdownItem<int>(1, label: 'One'),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('One'), findsOneWidget);
    });
  });

  group('滚动条', () {
    testWidgets('TextDropdown：滚动条贴着面板右边缘，不受 padding / itemPadding 影响', (
      tester,
    ) async {
      const Key dropdownKey = ValueKey<String>('dd');

      await tester.pumpWidget(
        _wrap(
          TextDropdown<String>(
            key: dropdownKey,
            items: _manyTextItems(),
            itemStyle: DropdownItemStyle.light().copyWith(
              maxHeight: 120,
              padding: 4,
              itemPadding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(dropdownKey));
      await tester.pumpAndSettle();

      final Rect body = tester.getRect(find.byKey(_textBodyKey));
      final Rect bar = _scrollbarRect(tester);
      final Rect view = tester.getRect(find.byType(SingleChildScrollView));

      expect(bar.right, closeTo(body.right, 0.01), reason: '滑块贴右边缘');
      expect(bar.width, closeTo(body.width, 0.01), reason: '滚动条层铺满内容区');
      expect(
        view.right,
        closeTo(body.right - 4, 0.01),
        reason: '列表本体仍按 padding 内缩，滚动条不被它推走',
      );

      // 把两层内边距都放大：行往里缩，滚动条位置不变。
      // key 相同 → State 复用，面板仍然开着，不用再点一次。
      await tester.pumpWidget(
        _wrap(
          TextDropdown<String>(
            key: dropdownKey,
            items: _manyTextItems(),
            itemStyle: DropdownItemStyle.light().copyWith(
              maxHeight: 120,
              padding: 12,
              itemPadding: const EdgeInsets.symmetric(horizontal: 30),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Rect body2 = tester.getRect(find.byKey(_textBodyKey));
      final Rect bar2 = _scrollbarRect(tester);
      expect(bar2.right, closeTo(body2.right, 0.01));
      expect(bar2.width, closeTo(body2.width, 0.01));
      expect(
        tester.getRect(find.byType(SingleChildScrollView)).right,
        closeTo(body2.right - 12, 0.01),
        reason: '只有列表本体跟着 padding 走',
      );
    });

    testWidgets('AnchoredDropdown：滚动条同样贴边，与 padding 无关', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AnchoredDropdown<int>(
            trigger: const Text('open'),
            items: _manyAnchoredItems(),
            itemStyle: DropdownItemStyle.light().copyWith(
              maxHeight: 120,
              padding: 12,
              itemPadding: const EdgeInsets.symmetric(horizontal: 24),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final Rect body = tester.getRect(find.byKey(kDropdownBodyKey));
      final Rect bar = _scrollbarRect(tester);
      expect(bar.right, closeTo(body.right, 0.01));
      expect(bar.width, closeTo(body.width, 0.01));
      expect(
        tester.getRect(find.byType(SingleChildScrollView)).right,
        closeTo(body.right - 12, 0.01),
      );
    });

    testWidgets('桌面平台只画这一条，不会跟平台注入的叠成两条', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await tester.pumpWidget(
        _wrap(
          TextDropdown<String>(
            items: _manyTextItems(),
            itemStyle: DropdownItemStyle.light().copyWith(maxHeight: 120),
          ),
        ),
      );
      await tester.tap(find.byType(TextDropdown<String>));
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsOneWidget);

      final Rect body = tester.getRect(find.byKey(_textBodyKey));
      expect(_scrollbarRect(tester).right, closeTo(body.right, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('列表能滚动（滚动条接的是同一个 controller）', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TextDropdown<String>(
            items: _manyTextItems(),
            itemStyle: DropdownItemStyle.light().copyWith(maxHeight: 120),
          ),
        ),
      );
      await tester.tap(find.byType(TextDropdown<String>));
      await tester.pumpAndSettle();

      final Finder scrollable = find.descendant(
        of: find.byType(Scrollbar),
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      final ScrollableState state = tester.state<ScrollableState>(scrollable);
      expect(state.position.maxScrollExtent, greaterThan(0));

      await tester.drag(find.text('Item 2'), const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(state.position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  });

  group('样式', () {
    testWidgets('两套 style 的 of() 都跟随 ThemeData.brightness', (tester) async {
      late DropdownFieldStyle field;
      late DropdownItemStyle item;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              field = DropdownFieldStyle.of(context);
              item = DropdownItemStyle.of(context);
              return const SizedBox.shrink();
            },
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(field.backgroundColor, const Color(0xFF211F26));
      expect(field.foreground, const Color(0xFFE6E1E5));
      expect(item.backgroundColor, const Color(0xFF211F26));
      expect(item.selectedColor, const Color(0xFF36343B));
      expect(item.foreground, const Color(0xFFE6E1E5));
      expect(item.borderColor, const Color(0xFF49454F));
    });

    test('light() / dark() / copyWith 只改指定字段', () {
      final DropdownFieldStyle field = DropdownFieldStyle.light();
      expect(field.backgroundColor, Colors.white);
      final DropdownFieldStyle patchedField = field.copyWith(width: 300);
      expect(patchedField.width, 300);
      expect(patchedField.foreground, field.foreground);

      final DropdownItemStyle light = DropdownItemStyle.light();
      final DropdownItemStyle patched = light.copyWith(radius: 20.0);
      expect(patched.radius, 20.0);
      expect(patched.foreground, light.foreground);
      expect(patched.itemHeight, light.itemHeight);

      final DropdownItemStyle dark = DropdownItemStyle.dark();
      expect(dark.shadowOpacity, 0.30);
      expect(dark.disabledColor.a, closeTo(0.6, 0.01));
    });
  });

  group('几何', () {
    test('DropdownWidth 解析宽度，触发器没量到时用兜底值', () {
      expect(
        const DropdownWidth.matchTrigger().resolve(0),
        kDropdownFallbackWidth,
      );
      expect(const DropdownWidth.matchTrigger().resolve(120), 120);
      expect(const DropdownWidth.fixed(280).resolve(120), 280);
      expect(const DropdownWidth.matchTrigger().matchesTrigger, isTrue);
      expect(const DropdownWidth.fixed(280).matchesTrigger, isFalse);
    });

    test('揭示进度 1 时裁切覆盖整个面板，进度 0 时只露贴边薄条', () {
      const Size size = Size(200, 100);

      final Path full = const DropdownRevealClipper(progress: 1).getClip(size);
      expect(full.contains(const Offset(10, 10)), isTrue);
      expect(full.contains(const Offset(190, 90)), isTrue);

      final Path start = const DropdownRevealClipper(
        progress: 0,
        lip: 8,
      ).getClip(size);
      expect(start.contains(const Offset(100, 90)), isFalse);
    });

    test('向上展开时薄条贴在底边', () {
      const Size size = Size(200, 100);
      final Path start = const DropdownRevealClipper(
        progress: 0,
        lip: 8,
        placedAbove: true,
      ).getClip(size);
      expect(start.contains(const Offset(100, 10)), isFalse);
    });

    test('斜向揭示在中途只露出起始角', () {
      const Size size = Size(200, 100);
      final Path partial = const DropdownRevealClipper(
        progress: 0.2,
        reveal: DropdownReveal.topLeftToBottomRight,
      ).getClip(size);
      expect(partial.contains(const Offset(6, 6)), isTrue);
      expect(partial.contains(const Offset(194, 94)), isFalse);
    });
  });
}

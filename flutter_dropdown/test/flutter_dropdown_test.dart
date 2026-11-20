import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_dropdown/flutter_dropdown.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: Center(child: child)),
  );
}

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

    testWidgets('fieldPadding 控制文字 / 箭头到边框的距离', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TextDropdown<String>(
            items: const <TextDropdownItem<String>>[
              TextDropdownItem<String>('a', label: 'Apple'),
            ],
            style: DropdownStyle.light().copyWith(
              fieldPadding: const EdgeInsets.symmetric(horizontal: 24),
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

    testWidgets('itemPadding 控制选项文字到行外框的距离', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TextDropdown<String>(
            items: const <TextDropdownItem<String>>[
              TextDropdownItem<String>('a', label: 'Apple'),
            ],
            style: DropdownStyle.light().copyWith(
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

    testWidgets('menuBuilder 完全自定义列表内容', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AnchoredDropdown<int>(
            trigger: const Text('open'),
            menuBuilder: (BuildContext context) =>
                const SizedBox(key: ValueKey<String>('custom'), width: 80),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('custom')), findsOneWidget);
    });
  });

  group('DropdownStyle', () {
    testWidgets('of() 跟随 ThemeData.brightness', (tester) async {
      late DropdownStyle style;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              style = DropdownStyle.of(context);
              return const SizedBox.shrink();
            },
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(style.backgroundColor, const Color(0xFF211F26));
      expect(style.selectedColor, const Color(0xFF36343B));
      expect(style.foreground, const Color(0xFFE6E1E5));
      expect(style.borderColor, const Color(0xFF49454F));
    });

    test('light() / dark() / copyWith 只改指定字段', () {
      final DropdownStyle light = DropdownStyle.light();
      expect(light.backgroundColor, Colors.white);

      final DropdownStyle patched = light.copyWith(radius: 20.0);
      expect(patched.radius, 20.0);
      expect(patched.foreground, light.foreground);
      expect(patched.itemHeight, light.itemHeight);

      final DropdownStyle dark = DropdownStyle.dark();
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

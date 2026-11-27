import 'package:flutter_calendar/flutter_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide showDatePicker;

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// 包住 [finder] 的最近一层 [MouseRegion] 的**解析后**光标。
///
/// `InkWell` / `IconButton` 都是把光标挂在内部那层 `MouseRegion` 上的，所以拉
/// 最近的一层就是「鼠标悬停在这颗组件上时显示什么」。
MouseCursor? _cursorAt(WidgetTester tester, Finder finder) {
  final Finder region = find
      .ancestor(of: finder, matching: find.byType(MouseRegion))
      .first;
  return tester.widget<MouseRegion>(region).cursor;
}

/// 某个日期格子里的文字（用来找它外层的光标）。
Finder _dayCellText(DateTime date) => find.descendant(
  of: find.byKey(calendarDayKey(date)),
  matching: find.byType(Text),
);

Text _cellText(WidgetTester tester, DateTime date) {
  return tester.widget<Text>(
    find.descendant(
      of: find.byKey(calendarDayKey(date)),
      matching: find.byType(Text),
    ),
  );
}

void main() {
  group('CalendarPanel', () {
    testWidgets('单月视图：只显示一个月的 42 格，邻月日期是浅灰', (tester) async {
      final DateTime selected = DateTime(2026, 11, 25);
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: selected,
            selectedDate: selected,
            labels: CalendarLabels.zh,
          ),
        ),
      );

      expect(find.text('2026年11月'), findsOneWidget);
      for (final String label in <String>[
        '周一',
        '周二',
        '周三',
        '周四',
        '周五',
        '周六',
        '周日',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      // 当月日期正常颜色，前后补格的邻月日期透明度更低。
      expect(_cellText(tester, DateTime(2026, 11, 18)).style!.color!.a, 1.0);
      expect(
        _cellText(tester, DateTime(2026, 10, 26)).style!.color!.a,
        lessThan(0.5),
      );
      expect(
        _cellText(tester, DateTime(2026, 12, 6)).style!.color!.a,
        lessThan(0.5),
      );
    });

    testWidgets('点当月日期回调，并归一化到当天 0 点', (tester) async {
      DateTime? picked;
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: DateTime(2026, 11),
            onDateSelected: (DateTime date) => picked = date,
          ),
        ),
      );

      await tester.tap(find.byKey(calendarDayKey(DateTime(2026, 11, 18))));
      await tester.pump();
      expect(picked, DateTime(2026, 11, 18));
    });

    testWidgets('点邻月日期会翻到那个月并直接选中', (tester) async {
      DateTime? picked;
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: DateTime(2026, 11),
            labels: CalendarLabels.zh,
            onDateSelected: (DateTime date) => picked = date,
          ),
        ),
      );

      await tester.tap(find.byKey(calendarDayKey(DateTime(2026, 12, 1))));
      await tester.pumpAndSettle();
      expect(picked, DateTime(2026, 12, 1), reason: '点哪天就选哪天');
      expect(find.text('2026年12月'), findsOneWidget);
    });

    testWidgets('selectAdjacentDays: false 时邻月日期只翻月', (tester) async {
      DateTime? picked;
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: DateTime(2026, 11),
            labels: CalendarLabels.zh,
            selectAdjacentDays: false,
            onDateSelected: (DateTime date) => picked = date,
          ),
        ),
      );

      await tester.tap(find.byKey(calendarDayKey(DateTime(2026, 12, 1))));
      await tester.pumpAndSettle();
      expect(picked, isNull);
      expect(find.text('2026年12月'), findsOneWidget);
    });

    testWidgets('点标题展开年份列表，选中年份回到月视图', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: DateTime(2026, 11),
            labels: CalendarLabels.zh,
          ),
        ),
      );

      await tester.tap(find.text('2026年11月'));
      await tester.pumpAndSettle();
      expect(find.byKey(kCalendarYearGridKey), findsOneWidget);

      await tester.tap(find.text('2028年'));
      await tester.pumpAndSettle();
      expect(find.text('2028年11月'), findsOneWidget);
      expect(find.byKey(kCalendarYearGridKey), findsNothing);
    });

    testWidgets('firstDate / lastDate 之外的日期不可选', (tester) async {
      DateTime? picked;
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: DateTime(2026, 11),
            firstDate: DateTime(2026, 11, 10),
            lastDate: DateTime(2026, 11, 20),
            onDateSelected: (DateTime date) => picked = date,
          ),
        ),
      );

      await tester.tap(find.byKey(calendarDayKey(DateTime(2026, 11, 5))));
      await tester.pump();
      expect(picked, isNull);

      await tester.tap(find.byKey(calendarDayKey(DateTime(2026, 11, 15))));
      await tester.pump();
      expect(picked, DateTime(2026, 11, 15));
    });

    testWidgets('showAdjacentDays: false 时不显示邻月日期', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(month: DateTime(2026, 11), showAdjacentDays: false),
        ),
      );

      expect(find.byKey(calendarDayKey(DateTime(2026, 10, 26))), findsNothing);
      expect(find.byKey(calendarDayKey(DateTime(2026, 12, 1))), findsNothing);
      expect(find.byKey(calendarDayKey(DateTime(2026, 11, 1))), findsOneWidget);
    });

    testWidgets('默认尺寸是收小后的 268 × 264', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: DateTime(2026, 11),
            labels: CalendarLabels.zh,
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(kCalendarPanelKey)),
        const Size(268, 264),
      );
    });

    testWidgets('标题完整显示，不会被挤成省略号', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: DateTime(2026, 12),
            labels: CalendarLabels.zh,
          ),
        ),
      );

      // 之前的布局是 Flexible + Spacer，两者平分剩余宽度，标题只拿到一半，
      // 文字就被省略号吃掉了。这里比「laid out 宽度」和「不换行时需要的宽度」。
      final RenderBox title = tester.renderObject(find.text('2026年12月'));
      expect(
        title.size.width,
        greaterThanOrEqualTo(title.getMaxIntrinsicWidth(double.infinity) - 0.5),
      );
    });

    testWidgets('不传 labels 时按 locale 自动选（英文环境是英文）', (tester) async {
      await tester.pumpWidget(_wrap(CalendarPanel(month: DateTime(2026, 11))));

      expect(find.text('Nov 2026'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('2026年11月'), findsNothing);
    });

    testWidgets('配了 locale + supportedLocales 就按中文走', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Center(child: CalendarPanel(month: DateTime(2026, 11))),
          ),
        ),
      );

      expect(find.text('2026年11月'), findsOneWidget);
      expect(find.text('周一'), findsOneWidget);
      expect(find.text('Nov 2026'), findsNothing);
    });

    testWidgets('只配 locale 不配 supportedLocales 还是英文', (tester) async {
      // 顺带确认 README 的另一个坑：delegates 不配，debug 下会报
      // 「not supported by all of its localization delegates」。
      final void Function(FlutterErrorDetails)? onError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {};
      addTearDown(() => FlutterError.onError = onError);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          home: Scaffold(
            body: Center(child: CalendarPanel(month: DateTime(2026, 11))),
          ),
        ),
      );

      // 解析时退回默认的 [en_US]：README 里特意提醒过的那个坑。
      expect(find.text('Nov 2026'), findsOneWidget);
    });

    testWidgets('自定义 CalendarLabels 覆盖年月与年份', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CalendarPanel(
                month: DateTime(2026, 11),
                labels: const _JapaneseLabels(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('2026年11月'), findsOneWidget);
      expect(find.text('月'), findsOneWidget);
      expect(find.text('日'), findsOneWidget);
    });

    testWidgets('Sunday 开头时星期表头跟着转', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: DateTime(2026, 11),
            labels: CalendarLabels.zh,
            weekStartsOnMonday: false,
          ),
        ),
      );

      final Rect sun = tester.getRect(find.text('周日'));
      final Rect mon = tester.getRect(find.text('周一'));
      expect(sun.left, lessThan(mon.left), reason: '周日应该在周一左边');
    });

    testWidgets('样式覆盖：宽度 / 格子高度 / 翻月按钮', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: DateTime(2026, 11),
            labels: CalendarLabels.zh,
            style: const CalendarStyle(
              width: 320,
              cellHeight: 36,
              navButtonSize: Size(36, 36),
              navIconSize: 24,
            ),
          ),
        ),
      );

      expect(tester.getRect(find.byKey(kCalendarPanelKey)).width, 320);
      expect(
        tester.getSize(find.byKey(calendarDayKey(DateTime(2026, 11, 1)))).height,
        36,
      );

      final Finder nav = find.byType(IconButton);
      expect(nav, findsNWidgets(2));
      expect(tester.getSize(nav.first), const Size(36, 36));
      expect(tester.widget<Icon>(find.byIcon(Icons.chevron_left)).size, 24);
    });
  });

  group('CalendarDateField', () {
    testWidgets('点击输入框弹面板，选择后回填并关闭', (tester) async {
      await _setSurface(tester, const Size(800, 900));
      DateTime? changed;
      await tester.pumpWidget(
        _wrap(
          CalendarDateField(
            label: 'Date',
            initialDate: DateTime(2026, 11, 25),
            onChanged: (DateTime date) => changed = date,
          ),
        ),
      );

      expect(find.text('Date'), findsOneWidget);
      expect(find.text('2026 / 11 / 25'), findsOneWidget);

      await tester.tap(find.text('2026 / 11 / 25'));
      await tester.pumpAndSettle();
      expect(find.byKey(kCalendarPanelKey), findsOneWidget);

      await tester.tap(find.byKey(calendarDayKey(DateTime(2026, 11, 18))));
      await tester.pumpAndSettle();
      expect(find.byKey(kCalendarPanelKey), findsNothing);
      expect(changed, DateTime(2026, 11, 18));
      expect(find.text('2026 / 11 / 18'), findsOneWidget);
    });

    testWidgets('formatDate 能换显示格式', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CalendarDateField(
            initialDate: DateTime(2026, 11, 25),
            formatDate: (DateTime d) => '${d.year}年${d.month}月${d.day}日',
          ),
        ),
      );

      expect(find.text('2026年11月25日'), findsOneWidget);
      expect(find.text('2026 / 11 / 25'), findsNothing);
    });

    testWidgets('没有值时显示占位文案', (tester) async {
      await tester.pumpWidget(
        _wrap(const CalendarDateField(label: 'Date', hint: '请选择日期')),
      );
      expect(find.text('请选择日期'), findsOneWidget);
    });
  });

  group('showDatePicker', () {
    testWidgets('按 placement 显示在按钮的上下左右', (tester) async {
      await _setSurface(tester, const Size(800, 900));

      for (final CalendarPlacement placement in CalendarPlacement.values) {
        final GlobalKey anchorKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (BuildContext context) => ElevatedButton(
                    key: anchorKey,
                    onPressed: () => showCalendarDatePicker(
                      context,
                      initialDate: DateTime(2026, 11, 25),
                      placement: placement,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final Rect anchor = tester.getRect(find.byKey(anchorKey));
        final Rect panel = tester.getRect(find.byKey(kCalendarPanelKey));
        switch (placement) {
          case CalendarPlacement.bottom:
            expect(
              panel.top,
              greaterThanOrEqualTo(anchor.bottom),
              reason: '下方弹窗应在按钮下面',
            );
          case CalendarPlacement.top:
            expect(
              panel.bottom,
              lessThanOrEqualTo(anchor.top),
              reason: '上方弹窗应在按钮上面',
            );
          case CalendarPlacement.right:
            expect(
              panel.left,
              greaterThanOrEqualTo(anchor.right),
              reason: '右侧弹窗应在按钮右边',
            );
          case CalendarPlacement.left:
            expect(
              panel.right,
              lessThanOrEqualTo(anchor.left),
              reason: '左侧弹窗应在按钮左边',
            );
        }
        expect(tester.takeException(), isNull);

        // 点空白处关闭，进入下一轮。
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
        expect(find.byKey(kCalendarPanelKey), findsNothing);
      }
    });

    testWidgets('选中日期后 Future 返回该日期', (tester) async {
      await _setSurface(tester, const Size(800, 900));
      DateTime? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (BuildContext context) => ElevatedButton(
                  onPressed: () async {
                    result = await showDatePicker(
                      context,
                      initialDate: DateTime(2026, 11, 25),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(calendarDayKey(DateTime(2026, 11, 9))));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 11, 9));
    });

    testWidgets('点外部关闭时返回 null', (tester) async {
      await _setSurface(tester, const Size(800, 900));
      DateTime? result;
      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (BuildContext context) => ElevatedButton(
                  onPressed: () async {
                    result = await showDatePicker(
                      context,
                      initialDate: DateTime(2026, 11, 25),
                    );
                    completed = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(result, isNull);
      expect(find.byKey(kCalendarPanelKey), findsNothing);
    });
  });
  group('鼠标样式', () {
    testWidgets('日期、标题、翻月按钮默认都是小手', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: DateTime(2026, 11),
            labels: CalendarLabels.zh,
          ),
        ),
      );

      expect(
        _cursorAt(tester, _dayCellText(DateTime(2026, 11, 10))),
        SystemMouseCursors.click,
      );
      // 邻月日期能点（点完翻月 + 选中），同样是手。
      expect(
        _cursorAt(tester, _dayCellText(DateTime(2026, 12, 1))),
        SystemMouseCursors.click,
      );
      expect(_cursorAt(tester, find.text('2026年11月')), SystemMouseCursors.click);
      expect(
        _cursorAt(tester, find.byIcon(Icons.chevron_left)),
        SystemMouseCursors.click,
      );
      expect(
        _cursorAt(tester, find.byIcon(Icons.chevron_right)),
        SystemMouseCursors.click,
      );
    });

    testWidgets('年份列表条目也是小手', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: DateTime(2026, 11),
            labels: CalendarLabels.zh,
          ),
        ),
      );

      await tester.tap(find.text('2026年11月'));
      await tester.pumpAndSettle();
      expect(
        _cursorAt(tester, find.text('2026年')),
        SystemMouseCursors.click,
      );
    });

    testWidgets('点不了的部分不给小手：范围外日期、到头的翻月按钮', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: DateTime(2026, 11),
            labels: CalendarLabels.zh,
            firstDate: DateTime(2026, 11, 5),
            lastDate: DateTime(2027, 3, 1),
          ),
        ),
      );

      // 范围外（1~4 号）不可点。
      expect(
        _cursorAt(tester, _dayCellText(DateTime(2026, 11, 1))),
        SystemMouseCursors.basic,
      );
      // 往前翻会翻到 10 月，出了范围；往后翻还在范围里。
      expect(
        _cursorAt(tester, find.byIcon(Icons.chevron_left)),
        SystemMouseCursors.basic,
      );
      expect(
        _cursorAt(tester, find.byIcon(Icons.chevron_right)),
        SystemMouseCursors.click,
      );
    });

    testWidgets('关掉 enableYearPicker 时标题不给小手', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: DateTime(2026, 11),
            labels: CalendarLabels.zh,
            enableYearPicker: false,
          ),
        ),
      );

      expect(
        _cursorAt(tester, find.text('2026年11月')),
        SystemMouseCursors.basic,
      );
    });

    testWidgets('style.mouseCursor 能整体换掉（比如换成箭头）', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CalendarPanel(
            month: DateTime(2026, 11),
            labels: CalendarLabels.zh,
            style: const CalendarStyle(mouseCursor: SystemMouseCursors.basic),
          ),
        ),
      );

      expect(
        _cursorAt(tester, _dayCellText(DateTime(2026, 11, 10))),
        SystemMouseCursors.basic,
      );
      expect(_cursorAt(tester, find.text('2026年11月')), SystemMouseCursors.basic);
    });

    testWidgets('CalendarDateField：可用时小手，禁用时不给', (tester) async {
      await tester.pumpWidget(
        _wrap(const CalendarDateField(label: 'Date', hint: '请选择日期')),
      );
      expect(
        _cursorAt(tester, find.text('请选择日期')),
        SystemMouseCursors.click,
      );

      await tester.pumpWidget(
        _wrap(
          const CalendarDateField(
            label: 'Date',
            hint: '请选择日期',
            enabled: false,
          ),
        ),
      );
      expect(
        _cursorAt(tester, find.text('请选择日期')),
        SystemMouseCursors.basic,
      );
    });

    testWidgets('CalendarDateField 也能自定义光标', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CalendarDateField(
            hint: '请选择日期',
            mouseCursor: SystemMouseCursors.grab,
          ),
        ),
      );
      expect(_cursorAt(tester, find.text('请选择日期')), SystemMouseCursors.grab);
    });
  });
}

/// README「加第三门语言」里那段示例的测试版。
class _JapaneseLabels extends CalendarLabels {
  const _JapaneseLabels();

  @override
  List<String> get weekdays =>
      const <String>['月', '火', '水', '木', '金', '土', '日'];

  @override
  String monthYear(int year, int month) => '$year年$month月';

  @override
  String year(int year) => '$year年';
}

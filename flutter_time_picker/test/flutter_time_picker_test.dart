import 'dart:math' as math;

import 'package:flutter_time_picker/flutter_time_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide showTimePicker;

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// 输入框里当前显示的文字（别用 `find.text`：表盘上也可能有一样的数字）。
String _fieldText(WidgetTester tester, Key key) {
  return tester.widget<TextField>(find.byKey(key)).controller!.text;
}

/// 外圈（分）上取点：落在 0.70 的分界之外。
const double _outer = 0.84;

/// 内圈（时）上取点：落在 0.70 的分界之内。
const double _inner = 0.50;

/// 表盘上某个方向的点：`degrees` 是表盘角度（0 = 12 点，顺时针），
/// `ratio` 是离圆心的半径比例（[_outer] 是分钟圈，[_inner] 是小时圈）。
Offset _dialPoint(
  WidgetTester tester, {
  required double degrees,
  double ratio = _outer,
}) {
  final Rect dial = tester.getRect(find.byKey(kTimeDialKey));
  final double radius = dial.width / 2 * ratio;
  final double rad = (degrees - 90) * math.pi / 180;
  return dial.center + Offset(math.cos(rad) * radius, math.sin(rad) * radius);
}

/// 包住 [finder] 的最近一层 [MouseRegion] 的解析后光标。
MouseCursor? _cursorAt(WidgetTester tester, Finder finder) {
  final Finder region = find
      .ancestor(of: finder, matching: find.byType(MouseRegion))
      .first;
  return tester.widget<MouseRegion>(region).cursor;
}

void main() {
  group('formatTimeOfDay', () {
    test('24 小时制补零', () {
      expect(formatTimeOfDay(const TimeOfDay(hour: 9, minute: 5)), '09:05');
      expect(formatTimeOfDay(const TimeOfDay(hour: 0, minute: 0)), '00:00');
      expect(formatTimeOfDay(const TimeOfDay(hour: 23, minute: 59)), '23:59');
    });

    test('12 小时制不补零，0 点写 12', () {
      expect(
        formatTimeOfDay(
          const TimeOfDay(hour: 0, minute: 30),
          use24HourFormat: false,
        ),
        '12:30',
      );
      expect(
        formatTimeOfDay(
          const TimeOfDay(hour: 13, minute: 5),
          use24HourFormat: false,
        ),
        '1:05',
      );
      expect(
        formatTimeOfDay(
          const TimeOfDay(hour: 12, minute: 0),
          use24HourFormat: false,
        ),
        '12:00',
      );
    });
  });

  group('TimePickerPanel', () {
    testWidgets('默认尺寸：宽 300、表盘 168，左边显示初始时间', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TimePickerPanel(
            initialTime: TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
          ),
        ),
      );

      expect(tester.getSize(find.byKey(kTimePickerPanelKey)).width, 300);
      expect(tester.getSize(find.byKey(kTimeDialKey)), const Size(168, 168));
      expect(_fieldText(tester, kTimePickerHourFieldKey), '09');
      expect(_fieldText(tester, kTimePickerMinuteFieldKey), '30');
      // 没传 onSubmit / onCancel 就不显示底部按钮（可以当普通面板嵌进布局）。
      expect(find.text('确定'), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('小时直接敲数字，分钟不动', (tester) async {
      TimeOfDay? last;
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
            onChanged: (TimeOfDay time) => last = time,
          ),
        ),
      );

      await tester.tap(find.byKey(kTimePickerHourFieldKey));
      await tester.pump();
      await tester.enterText(find.byKey(kTimePickerHourFieldKey), '18');
      await tester.pump();

      expect(_fieldText(tester, kTimePickerHourFieldKey), '18');
      expect(_fieldText(tester, kTimePickerMinuteFieldKey), '30');
      expect(last, const TimeOfDay(hour: 18, minute: 30));
    });

    testWidgets('分钟敲 5 不补零；敲 75 不生效，失焦后夹到 59', (tester) async {
      TimeOfDay? last;
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
            onChanged: (TimeOfDay time) => last = time,
          ),
        ),
      );

      await tester.tap(find.byKey(kTimePickerMinuteFieldKey));
      await tester.pump();
      await tester.enterText(find.byKey(kTimePickerMinuteFieldKey), '5');
      await tester.pump();
      expect(_fieldText(tester, kTimePickerMinuteFieldKey), '5');
      expect(last, const TimeOfDay(hour: 9, minute: 5));

      // 75 越界：先不打断输入，值保持 5。
      await tester.enterText(find.byKey(kTimePickerMinuteFieldKey), '75');
      await tester.pump();
      expect(last, const TimeOfDay(hour: 9, minute: 5));

      // 失焦时归一化。
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(_fieldText(tester, kTimePickerMinuteFieldKey), '59');
      expect(last, const TimeOfDay(hour: 9, minute: 59));
    });

    testWidgets('小时敲超范围的数字不会改值，失焦夹到 23', (tester) async {
      TimeOfDay? last;
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
            onChanged: (TimeOfDay time) => last = time,
          ),
        ),
      );

      await tester.tap(find.byKey(kTimePickerHourFieldKey));
      await tester.pump();
      await tester.enterText(find.byKey(kTimePickerHourFieldKey), '45');
      await tester.pump();
      expect(last, isNull, reason: '45 点不合法，先不动值');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(_fieldText(tester, kTimePickerHourFieldKey), '23');
      expect(last, const TimeOfDay(hour: 23, minute: 30));
    });

    testWidgets('内圈改时：3 点方向 → 3 点', (tester) async {
      TimeOfDay? last;
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
            onChanged: (TimeOfDay time) => last = time,
          ),
        ),
      );

      await tester.tapAt(_dialPoint(tester, degrees: 90, ratio: _inner));
      await tester.pump();

      expect(_fieldText(tester, kTimePickerHourFieldKey), '03');
      expect(last, const TimeOfDay(hour: 3, minute: 30));
    });

    testWidgets('外圈改分：3 点方向 → 15 分，小时不动', (tester) async {
      TimeOfDay? last;
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
            onChanged: (TimeOfDay time) => last = time,
          ),
        ),
      );

      // 不用先点分钟框：外圈本来就是分钟。
      await tester.tapAt(_dialPoint(tester, degrees: 90));
      await tester.pump();

      expect(_fieldText(tester, kTimePickerMinuteFieldKey), '15');
      expect(last, const TimeOfDay(hour: 9, minute: 15));
    });

    testWidgets('外圈不是只能选 5 的倍数：7 点方向 → 35 分', (tester) async {
      TimeOfDay? last;
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 0),
            labels: TimePickerLabels.zh,
            onChanged: (TimeOfDay time) => last = time,
          ),
        ),
      );

      await tester.tapAt(_dialPoint(tester, degrees: 210));
      await tester.pump();

      expect(last, const TimeOfDay(hour: 9, minute: 35));
      expect(_fieldText(tester, kTimePickerMinuteFieldKey), '35');
    });

    testWidgets('两圈连着点：先改分再改时，互不影响', (tester) async {
      TimeOfDay? last;
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
            onChanged: (TimeOfDay time) => last = time,
          ),
        ),
      );

      await tester.tapAt(_dialPoint(tester, degrees: 90));
      await tester.pump();
      expect(last, const TimeOfDay(hour: 9, minute: 15));

      await tester.tapAt(_dialPoint(tester, degrees: 180, ratio: _inner));
      await tester.pump();
      expect(last, const TimeOfDay(hour: 6, minute: 15));
    });

    testWidgets('在表盘上按住拖动，指针跟着走', (tester) async {
      TimeOfDay? last;
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
            onChanged: (TimeOfDay time) => last = time,
          ),
        ),
      );

      final TestGesture gesture = await tester.startGesture(
        _dialPoint(tester, degrees: 0),
      );
      // 单击的 onTapDown 要等 tap 识别器落定（kPressTimeout）才回调。
      await tester.pump(const Duration(milliseconds: 150));
      expect(last, const TimeOfDay(hour: 9, minute: 0));

      await gesture.moveTo(_dialPoint(tester, degrees: 120));
      await tester.pump();
      expect(last, const TimeOfDay(hour: 9, minute: 20));

      await gesture.up();
      await tester.pump();
    });

    testWidgets('拖动跨圈：外圈→内圈改时、再回外圈改分，mode 跟着切', (tester) async {
      TimeOfDay? last;
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
            onChanged: (TimeOfDay time) => last = time,
          ),
        ),
      );

      TimeDialMode modeOf() =>
          tester.widget<TimeDial>(find.byType(TimeDial)).mode;

      // 外圈 30° → 5 分，mode 是分。
      final TestGesture gesture = await tester.startGesture(
        _dialPoint(tester, degrees: 30),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(last, const TimeOfDay(hour: 9, minute: 5));
      expect(modeOf(), TimeDialMode.minute);

      // 手指滑到内圈 90°（= 3 点）→ 改小时，mode 跟着切到时。
      await gesture.moveTo(_dialPoint(tester, degrees: 90, ratio: _inner));
      await tester.pump();
      expect(last, const TimeOfDay(hour: 3, minute: 5));
      expect(modeOf(), TimeDialMode.hour);

      // 再滑回外圈 180°（= 30 分）→ 改分钟，mode 又切回分。
      await gesture.moveTo(_dialPoint(tester, degrees: 180));
      await tester.pump();
      expect(last, const TimeOfDay(hour: 3, minute: 30));
      expect(modeOf(), TimeDialMode.minute);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('24 小时制：内圈点 12 / 1，上下午决定 00 还是 12、13', (tester) async {
      TimeOfDay? last;
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 0),
            labels: TimePickerLabels.zh,
            onChanged: (TimeOfDay time) => last = time,
          ),
        ),
      );

      // 上午点内圈 12 点方向 → 00 点。
      await tester.tapAt(_dialPoint(tester, degrees: 0, ratio: _inner));
      await tester.pump();
      expect(last, const TimeOfDay(hour: 0, minute: 0));
      expect(_fieldText(tester, kTimePickerHourFieldKey), '00');

      // 切到下午：同一格就是 12 点。
      await tester.tap(find.text('下午'));
      await tester.pump();
      expect(last, const TimeOfDay(hour: 12, minute: 0));
      expect(_fieldText(tester, kTimePickerHourFieldKey), '12');

      // 内圈 1 点方向 → 13 点。
      await tester.tapAt(_dialPoint(tester, degrees: 30, ratio: _inner));
      await tester.pump();
      expect(last, const TimeOfDay(hour: 13, minute: 0));
      expect(_fieldText(tester, kTimePickerHourFieldKey), '13');
    });

    testWidgets('12 小时制：显示上午 / 下午，点下午把小时 +12', (tester) async {
      TimeOfDay? last;
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
            use24HourFormat: false,
            onChanged: (TimeOfDay time) => last = time,
          ),
        ),
      );

      expect(find.text('上午'), findsOneWidget);
      expect(find.text('下午'), findsOneWidget);
      expect(_fieldText(tester, kTimePickerHourFieldKey), '09');

      await tester.tap(find.text('下午'));
      await tester.pump();
      expect(last, const TimeOfDay(hour: 21, minute: 30));
      // 12 小时制下小时框还是 09，靠上下午区分。
      expect(_fieldText(tester, kTimePickerHourFieldKey), '09');

      // 表盘内圈只给 1..12，面板自己补上下午。
      await tester.tapAt(_dialPoint(tester, degrees: 30, ratio: _inner));
      await tester.pump();
      expect(last?.hour, 13);
      expect(_fieldText(tester, kTimePickerHourFieldKey), '01');
    });

    testWidgets('上午 / 下午切换：主色滑块整段平移', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
            onCancel: () {},
            onSubmit: (_) {},
          ),
        ),
      );

      // 滑块是上下午容器里唯一的 AnimatedPositioned。
      AnimatedPositioned slider() => tester.widget<AnimatedPositioned>(
            find.byType(AnimatedPositioned),
          );
      expect(slider().left, 2); // 上午：贴左边

      await tester.tap(find.text('下午'));
      // 不 settle：动画进行中，left 正向右移（200ms 的目标在 42）。
      await tester.pump(const Duration(milliseconds: 40));
      expect(slider().left, greaterThan(2));
      await tester.pumpAndSettle();
      expect(slider().left, 42); // 下午：右半段
    });

    testWidgets('12 小时制敲 0 或 13 都不改值', (tester) async {
      TimeOfDay? last;
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 0),
            labels: TimePickerLabels.zh,
            use24HourFormat: false,
            onChanged: (TimeOfDay time) => last = time,
          ),
        ),
      );

      await tester.tap(find.byKey(kTimePickerHourFieldKey));
      await tester.pump();
      await tester.enterText(find.byKey(kTimePickerHourFieldKey), '0');
      await tester.pump();
      expect(last, isNull);

      await tester.enterText(find.byKey(kTimePickerHourFieldKey), '13');
      await tester.pump();
      expect(last, isNull);
    });

    testWidgets('确定拿到当前值，取消只回调', (tester) async {
      TimeOfDay? submitted;
      bool cancelled = false;
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
            onCancel: () => cancelled = true,
            onSubmit: (TimeOfDay time) => submitted = time,
          ),
        ),
      );

      expect(find.text('取消'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pump();
      expect(cancelled, isTrue);
      expect(submitted, isNull);

      await tester.tapAt(_dialPoint(tester, degrees: 180, ratio: _inner));
      await tester.pump();
      await tester.tap(find.text('确定'));
      await tester.pump();
      expect(submitted, const TimeOfDay(hour: 6, minute: 30));
    });

    testWidgets('配了 locale + supportedLocales + delegates 就用中文', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: TimePickerPanel(
              initialTime: const TimeOfDay(hour: 9, minute: 30),
              use24HourFormat: false,
              onCancel: () {},
              onSubmit: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('上午'), findsOneWidget);
      expect(find.text('下午'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确定'), findsOneWidget);
      expect(find.text('AM'), findsNothing);
    });

    testWidgets('只配 locale 不配 supportedLocales 则回退英文', (tester) async {
      // 缺 delegates 时 debug 会报 locale 不被支持，教程里提过这个坑。
      final void Function(FlutterErrorDetails)? prev = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {};
      addTearDown(() => FlutterError.onError = prev);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          home: Scaffold(
            body: TimePickerPanel(
              initialTime: const TimeOfDay(hour: 9, minute: 30),
              use24HourFormat: false,
              onCancel: () {},
              onSubmit: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('AM'), findsOneWidget);
      expect(find.text('PM'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('上午'), findsNothing);
    });

    testWidgets('自定义 labels 覆盖六处文案', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimePickerPanel(
            initialTime: const TimeOfDay(hour: 9, minute: 30),
            labels: const _JapaneseTimeLabels(),
            use24HourFormat: false,
            onCancel: () {},
            onSubmit: (_) {},
          ),
        ),
      );

      expect(find.text('午前'), findsOneWidget);
      expect(find.text('午後'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    test('resolve 只认 en，其它都是中文', () {
      expect(TimePickerLabels.resolve(const Locale('en')), TimePickerLabels.en);
      expect(TimePickerLabels.resolve(const Locale('en', 'US')), TimePickerLabels.en);
      expect(TimePickerLabels.resolve(const Locale('zh')), TimePickerLabels.zh);
      expect(TimePickerLabels.resolve(const Locale('ja')), TimePickerLabels.zh);
      expect(TimePickerLabels.resolve(null), TimePickerLabels.zh);
    });

    testWidgets('底部按钮字重是 normal，样式可覆盖', (tester) async {
      Future<void> check(TimePickerStyle? style, FontWeight expected) async {
        await tester.pumpWidget(
          _wrap(
            TimePickerPanel(
              initialTime: const TimeOfDay(hour: 9, minute: 30),
              labels: TimePickerLabels.zh,
              style: style ?? const TimePickerStyle(),
              onCancel: () {},
              onSubmit: (_) {},
            ),
          ),
        );
        final ButtonStyle cancelStyle =
            tester.widget<TextButton>(find.byType(TextButton)).style!;
        final TextStyle? text = cancelStyle.textStyle?.resolve(<WidgetState>{});
        expect(text?.fontWeight, expected);
      }

      await check(null, FontWeight.normal);
      await check(
        const TimePickerStyle(
          actionTextStyle: TextStyle(fontWeight: FontWeight.w700),
        ),
        FontWeight.w700,
      );
    });

    testWidgets('样式覆盖：宽度 / 表盘大小 / 字号', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TimePickerPanel(
            initialTime: TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
            style: TimePickerStyle(
              width: 340,
              dialSize: 200,
              timeTextStyle: TextStyle(fontSize: 24),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(kTimePickerPanelKey)).width, 340);
      expect(tester.getSize(find.byKey(kTimeDialKey)), const Size(200, 200));
      final TextField hour = tester.widget<TextField>(
        find.byKey(kTimePickerHourFieldKey),
      );
      expect(hour.style?.fontSize, 24);
    });

    testWidgets('光标：表盘是手，输入框是文本光标', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TimePickerPanel(
            initialTime: TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
          ),
        ),
      );

      final Finder dial = find.descendant(
        of: find.byKey(kTimeDialKey),
        matching: find.byType(MouseRegion),
      );
      expect(
        tester.widget<MouseRegion>(dial.first).cursor,
        SystemMouseCursors.click,
      );
      expect(
        _cursorAt(
          tester,
          find.descendant(
            of: find.byKey(kTimePickerHourFieldKey),
            matching: find.byType(EditableText),
          ),
        ),
        SystemMouseCursors.text,
      );
    });

    testWidgets('切换制式不会把用户选的分钟冲掉', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TimePickerPanel(
            initialTime: TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
          ),
        ),
      );
      await tester.tapAt(_dialPoint(tester, degrees: 90, ratio: _inner));
      await tester.pump();
      expect(_fieldText(tester, kTimePickerHourFieldKey), '03');

      // 同一个 initialTime，只是换了制式：选过的 3 点要留着。
      await tester.pumpWidget(
        _wrap(
          const TimePickerPanel(
            initialTime: TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
            use24HourFormat: false,
          ),
        ),
      );
      expect(_fieldText(tester, kTimePickerHourFieldKey), '03');
      expect(_fieldText(tester, kTimePickerMinuteFieldKey), '30');
    });

    testWidgets('切换 use24HourFormat 时输入框跟着改格式', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TimePickerPanel(
            initialTime: TimeOfDay(hour: 21, minute: 5),
            labels: TimePickerLabels.zh,
          ),
        ),
      );
      expect(_fieldText(tester, kTimePickerHourFieldKey), '21');

      await tester.pumpWidget(
        _wrap(
          const TimePickerPanel(
            initialTime: TimeOfDay(hour: 21, minute: 5),
            labels: TimePickerLabels.zh,
            use24HourFormat: false,
          ),
        ),
      );
      expect(_fieldText(tester, kTimePickerHourFieldKey), '09');
      expect(find.text('下午'), findsOneWidget);
    });
  });

  group('showTimePicker', () {
    testWidgets('弹在锚点下方，确定后 Future 返回该时间', (tester) async {
      await _setSurface(tester, const Size(800, 900));
      TimeOfDay? result;
      final GlobalKey anchorKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (BuildContext context) => ElevatedButton(
                  key: anchorKey,
                  onPressed: () async {
                    result = await showTimePicker(
                      context,
                      initialTime: const TimeOfDay(hour: 9, minute: 30),
                      labels: TimePickerLabels.zh,
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
      expect(find.byKey(kTimePickerPanelKey), findsOneWidget);

      final Rect anchor = tester.getRect(find.byKey(anchorKey));
      final Rect panel = tester.getRect(find.byKey(kTimePickerPanelKey));
      expect(panel.top, greaterThanOrEqualTo(anchor.bottom));

      await tester.tapAt(_dialPoint(tester, degrees: 90, ratio: _inner));
      await tester.pump();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(find.byKey(kTimePickerPanelKey), findsNothing);
      expect(result, const TimeOfDay(hour: 3, minute: 30));
    });

    testWidgets('按 placement 显示在按钮上下左右', (tester) async {
      await _setSurface(tester, const Size(800, 900));

      for (final TimePickerPlacement placement in TimePickerPlacement.values) {
        final GlobalKey anchorKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (BuildContext context) => ElevatedButton(
                    key: anchorKey,
                    onPressed: () => showCompactTimePicker(
                      context,
                      initialTime: const TimeOfDay(hour: 9, minute: 30),
                      placement: placement,
                      labels: TimePickerLabels.zh,
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
        final Rect panel = tester.getRect(find.byKey(kTimePickerPanelKey));
        switch (placement) {
          case TimePickerPlacement.bottom:
            expect(panel.top, greaterThanOrEqualTo(anchor.bottom));
          case TimePickerPlacement.top:
            expect(panel.bottom, lessThanOrEqualTo(anchor.top));
          case TimePickerPlacement.right:
            expect(panel.left, greaterThanOrEqualTo(anchor.right));
          case TimePickerPlacement.left:
            expect(panel.right, lessThanOrEqualTo(anchor.left));
        }
        expect(tester.takeException(), isNull);

        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
        expect(find.byKey(kTimePickerPanelKey), findsNothing);
      }
    });

    testWidgets('点取消返回 null', (tester) async {
      await _setSurface(tester, const Size(800, 900));
      TimeOfDay? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (BuildContext context) => ElevatedButton(
                  onPressed: () async {
                    result = await showTimePicker(
                      context,
                      initialTime: const TimeOfDay(hour: 9, minute: 30),
                      labels: TimePickerLabels.zh,
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
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  group('TimePickerField', () {
    testWidgets('点击输入框弹面板，确定后回填并关闭', (tester) async {
      await _setSurface(tester, const Size(900, 900));
      TimeOfDay? changed;
      await tester.pumpWidget(
        _wrap(
          TimePickerField(
            label: '时间',
            initialTime: const TimeOfDay(hour: 9, minute: 30),
            labels: TimePickerLabels.zh,
            onChanged: (TimeOfDay time) => changed = time,
          ),
        ),
      );

      expect(find.text('时间'), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);

      await tester.tap(find.text('09:30'));
      await tester.pumpAndSettle();
      expect(find.byKey(kTimePickerPanelKey), findsOneWidget);

      // 内圈 9 点方向 + 下午 = 21 点。
      await tester.tapAt(_dialPoint(tester, degrees: 270, ratio: _inner));
      await tester.pump();
      await tester.tap(find.text('下午'));
      await tester.pump();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(find.byKey(kTimePickerPanelKey), findsNothing);
      expect(changed, const TimeOfDay(hour: 21, minute: 30));
      expect(find.text('21:30'), findsOneWidget);
    });

    testWidgets('12 小时制显示带上午 / 下午', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TimePickerField(
            initialTime: TimeOfDay(hour: 21, minute: 5),
            labels: TimePickerLabels.zh,
            use24HourFormat: false,
          ),
        ),
      );
      expect(find.text('下午 9:05'), findsOneWidget);
    });

    testWidgets('没有值时显示占位文案', (tester) async {
      await tester.pumpWidget(_wrap(const TimePickerField(hint: '请选择时间')));
      expect(find.text('请选择时间'), findsOneWidget);
    });

    testWidgets('光标：可用时小手，禁用时不给', (tester) async {
      await tester.pumpWidget(_wrap(const TimePickerField(hint: '请选择时间')));
      expect(_cursorAt(tester, find.text('请选择时间')), SystemMouseCursors.click);

      await tester.pumpWidget(
        _wrap(const TimePickerField(hint: '请选择时间', enabled: false)),
      );
      expect(_cursorAt(tester, find.text('请选择时间')), SystemMouseCursors.basic);
    });
  });
}


/// README「加第三门语言」里那段示例的测试版。
class _JapaneseTimeLabels extends TimePickerLabels {
  const _JapaneseTimeLabels();

  @override
  String get am => '午前';
  @override
  String get pm => '午後';
  @override
  String get hour => '時';
  @override
  String get minute => '分';
  @override
  String get cancel => 'キャンセル';
  @override
  String get confirm => 'OK';
}

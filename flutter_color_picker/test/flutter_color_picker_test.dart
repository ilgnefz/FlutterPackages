import 'package:flutter_color_picker/flutter_color_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const Key _satValKey = ValueKey<String>('color-picker-sat-val');
const Key _hueKey = ValueKey<String>('color-picker-hue');
const Key _alphaKey = ValueKey<String>('color-picker-alpha');
const Key _hexKey = ValueKey<String>('color-picker-hex');
const Key _alphaLabelKey = ValueKey<String>('color-picker-alpha-label');
const Key _previewKey = ValueKey<String>('color-picker-preview');

/// 面板里当前的色值（直接读左下角预览圆点的填充）。
Color _currentColor(WidgetTester tester) {
  final Container box = tester.widget<Container>(find.byKey(_previewKey));
  return (box.decoration! as BoxDecoration).color!;
}

/// 输入框里现在的文本。
String _hexText(WidgetTester tester) {
  final TextField field = tester.widget<TextField>(find.byKey(_hexKey));
  return field.controller!.text;
}

/// 输入框里的选区。
TextSelection _hexSelection(WidgetTester tester) {
  final TextField field = tester.widget<TextField>(find.byKey(_hexKey));
  return field.controller!.selection;
}

/// 输入框右边那个透明度读数。
String _alphaText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(_alphaLabelKey)).data!;

Rect _rectOf(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: child),
    ),
  );
}

void main() {
  testWidgets('初始渲染：显示初始色的 hex 与预览', (tester) async {
    await tester.pumpWidget(_host(const ColorPicker()));

    expect(_hexText(tester), '#2B7FFF');
    expect(_currentColor(tester), const Color(0xFF2B7FFF));
    expect(find.byKey(_satValKey), findsOneWidget);
    expect(find.byKey(_hueKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点面板左上角得白色、右下角得黑色', (tester) async {
    final List<int> changed = <int>[];
    await tester.pumpWidget(_host(ColorPicker(onChanged: changed.add)));

    final Rect panel = _rectOf(tester, _satValKey);
    // 贴着角点（但不落在边界上，边界不参与命中测试）。
    await tester.tapAt(panel.topLeft + const Offset(0.5, 0.5));
    await tester.pump();
    Color color = _currentColor(tester);
    expect(color.r * 255, greaterThan(250));
    expect(color.g * 255, greaterThan(250));
    expect(color.b * 255, greaterThan(250));
    expect(changed, isNotEmpty);

    await tester.tapAt(panel.bottomRight - const Offset(0.5, 0.5));
    await tester.pump();
    color = _currentColor(tester);
    expect(color.r * 255, lessThan(5));
    expect(color.g * 255, lessThan(5));
    expect(color.b * 255, lessThan(5));
    expect(changed, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动面板时按帧回调 onChanged，松手回调 onChangeEnd', (tester) async {
    final List<int> changing = <int>[];
    final List<int> ended = <int>[];
    await tester.pumpWidget(
      _host(ColorPicker(onChanged: changing.add, onChangeEnd: ended.add)),
    );

    final Rect panel = _rectOf(tester, _satValKey);
    final TestGesture gesture = await tester.startGesture(panel.center);
    await tester.pump();
    expect(changing, hasLength(1));

    await gesture.moveTo(panel.center + const Offset(-40, 30));
    await tester.pump();
    expect(changing.length, greaterThan(1));
    expect(ended, isEmpty, reason: '松手前不该发 onChangeEnd');

    await gesture.up();
    await tester.pump();
    expect(ended, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动跟手：按下就生效，拖到面板外面也继续跟着走', (tester) async {
    final List<int> changing = <int>[];
    final List<int> ended = <int>[];
    await tester.pumpWidget(
      _host(ColorPicker(onChanged: changing.add, onChangeEnd: ended.add)),
    );

    final Rect panel = _rectOf(tester, _satValKey);
    final TestGesture gesture = await tester.startGesture(panel.center);
    await tester.pump();
    expect(changing, hasLength(1), reason: '按下即生效，不等拖动阈值');

    // 拖到面板右下角的**外面**：仍要按指针位置更新（夹到纯黑），
    // 不是等松手才一次性跳过去。
    await gesture.moveTo(panel.bottomRight + const Offset(80, 80));
    await tester.pump();
    expect(changing, hasLength(2));
    expect(changing.last, 0xFF000000, reason: '超出右下角 → s=1,v=0');

    await gesture.up();
    await tester.pump();
    expect(ended, hasLength(1), reason: '拖出边界也一样，松手才发 onChangeEnd');
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动跟手：面板放在竖向列表里也不被滚动手势吞掉', (tester) async {
    final List<int> changing = <int>[];
    await tester.pumpWidget(
      _host(
        SizedBox(
          height: 420,
          child: ListView(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(24),
                child: ColorPicker(onChanged: changing.add),
              ),
            ],
          ),
        ),
      ),
    );

    final Rect panel = _rectOf(tester, _satValKey);
    final TestGesture gesture = await tester.startGesture(panel.center);
    await tester.pump();
    expect(changing, hasLength(1));

    // 竖直方向拖（正是 Scrollable 会抢的方向）。
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    expect(changing, hasLength(2), reason: '竖直拖动也要跟手');

    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    expect(changing, hasLength(3));

    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('点色相条中点：色相回到青色，颜色仍是全饱和', (tester) async {
    final List<int> changed = <int>[];
    await tester.pumpWidget(_host(ColorPicker(onChanged: changed.add)));

    final Rect bar = _rectOf(tester, _hueKey);
    // 中点 → hue = 180（青）。饱和度 / 明度沿用当前值（#2B7FFF 约 83%）,
    // 所以不是纯青，但绿 + 蓝必须拉满、红明显低于它们。
    await tester.tapAt(bar.center);
    await tester.pump();

    final Color color = _currentColor(tester);
    expect(color.g * 255, greaterThan(245));
    expect(color.b * 255, greaterThan(245));
    expect(color.r * 255, lessThan(80));
    expect(changed, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hex 输入提交：颜色跟着变，并回调 onChangeEnd', (tester) async {
    final List<int> ended = <int>[];
    await tester.pumpWidget(_host(ColorPicker(onChangeEnd: ended.add)));

    await tester.enterText(find.byKey(_hexKey), '#00ff00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(_currentColor(tester), const Color(0xFF00FF00));
    expect(ended.last, 0xFF00FF00, reason: '回调参数是 0xAARRGGBB 的 int');
    // 提交后统一成大写。
    expect(_hexText(tester), '#00FF00');
    expect(tester.takeException(), isNull);
  });

  testWidgets('回调参数就是 0xAARRGGBB 的 int，Color(argb) 能还原', (tester) async {
    final List<int> changing = <int>[];
    final List<int> ended = <int>[];
    await tester.pumpWidget(
      _host(ColorPicker(onChanged: changing.add, onChangeEnd: ended.add)),
    );

    // 面板里输入 0x 写法，提交后两个回调都该拿到同一个 int。
    await tester.enterText(find.byKey(_hexKey), '0xFF00FF00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(changing, isNotEmpty);
    expect(changing.last, 0xFF00FF00);
    expect(ended.single, 0xFF00FF00);
    expect(ended.single, const Color(0xFF00FF00).toARGB32());
    expect(Color(ended.single), const Color(0xFF00FF00));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hex 输入非法：恢复成当前颜色，不回调', (tester) async {
    final List<int> ended = <int>[];
    await tester.pumpWidget(_host(ColorPicker(onChangeEnd: ended.add)));

    await tester.enterText(find.byKey(_hexKey), '#12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(_currentColor(tester), const Color(0xFF2B7FFF));
    expect(_hexText(tester), '#2B7FFF');
    expect(ended, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('受控：外部换 value 时指针与 hex 跟上', (tester) async {
    await tester.pumpWidget(_host(const ColorPicker(value: Color(0xFF2B7FFF))));
    expect(_hexText(tester), '#2B7FFF');

    await tester.pumpWidget(_host(const ColorPicker(value: Color(0xFFFF0000))));
    await tester.pump();
    expect(_hexText(tester), '#FF0000');
    expect(_currentColor(tester), const Color(0xFFFF0000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('纯黑 / 纯灰不会把色相条拽回红色', (tester) async {
    // 先拖到蓝色区域，再把明度拖到底 → 纯黑。
    await tester.pumpWidget(_host(const ColorPicker()));
    final Rect panel = _rectOf(tester, _satValKey);
    await tester.tapAt(panel.bottomRight - const Offset(0.5, 0.5));
    await tester.pump();
    Color black = _currentColor(tester);
    expect(black.r * 255, lessThan(3));
    expect(black.g * 255, lessThan(3));
    expect(black.b * 255, lessThan(3));

    // 再往右上方拖一点：如果 hue 被 Color 换算丢了，这里会得到红色。
    await tester.tapAt(
      Offset(panel.right - 0.5, panel.top + panel.height * 0.5),
    );
    await tester.pump();
    // 明度只剩一半，所以不是亮蓝；关键是「蓝 > 绿 > 红」——要是 hue 被
    // 丢成 0，这里会变成红 > 绿 > 蓝。
    final Color color = _currentColor(tester);
    expect(color.b * 255, greaterThan(100), reason: '应该还是蓝色系');
    expect(color.b * 255, greaterThan(color.g * 255));
    expect(color.g * 255, greaterThan(color.r * 255));
    expect(color.r * 255, lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('禁用时不响应手势', (tester) async {
    final List<int> changed = <int>[];
    await tester.pumpWidget(
      _host(ColorPicker(enabled: false, onChanged: changed.add)),
    );

    final Rect panel = _rectOf(tester, _satValKey);
    await tester.tapAt(panel.center);
    await tester.pump();
    expect(changed, isEmpty);
    expect(_currentColor(tester), const Color(0xFF2B7FFF));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ColorPickerButton：点色块弹面板，选色回传', (tester) async {
    final List<int> changed = <int>[];
    await tester.pumpWidget(
      _host(
        Center(
          child: ColorPickerButton(
            initialColor: const Color(0xFF2B7FFF),
            onChanged: changed.add,
          ),
        ),
      ),
    );
    expect(find.byType(ColorPicker), findsNothing);

    await tester.tap(find.byType(ColorPickerButton));
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsOneWidget);

    final Rect panel = _rectOf(tester, _satValKey);
    await tester.tapAt(panel.bottomRight - const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(changed, isNotEmpty);
    expect(Color(changed.last).r * 255, lessThan(5));
    expect(tester.takeException(), isNull);
  });

  // ── 弹层（PopoverHost，本包自带） ──────────────────────────────────────

  testWidgets('弹层：点空白处收起', (tester) async {
    await tester.pumpWidget(_host(const ColorPickerButton()));
    await tester.tap(find.byType(ColorPickerButton));
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsOneWidget);

    // 面板之外的地方（barrier 覆盖全屏）。
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('弹层：Esc 收起', (tester) async {
    await tester.pumpWidget(_host(const ColorPickerButton()));
    await tester.tap(find.byType(ColorPickerButton));
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('弹层：再点触发器等于是点空白，收起', (tester) async {
    await tester.pumpWidget(_host(const ColorPickerButton()));
    await tester.tap(find.byType(ColorPickerButton));
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsOneWidget);

    // barrier 盖住触发器，点下去命中的是它，效果同样是「点外面收起」。
    await tester.tapAt(tester.getCenter(find.byType(ColorPickerButton)));
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('弹层：下方放不下时自动翻到触发器上方', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: const ColorPickerButton(),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ColorPickerButton));
    await tester.pumpAndSettle();

    final Rect panel = tester.getRect(find.byType(ColorPicker));
    final Rect trigger = tester.getRect(find.byType(ColorPickerButton));
    expect(panel.bottom, lessThanOrEqualTo(trigger.top), reason: '翻到上方');
    expect(panel.top, greaterThanOrEqualTo(0), reason: '不能超出屏幕');
    expect(tester.takeException(), isNull);
  });

  test('colorToHex / parseHexColor 互转', () {
    expect(colorToHex(const Color(0xFF2B7FFF)), '#2B7FFF');
    expect(
      colorToHex(const Color(0x992B7FFF)),
      '#2B7FFF',
      reason: 'alpha 不进 hex',
    );
    expect(
      colorToHex(const Color(0xFF2B7FFF), format: ColorHexFormat.flutterArgb),
      '0xFF2B7FFF',
    );
    expect(parseHexColor('#2b7fff'), const Color(0xFF2B7FFF));
    expect(parseHexColor('2b7fff'), const Color(0xFF2B7FFF));
    expect(parseHexColor('#fff'), const Color(0xFFFFFFFF));
    expect(
      parseHexColor('#2B7FFF80'),
      const Color(0xFF2B7FFF),
      reason: '只取 RGB',
    );
    expect(parseHexColor('#12'), isNull);
    expect(parseHexColor(''), isNull);
  });

  test('parseHexColor 认 Flutter 的 0x 写法（6 / 8 位都只取 RGB）', () {
    expect(parseHexColor('0xFF2B7FFF'), const Color(0xFF2B7FFF));
    expect(parseHexColor('0X2b7fff'), const Color(0xFF2B7FFF));
    expect(parseHexColor('0x2B7FFF'), const Color(0xFF2B7FFF));
    expect(
      parseHexColor('0x802B7FFF'),
      const Color(0xFF2B7FFF),
      reason: '0xAARRGGBB 的 alpha 丢掉',
    );
    expect(parseHexColor('0xFF12'), isNull);
    expect(parseHexColor('0x'), isNull);
  });

  // ── hex 显示格式 ────────────────────────────────────────────────────────

  testWidgets('hexFormat.flutterArgb：显示 0xFFRRGGBB，0x 与 # 写法都能输', (
    tester,
  ) async {
    final List<int> ended = <int>[];
    await tester.pumpWidget(
      _host(
        ColorPicker(
          hexFormat: ColorHexFormat.flutterArgb,
          onChangeEnd: ended.add,
        ),
      ),
    );
    expect(_hexText(tester), '0xFF2B7FFF');

    await tester.enterText(find.byKey(_hexKey), '0xFF00FF00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_currentColor(tester), const Color(0xFF00FF00));
    expect(_hexText(tester), '0xFF00FF00');
    expect(ended.last, 0xFF00FF00, reason: '回调参数是 0xAARRGGBB 的 int');

    // 六位 0xRRGGBB 也认，提交后按当前格式归一。
    await tester.enterText(find.byKey(_hexKey), '0x0000ff');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_currentColor(tester), const Color(0xFF0000FF));
    expect(_hexText(tester), '0xFF0000FF');

    // 换个写法（#RRGGBB）依旧能用。
    await tester.enterText(find.byKey(_hexKey), '#ff0000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_currentColor(tester), const Color(0xFFFF0000));
    expect(_hexText(tester), '0xFFFF0000');
    expect(tester.takeException(), isNull);
  });

  testWidgets('hexFormat 切换后输入框按新写法重写，不触发回调', (tester) async {
    await tester.pumpWidget(_host(const ColorPicker()));
    expect(_hexText(tester), '#2B7FFF');

    await tester.pumpWidget(
      _host(const ColorPicker(hexFormat: ColorHexFormat.flutterArgb)),
    );
    await tester.pump();
    expect(_hexText(tester), '0xFF2B7FFF');
    expect(tester.takeException(), isNull);
  });

  testWidgets('同一颜色的另一种写法提交时只归一文本，不发 onChangeEnd', (tester) async {
    final List<int> ended = <int>[];
    await tester.pumpWidget(_host(ColorPicker(onChangeEnd: ended.add)));

    await tester.enterText(find.byKey(_hexKey), '0xFF2B7FFF');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(ended, isEmpty);
    expect(_hexText(tester), '#2B7FFF');
    expect(tester.takeException(), isNull);
  });

  // ── 鼠标指针 ────────────────────────────────────────────────────────────

  testWidgets('ColorPickerButton.mouseCursor 覆盖默认手型，不传时是 click', (
    tester,
  ) async {
    MouseCursor? triggerCursor() => tester
        .widget<MouseRegion>(
          find
              .descendant(
                of: find.byType(ColorPickerButton),
                matching: find.byType(MouseRegion),
              )
              .first,
        )
        .cursor;

    await tester.pumpWidget(
      _host(const ColorPickerButton(mouseCursor: SystemMouseCursors.grab)),
    );
    expect(triggerCursor(), SystemMouseCursors.grab);

    await tester.pumpWidget(_host(const ColorPickerButton()));
    await tester.pump();
    expect(triggerCursor(), SystemMouseCursors.click);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ColorPicker.mouseCursor 作用在面板与色相条上', (tester) async {
    await tester.pumpWidget(
      _host(const ColorPicker(mouseCursor: SystemMouseCursors.precise)),
    );
    final MouseRegion region = tester.widget<MouseRegion>(
      find
          .ancestor(
            of: find.byKey(_satValKey),
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    expect(region.cursor, SystemMouseCursors.precise);
    expect(tester.takeException(), isNull);
  });

  // ── 命令式弹出：自己的按钮调面板 ────────────────────────────────────────

  testWidgets('showColorPicker：自定义按钮调出面板，选色回传，句柄能关', (tester) async {
    const Key ownButton = ValueKey<String>('own-button');
    final List<int> changed = <int>[];
    ColorPickerPopup? popup;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // 贴顶部放：下方有足够空间，验证「默认从按钮下方弹出」。
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Builder(
                builder: (BuildContext context) => IconButton(
                  key: ownButton,
                  icon: const Icon(Icons.palette_outlined),
                  onPressed: () {
                    popup = showColorPicker(
                      context,
                      color: const Color(0xFF2B7FFF),
                      onChanged: changed.add,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(ColorPicker), findsNothing);

    await tester.tap(find.byKey(ownButton));
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsOneWidget);
    expect(popup!.isOpen, isTrue);

    // 默认在按钮下方弹出。
    final Rect panel = tester.getRect(find.byType(ColorPicker));
    final Rect anchor = tester.getRect(find.byKey(ownButton));
    expect(panel.top, greaterThanOrEqualTo(anchor.bottom));

    await tester.tapAt(
      _rectOf(tester, _satValKey).bottomRight - const Offset(0.5, 0.5),
    );
    await tester.pumpAndSettle();
    expect(changed, isNotEmpty);
    expect(Color(changed.last).r * 255, lessThan(5));

    popup!.close();
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsNothing);
    expect(popup!.isOpen, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showColorPicker：同时只留一个弹层，点空白收起', (tester) async {
    const Key ownButton = ValueKey<String>('own-button');
    BuildContext? anchorContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (BuildContext context) {
                anchorContext = context;
                return const IconButton(
                  key: ownButton,
                  icon: Icon(Icons.palette_outlined),
                  onPressed: null,
                );
              },
            ),
          ),
        ),
      ),
    );

    final ColorPickerPopup first = showColorPicker(anchorContext!);
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsOneWidget);
    expect(first.isOpen, isTrue);

    // 再开一个：旧的自动收起，不会叠两个。
    final ColorPickerPopup second = showColorPicker(anchorContext!);
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsOneWidget, reason: '旧的先收起');
    expect(first.isOpen, isFalse);
    expect(second.isOpen, isTrue);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsNothing);
    expect(second.isOpen, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showColorPicker：不接返回值，点外面照样能关', (tester) async {
    BuildContext? anchorContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              anchorContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    // 返回值直接丢掉：调用方不用存任何一个字段。
    showColorPicker(anchorContext!);
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showColorPicker：anchorRect 用全局坐标定位，刚打开就能 close', (tester) async {
    BuildContext? pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              pageContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    const Rect anchor = Rect.fromLTWH(100, 100, 40, 20);
    final ColorPickerPopup popup = showColorPicker(
      pageContext!,
      anchorRect: anchor,
    );
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsOneWidget);
    expect(
      tester.getRect(find.byType(ColorPicker)).top,
      greaterThan(anchor.bottom),
      reason: '从锚点下方弹出',
    );

    // 还没 build 就要求关闭：走「直接摘 entry」那条路。
    final ColorPickerPopup quick = showColorPicker(
      pageContext!,
      anchorRect: anchor,
    );
    quick.close();
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsNothing);
    expect(quick.isOpen, isFalse);
    expect(popup.isOpen, isFalse, reason: '开新的会先收掉旧的');
    expect(tester.takeException(), isNull);
  });

  // ── 透明度 ──────────────────────────────────────────────────────────────

  testWidgets('默认不显示透明度：没有透明度条、没有百分比，hex 不带 alpha', (tester) async {
    await tester.pumpWidget(_host(const ColorPicker()));

    expect(find.byKey(_alphaKey), findsNothing);
    expect(find.byKey(_alphaLabelKey), findsNothing);
    expect(_hexText(tester), '#2B7FFF');
    expect(tester.takeException(), isNull);
  });

  testWidgets('showOpacity：显示透明度条与百分比，拖到最左变全透明', (tester) async {
    final List<int> changing = <int>[];
    final List<int> ended = <int>[];
    await tester.pumpWidget(
      _host(
        ColorPicker(
          showOpacity: true,
          value: const Color(0xFF2B7FFF),
          onChanged: changing.add,
          onChangeEnd: ended.add,
        ),
      ),
    );

    expect(find.byKey(_alphaKey), findsOneWidget);
    expect(_alphaText(tester), '100%', reason: '初始不透明');
    expect(_hexText(tester), '#2B7FFFFF', reason: 'hex 里也带 alpha');

    final Rect bar = _rectOf(tester, _alphaKey);
    final TestGesture gesture = await tester.startGesture(
      bar.centerLeft + const Offset(0.5, 0),
    );
    await tester.pump();

    expect(_currentColor(tester), const Color(0x002B7FFF), reason: 'alpha 归零');
    expect(_alphaText(tester), '0%');
    expect(_hexText(tester), '#2B7FFF00');
    expect(changing.last, 0x002B7FFF, reason: '回调带着 alpha 出去');
    expect(ended, isEmpty, reason: '松手前不该发 onChangeEnd');

    await gesture.moveTo(bar.center);
    await tester.pump();
    expect(_alphaText(tester), '50%');
    expect(changing.last, 0x802B7FFF);

    await gesture.up();
    await tester.pump();
    expect(ended.last, 0x802B7FFF);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showOpacity: false 时输入框也改不了透明度（八位 alpha 被丢掉）', (tester) async {
    final List<int> ended = <int>[];
    await tester.pumpWidget(_host(ColorPicker(onChangeEnd: ended.add)));

    await tester.enterText(find.byKey(_hexKey), '#00FF0080');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(_currentColor(tester), const Color(0xFF00FF00));
    expect(_hexText(tester), '#00FF00');
    expect(ended.last, 0xFF00FF00);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showOpacity: true 时八位 hex 输入能改透明度', (tester) async {
    final List<int> ended = <int>[];
    await tester.pumpWidget(
      _host(ColorPicker(showOpacity: true, onChangeEnd: ended.add)),
    );

    await tester.enterText(find.byKey(_hexKey), '#00FF0080');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(_currentColor(tester), const Color(0x8000FF00));
    expect(_alphaText(tester), '50%');
    expect(_hexText(tester), '#00FF0080');
    expect(ended.last, 0x8000FF00);

    // 六位写法（没写 alpha）照旧按不透明处理。
    await tester.enterText(find.byKey(_hexKey), '#00FF00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_currentColor(tester), const Color(0xFF00FF00));
    expect(_alphaText(tester), '100%');
    expect(tester.takeException(), isNull);
  });

  testWidgets('showOpacity 与 hexFormat.flutterArgb：显示 0xAARRGGBB', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ColorPicker(
          showOpacity: true,
          hexFormat: ColorHexFormat.flutterArgb,
          initialColor: const Color(0x802B7FFF),
        ),
      ),
    );
    expect(_hexText(tester), '0x802B7FFF');
    expect(_alphaText(tester), '50%');
    expect(_currentColor(tester), const Color(0x802B7FFF), reason: '预览也半透明');
    expect(tester.takeException(), isNull);
  });

  testWidgets('外部换 value 时透明度也跟着变', (tester) async {
    await tester.pumpWidget(
      _host(const ColorPicker(showOpacity: true, value: Color(0xFF2B7FFF))),
    );
    expect(_alphaText(tester), '100%');

    await tester.pumpWidget(
      _host(const ColorPicker(showOpacity: true, value: Color(0x332B7FFF))),
    );
    await tester.pump();
    expect(_alphaText(tester), '20%');
    expect(_hexText(tester), '#2B7FFF33');
    expect(tester.takeException(), isNull);
  });

  testWidgets('开关 showOpacity 后输入框按新写法重写', (tester) async {
    await tester.pumpWidget(_host(const ColorPicker()));
    expect(_hexText(tester), '#2B7FFF');

    await tester.pumpWidget(_host(const ColorPicker(showOpacity: true)));
    await tester.pump();
    expect(_hexText(tester), '#2B7FFFFF');
    expect(find.byKey(_alphaKey), findsOneWidget);

    await tester.pumpWidget(_host(const ColorPicker()));
    await tester.pump();
    expect(_hexText(tester), '#2B7FFF');
    expect(find.byKey(_alphaKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ColorPickerButton / showColorPicker 也能透出透明度条', (tester) async {
    await tester.pumpWidget(_host(const ColorPickerButton(showOpacity: true)));
    await tester.tap(find.byType(ColorPickerButton));
    await tester.pumpAndSettle();
    expect(find.byKey(_alphaKey), findsOneWidget);
    expect(_alphaText(tester), '100%');
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    BuildContext? anchorContext;
    final List<int> changed = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              anchorContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    showColorPicker(anchorContext!, showOpacity: true, onChanged: changed.add);
    await tester.pumpAndSettle();
    expect(find.byKey(_alphaKey), findsOneWidget);

    final Rect bar = _rectOf(tester, _alphaKey);
    await tester.tapAt(bar.center);
    await tester.pumpAndSettle();
    expect(changed.last, 0x802B7FFF);
    expect(tester.takeException(), isNull);
  });

  testWidgets('禁用的面板不响应透明度条', (tester) async {
    final List<int> changed = <int>[];
    await tester.pumpWidget(
      _host(
        ColorPicker(showOpacity: true, enabled: false, onChanged: changed.add),
      ),
    );
    await tester.tapAt(_rectOf(tester, _alphaKey).center);
    await tester.pump();
    expect(changed, isEmpty);
    expect(_alphaText(tester), '100%');
    expect(tester.takeException(), isNull);
  });

  // ── 输入框聚焦全选 ──────────────────────────────────────────────────────

  testWidgets('输入框聚焦时全选内容，再点一次是正常摆光标', (tester) async {
    await tester.pumpWidget(_host(const ColorPicker()));
    expect(_hexSelection(tester).isCollapsed, isTrue, reason: '没聚焦时不选');

    await tester.tap(find.byKey(_hexKey));
    await tester.pumpAndSettle();
    final TextSelection selected = _hexSelection(tester);
    expect(selected.baseOffset, 0);
    expect(selected.extentOffset, _hexText(tester).length, reason: '整段选中');

    // 已经聚焦后（过了双击判定窗口）再点：正常落光标，不然没法改中间某一位。
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(_hexKey));
    await tester.pumpAndSettle();
    expect(_hexSelection(tester).isCollapsed, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('colorToHex / parseHexColor 的 includeAlpha', () {
    expect(
      colorToHex(const Color(0x802B7FFF), includeAlpha: true),
      '#2B7FFF80',
    );
    expect(
      colorToHex(
        const Color(0x802B7FFF),
        includeAlpha: true,
        format: ColorHexFormat.flutterArgb,
      ),
      '0x802B7FFF',
    );
    expect(
      colorToHex(const Color(0x802B7FFF), format: ColorHexFormat.flutterArgb),
      '0xFF2B7FFF',
      reason: '不带 alpha 时仍是 0xFF 开头',
    );

    expect(
      parseHexColor('#2B7FFF80', includeAlpha: true),
      const Color(0x802B7FFF),
    );
    expect(
      parseHexColor('0x802B7FFF', includeAlpha: true),
      const Color(0x802B7FFF),
    );
    expect(
      parseHexColor('#2B7FFF80'),
      const Color(0xFF2B7FFF),
      reason: '默认丢掉 alpha',
    );
    expect(
      parseHexColor('#2B7FFF', includeAlpha: true),
      const Color(0xFF2B7FFF),
      reason: '六位写法本身不带 alpha',
    );
    expect(
      parseHexColor('#2B7FFF80', includeAlpha: true)!.a,
      closeTo(0.502, 0.01),
    );
  });
}

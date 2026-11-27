import 'package:flutter/gestures.dart';
import 'package:flutter_notification/flutter_notification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const Size _screen = Size(800, 600);

Widget _app({NotificationStyle? style, Widget? home}) {
  return MaterialApp(
    home: home ?? const Scaffold(body: SizedBox.expand()),
    builder: (BuildContext context, Widget? child) =>
        NotificationHost(style: style, child: child ?? const SizedBox.shrink()),
  );
}

/// 铺开画布 + 清空上一轮的静态状态。
void _prepare(WidgetTester tester) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  NotificationCenter.reset();
}

/// 单条覆盖：从当前全局样式派生，只改想改的那几项。
NotificationStyle _overrides({
  Duration? duration,
  NotificationPosition? position,
  bool? showProgress,
  double? width,
  double? radius,
  IconData? icon,
  Color? accentColor,
  double? elevation,
}) {
  return NotificationCenter.style.copyWith(
    duration: duration,
    position: position,
    showProgress: showProgress,
    width: width,
    radius: radius,
    icon: icon,
    accentColor: accentColor,
    elevation: elevation,
  );
}

/// 某条通知卡片的 rect（含与下一条之间的间距）。
Rect _cardOf(WidgetTester tester, String label) => tester.getRect(
  find.ancestor(of: find.text(label), matching: find.byType(NotificationCard)),
);

/// 插入一条通知并等进场动画播完。
Future<void> _settleIn(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// 等退场动画播完：closing 帧 → reverse → post-frame 移除 → 再重建一帧。
Future<void> _settleOut(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  group('NotificationCenter', () {
    testWidgets('默认停在右上角，带成功图标和标题正文', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.success('已保存', message: '3 个文件已同步');
      await _settleIn(tester);

      expect(find.text('已保存'), findsOneWidget);
      expect(find.text('3 个文件已同步'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

      final Rect card = tester.getRect(find.byType(NotificationCard));
      expect(card.width, 360);
      expect(card.right, closeTo(_screen.width - 16, 0.5));
      expect(card.top, closeTo(16, 0.5));

      // 默认圆角是 8，投影和裁剪都跟着它走。
      final Material material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(NotificationCard),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('进度条走完自动关闭', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.info(
        '提示',
        style: _overrides(duration: const Duration(milliseconds: 600)),
      );
      await _settleIn(tester);
      expect(find.text('提示'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      await _settleOut(tester);
      expect(find.text('提示'), findsNothing);
    });

    testWidgets('loading 默认不自动关闭，update 成 success 后按默认时长收起', (
      WidgetTester tester,
    ) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      final NotificationHandle handle = NotificationCenter.loading(
        '上传中…',
        message: '0 / 3',
      );
      await _settleIn(tester);

      await tester.pump(const Duration(seconds: 10));
      expect(find.text('上传中…'), findsOneWidget, reason: '没有 duration 就一直挂着');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      handle.update(title: '上传完成', kind: NotificationKind.success);
      await tester.pump();
      expect(find.text('上传完成'), findsOneWidget);
      expect(find.text('上传中…'), findsNothing);
      expect(find.text('0 / 3'), findsOneWidget, reason: 'update 不传就不动');

      // 变成 success 后自动套上全局的 4s。
      await tester.pump(const Duration(seconds: 5));
      await _settleOut(tester);
      expect(find.text('上传完成'), findsNothing);
    });

    testWidgets('同一个 id 就地更新，不会堆两条', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.show(title: '正在导出', id: 'export');
      await _settleIn(tester);
      NotificationCenter.show(title: '导出 50%', id: 'export');
      await tester.pump();

      expect(find.byType(NotificationCard), findsOneWidget);
      expect(find.text('正在导出'), findsNothing);
      expect(find.text('导出 50%'), findsOneWidget);
    });

    testWidgets('handle.close / dismissAll 都能关掉', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      final NotificationHandle a = NotificationCenter.success('A');
      NotificationCenter.error('B');
      await _settleIn(tester);
      expect(find.byType(NotificationCard), findsNWidgets(2));

      a.close();
      await _settleOut(tester);
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);

      NotificationCenter.dismissAll();
      await _settleOut(tester);
      expect(find.byType(NotificationCard), findsNothing);
      expect(a.isVisible, isFalse);
    });

    testWidgets('超过 maxVisible 时最早的一条自动收起', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(
        _app(style: const NotificationStyle(maxVisible: 2)),
      );

      NotificationCenter.info(
        '第一条',
        style: _overrides(duration: const Duration(seconds: 30)),
      );
      NotificationCenter.info(
        '第二条',
        style: _overrides(duration: const Duration(seconds: 30)),
      );
      await _settleIn(tester);
      NotificationCenter.info(
        '第三条',
        style: _overrides(duration: const Duration(seconds: 30)),
      );
      await _settleOut(tester);

      expect(find.text('第一条'), findsNothing);
      expect(find.text('第二条'), findsOneWidget);
      expect(find.text('第三条'), findsOneWidget);
      expect(NotificationCenter.items.length, 2);
    });

    testWidgets('宿主挂载前调用的通知，挂载后补显示', (WidgetTester tester) async {
      _prepare(tester);
      NotificationCenter.warning('磁盘快满了');

      await tester.pumpWidget(_app());
      await _settleIn(tester);

      expect(find.text('磁盘快满了'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('鼠标悬停时暂停倒计时', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.info(
        '悬停我',
        style: _overrides(duration: const Duration(milliseconds: 500)),
      );
      await _settleIn(tester);

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.byType(NotificationCard)));
      await tester.pump();

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('悬停我'), findsOneWidget, reason: '悬停期间不计时');

      // 移开：从剩下的时间继续走。
      await mouse.moveTo(const Offset(5, 5));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _settleOut(tester);
      expect(find.text('悬停我'), findsNothing);
    });

    testWidgets('showProgress: false 不画进度条', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.info('没有进度条', style: _overrides(showProgress: false));
      await _settleIn(tester);

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('clearDuration 既不倒计时也没有进度条', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.info(
        '不自动关',
        style: NotificationCenter.style.copyWith(clearDuration: true),
      );
      await _settleIn(tester);

      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('不自动关'), findsOneWidget);
    });

    testWidgets('按钮动作先执行回调再关闭', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      int taps = 0;
      NotificationCenter.show(
        title: '文件已删除',
        actions: <NotificationAction>[
          NotificationAction(label: '撤销', onPressed: () => taps++),
        ],
      );
      await _settleIn(tester);

      await tester.tap(find.text('撤销'));
      await tester.pump();
      expect(taps, 1);

      await _settleOut(tester);
      expect(find.text('文件已删除'), findsNothing);
    });

    testWidgets('多个按钮排在右下角，主按钮用实心样式', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      int deleted = 0;
      int cancelled = 0;
      NotificationCenter.show(
        title: '删除 3 个文件？',
        actions: <NotificationAction>[
          NotificationAction(
            label: '取消',
            onPressed: () => cancelled++,
            closeOnTap: false,
          ),
          NotificationAction(
            label: '删除',
            onPressed: () => deleted++,
            isPrimary: true,
          ),
        ],
      );
      await _settleIn(tester);

      final Rect card = _cardOf(tester, '删除 3 个文件？');
      final Rect cancel = tester.getRect(find.widgetWithText(TextButton, '取消'));
      final Rect confirm = tester.getRect(
        find.widgetWithText(FilledButton, '删除'),
      );

      expect(find.byType(FilledButton), findsOneWidget, reason: 'isPrimary');
      // 两颗按钮同排、都贴着卡片右侧（和正文同一条缩进），顺序从左到右。
      expect(cancel.center.dy, closeTo(confirm.center.dy, 1));
      expect(cancel.left, lessThan(confirm.left));
      expect(card.right - confirm.right, closeTo(14, 1.5));
      // 胶囊够高，文字上下各有留白，不会顶到胶囊边上。
      expect(confirm.height, closeTo(32, 0.5));
      final Rect label = tester.getRect(find.text('删除'));
      expect(label.top - confirm.top, greaterThan(6));
      expect(confirm.bottom - label.bottom, greaterThan(6));
      // 按钮在正文下方，不在正文里跟标题挤一行。
      expect(
        confirm.top,
        greaterThan(tester.getRect(find.text('删除 3 个文件？')).bottom),
      );

      // 关闭按钮不会被误触：取消那颗不关，删除那颗关。
      await tester.tap(find.text('取消'));
      await tester.pump();
      expect(cancelled, 1);
      expect(find.text('删除 3 个文件？'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pump();
      expect(deleted, 1);
      await _settleOut(tester);
      expect(find.text('删除 3 个文件？'), findsNothing);
    });

    testWidgets('update 可以换掉 / 清空按钮', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      final NotificationHandle handle = NotificationCenter.loading(
        '上传中…',
        actions: <NotificationAction>[
          NotificationAction(label: '取消', onPressed: () {}),
        ],
        style: _overrides(duration: const Duration(seconds: 30)),
      );
      await _settleIn(tester);
      expect(find.text('取消'), findsOneWidget);

      // loading → success 时换成另一颗按钮。
      handle.update(
        title: '上传完成',
        kind: NotificationKind.success,
        actions: <NotificationAction>[
          NotificationAction(label: '查看', onPressed: () {}),
        ],
      );
      await tester.pump();
      expect(find.text('取消'), findsNothing);
      expect(find.text('查看'), findsOneWidget);

      // 传空列表就是全去掉。
      handle.update(actions: const <NotificationAction>[]);
      await tester.pump();
      expect(find.text('查看'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('builder 换掉默认按钮，点击仍走同一套关闭逻辑', (
      WidgetTester tester,
    ) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      int taps = 0;
      NotificationCenter.show(
        title: '同步失败',
        actions: <NotificationAction>[
          NotificationAction(
            onPressed: () => taps++,
            builder: (BuildContext context, VoidCallback onPressed) =>
                IconButton.filledTonal(
                  onPressed: onPressed,
                  icon: const Icon(Icons.refresh, size: 16),
                  tooltip: '重试',
                ),
          ),
        ],
      );
      await _settleIn(tester);

      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(taps, 1);

      // closeOnTap 默认开着，点完这条就退场。
      await _settleOut(tester);
      expect(find.text('同步失败'), findsNothing);
    });

    testWidgets('mouseCursor 管到卡片、关闭按钮和操作按钮', (
      WidgetTester tester,
    ) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.info(
        '删除记录',
        style: _overrides(duration: const Duration(seconds: 30)).copyWith(
          dismissOnTap: true,
          mouseCursor: SystemMouseCursors.precise,
        ),
        actions: <NotificationAction>[
          NotificationAction(label: '撤销', onPressed: () {}),
        ],
      );
      await _settleIn(tester);

      final InkWell card = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('删除记录'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(card.mouseCursor, SystemMouseCursors.precise, reason: '整张卡片');

      final ButtonStyle action = tester
          .widget<TextButton>(find.byType(TextButton))
          .style!;
      expect(
        action.mouseCursor?.resolve(const <WidgetState>{}),
        SystemMouseCursors.precise,
        reason: '操作按钮',
      );

      final IconButton close = tester.widget<IconButton>(
        find.byType(IconButton),
      );
      expect(
        close.style?.mouseCursor?.resolve(const <WidgetState>{}),
        SystemMouseCursors.precise,
        reason: '关闭按钮',
      );
    });

    testWidgets('卡片没接回调时不显示可点光标', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.success(
        '纯提示',
        style: _overrides(duration: const Duration(seconds: 30)),
      );
      await _settleIn(tester);

      final InkWell card = tester.widget<InkWell>(
        find
            .ancestor(of: find.text('纯提示'), matching: find.byType(InkWell))
            .first,
      );
      expect(card.mouseCursor, MouseCursor.defer);
    });

    testWidgets('没有按钮时正文下边距不变', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.success(
        '纯提示',
        message: '没有按钮',
        style: _overrides(duration: const Duration(seconds: 30)),
      );
      await _settleIn(tester);

      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('通知层不挡下面按钮的点击', (WidgetTester tester) async {
      _prepare(tester);
      int taps = 0;
      await tester.pumpWidget(
        _app(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => taps++,
                child: const Text('下面的按钮'),
              ),
            ),
          ),
        ),
      );

      NotificationCenter.info(
        '右上角通知',
        style: _overrides(duration: const Duration(seconds: 30)),
      );
      await _settleIn(tester);

      await tester.tap(find.text('下面的按钮'));
      await tester.pump();
      expect(taps, 1);

      // 通知卡片自己的空白区域也不会穿透到下面的按钮。
      await tester.tap(find.text('右上角通知'));
      await tester.pump();
      expect(taps, 1, reason: '点在卡片上不应触到下面的按钮');
    });

    testWidgets('自定义内容里需要 Overlay 的组件也能用', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.show(
        title: '自定义内容',
        content: const Tooltip(message: '气泡提示', child: Text('卡片里的 Tooltip')),
        style: _overrides(duration: const Duration(seconds: 30)),
      );
      await _settleIn(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('卡片里的 Tooltip'), findsOneWidget);
    });

    testWidgets('custom() 只放自定义内容', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.custom(
        const Row(
          children: <Widget>[
            Icon(Icons.chat_bubble_outline, size: 16),
            SizedBox(width: 8),
            Text('新消息：晚上吃什么？'),
          ],
        ),
        style: _overrides(duration: const Duration(seconds: 30)),
      );
      await _settleIn(tester);

      expect(find.text('新消息：晚上吃什么？'), findsOneWidget);
      expect(find.byType(NotificationCard), findsOneWidget);
    });
  });

  group('位置与样式', () {
    testWidgets('六个角各就各位', (WidgetTester tester) async {
      _prepare(tester);
      // 六个位置各一条，别让 maxVisible 把最早的两条收掉。
      await tester.pumpWidget(
        _app(style: const NotificationStyle(maxVisible: 6)),
      );

      const Map<NotificationPosition, String> labels =
          <NotificationPosition, String>{
            NotificationPosition.topLeft: '左上',
            NotificationPosition.topCenter: '上中',
            NotificationPosition.topRight: '右上',
            NotificationPosition.bottomLeft: '左下',
            NotificationPosition.bottomCenter: '下中',
            NotificationPosition.bottomRight: '右下',
          };
      for (final MapEntry<NotificationPosition, String> entry
          in labels.entries) {
        NotificationCenter.show(
          title: entry.value,
          style: _overrides(
            position: entry.key,
            duration: const Duration(seconds: 30),
          ),
        );
      }
      await _settleIn(tester);

      Rect rectOf(String label) => tester.getRect(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(NotificationCard),
        ),
      );

      final Rect topLeft = rectOf('左上');
      expect(topLeft.left, closeTo(16, 0.5));
      expect(topLeft.top, closeTo(16, 0.5));

      final Rect topCenter = rectOf('上中');
      expect(topCenter.center.dx, closeTo(_screen.width / 2, 0.5));
      expect(topCenter.top, closeTo(16, 0.5));

      final Rect bottomRight = rectOf('右下');
      expect(bottomRight.right, closeTo(_screen.width - 16, 0.5));
      expect(bottomRight.bottom, closeTo(_screen.height - 16, 0.5));

      final Rect bottomLeft = rectOf('左下');
      expect(bottomLeft.left, closeTo(16, 0.5));
      expect(bottomLeft.bottom, closeTo(_screen.height - 16, 0.5));
    });

    testWidgets('上方新通知贴近上边缘，下方贴近下边缘', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      final NotificationStyle long = _overrides(
        duration: const Duration(seconds: 30),
      );
      NotificationCenter.show(title: '上1', style: long);
      await _settleIn(tester);
      NotificationCenter.show(title: '上2', style: long);
      await _settleIn(tester);

      expect(
        tester.getRect(find.text('上2')).center.dy,
        lessThan(tester.getRect(find.text('上1')).center.dy),
        reason: '上方：新的在上',
      );

      final NotificationStyle bottom = _overrides(
        position: NotificationPosition.bottomRight,
        duration: const Duration(seconds: 30),
      );
      NotificationCenter.show(title: '下1', style: bottom);
      await _settleIn(tester);
      NotificationCenter.show(title: '下2', style: bottom);
      await _settleIn(tester);

      expect(
        tester.getRect(find.text('下2')).center.dy,
        greaterThan(tester.getRect(find.text('下1')).center.dy),
        reason: '下方：新的在下',
      );
    });

    testWidgets('样式可以全局定制', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(
        _app(
          style: const NotificationStyle(
            width: 280,
            radius: 4,
            margin: EdgeInsets.all(40),
            position: NotificationPosition.bottomLeft,
            duration: Duration(seconds: 1),
            showProgress: false,
          ),
        ),
      );

      NotificationCenter.show(title: '定制');
      await _settleIn(tester);

      final Rect card = tester.getRect(find.byType(NotificationCard));
      expect(card.width, 280);
      expect(card.left, closeTo(40, 0.5));
      expect(card.bottom, closeTo(_screen.height - 40, 0.5));
      expect(find.byType(LinearProgressIndicator), findsNothing);

      final Material material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(NotificationCard),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        material.borderRadius,
        BorderRadius.circular(4),
        reason: '圆角走全局样式',
      );

      // 全局 duration 1s 生效。
      await tester.pump(const Duration(milliseconds: 1200));
      await _settleOut(tester);
      expect(find.text('定制'), findsNothing);
    });

    testWidgets('单条 style 覆盖全局，其它条不受影响', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app(style: const NotificationStyle(width: 320)));

      NotificationCenter.success(
        '改过的',
        style: _overrides(
          width: 220,
          radius: 6,
          icon: Icons.save_outlined,
          accentColor: Colors.purple,
          duration: const Duration(seconds: 30),
        ),
      );
      NotificationCenter.info(
        '没改的',
        style: _overrides(duration: const Duration(seconds: 30)),
      );
      await _settleIn(tester);

      expect(
        tester
            .getRect(
              find.ancestor(
                of: find.text('改过的'),
                matching: find.byType(NotificationCard),
              ),
            )
            .width,
        220,
      );
      expect(
        tester
            .getRect(
              find.ancestor(
                of: find.text('没改的'),
                matching: find.byType(NotificationCard),
              ),
            )
            .width,
        320,
      );

      final Material material = tester.widget<Material>(
        find
            .descendant(
              of: find.ancestor(
                of: find.text('改过的'),
                matching: find.byType(NotificationCard),
              ),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.borderRadius, BorderRadius.circular(6));
      expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    });

    testWidgets('进度条铺满底边，两端由卡片圆角裁进去', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.success(
        '圆角',
        style: _overrides(radius: 24, duration: const Duration(seconds: 30)),
      );
      await _settleIn(tester);

      final Rect card = tester.getRect(find.byType(NotificationCard));
      final Rect bar = tester.getRect(find.byType(LinearProgressIndicator));
      // 满宽：多出来的 2 * 24 落在两个圆角里，靠 Material 的圆角裁剪收边，
      // 这样进度条看起来和卡片一样宽，下角也不会留缺口。
      expect(bar.left, closeTo(card.left, 0.5));
      expect(bar.right, closeTo(card.right, 0.5));
      expect(bar.bottom, closeTo(card.bottom, 0.5), reason: '贴着底边');

      // 端点必须是方的，交给圆角去裁；胶囊端点会把条缩短。
      final LinearProgressIndicator indicator = tester.widget(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.borderRadius, BorderRadius.zero);

      // 收边靠的是卡片自己的圆角裁剪。
      final Material material = tester.widget(
        find
            .descendant(
              of: find.byType(NotificationCard),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.borderRadius, BorderRadius.circular(24));
      expect(material.clipBehavior, Clip.antiAlias);
    });

    testWidgets('卡片用 Material 自己的投影', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.success(
        '投影',
        style: _overrides(elevation: 4, duration: const Duration(seconds: 30)),
      );
      await _settleIn(tester);

      final Material material = tester.widget(
        find
            .descendant(
              of: find.byType(NotificationCard),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.elevation, 4);
      expect(material.borderRadius, BorderRadius.circular(8));
      expect(material.clipBehavior, Clip.antiAlias);
      expect(material.surfaceTintColor, Colors.transparent, reason: '不染主题色');
    });

    testWidgets('进场裁剪盒给投影留了余量', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.success(
        '投影',
        style: _overrides(elevation: 4, duration: const Duration(seconds: 30)),
      );
      await _settleIn(tester);

      final ClipRect clip = tester.widget(
        find
            .descendant(
              of: find.byType(NotificationCard),
              matching: find.byType(ClipRect),
            )
            .first,
      );
      final Rect rect = clip.clipper!.getClip(const Size(360, 80));
      // 裁剪盒必须比卡片大一圈，否则 Material 的投影会被切成直角矩形。
      expect(rect.left, lessThan(0));
      expect(rect.top, lessThan(0));
      expect(rect.right, greaterThan(360));
      expect(rect.bottom, greaterThan(80));
    });
  });

  group('动画与倒计时', () {
    testWidgets('show 之后下一帧就上屏，不等动画', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      NotificationCenter.info('立即出现');
      // 只推一帧：卡片已经在树上，而不是等进场动画播完才出现。
      await tester.pump();
      expect(find.byType(NotificationCard), findsOneWidget);
      expect(find.text('立即出现'), findsOneWidget);

      // 动画走完，占位高度长到卡片本身的高度。
      await _settleIn(tester);
      final Rect card = tester.getRect(find.byType(NotificationCard));
      expect(card.height, greaterThan(0));
    });

    testWidgets('新通知进场时旧卡片只平移，不重播进场动画', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());
      final NotificationStyle long = _overrides(
        duration: const Duration(seconds: 30),
      );

      NotificationCenter.info('A', style: long);
      await _settleIn(tester);
      NotificationCenter.info('B', style: long);
      await _settleIn(tester);

      // A 是最老的一条（贴着里侧，没有下间距），B 上面还有间距。
      final double beforeA = _cardOf(tester, 'A').height;
      final double beforeB = _cardOf(tester, 'B').height;
      NotificationCenter.info('C', style: long);
      await tester.pump();

      // 旧卡片如果被重建，这里会变成 0（重新播一遍高度展开）。
      expect(_cardOf(tester, 'A').height, closeTo(beforeA, 0.5));
      expect(_cardOf(tester, 'B').height, closeTo(beforeB, 0.5));

      // 新卡片自己从 0 长起来，把旧的往下顶。
      await _settleIn(tester);
      expect(_cardOf(tester, 'A').top, greaterThan(16 + beforeA));
      expect(_cardOf(tester, 'C').top, closeTo(16, 0.5));
    });

    testWidgets('update 不重置倒计时', (WidgetTester tester) async {
      _prepare(tester);
      await tester.pumpWidget(_app());

      final NotificationHandle handle = NotificationCenter.info(
        '倒计时',
        style: _overrides(duration: const Duration(seconds: 2)),
      );
      await _settleIn(tester);
      await tester.pump(const Duration(milliseconds: 1200));

      // 1.5s 时改文案：剩下的 0.5s 继续走，不重新计时。
      handle.update(title: '倒计时（已更新）');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _settleOut(tester);

      expect(find.text('倒计时（已更新）'), findsNothing);
    });
  });
}

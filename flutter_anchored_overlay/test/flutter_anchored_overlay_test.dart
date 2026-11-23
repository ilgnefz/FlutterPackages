import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_anchored_overlay/flutter_anchored_overlay.dart';

void main() {
  test('computeTooltipPlacement 返回 Overlay 绝对坐标', () {
    final TooltipPlacement placement = computeTooltipPlacement(
      target: const Rect.fromLTWH(100, 100, 40, 40),
      bubble: const Size(120, 80),
      viewport: const Size(400, 300),
      preferred: TooltipDirection.down,
      align: TooltipAlign.center,
      gap: 8,
      arrowWidth: 12,
      radius: 6,
      viewportPadding: 8,
    );

    expect(placement.direction, TooltipDirection.down);
    expect(placement.offset.dx, closeTo(60.0, 0.001));
    expect(placement.offset.dy, greaterThan(140.0));
    expect(
      placement.offset.dx + 120.0,
      lessThanOrEqualTo(400.0),
    );
    expect(placement.flipped, isFalse);
  });

  testWidgets('Popover 能挂载在 MaterialApp 里', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: Popover(
              content: Text('气泡内容'),
              child: Icon(Icons.info_outline),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Popover), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('SmartTooltip 与 Popover 共用控制器', (tester) async {
    final SmartTooltipController controller = SmartTooltipController();
    expect(controller.isVisible, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: SmartTooltip(
              controller: controller,
              message: '这是一段提示',
              child: const Text('悬停我'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SmartTooltip), findsOneWidget);
    expect(find.text('悬停我'), findsOneWidget);
  });

  testWidgets('圆角气泡会把内容裁进轮廓', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Popover(
              initialOpen: true,
              style: const PopoverStyle(radius: 20, showArrow: false),
              padding: EdgeInsets.zero,
              content: const SizedBox(width: 180, height: 80),
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder clipFinder = find.ancestor(
      of: find.byKey(kPopoverContentKey),
      matching: find.byType(ClipPath),
    );
    expect(clipFinder, findsWidgets);
    // ShapeDecoration 自己也带一层 ShapeBorderClipper，外层才是我们加的。
    final ClipPath clip = tester.widget<ClipPath>(clipFinder.first);
    final Rect bubble = tester.getRect(find.byKey(kPopoverBubbleKey));
    final path = clip.clipper!.getClip(bubble.size);
    expect(path.contains(const Offset(1, 1)), isFalse);
    expect(path.contains(Offset(bubble.width / 2, bubble.height / 2)), isTrue);
  });

  testWidgets('padding 控制气泡内边距，edgePadding 只管视口边距', (tester) async {
    Future<double> bubbleWidth({
      EdgeInsetsGeometry? padding,
      double edgePadding = 8,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Popover(
                initialOpen: true,
                placement: PopoverPlacement.bottom,
                padding: padding,
                edgePadding: edgePadding,
                content: const SizedBox(width: 180, height: 80),
                child: const SizedBox(width: 40, height: 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getRect(find.byKey(kPopoverBubbleKey)).width;
    }

    final double base = await bubbleWidth();
    expect(
      await bubbleWidth(edgePadding: 48),
      base,
      reason: '居中时 edgePadding 不影响气泡',
    );
    expect(await bubbleWidth(padding: const EdgeInsets.all(30)), base + 32);
  });
}

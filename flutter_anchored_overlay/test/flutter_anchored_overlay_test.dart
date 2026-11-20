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
}

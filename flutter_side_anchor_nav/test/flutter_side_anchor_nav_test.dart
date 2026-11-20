import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_side_anchor_nav/flutter_side_anchor_nav.dart';

void main() {
  testWidgets('SideAnchorNav 挂载并让控制器驱动选中页', (tester) async {
    final SideTabController controller = SideTabController();
    expect(controller.index, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: SideAnchorNav(
              controller: controller,
              views: <SideTabView>[
                SideTabView(
                  label: 'A',
                  child: const SizedBox(height: 300, child: Text('A 页')),
                ),
                SideTabView(
                  label: 'B',
                  child: const SizedBox(height: 300, child: Text('B 页')),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SideAnchorNav), findsOneWidget);
    expect(find.text('A 页'), findsOneWidget);
    expect(find.text('B 页'), findsOneWidget);

    controller.select(1);
    await tester.pumpAndSettle();
    expect(controller.index, 1);
  });
}

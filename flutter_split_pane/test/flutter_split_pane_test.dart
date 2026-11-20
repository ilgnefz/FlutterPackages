import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_split_pane/flutter_split_pane.dart';

SplitPaneView _view(String label, {double? ratio}) => SplitPaneView(
  ratio: ratio,
  child: SizedBox(height: 40, child: Text(label)),
);

void main() {
  test('resolveSplitPaneRatios：平分、按声明分配、超出 1 时缩放', () {
    final List<double> even = resolveSplitPaneRatios(<SplitPaneView>[
      _view('a'),
      _view('b'),
      _view('c'),
    ]);
    expect(even.length, 3);
    for (final double ratio in even) {
      expect(ratio, closeTo(1 / 3, 0.000001));
    }

    final List<double> mixed = resolveSplitPaneRatios(<SplitPaneView>[
      _view('a', ratio: 0.8),
      _view('b'),
    ]);
    expect(mixed[0], closeTo(0.8, 0.000001));
    expect(mixed[1], closeTo(0.2, 0.000001));

    final List<double> scaled = resolveSplitPaneRatios(<SplitPaneView>[
      _view('a', ratio: 0.8),
      _view('b', ratio: 0.8),
    ]);
    expect(scaled[0], closeTo(0.5, 0.000001));
    expect(scaled[1], closeTo(0.5, 0.000001));
  });

  test('splitPaneFlex：按比例换算，最小为 1', () {
    expect(splitPaneFlex(<double>[0.25, 0.75]), <int>[250, 750]);
    expect(splitPaneFlex(<double>[0.0, 0.5]), <int>[1, 500]);
  });

  testWidgets('SplitPane 自动在视图之间插入分割线', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 200,
            child: SplitPane(
              views: <SplitPaneView>[_view('左'), _view('中'), _view('右')],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SplitPane), findsOneWidget);
    expect(find.text('左'), findsOneWidget);
    expect(find.text('中'), findsOneWidget);
    expect(find.text('右'), findsOneWidget);
    expect(find.byKey(splitPaneDividerKey(0)), findsOneWidget);
    expect(find.byKey(splitPaneDividerKey(1)), findsOneWidget);
  });
}

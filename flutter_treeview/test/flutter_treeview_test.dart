import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_treeview/flutter_treeview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const List<TreeNode<String>> _nodes = <TreeNode<String>>[
  TreeNode<String>(
    'image',
    label: '图片',
    children: <TreeNode<String>>[
      TreeNode<String>('png', label: 'png'),
      TreeNode<String>('jpg', label: 'jpg'),
    ],
  ),
  TreeNode<String>('video', label: '视频'),
];

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 240, child: child)),
  ),
);

/// 抓一帧，读各行中间的底色（只取 R 通道，行底色是中性灰）。
///
/// 采样点放在行内 62% 处，避开左侧文字和右侧箭头。
///
/// `toImage()/toByteData()` 只能在真实异步环境里完成，直接 await 在
/// `testWidgets` 的假异步时钟下永远不会 resolve（表现就是测试挂住），
/// 所以必须包进 [WidgetTester.runAsync]。
Future<Map<String, int>> _rowBackgroundRed(
  WidgetTester tester,
  GlobalKey key,
  List<String> labels,
) async {
  final RenderRepaintBoundary boundary =
      tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
  final Offset origin = tester.getTopLeft(find.byKey(key));
  // tester 的 find 系列不能在 runAsync 里调用，先算好行中心。
  final Map<String, int> rows = <String, int>{
    for (final String label in labels)
      label: (tester.getCenter(find.text(label)).dy - origin.dy).round(),
  };

  final Map<String, int>? result = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData bytes = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final int x = (image.width * 0.62).round();
    final Map<String, int> out = <String, int>{};
    for (final String label in labels) {
      out[label] = bytes.getUint8((rows[label]! * image.width + x) * 4);
    }
    image.dispose();
    return out;
  });
  return result ?? <String, int>{};
}

void main() {
  testWidgets('常用树：默认收起，点箭头展开子级', (WidgetTester tester) async {
    await tester.pumpWidget(_app(const TreeView<String>(nodes: _nodes)));

    expect(find.text('图片'), findsOneWidget);
    expect(find.text('png'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();

    expect(find.text('png'), findsOneWidget);
    expect(find.text('jpg'), findsOneWidget);
  });

  testWidgets('常用树：点行回传 id', (WidgetTester tester) async {
    String? picked;
    await tester.pumpWidget(
      _app(
        TreeView<String>(
          nodes: _nodes,
          expandAll: true,
          onChanged: (String id) => picked = id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 展开全部后子级已经在树上了。
    expect(find.text('png'), findsOneWidget);

    await tester.tap(find.text('png'));
    await tester.pumpAndSettle();

    expect(picked, 'png');
  });

  testWidgets('勾选树：勾父级会勾上整棵子树', (WidgetTester tester) async {
    Set<String>? reported;
    await tester.pumpWidget(
      _app(
        TreeView.checkbox<String>(
          nodes: _nodes,
          expandAll: true,
          onCheckedChanged: (Set<String> ids) => reported = ids,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('图片'));
    await tester.pumpAndSettle();

    expect(reported, <String>{'image', 'png', 'jpg'});
  });

  testWidgets('勾选树：取消一个子项后父级只剩部分', (WidgetTester tester) async {
    Set<String>? reported;
    await tester.pumpWidget(
      _app(
        TreeView.checkbox<String>(
          nodes: _nodes,
          expandAll: true,
          onCheckedChanged: (Set<String> ids) => reported = ids,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('图片'));
    await tester.pumpAndSettle();
    expect(reported, <String>{'image', 'png', 'jpg'});

    await tester.tap(find.text('png'));
    await tester.pumpAndSettle();

    // 父级不再是「完全勾选」，自己也不再上报。
    expect(reported, <String>{'jpg'});
  });

  testWidgets('勾选树：受控 checkedIds 决定初始勾选', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        TreeView.checkbox<String>(
          nodes: _nodes,
          expandAll: true,
          checkedIds: <String>{'video'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 两个子项未选 + 父级三态未选 + video 已选 = 只有 video 打勾。
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('展开集合受控：外部给了 expandedIds 就按外面的来', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        const TreeView<String>(nodes: _nodes, expandedIds: <String>{'image'}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('png'), findsOneWidget);
  });

  testWidgets('maxHeight：桌面上也只有一条滚动条，厚度走 style', (
    WidgetTester tester,
  ) async {
    // 桌面平台的 MaterialScrollBehavior 会自动给 Scrollable 再套一条
    // 默认厚度的 Scrollbar；树组件应该只留自己那条可配置的。
    final TargetPlatform? original = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = original);

    await tester.pumpWidget(
      _app(
        TreeView.checkbox<String>(nodes: _nodes, expandAll: true, maxHeight: 40),
      ),
    );

    expect(find.byType(Scrollbar), findsOneWidget);
    expect(tester.widget<Scrollbar>(find.byType(Scrollbar)).thickness, 4.0);
  });

  testWidgets('hover：切换行时只有一行高亮，中间不会闪过深灰', (
    WidgetTester tester,
  ) async {
    final GlobalKey key = GlobalKey();
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: const Offset(1, 1));
    addTearDown(mouse.removePointer);

    await tester.pumpWidget(
      _app(
        RepaintBoundary(
          key: key,
          // 边界内铺一层不透明底：行底色熄灭时是 alpha=0 的浅灰，
          // 而 rawRgba 是预乘 alpha（alpha=0 → RGB 也是 0），
          // 直接读会得到「纯黑」而看不出是不是真的熄灭了。
          child: ColoredBox(
            color: Colors.white,
            child: TreeView.checkbox<String>(nodes: _nodes, expandAll: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await mouse.moveTo(tester.getCenter(find.text('png')));
    await tester.pumpAndSettle();
    // 停在 png 上：底色就是 hoverColor #F4F4F5。
    expect((await _rowBackgroundRed(tester, key, <String>['png']))['png'], 244);

    // 移到 jpg，只看动画半途那一帧。
    await mouse.moveTo(tester.getCenter(find.text('jpg')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final Map<String, int> mid = await _rowBackgroundRed(tester, key, <String>[
      'png',
      'jpg',
    ]);

    // 离开的那行当帧就熄灭（不再和落上的那行一起发灰）。
    expect(mid['png'], greaterThanOrEqualTo(250));
    // 进入的那行只在浅色区间淡入，不会经过「深灰」。
    expect(mid['jpg'], inInclusiveRange(235, 254));

    await tester.pumpAndSettle();
    final Map<String, int> settled = await _rowBackgroundRed(
      tester,
      key,
      <String>['png', 'jpg'],
    );
    expect(settled['png'], 255);
    expect(settled['jpg'], 244);
  });
}

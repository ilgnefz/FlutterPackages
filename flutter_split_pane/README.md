# flutter_split_pane

可拖动分割线的多视图布局：面板之间自动插入分割线，拖中间那条带子就能改变两侧宽度。

## 用法

```dart
import 'package:flutter_split_pane/flutter_split_pane.dart';

SplitPane(
  views: <SplitPaneView>[
    SplitPaneView(child: const Text('左'), ratio: 0.6),
    SplitPaneView(child: const Text('右')), // 分剩下的 40%
  ],
)
```

占比写在每个视图自己身上：全都不写就平分；有的写了就由没写的平分剩下部分；
写了的合计超过 1 会按比例缩放到 1。

* 不给 `controller`：组件自己维护比例，用 `onRatiosChanged` 实时抛出。
* 给了 `SplitPaneController`：控制器是唯一数据源，外部改 `ratios` 组件跟着重排。
* 持久化用 `onRatiosCommitted`：一次调整结束才抛一次（松手 / 键盘调整 / 双击复位）。

## 能力与约束

- 分割线可悬停高亮、拖动跟手、聚焦后用方向键调整、`Home`/`End` 到边界、双击复位。
- `SplitPaneView.minExtent` / `maxExtent` 限制单个面板像素尺寸，拖动撞到上限就停。
- `SplitPaneStyle.dividerThickness` / `dividerSpace` / `dividerHitPadding` 分别控制可见带子、
  两侧留白和命中区；短分割线用 `dividerExtent` / `dividerMargin`。
- 主轴（横向时的宽、竖向时的高）需要有界，否则只能按 flex 近似分配。

`resolveSplitPaneRatios` / `splitPaneFlex` / `splitPaneDividerKey` 等纯函数与 key
也一并导出。

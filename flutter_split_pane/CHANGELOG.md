## 0.0.1

* 从 `once_power/lib/widget/base/split_pane` 迁移为独立包
  `flutter_split_pane`，入口改为 `package:flutter_split_pane/flutter_split_pane.dart`。
* 公开组件名保持不变：`SplitPane`、`SplitPaneView`、`SplitPaneController`、
  `SplitPaneStyle` 以及 `resolveSplitPaneRatios` / `splitPaneFlex` 等纯函数。
* part 文件移入 `src/`；补 `material_ui` 依赖与冒烟测试。

## 0.0.1

* 从 `once_power/lib/widget/base/side_anchor_nav` 迁移为独立包
  `flutter_side_anchor_nav`，入口改为
  `package:flutter_side_anchor_nav/flutter_side_anchor_nav.dart`。
* 公开组件名保持不变：主组件 `SideAnchorNav`，配套类型沿用 `SideTabView` /
  `SideTabStyle` / `SideTabController` / `SideTabBuilder` 等原名。
* part 文件移入 `src/`；补 `material_ui` 依赖与冒烟测试。

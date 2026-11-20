## 0.0.1

* 从 `once_power/lib/widget/base/anchored_overlay` 迁移为独立包
  `flutter_anchored_overlay`，入口改为
  `package:flutter_anchored_overlay/flutter_anchored_overlay.dart`。
* 公开组件名保持不变：`Popover`、`SmartTooltip`、`PopoverController`、
  `SmartTooltipController` 以及 Tooltip 兼容类型 `TooltipDirection` /
  `TooltipAlign` / `TooltipPlacement` / `computeTooltipPlacement`。
* part 文件移入 `src/`；补 `material_ui` 依赖与冒烟测试。

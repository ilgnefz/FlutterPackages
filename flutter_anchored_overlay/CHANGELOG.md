## 未发布

* `Popover` 新增顶层 `padding`，用于设置气泡内容与边框的内边距（覆盖
  `PopoverStyle.padding`）；补充文档说明它与 `edgePadding`（视口边距）的区别。
* 气泡内容按 `PopoverShapeBorder` 轮廓裁剪，带方角背景 / 图片的 content 不再
  露出圆角外；箭头与阴影保持原样。

## 0.0.1

* 从 `once_power/lib/widget/base/anchored_overlay` 迁移为独立包
  `flutter_anchored_overlay`，入口改为
  `package:flutter_anchored_overlay/flutter_anchored_overlay.dart`。
* 公开组件名保持不变：`Popover`、`SmartTooltip`、`PopoverController`、
  `SmartTooltipController` 以及 Tooltip 兼容类型 `TooltipDirection` /
  `TooltipAlign` / `TooltipPlacement` / `computeTooltipPlacement`。
* part 文件移入 `src/`；补 `material_ui` 依赖与冒烟测试。

## 1.0.2

* `DropdownStyle` 新增 `itemPadding`（默认水平 10）：控制下拉栏选项里文字 /
  打勾图标到选项行外框的距离。此前这层是硬编码的，只能改 `padding`（选项行
  到面板）。`TextDropdown` 与 `AnchoredDropdown` 的默认行渲染都读它。

## 1.0.1

* `DropdownStyle` 新增 `fieldPadding`（默认水平 12）：控制触发器里文字 / 箭头
  到边框的距离；`TextDropdown` 与 `AnchoredDropdownField` 都读它，后者仍可用
  自己的 `padding` 参数覆盖。

## 1.0.0

首个版本。从 `once_power` 的 `lib/widget/base/dropdown/` 抽成独立包，源码与
行为都保持原样，只做了脱钩：

* `TextDropdown<T>`：内置字段 + 连体下拉列表，单一进度值驱动裁切 / 位移 /
  淡入 / 行内容 / 箭头 / 阴影，四角全程恒定。
* `AnchoredDropdown<T>`：任意 Widget 当触发器，面板独立宽度、5 种水平对齐、
  边缘自动夹取，下方放不下自动翻到上方。
* 三种揭示动画：`unfold`（默认）/ `topLeftToBottomRight` /
  `topRightToBottomLeft`；`reduceMotion` 走 120ms 纯淡入淡出。
* `DropdownStyle`：圆角 / 间距 / 行高 / 阴影 / 全部颜色，`of(context)` 跟随
  `ThemeData.brightness`，`copyWith` 可单点覆盖。
* `AnchoredDropdownField` / `AnchoredDropdownArrow`：可选便捷件。
* 脱钩项：`DropdownStyle.dark()` 不再 import 宿主的 `AppColors`，把原来那组
  颜色（`#211F26` / `#36343B` / `#49454F` / `#E6E1E5` / `#938F99`）写成字面量，
  外观与迁移前逐值一致。
* 13 条测试：两个门面的展开 / 选中 / 禁用 / 回调、`initialOpen`、
  `menuBuilder`、`DropdownStyle.of` 的明暗切换、宽度解析、三种裁切路径。

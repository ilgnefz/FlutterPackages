# Flutter 组件库

一组小巧、可独立使用的 Flutter 组件包。每个包都有自己的 `README.md`（用法、参数、行为细节）和测试。

## 组件

| 包                                                             | 说明                                                                                                                                       | 版本  |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ----- |
| [`flutter_anchored_overlay`](flutter_anchored_overlay)         | 锚定浮层与智能提示气泡（popover / tooltip），一套 overlay 两种预设                                                                         | 0.0.1 |
| [`flutter_calendar`](flutter_calendar)                         | 单月日期选择：日期输入框、日历面板、年份选择，以及带上下左右定位的 `showDatePicker()`                                                      | 0.2.2 |
| [`flutter_color_picker`](flutter_color_picker)                 | Material 颜色选择器：饱和度 / 明度框、色相滑块、十六进制输入，另带锚定按钮和 `showColorPicker()`                                           | 0.0.1 |
| [`flutter_context_menu`](flutter_context_menu)                 | 级联右键菜单：任意层级嵌套、靠边自动换向、键盘导航、展开动画                                                                               | 0.8.1 |
| [`flutter_dropdown`](flutter_dropdown)                         | 下拉菜单：`TextDropdown`（自带输入框 + 列表）与 `AnchoredDropdown`（任意组件当触发器、面板锚在旁边），三种展开动画                         | 1.0.6 |
| [`flutter_multi_select_reorder`](flutter_multi_select_reorder) | 多选拖拽排序列表与网格                                                                                                                     | 0.0.1 |
| [`flutter_notification`](flutter_notification)                 | 全局应用内通知：静态 `NotificationCenter`、挂在 `MaterialApp.builder` 上的 `NotificationHost`、六个方位、自动消失 + 悬停暂停、可更新的句柄 | 0.4.1 |
| [`flutter_side_anchor_nav`](flutter_side_anchor_nav)           | 左侧标签栏 + 滚动联动的锚定导航，点标签滚到对应区块                                                                                        | 0.0.1 |
| [`flutter_split_pane`](flutter_split_pane)                     | 可拖拽分栏布局：比例控制器、键盘调整尺寸、可自定义分隔条                                                                                   | 0.0.1 |
| [`flutter_time_picker`](flutter_time_picker)                   | 紧凑时间选择器：左边直接输入、右边双圈表盘（外圈分 / 内圈时），不是全屏对话框                                                              | 0.2.1 |
| [`flutter_treeview`](flutter_treeview)                         | 树形视图：经典单选树 + 级联勾选树（父节点三态、箭头在右侧）                                                                                | 0.1.1 |

所有包都基于 [`material_ui`](https://pub.dev/packages/material_ui)。

## 示例代码

每个组件的完整演示示例（左侧导航逐项切换、每例带标题和说明）都在独立工程里：

[https://github.com/ilgnefz/flutter_custom_component](https://github.com/ilgnefz/flutter_custom_component)

该工程同时演示了上面这些包以及若干通用组件（折叠按钮、图标切换、路径变形、数字步进、文字省略、级联菜单等）。

/// 一套揭示式下拉组件，**一个 import 同时用两个门面**：
///
/// ```dart
/// import 'package:flutter_dropdown/flutter_dropdown.dart';
///
/// TextDropdown<String>(...);     // 内置字段 + 连体列表，从贴边揭开
/// AnchoredDropdown<int>(...);    // 任意 Widget 当触发器，面板锚定在旁边
/// ```
///
/// 两者都按「选项值的类型」泛型：`TextDropdown<T>` / `AnchoredDropdown<T>`。
/// `value` / `onChanged` 用的是 `T` 本身，显示文字由 item 的 `label` 决定，
/// 所以 enum、数字、自定义对象都能直接当值用，不必先转成字符串。
///
/// ## 外观：两类 style，各管一块
///
/// * [DropdownFieldStyle] —— **外面显示的触发器**（宽 / 高 / 圆角 / 边框 /
///   内边距 / 文字样式）。只有内置字段的 [TextDropdown] 需要；
///   [AnchoredDropdown] 的触发器是外部传入的 Widget，样式由调用方自己管。
/// * [DropdownItemStyle] —— **下拉面板 + 选项行**（面板宽度 / 最大高度 /
///   与触发器的间距 / 行高 / 行间距 / 圆角 / 阴影 / 全部颜色 / 选项文字样式）。
///   两个门面共用。
///
/// 单项的 [TextDropdownItem.textStyle] 用 `merge` 覆盖组件级选项样式。
///
/// 两者不传 style 时分别取 `XxxStyle.of(context)`，按 `ThemeData.brightness`
/// 在 light / dark 之间自动切换；只改几项用 `.copyWith(...)`。
///
/// ## 两个门面怎么选
///
/// | | [TextDropdown] | [AnchoredDropdown] |
/// |---|---|---|
/// | 触发器 | 组件内部画的字段 | 外部传入的任意 Widget |
/// | 字段与列表 | 连体，共享一个裁切框、四角全程恒定 | 分离，面板是独立浮层 |
/// | 布局 | 等宽，只上下翻转 | 独立宽度、5 种水平对齐 |
/// | 揭示方式 | 单一进度 p 的贴边揭开 | unfold / 两种斜向，共三种 |
///
/// 两者都用 `OverlayPortal + LayerLink` 浮出（不用 `Stack`：父级 hitTest 会因为
/// 点落在自身尺寸之外而拒绝下沉，选项会点不到），并且都遵循「一个进度 p 驱动
/// 所有部件」：面板始终保持完整尺寸、不缩放内容、阴影画在裁切层之外随 p 渐强。
///
/// ## 目录约定（照 pub.dev 的 Dart 包惯例）
///
/// `lib/flutter_dropdown.dart` 是唯一公开入口，`lib/src/` 是实现细节：外部只
/// import 入口，之后内部文件怎么拆都不会破坏调用方。
library;

export 'src/anchored_dropdown.dart';
export 'src/text_dropdown.dart';

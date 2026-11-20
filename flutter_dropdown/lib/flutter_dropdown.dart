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
/// 文字样式分两层：`TextDropdown.textStyle` 管触发器和全部选项，
/// `TextDropdownItem.textStyle` 只覆盖某一项（merge 叠加）。
///
/// ## 外观与明暗主题
///
/// 两个门面共用 [DropdownStyle]（圆角 / 间距 / 内边距 / 行高 / 阴影 / 全部颜色）。
/// 两者不传 `style` 时都用 `DropdownStyle.of(context)`，按
/// `ThemeData.brightness` 在 `DropdownStyle.light()` 与
/// `DropdownStyle.dark()` 之间自动切换；想只改几项用
/// `DropdownStyle.of(context).copyWith(...)`。
///
/// [TextDropdown] 的高度、圆角、边框色、选项间距、鼠标光标都是构造参数，
/// 见它的类文档示例。
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

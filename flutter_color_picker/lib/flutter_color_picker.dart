/// 颜色选择面板：饱和度-明度方块 + 色相条 +（可选）透明度条 + 当前色 + hex
/// 输入，另带「点色块弹出面板」的组合和命令式弹出。
///
/// **传进来用 `Color`，回调出去是 `int`**：`onChanged` / `onChangeEnd` 的参数
/// 都是 `0xAARRGGBB`（代码里写 `Color(0xFF2B7FFF)` 的那个数，等价
/// `color.toARGB32()`），存配置、拼代码都直接能用；要回给 `value` 就
/// `Color(argb)`。
///
/// ```dart
/// import 'package:flutter_color_picker/flutter_color_picker.dart';
///
/// // 1) 直接嵌在布局里
/// ColorPicker(
///   value: Color(_argb),
///   showOpacity: true,                          // 需要调透明度就打开
///   onChanged: (int argb) => setState(() => _argb = argb),
///   onChangeEnd: (int argb) => save(argb),      // 松手 / 提交时一次
/// );
///
/// // 2) 一个色块点开面板
/// ColorPickerButton(
///   initialColor: Color(_argb),
///   onChanged: (int argb) => setState(() => _argb = argb),
/// );
///
/// // 3) 自己的按钮调弹出
/// IconButton(
///   icon: const Icon(Icons.palette_outlined),
///   onPressed: () => showColorPicker(
///     context,
///     color: Color(_argb),
///     onChanged: (int argb) => setState(() => _argb = argb),
///   ),
/// );
/// ```
///
/// 包内只有 Flutter（和 Material / `material_ui`）依赖：弹层由 `PopoverHost`
/// 自己实现，不需要 `anchored_overlay` 之类的外部浮层库。
library;

export 'src/color_picker.dart' show ColorPicker;
export 'src/color_picker_button.dart' show ColorPickerButton;
export 'src/color_picker_popup.dart' show ColorPickerPopup, showColorPicker;
export 'src/hex.dart' show ColorHexFormat, colorToHex, parseHexColor;
export 'src/popover_host.dart'
    show ColorPickerAlign, ColorPickerPlacement, PopoverHost, PopoverHostState;

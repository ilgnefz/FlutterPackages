## 未发布

* **透明度**：新增 `ColorPicker.showOpacity`（默认 `false`，行为不变）。
  打开后色相条下面多一条透明度条（棋盘格 + 「全透明 → 当前色」渐变），
  hex 输入框右侧显示百分比读数；hex 文本变成带 alpha 的写法
  （`#RRGGBBAA` / `0xAARRGGBB`），输入八位写法也能改透明度。
  `showOpacity: false` 时不画透明度条、输入框里的 alpha 也被丢掉，没有任何
  入口能改透明度。当前色圆点垫上棋盘格，半透明时能看出透了多少。
* `ColorPickerButton` / `showColorPicker` 同步新增 `showOpacity`。
* **hex 输入框聚焦时整体选中**：点进去直接打字就是整段替换；已聚焦后再点
  一次是正常摆光标。
* `colorToHex` / `parseHexColor` 新增 `includeAlpha` 参数（默认 `false`，
  保持原来的「丢掉 alpha」行为）。

## 0.0.1

* 从 `color_picker` 迁移为 `flutter_color_picker`，入口改为
  `package:flutter_color_picker/flutter_color_picker.dart`。公开组件名
  （`ColorPicker` / `ColorPickerButton` / `showColorPicker` 等）保持不变。

## 1.0.0

首个版本，从 `custom_compent/packages/color_picker`（当时的包名是
`color_picker_panel`）迁移过来，包名改为 `color_picker`，入口是
`package:color_picker/color_picker.dart`。

* `ColorPicker`：饱和度-明度方块 + 色相条 + 当前色预览 + hex 输入；受控 /
  非受控两种用法；内部以 `HSVColor` 为真值，拖到纯黑不丢色相。
* **回调参数是 `int`（`0xAARRGGBB`）**：`onChanged` / `onChangeEnd` 直接给
  `0xFF2B7FFF` 这个数（等价 `color.toARGB32()`），存配置、拼代码直接可用；
  `value` / `initialColor` / `showColorPicker(color:)` 仍收 `Color`
  （能直接给 `Colors.xxx`），还原用 `Color(argb)`。
* `ColorPickerButton`：色块 + 点击弹出面板，`child` 可换外观，`mouseCursor`
  可换鼠标指针。
* 拖动改由 pointer 事件驱动（原先用 `GestureDetector` 的 pan）：按下立即生效、
  拖出面板边界继续跟随、在 `ListView` 等可滚动容器里也不会被滚动手势抢走，
  解决“圆环不跟手、松手才跳到位”。
* `showColorPicker`：命令式弹出，任意按钮都能调，返回的 `ColorPickerPopup`
  可 `close()` / 查 `isOpen`；同时只保留一个弹层。
* `PopoverHost` + `resolvePopoverOffset`：零第三方依赖的锚定浮层（`OverlayEntry`
  + `RenderBox` 坐标换算），放不下自动翻转并夹进视口。
* `ColorHexFormat` / `colorToHex` / `parseHexColor`：`#RRGGBB` 与
  `0xFFRRGGBB` 两种写法互转，`0xAARRGGBB` 输入只取 RGB。
* 25 条测试覆盖手势、int 回调、hex 提交、格式切换、鼠标指针、弹层关闭与翻转定位。

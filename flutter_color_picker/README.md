# flutter_color_picker

Material 风格的颜色选择器：饱和度-明度方块 + 色相条 +（可选）透明度条 +
当前色 + hex 输入，另带「点色块弹出面板」的组合和命令式弹出。

**只依赖 Flutter（和 `material_ui`）**，弹层自己实现（`OverlayEntry` +
`RenderBox` 坐标换算），不依赖 `anchored_overlay` 之类的外部浮层库。

## 回调给的是 int（`0xAARRGGBB`）

传进来用 `Color`（能直接给 `Colors.xxx` / 主题色），**回调出去是 `int`**：
`onChanged` / `onChangeEnd` 的参数就是代码里 `Color(0xFF2B7FFF)` 的那个数，
等价 `color.toARGB32()`。存配置、拼代码直接用它，要变回颜色就 `Color(argb)`。

```dart
int _argb = 0xFF2B7FFF;

ColorPicker(
  value: Color(_argb),
  onChanged: (int argb) => setState(() => _argb = argb),
  onChangeEnd: (int argb) => save(argb),   // 落库用这个
);
```

> `int` 打印出来是十进制：纯红 `0xFFFF0000` 会显示成 `4294901760`，是同一个数。
> 要看十六进制就 `value.toRadixString(16).toUpperCase()`（补到 8 位），
> 要常量写法就 `'0x${value.toRadixString(16).padLeft(8, '0')}'`。

## 用法

```dart
import 'package:flutter_color_picker/flutter_color_picker.dart';

int _argb = 0xFF2B7FFF;

// 1) 一个色块，点开弹面板
ColorPickerButton(
  initialColor: Color(_argb),
  onChanged: (int argb) => setState(() => _argb = argb),
);

// 2) 面板直接嵌在布局里
ColorPicker(
  value: Color(_argb),                            // 不传 = 非受控，用 initialColor
  showOpacity: true,                             // 要调透明度就打开，默认关
  onChanged: (int argb) => setState(() => _argb = argb),
  onChangeEnd: (int argb) => save(argb),          // 松手 / 提交时一次
);

// 3) 自己的按钮调弹出（最灵活）
IconButton(
  icon: const Icon(Icons.palette_outlined),
  onPressed: () => showColorPicker(
    context,                                      // 传按钮自己的 context
    color: Color(_argb),
    onChanged: (int argb) => setState(() => _argb = argb),
  ),
);
```

## 自定义按钮弹出：`showColorPicker`

不要求触发器是 `ColorPickerButton` —— 按钮、菜单项、表格单元格都能调。
`context` 只用来**定位**（取它的矩形当锚点）和找 `Overlay`，所以要传触发按钮
自己的 context（`Builder` 里那个，或 `State` 的 `context`），别传页面根
context，那会拿整页的矩形去算落点。

```dart
ColorPickerPopup? _popup;
int _argb = 0xFF2B7FFF;

// 在鼠标位置弹出（anchorRect 用全局坐标）
_popup = showColorPicker(
  context,
  color: Color(_argb),
  anchorRect: Rect.fromLTWH(event.position.dx, event.position.dy, 0, 0),
  placement: ColorPickerPlacement.top,
  hexFormat: ColorHexFormat.flutterArgb,
  onChanged: (int argb) => setState(() => _argb = argb),
  onChangeEnd: (int argb) => save(argb),
);

_popup?.close();          // 主动收起
_popup?.isOpen;           // 还开着吗
```

同时只留一个弹层：再调一次会先把上一个收掉。点空白处、按 Esc 也会收起。

**返回值可以不接。** 用户自己点外面 / 按 Esc 就关了，不用为了能关而存一个
`ColorPickerPopup?` 字段；接住它只是为了在**代码里**主动关：

```dart
onPressed: () => showColorPicker(context, ...),   // 常见写法，返回句柄丢掉

// 需要在代码里关时才接：
final ColorPickerPopup popup = showColorPicker(context, ...);
popup.close();   // 「确定」按钮、切页面、另一个按钮也来管它
popup.isOpen;    // 还开着吗
```

`ColorPickerButton` 的 `child` 也能换触发器，但那只换**外观**——点击仍由
`ColorPickerButton` 接管，child 里别再挂 `onPressed` / `onTap`，否则它的手势
会赢下点击、面板打不开。需要「自己的按钮自己控制」就用 `showColorPicker`。

## 鼠标指针

| 位置 | 参数 |
|---|---|
| `ColorPickerButton` 触发器 | `mouseCursor`（不传：启用时手型、禁用时箭头） |
| 面板（SV 方块 + 色相条） | `ColorPicker.mouseCursor`（不传：不覆盖系统默认） |

```dart
ColorPickerButton(mouseCursor: SystemMouseCursors.grab);
ColorPicker(mouseCursor: SystemMouseCursors.precise);
```

## 弹层行为

| 行为 | 说明 |
|---|---|
| 位置 | 默认在触发器下方、左对齐；下方放不下自动翻到上方，最后夹进视口 |
| 关闭 | 点空白处、按 Esc、再点一次触发器 |
| 不自动收起 | 拖动中每次松手都算一次结束，自动关会打断连续调色 |
| 主题 | 卡片用 `colorScheme.surface`，可用 `panelColor` 覆盖 |

位置与外观参数：`placement`（`top` / `bottom` / `left` / `right`）、
`align`（`start` / `center` / `end`）、`panelWidth`、`panelPadding`、
`panelRadius`、`panelColor`。

## 颜色状态

内部真值是 `HSVColor` 而不是 `Color`：饱和度或明度为 0（纯灰 / 纯黑）时
`Color` 里已经看不出色相，来回换算会把色相条拽回红色。现在拖到纯黑时保留
上一次的色相，再拖回来还是原来那个色系。

`onChanged` 在拖动过程中按帧触发（实时预览），`onChangeEnd` 在松手 / hex
提交时触发一次（落库）。两者的参数都是 `0xAARRGGBB` 的 int。

拖动直接用 pointer 事件驱动（不走 `GestureDetector` 的 pan）：按下就生效、
拖出面板边界继续跟着走、放在 `ListView` 里也不会被滚动手势吞掉。**面板里的
滑块/圆环由组件自己实时画，跟 `onChanged` 无关**——所以 `onChanged` 里别做
重活（写文件、发请求、整页 `setState`），否则每帧都被拖慢，手感会变成
“松手才跳过去”；要落库用 `onChangeEnd`。

## 透明度

默认**不处理透明度**：面板只画不透明色，`#RRGGBBAA` 里的 alpha 会被丢掉。
要调透明度就传 `showOpacity: true`：

```dart
ColorPicker(
  showOpacity: true,
  value: Color(0x802B7FFF),        // 半透明的蓝
  onChanged: (int argb) => setState(() => _argb = argb),  // 0x802B7FFF
);

ColorPickerButton(showOpacity: true);       // 弹出面板同理
showColorPicker(context, showOpacity: true);
```

打开后：

| 位置 | 变化 |
|---|---|
| 色相条下面 | 多一条透明度条（棋盘格 + 「全透明 → 当前色」渐变），可拖 |
| hex 输入框右边 | 显示当前透明度百分比（`100%` / `50%` / `0%`） |
| hex 文本 | 带上 alpha：`#RRGGBBAA`、`0xAARRGGBB`（直接粘进代码不丢透明度） |
| hex 输入 | 写八位（`#RRGGBBAA` / `0xAARRGGBB`）就能改透明度 |
| 当前色圆点 | 底下垫棋盘格，看得出透了多少 |

关掉 `showOpacity` 时这些全都不存在——包括输入框：八位 hex 的 alpha 会被丢掉、
按不透明处理，所以**关掉之后没有任何入口能改透明度**。

回调参数始终是 `0xAARRGGBB`：透明度打开时高两位就是当前 alpha，
关掉时保持颜色自带的值（默认 `FF`）。

## hex 输入

支持 `#RGB`、`#RRGGBB`、`RRGGBB`、`#RRGGBBAA`、`0xRRGGBB`、`0xAARRGGBB`；
回车、失焦、点面板都会提交；非法输入恢复成当前颜色；输入过程中不会被拖动
回写覆盖。

**输入框聚焦时会整体选中**：点进去直接打字就是整段替换，不用先手动全删；
已经聚焦后再点一下则是正常摆光标，可以改某一位。

显示格式由 `hexFormat` 决定：

```dart
ColorPicker();                                      // #2B7FFF
ColorPicker(hexFormat: ColorHexFormat.flutterArgb); // 0xFF2B7FFF，可直接粘进 Color(...)
ColorPicker(showOpacity: true);                     // #2B7FFF80
ColorPicker(showOpacity: true, hexFormat: ColorHexFormat.flutterArgb);
                                                    // 0x802B7FFF
```

要粘进 Flutter 代码就传 `ColorHexFormat.flutterArgb`；输入时两种写法都认，
提交后按当前格式归一。颜色没变、只是写法不同时只归一文本，不会多发一次
`onChangeEnd`。

`colorToHex(Color, {format, includeAlpha})` / `parseHexColor(String, {includeAlpha})`
也导出了，单独用也行：

```dart
colorToHex(const Color(0x802B7FFF), includeAlpha: true);    // #2B7FFF80
parseHexColor('#2B7FFF80', includeAlpha: true);             // Color(0x802B7FFF)
parseHexColor('#2B7FFF80');                                 // Color(0xFF2B7FFF)，默认丢 alpha
```

## 复用弹层

`PopoverHost` 是包内那个弹层本身，可以拿去做别的弹层：

```dart
PopoverHost(
  contentBuilder: (context) => const Text('任意内容'),
  width: 200,
  child: GestureDetector(
    onTap: () => key.currentState?.toggle(),
    child: const Text('点我'),
  ),
);
```

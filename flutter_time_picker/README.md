# flutter_time_picker

紧凑的时间选择器：**左边的时间可以直接敲，右边是双圈表盘**（外圈改分、内圈改时），
不是 Material 那种全屏对话框。

和 `flutter_calendar` 同一套做法：一块小面板，可以就地弹在按钮旁边，也能直接
嵌进自己的布局。

## 和 Material `TimePicker` 的差别

| | Material `TimePicker` | 这个包 |
|---|---|---|
| 形态 | 全屏对话框（约 328 × 512） | 小面板（默认 300 宽，约 224 高） |
| 输入方式 | 表盘 / 键盘两种模式，靠左下角按钮切换 | **没有切换按钮**：时间一直在左边，点一下就能敲 |
| 表盘在调什么 | 靠顶部的小时 / 分钟两个圆角块切 | **双圈同时可用**：外圈改分、内圈改时，不用先说「我要调哪一个」 |
| 24 小时制 | 内圈 `13 ~ 00` | 内圈仍是 12 小时表盘，另用「上午 / 下午」补那 12 小时 |
| 返回 | `Future<TimeOfDay>` | 同样是 `Future<TimeOfDay>` |

## 三件套

| 入口 | 用途 |
|---|---|
| `TimePickerField` | 带标题 / 时钟图标的输入框，点一下在旁边弹面板 |
| `TimePickerPanel` | 面板本体，也可以单独嵌进自己的布局 |
| `showTimePicker` | 给任意按钮调用，按 `placement` 弹在上下左右 |

```dart
import 'package:flutter_time_picker/flutter_time_picker.dart';

// 1) 输入框 + 弹窗
TimePickerField(
  label: '时间',
  initialTime: const TimeOfDay(hour: 9, minute: 30),
  onChanged: (TimeOfDay time) => print(time),
)

// 2) 任意按钮旁边弹（任何 Builder 的 context 都行）
ElevatedButton(
  onPressed: () async {
    final TimeOfDay? picked = await showTimePicker(
      context,
      initialTime: TimeOfDay.now(),
      placement: TimePickerPlacement.top,
    );
    print(picked);
  },
  child: const Text('选择时间'),
)

// 3) 直接嵌进布局
TimePickerPanel(
  initialTime: const TimeOfDay(hour: 9, minute: 30),
  onChanged: (TimeOfDay time) => setState(() => _time = time),
)
```

`showTimePicker` 和 Material 的同名函数重名：同一个文件里还要用系统那个就
`import 'package:material_ui/material_ui.dart' hide showTimePicker;`，或者改用
别名 `showCompactTimePicker`。

## 面板行为

- **左边的时间一直可编辑**：点小时那两位直接敲 `0~23`（24 小时制）或 `1~12`
  （12 小时制），点分钟敲 `0~59`；回车 / 失焦自动补零并夹到合法范围（敲 `75`
  会变成 `59`）。正在编辑的那段有浅色底，表盘上对应那一圈是实心点。
- **表盘是双圈的**，照着真表盘来：
  - 外圈 `00 05 … 55` 是分钟，点 / 拖都行，指针能停在**任意一分钟**（不是只能
    选 5 的倍数）；
  - 内圈 `12 1 2 … 11` 是小时，也就是表面的小时盘；
  - 两圈**同时可点**：点内圈就改小时、点外圈就改分钟，不用先切「现在调什么」。
    正在调的那圈是实心点 + 指针杆，另一圈留一个空心点，两个值都看得见。
  - 按住拖动时**指针跟着手指跨圈**：从外圈滑进内圈就改成调小时，滑回外圈又改回
    分钟，不用抬手重按；左边高亮的那段（时 / 分）也跟着切。分界在两圈数字中间
    （0.67R），正中心不响应（角度没有意义）。
- **「上午 / 下午」常驻在时间下面**，切换时不动分钟。24 小时制也有它 ——
  内圈是 12 小时表盘，`12` 点方向到底是 `00` 还是 `12`、`3` 到底是凌晨还是
  下午，全靠这两段区分（168 直径的表盘塞 24 个数字会糊成一圈点）。
- 传了 `onSubmit` / `onCancel` 才有底部那行「取消 / 确定」；都不传就是纯面板
  （适合嵌在页面里，靠 `onChanged` 实时拿值）。

## 尺寸与文案

所有尺寸 / 配色 / 字号都在 `TimePickerStyle` 里：

```dart
TimePickerPanel(
  initialTime: const TimeOfDay(hour: 9, minute: 30),
  style: const TimePickerStyle(
    width: 300,            // 面板宽度
    radius: 12,
    dialSize: 168,         // 表盘直径（两圈都跟着缩）
    padding: EdgeInsets.fromLTRB(14, 12, 12, 8),
    dialHandColor: null,   // 默认主题主色
    dialLabelStyle: TextStyle(fontSize: 11.5),      // 外圈（分）数字
    dialInnerLabelStyle: TextStyle(fontSize: 10),   // 内圈（时）数字
    timeTextStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
    fieldWidth: 40,        // 单个数字框宽
    fieldHeight: 42,
    meridiemTextStyle: TextStyle(fontSize: 11.5),
    actionTextStyle: TextStyle(fontSize: 13), // 默认正常字重
    mouseCursor: SystemMouseCursors.click,
  ),
)
```

文案在 `TimePickerLabels` 里，怎么换语言见下一节 [国际化](#国际化)。

## 国际化

面板里所有**会变的字**都收在 `TimePickerLabels` 里，一共六个：

| 成员 | 出现的位置 | 中文默认 |
|---|---|---|
| `am` / `pm` | 时间下面的上午 / 下午两段 | `上午` / `下午` |
| `hour` / `minute` | **读屏语义标签**（界面上不显示「时 / 分」小字） | `时` / `分` |
| `cancel` / `confirm` | 底部两个按钮 | `取消` / `确定` |

内置两份：`TimePickerLabels.zh`（默认实现）和 `TimePickerLabels.en`（`AM/PM/Cancel/
OK`）。不传 `labels` 时按当前 locale 自动选：`TimePickerLabels.of(context)` →
`resolve()`，**只有 `languageCode == 'en'` 用英文，其它（含拿不到 locale）一律中文**。

### 1. 先把 locale 配对，否则中文会显示成英文

`MaterialApp` 的默认 locale 是 `en_US`，所以「什么都没配」反而拿到英文。三样要一起配：

```dart
import 'package:material_ui/material_ui.dart';

MaterialApp(
  locale: const Locale('zh'),
  supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
)
```

- `locale` 只是「我想要什么」，最终还得在 `supportedLocales` 里能找到，否则解析时
  退回默认的 `[en_US]` —— 时间选择器还是英文。
- `localizationsDelegates` 决定 Material 自己的组件（文本选择菜单、tooltip、语义）
  用哪种语言。不配的话 debug 下会报
  `This application's locale, zh, is not supported by all of its localization delegates`。
- `GlobalMaterialLocalizations` 由 `material_ui` 直接导出（它是
  `flutter_localizations` 的一份 fork），**不用**再往 `pubspec.yaml` 里加
  `flutter_localizations`。用官方 `package:flutter/material.dart` 的项目才需要：

  ```yaml
  dependencies:
    flutter_localizations:
      sdk: flutter
  ```

### 2. 加第三门语言（以日文为例）

继承 `TimePickerLabels`，覆盖那六个 getter，再写一个按 locale 挑的工厂：

```dart
class JapaneseTimeLabels extends TimePickerLabels {
  const JapaneseTimeLabels();

  @override
  String get am => '午前';
  @override
  String get pm => '午後';
  @override
  String get hour => '時';
  @override
  String get minute => '分';
  @override
  String get cancel => 'キャンセル';
  @override
  String get confirm => 'OK';
}

/// 内置的 resolve() 只认 en，其它语言要自己映射。
TimePickerLabels labelsOf(BuildContext context) {
  return switch (Localizations.maybeLocaleOf(context)?.languageCode) {
    'ja' => const JapaneseTimeLabels(),
    'en' => TimePickerLabels.en,
    _ => TimePickerLabels.zh,
  };
}
```

然后传给三个入口（都接受 `labels:`）：

```dart
TimePickerField(
  label: '時刻',              // 这个不在 labels 里，见下一节
  hint: '時刻を選択',         // 同上
  initialTime: TimeOfDay.now(),
  labels: labelsOf(context),
  panelStyle: const TimePickerStyle(),
)

showTimePicker(
  context,
  initialTime: TimeOfDay.now(),
  labels: labelsOf(context),
)

TimePickerPanel(
  initialTime: TimeOfDay.now(),
  labels: labelsOf(context),
)
```

`showTimePicker` 只是把 `labels` 透传给面板；用别名 `showCompactTimePicker` 时一样。

### 3. 只给某一处固定语言

不想动全局 locale，就直接指定一份：

```dart
TimePickerPanel(
  initialTime: TimeOfDay.now(),
  labels: TimePickerLabels.en, // 这块面板永远英文
)
```

### 4. 不在 `TimePickerLabels` 里的文案

这几个要自己传，国际化时别忘了：

| 位置 | 参数 | 默认 |
|---|---|---|
| `TimePickerField` 上方的标题 | `label` | `null`（不显示） |
| `TimePickerField` 没值时的占位 | `hint` | `选择时间` |
| `TimePickerField` 输入框里 12 小时制显示 | 由 `use24HourFormat` + `labels.am`/`pm` 拼成 | — |

另外 `formatTimeOfDay(time, use24HourFormat: false)` 只给 `9:30` 这样的数字部分，
**不带上下午**——因为不同语言里上下午的位置不一样（中文在数字前，英文常在
后面）。要显示完整时间就自己拼：

```dart
final String text = '${labels.am} ${formatTimeOfDay(time, use24HourFormat: false)}';
```

### 5. 常见坑

- **显示 `AM / PM / OK`**：没配 `locale` / `supportedLocales`，`Material` 默认 `en_US`。
- **只有按钮变了、上午下午还是中文**：自写的 labels 忘了覆盖 `am` / `pm`。
- **读屏念「时 / 分」而不是本地词**：`hour` / `minute` 只用于 `Semantics`，界面上看
  不到；翻译时也要覆盖，否则无障碍走默认中文。
- **`TimePickerField` 上方还是中文「时间」**：那是 `label` 参数，不归 labels 管。
- **弹窗里没生效**：`TimePickerField` 会把 `labels` 透传给弹窗；但自己调
  `showTimePicker` 时记得那次调用也要传。

## 鼠标样式

`TimePickerStyle.mouseCursor`（默认 `SystemMouseCursors.click`）管表盘、
「上午 / 下午」和底部两个按钮；两个数字框保持文本框的 I 形光标（本来就是要
输入的）。`TimePickerField` 另有独立的 `mouseCursor`，`enabled: false` 时不用它。

## 导出

- `TimePickerField`、`TimePickerPanel`、`TimeDial`
- `TimePickerStyle`、`TimePickerLabels`
- `showTimePicker` / `showCompactTimePicker`
- `TimePickerPlacement`、`TimeDialMode`、`formatTimeOfDay`
- `kTimePickerPanelKey`、`kTimePickerHourFieldKey`、`kTimePickerMinuteFieldKey`、
  `kTimeDialKey`

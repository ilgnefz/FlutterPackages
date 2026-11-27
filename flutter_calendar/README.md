# flutter_calendar

单月日期选择器：日期输入框 + 月历面板 + 年份选择，另带一个可按上下左右定
位的 `showDatePicker()`。

**只依赖 Flutter（和 `material_ui`）**，弹层自己用 `OverlayEntry` +
`CustomSingleChildLayout` 实现，不依赖外部浮层库。

## 用法

```dart
import 'package:flutter_calendar/flutter_calendar.dart';
```

### 1. 日期输入框

标题在上、日期在左、日历图标在右，点一下就在旁边弹出面板：

```dart
CalendarDateField(
  label: 'Date',
  initialDate: DateTime(2026, 11, 25),
  placement: CalendarPlacement.bottom, // 弹窗方向
  firstDate: DateTime(2026, 1, 1),      // 可选范围（可选）
  lastDate: DateTime(2026, 12, 31),
  onChanged: (DateTime date) => print(date),
)
```

传 `value` 就是受控模式；传 `initialDate` 是初始值。显示格式默认是
`2026 / 11 / 25`（想换成 `2026年11月25日` 之类传 `formatDate`，见
[国际化](#国际化)），没有值时显示 `hint`。

### 2. 任意按钮调用 `showDatePicker`

传任何 `Builder` 的 `context` 都可以，它只拿这个组件的矩形当锚点：

```dart
ElevatedButton(
  onPressed: () async {
    final DateTime? picked = await showDatePicker(
      context,
      initialDate: DateTime(2026, 11, 25),
      placement: CalendarPlacement.right, // top / bottom / left / right
    );
    if (picked != null) print('选了 $picked');
  },
  child: const Text('选择日期'),
)
```

- 首选方向放不下时会自动翻到对面，仍放不下就夹回视口内。
- 点外部 / 按 Esc 关闭并返回 `null`；选中日期则关闭并返回那天 0 点。
- 同名冲突：本库的 `showDatePicker` 和 Material 的重名。同一个文件里还要用
  系统那个时，可以 `import 'package:flutter/material.dart' hide showDatePicker;`，
  或者改用本库的别名 `showCalendarDatePicker`。

### 3. 单独嵌面板

```dart
CalendarPanel(
  month: DateTime(2026, 11),
  selectedDate: DateTime(2026, 11, 25),
  onDateSelected: (DateTime date) => print(date),
  onMonthChanged: (DateTime month) => print(month),
)
```

## 面板行为

- **只显示一个月份**：6 × 7 网格。前后补格的邻月日期以浅灰显示（可用
  `showAdjacentDays: false` 关掉）；点它们**会翻到那个月并选中那天**，点哪天
  就是哪天。只想翻月、不选中就传 `selectAdjacentDays: false`。
- 点标题「2026年11月」在面板内展开 **年份列表**（3 列、可滚动），选完年份
  回到月视图；左右箭头切换月份，年份列表展开时切年份。
- 选中日期是主题色圆形 + 白字。
- `firstDate` / `lastDate` 之外的日期变灰且不可点，月份也不会翻出范围。
- 星期表头默认周一开始，可用 `weekStartsOnMonday: false` 改成周日开始（文案
  会跟着转一格）。

## 尺寸与文案

所有尺寸 / 间距 / 字号都在 `CalendarStyle` 里，组件本身不留写死的数字：

```dart
CalendarPanel(
  month: DateTime(2026, 11),
  style: const CalendarStyle(
    width: 268,          // 面板宽度
    radius: 12,
    cellHeight: 32,      // 一格多高（宽 = 宽度 / 7）
    dayCircleSize: 28,   // 选中圆点直径
    dayTextStyle: TextStyle(fontSize: 13),
    headerTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    weekdayTextStyle: TextStyle(fontSize: 11),
    navButtonSize: Size(30, 30),
    navIconSize: 20,
    navButtonStyle: IconButton.styleFrom(...), // 两颗翻月按钮
    mouseCursor: SystemMouseCursors.click,    // 可点部分的光标
  ),
)
```

翻月按钮就是标题右端那两颗 `IconButton`：位置 / 图标 / 尺寸 / 样式全部在
`CalendarStyle` 的 `navButtonStyle`、`navButtonSize`、`navIconSize`、
`previousIcon`、`nextIcon` 里，想加底色、换图标都改这里。

文案在 `CalendarLabels` 里（星期表头 + 年月 + 年份），怎么换语言见下一节
[国际化](#国际化)。

## 国际化

面板里所有**会变的字**都收在 `CalendarLabels` 里，一共三处：

| 成员 | 出现的位置 | 中文默认值 |
|---|---|---|
| `weekdays` | 星期表头（固定 7 个，从周一开始） | `周一 … 周日` |
| `monthYear(year, month)` | 标题上的年月 | `2026年11月` |
| `year(year)` | 展开年份列表后的每一行 | `2026年` |

内置两份：`CalendarLabels.zh`（默认实现）和 `CalendarLabels.en`。不传 `labels`
时按当前 locale 自动挑：`CalendarLabels.of(context)` → `resolve()`，**只有
`languageCode == 'en'` 用英文，其它（含拿不到 locale）一律中文**。

### 1. 先把 locale 配对，否则中文会被显示成英文

`MaterialApp` 的默认 locale 是 `en_US`，所以「什么都没配」的中文应用反而会拿到
英文文案。三样要一起配：

```dart
import 'package:material_ui/material_ui.dart';

MaterialApp(
  locale: const Locale('zh'),
  supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
)
```

- `locale` 只是「我想要什么」，最终还得在 `supportedLocales` 里能找到，否则解析
  时会退回默认的 `[en_US]` —— 日历仍然是英文。
- `localizationsDelegates` 决定 Material 自己的组件（文本选择菜单、tooltip、
  语义标签）用哪种语言。不配的话 debug 下会报
  `This application's locale, zh, is not supported by all of its localization
  delegates`。
- `GlobalMaterialLocalizations` 由 `material_ui` 直接导出（它是
  `flutter_localizations` 的一份 fork），所以**不用**再往 `pubspec.yaml` 里加
  `flutter_localizations`。用官方 `package:flutter/material.dart` 的项目才需要：

  ```yaml
  dependencies:
    flutter_localizations:
      sdk: flutter
  ```

### 2. 加第三门语言（以日文为例）

继承 `CalendarLabels`，覆盖那三个成员，再写一个按 locale 挑的工厂：

```dart
class JapaneseLabels extends CalendarLabels {
  const JapaneseLabels();

  @override
  List<String> get weekdays =>
      const <String>['月', '火', '水', '木', '金', '土', '日'];

  @override
  String monthYear(int year, int month) => '$year年$month月';

  @override
  String year(int year) => '$year年';
}

/// 自己的 locale → labels 映射。内置的 resolve() 只认 en，所以这里自己写。
CalendarLabels labelsOf(BuildContext context) {
  return switch (Localizations.maybeLocaleOf(context)?.languageCode) {
    'ja' => const JapaneseLabels(),
    'en' => CalendarLabels.en,
    _ => CalendarLabels.zh,
  };
}
```

然后把它传给用得着的入口（三处都接受 `labels:`）：

```dart
// 输入框（会一并传给弹出的面板）
CalendarDateField(
  label: '日付',
  hint: '日付を選択',
  initialDate: DateTime(2026, 11, 25),
  labels: labelsOf(context),
  formatDate: (DateTime d) => '${d.year}年${d.month}月${d.day}日',
)

// 直接弹面板
showDatePicker(context, initialDate: DateTime.now(), labels: labelsOf(context));

// 嵌在页面里的面板
CalendarPanel(
  month: DateTime(2026, 11),
  labels: labelsOf(context),
  onDateSelected: (DateTime date) => print(date),
)
```

### 3. 只给某一块固定语言

不想动全局 locale，就直接指定一份：

```dart
CalendarDateField(
  initialDate: DateTime(2026, 11, 25),
  labels: CalendarLabels.en, // 这个输入框永远是英文
)
```

### 4. 日期本身怎么显示

输入框里的 `2026 / 11 / 25` 是 `formatCalendarDate` 的固定格式。要按本地习惯
显示（`2026年11月25日`、`25/11/2026`、`Nov 25, 2026`），传 `formatDate`：

```dart
CalendarDateField(
  initialDate: DateTime(2026, 11, 25),
  labels: labelsOf(context),
  formatDate: (DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}'
      '/${d.day.toString().padLeft(2, '0')}',
)
```

`CalendarDateField` 还有两个**不在 `CalendarLabels` 里**、要自己传的文案：
`label`（输入框上方的标题）和 `hint`（没选日期时的占位，默认「选择日期」）。

### 5. 常见坑

- **显示英文**：没配 `locale` / `supportedLocales`，`Material` 默认 `en_US`。
- **只有星期变了、年月还是中文**：自写的 labels 忘了覆盖 `monthYear()`（它有
  默认实现，不覆盖就一直是 `2026年11月`）。
- **周起始日**：`weekdays` 固定从周一开始，`weekStartsOnMonday: false` 时组件
  自己把它转成周日开头，labels 里不用改顺序。
- **弹窗里没生效**：`CalendarDateField` 会把 `labels` 透传给弹窗；但如果是自己
  调 `showDatePicker`，记得那次调用也要传。

## 鼠标样式

`CalendarStyle.mouseCursor`（默认 `SystemMouseCursors.click`）统一管面板里**所有
能点的地方**：年月标题（`enableYearPicker` 打开时）、范围内的日期格子、年份列表
条目、两颗翻月按钮。

这里必须显式指定：`InkWell` 的默认光标是 `WidgetStateMouseCursor.adaptiveClickable`，
在桌面端（非 web）解析成**箭头**，所以不传的话点在日期上光标根本不变。

点不了的部分不会变小手：范围外的日期、范围到头时的翻月按钮（箭头还在，但翻不出
去）、关掉年份选择时的年月标题，都保持默认箭头。

```dart
CalendarStyle(mouseCursor: SystemMouseCursors.basic) // 想统一成箭头
```

`CalendarDateField` 有独立的 `mouseCursor`（同样默认小手），`enabled: false` 时
不用它；弹窗里面板的光标仍由 `panelStyle.mouseCursor` 控制。

## 导出

- `CalendarDateField`、`CalendarPanel`
- `CalendarStyle`、`CalendarLabels`
- `showDatePicker` / `showCalendarDatePicker`
- `CalendarPlacement`
- `formatCalendarDate`、`isSameCalendarDay`、`isDateInRange`、`isMonthInRange`
- `calendarDayKey(DateTime)`：日期格子 key（形如 `calendar-day-2026-11-25`）
- `kCalendarPanelKey`、`kCalendarYearGridKey`

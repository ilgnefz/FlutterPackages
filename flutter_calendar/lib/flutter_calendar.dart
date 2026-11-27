/// # flutter_calendar —— 单月日期选择器
///
/// 三件套：
///
/// | 入口 | 用途 |
/// |---|---|
/// | [CalendarDateField] | 带标题 / 日历图标的输入框，点一下在旁边弹面板 |
/// | [CalendarPanel] | 单月日历面板，也可以单独嵌进自己的布局 |
/// | [showDatePicker] | 给任意按钮调用，按 `placement` 弹在上下左右 |
///
/// 面板只显示**一个月份**：6 × 7 网格，前后补格的邻月日期以浅灰显示（可用
/// `showAdjacentDays` 关掉）。点邻月日期会翻到那个月并选中那天，只想要翻月就传
/// `selectAdjacentDays: false`。点标题在面板内展开年份列表，选完回到月视图。
///
/// 尺寸 / 字号 / 翻月按钮样式 / 光标在 [CalendarStyle] 里，星期表头与年月的
/// 文案在 [CalendarLabels] 里（默认按 locale：`en` 英文、其它中文）。
///
/// 桌面端光标默认是 `SystemMouseCursors.click`，作用于所有能点的地方（标题、
/// 范围内的日期、年份条目、翻月按钮）；点不了的地方保持箭头。
///
/// ```dart
/// import 'package:flutter_calendar/flutter_calendar.dart';
///
/// // 1) 输入框 + 弹窗
/// CalendarDateField(
///   label: 'Date',
///   initialDate: DateTime(2026, 11, 25),
///   onChanged: (DateTime date) => print(date),
/// )
///
/// // 2) 任意按钮旁边弹（任何 Builder 的 context 都行）
/// ElevatedButton(
///   onPressed: () async {
///     final DateTime? picked = await showDatePicker(
///       context,
///       initialDate: DateTime(2026, 11, 25),
///       placement: CalendarPlacement.top,
///     );
///     print(picked);
///   },
///   child: const Text('选择日期'),
/// )
/// ```
///
/// `showDatePicker` 与 Material 的同名函数重名：同一个文件里如果还要用系统
/// 那个，可以 `import 'package:flutter/material.dart' hide showDatePicker;`，
/// 或改用本库的别名 [showCalendarDatePicker]。
library;

export 'src/calendar_date_field.dart' show CalendarDateField;
export 'src/calendar_panel.dart'
    show CalendarPanel, kCalendarPanelKey, kCalendarYearGridKey;
export 'src/calendar_style.dart' show CalendarLabels, CalendarStyle;
export 'src/calendar_types.dart'
    show
        CalendarPlacement,
        calendarDayKey,
        formatCalendarDate,
        isDateInRange,
        isMonthInRange,
        isSameCalendarDay;
export 'src/date_picker_popup.dart' show showCalendarDatePicker, showDatePicker;

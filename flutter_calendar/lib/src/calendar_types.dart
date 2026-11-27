import 'package:material_ui/material_ui.dart';

/// 弹窗相对触发组件的位置。
enum CalendarPlacement {
  /// 显示在触发组件下方（空间不够会自动翻到上方）。
  bottom,

  /// 显示在触发组件上方（空间不够会自动翻到下方）。
  top,

  /// 显示在触发组件右侧（空间不够会自动翻到左侧）。
  right,

  /// 显示在触发组件左侧（空间不够会自动翻到右侧）。
  left,
}

/// 两个日期是否是同一天（只比年月日，不比时分秒）。
bool isSameCalendarDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 把日期格式化成 `2026 / 11 / 25`，和输入框里的显示保持一致。
String formatCalendarDate(DateTime date) {
  final String y = date.year.toString().padLeft(4, '0');
  final String m = date.month.toString().padLeft(2, '0');
  final String d = date.day.toString().padLeft(2, '0');
  return '$y / $m / $d';
}

/// 日期是否落在 [firstDate] ~ [lastDate] 之间（含边界）。
///
/// 只比较年月日；两个边界都可以为 null，表示不限。
bool isDateInRange(DateTime date, {DateTime? firstDate, DateTime? lastDate}) {
  final DateTime day = DateTime(date.year, date.month, date.day);
  if (firstDate != null &&
      day.isBefore(DateTime(firstDate.year, firstDate.month, firstDate.day))) {
    return false;
  }
  if (lastDate != null &&
      day.isAfter(DateTime(lastDate.year, lastDate.month, lastDate.day))) {
    return false;
  }
  return true;
}

/// 某个月（只看年月）里是否至少有一天落在可选范围内。
bool isMonthInRange(DateTime month, {DateTime? firstDate, DateTime? lastDate}) {
  final DateTime first = DateTime(month.year, month.month);
  final DateTime last = DateTime(month.year, month.month + 1, 0);
  if (firstDate != null &&
      last.isBefore(DateTime(firstDate.year, firstDate.month, firstDate.day))) {
    return false;
  }
  if (lastDate != null &&
      first.isAfter(DateTime(lastDate.year, lastDate.month, lastDate.day))) {
    return false;
  }
  return true;
}

/// 日期格子的 key，方便测试或外部高亮定位某一天。
///
/// 值形如 `calendar-day-2026-11-25`。
Key calendarDayKey(DateTime date) =>
    ValueKey<String>('calendar-day-${date.year}-${date.month}-${date.day}');

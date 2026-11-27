import 'package:material_ui/material_ui.dart';

/// 面板相对锚点的方向。
///
/// 和 `flutter_calendar` 的 `CalendarPlacement` 一一对应：首选方向放不下时会
/// 自动翻到对面，两边都不够就夹回视口。
enum TimePickerPlacement {
  /// 锚点上方。
  top,

  /// 锚点下方（默认）。
  bottom,

  /// 锚点左侧。
  left,

  /// 锚点右侧。
  right,
}

/// 面板内部当前在调哪一项。
enum TimeDialMode {
  /// 调小时。
  hour,

  /// 调分钟。
  minute,
}

/// 把 [time] 格式化成 `09:30`（24 小时制）或 `9:30`（12 小时制，不带上下午）。
///
/// 12 小时制下 `00:30` 得到 `12:30`、`13:05` 得到 `1:05`；上下午文案不在这里
/// 拼，交给 `TimePickerLabels.am` / `pm`（不同语言位置也不一样）。
String formatTimeOfDay(TimeOfDay time, {bool use24HourFormat = true}) {
  final String minute = time.minute.toString().padLeft(2, '0');
  if (use24HourFormat) {
    return '${time.hour.toString().padLeft(2, '0')}:$minute';
  }
  final int hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  return '$hour12:$minute';
}

/// # flutter_time_picker —— 紧凑时间选择器
///
/// 和 `flutter_calendar` 同一套做法：不是全屏对话框，而是一块小面板，可以就地
/// 弹出、也能直接嵌进自己的布局。相对 Material `TimePicker` 的差别：
///
/// * 没有「切换输入方式」的按钮——时间一直显示在**左边**，点一下就能直接敲数字；
/// * 右边的表盘是**双圈**：外圈改分、内圈改时，两圈同时可点，不用先选「现在调
///   什么」；
/// * 时间下面常驻「上午 / 下午」：内圈是 12 小时表盘，24 小时制也靠它决定
///   `03` 还是 `15`。
///
/// 三件套：
///
/// | 入口 | 用途 |
/// |---|---|
/// | [TimePickerField] | 带标题 / 时钟图标的输入框，点一下在旁边弹面板 |
/// | [TimePickerPanel] | 面板本体，也可以单独嵌进自己的布局 |
/// | [showTimePicker] | 给任意按钮调用，按 `placement` 弹在上下左右 |
///
/// ```dart
/// import 'package:flutter_time_picker/flutter_time_picker.dart';
///
/// // 1) 输入框 + 弹窗
/// TimePickerField(
///   label: '时间',
///   initialTime: const TimeOfDay(hour: 9, minute: 30),
///   onChanged: (TimeOfDay time) => print(time),
/// )
///
/// // 2) 任意按钮旁边弹
/// ElevatedButton(
///   onPressed: () async {
///     final TimeOfDay? picked = await showTimePicker(
///       context,
///       initialTime: TimeOfDay.now(),
///       placement: TimePickerPlacement.top,
///     );
///     print(picked);
///   },
///   child: const Text('选择时间'),
/// )
/// ```
///
/// 尺寸 / 字号 / 配色全在 [TimePickerStyle] 里，文案在 [TimePickerLabels] 里
/// （默认按 locale：`en` 英文、其它中文）。
///
/// `showTimePicker` 与 Material 的同名函数重名：同一个文件里如果还要用系统那个，
/// 可以 `import 'package:material_ui/material_ui.dart' hide showTimePicker;`，
/// 或改用本库的别名 [showCompactTimePicker]。
library;

export 'src/time_dial.dart' show TimeDial, kTimeDialKey;
export 'src/time_picker_field.dart' show TimePickerField;
export 'src/time_picker_panel.dart'
    show
        TimePickerPanel,
        kTimePickerHourFieldKey,
        kTimePickerMinuteFieldKey,
        kTimePickerPanelKey;
export 'src/time_picker_popup.dart'
    show showCompactTimePicker, showTimePicker;
export 'src/time_picker_style.dart' show TimePickerLabels, TimePickerStyle;
export 'src/time_picker_types.dart'
    show TimeDialMode, TimePickerPlacement, formatTimeOfDay;

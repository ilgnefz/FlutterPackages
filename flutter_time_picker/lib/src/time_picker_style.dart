import 'package:material_ui/material_ui.dart';

/// 时间选择面板的尺寸、间距与文字样式（配色默认跟主题走）。
///
/// 份量和 `flutter_calendar` 的 `CalendarStyle` 一致：**所有装饰项都在这里**，
/// 组件本身不留写死的数字。
///
/// ```dart
/// TimePickerPanel(
///   initialTime: const TimeOfDay(hour: 9, minute: 30),
///   style: const TimePickerStyle(width: 320, dialSize: 184),
/// )
/// ```
@immutable
class TimePickerStyle {
  const TimePickerStyle({
    this.width = 300,
    this.radius = 12,
    this.elevation = 8,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 12, 8),
    this.backgroundColor,
    this.dialSize = 168,
    this.dialBackgroundColor,
    this.dialHandColor,
    this.dialLabelStyle,
    this.dialInnerLabelStyle,
    this.dialSelectedLabelColor,
    this.timeTextStyle,
    this.fieldWidth = 40,
    this.fieldHeight = 42,
    this.editBackgroundColor,
    this.meridiemTextStyle,
    this.actionTextStyle,
    this.mouseCursor = SystemMouseCursors.click,
    this.textCursorColor,
  });

  /// 面板宽度（含内边距）。左边的时间区拿到的是「宽 - 表盘 - 内边距」。
  final double width;

  /// 面板圆角。
  final double radius;

  /// 投影高度（直接交给 `Material.elevation`）。
  final double elevation;

  /// 面板内边距。
  final EdgeInsets padding;

  /// 面板底色；不传用 `ColorScheme.surface`。
  final Color? backgroundColor;

  /// 表盘直径。
  final double dialSize;

  /// 表盘底圆颜色；不传是 `surfaceContainerHighest` 的 55% 透明度。
  final Color? dialBackgroundColor;

  /// 指针和选中圆点的颜色；不传用主题主色。
  final Color? dialHandColor;

  /// **外圈（分）**数字样式；不传 12 号。颜色由状态决定（选中 / 未选中），这里
  /// 只改字号字重，或者整个换一份字体。
  final TextStyle? dialLabelStyle;

  /// **内圈（时）**数字样式；不传 11 号。内圈比外圈窄，字号别超过外圈。
  final TextStyle? dialInnerLabelStyle;

  /// 选中数字压在指针圆点上的颜色；不传 `ColorScheme.onPrimary`。
  final Color? dialSelectedLabelColor;

  /// 左侧可编辑时间的字号样式；不传 28 号、`w500`、等宽数字。
  final TextStyle? timeTextStyle;

  /// 单个小时 / 分钟输入框的宽度。
  final double fieldWidth;

  /// 单个小时 / 分钟输入框的高度。
  final double fieldHeight;

  /// 正在编辑的那一段的底色；不传是主色 10% 透明度。
  final Color? editBackgroundColor;

  /// 上午 / 下午两段文字的样式；不传 11.5 号（选中时是主色底 + 白字 + `w600`）。
  final TextStyle? meridiemTextStyle;

  /// 底部「取消 / 确定」的文字样式；不传 13 号 `w600`。
  final TextStyle? actionTextStyle;

  /// 可点部分的鼠标样式：表盘、小时 / 分钟输入框、上下午、取消 / 确定。
  ///
  /// 默认 `SystemMouseCursors.click`（小手）。这里必须显式给：`InkWell` 默认的
  /// `WidgetStateMouseCursor.adaptiveClickable` 在桌面端（非 web）解析成箭头。
  final MouseCursor mouseCursor;

  /// 输入框里那根光标 / 选区的颜色；不传跟主题。
  final Color? textCursorColor;

  /// 派生一份新样式。
  TimePickerStyle copyWith({
    double? width,
    double? radius,
    double? elevation,
    EdgeInsets? padding,
    Color? backgroundColor,
    double? dialSize,
    Color? dialBackgroundColor,
    Color? dialHandColor,
    TextStyle? dialLabelStyle,
    TextStyle? dialInnerLabelStyle,
    Color? dialSelectedLabelColor,
    TextStyle? timeTextStyle,
    double? fieldWidth,
    double? fieldHeight,
    Color? editBackgroundColor,
    TextStyle? meridiemTextStyle,
    TextStyle? actionTextStyle,
    MouseCursor? mouseCursor,
    Color? textCursorColor,
  }) {
    return TimePickerStyle(
      width: width ?? this.width,
      radius: radius ?? this.radius,
      elevation: elevation ?? this.elevation,
      padding: padding ?? this.padding,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      dialSize: dialSize ?? this.dialSize,
      dialBackgroundColor: dialBackgroundColor ?? this.dialBackgroundColor,
      dialHandColor: dialHandColor ?? this.dialHandColor,
      dialLabelStyle: dialLabelStyle ?? this.dialLabelStyle,
      dialInnerLabelStyle: dialInnerLabelStyle ?? this.dialInnerLabelStyle,
      dialSelectedLabelColor:
          dialSelectedLabelColor ?? this.dialSelectedLabelColor,
      timeTextStyle: timeTextStyle ?? this.timeTextStyle,
      fieldWidth: fieldWidth ?? this.fieldWidth,
      fieldHeight: fieldHeight ?? this.fieldHeight,
      editBackgroundColor: editBackgroundColor ?? this.editBackgroundColor,
      meridiemTextStyle: meridiemTextStyle ?? this.meridiemTextStyle,
      actionTextStyle: actionTextStyle ?? this.actionTextStyle,
      mouseCursor: mouseCursor ?? this.mouseCursor,
      textCursorColor: textCursorColor ?? this.textCursorColor,
    );
  }
}

/// 面板里的文案：上午 / 下午、「时 / 分」小字、取消 / 确定。
///
/// 默认中文；[TimePickerLabels.of] 会按当前 locale 自动挑（英文环境用 [en]，
/// 其它都是中文）。要加别的语言，继承它把这几个成员覆盖掉即可。
@immutable
class TimePickerLabels {
  const TimePickerLabels();

  /// 上午。
  String get am => '上午';

  /// 下午。
  String get pm => '下午';

  /// 小时输入框下面的小字。
  String get hour => '时';

  /// 分钟输入框下面的小字。
  String get minute => '分';

  /// 取消。
  String get cancel => '取消';

  /// 确定。
  String get confirm => '确定';

  /// 中文（默认）。
  static const TimePickerLabels zh = TimePickerLabels();

  /// 英文。
  static const TimePickerLabels en = _EnglishLabels();

  /// 按 locale 挑一份：`en` 用英文，其它（含 null）用中文。
  static TimePickerLabels resolve(Locale? locale) =>
      locale?.languageCode == 'en' ? en : zh;

  /// 按当前 `Localizations` 的 locale 挑一份。
  static TimePickerLabels of(BuildContext context) =>
      resolve(Localizations.maybeLocaleOf(context));
}

class _EnglishLabels extends TimePickerLabels {
  const _EnglishLabels();

  @override
  String get am => 'AM';

  @override
  String get pm => 'PM';

  @override
  String get hour => 'Hour';

  @override
  String get minute => 'Minute';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'OK';
}

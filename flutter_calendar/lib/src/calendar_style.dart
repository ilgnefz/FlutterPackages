import 'package:material_ui/material_ui.dart';

/// 日历面板的尺寸、间距与文字样式（配色仍跟主题走）。
///
/// 份量和通知包里的 `NotificationStyle` 一样：**所有装饰项都在这里**，组件本身
/// 不留写死的数字。面板宽度、圆角、表头高度、格子高度、字号、翻月按钮的样式与
/// 图标，全都可以从外面改。
///
/// ```dart
/// CalendarPanel(
///   month: DateTime(2026, 11),
///   style: const CalendarStyle(
///     width: 280,
///     cellHeight: 36,
///     dayTextStyle: TextStyle(fontSize: 14),
///   ),
/// )
/// ```
@immutable
class CalendarStyle {
  const CalendarStyle({
    this.width = 268,
    this.radius = 12,
    this.elevation = 8,
    this.padding = const EdgeInsets.fromLTRB(8, 2, 8, 8),
    this.backgroundColor,
    this.headerHeight = 40,
    this.headerTextStyle,
    this.headerIconSize = 16,
    this.weekdayHeight = 22,
    this.weekdayTextStyle,
    this.cellHeight = 32,
    this.dayCircleSize = 28,
    this.dayTextStyle,
    this.yearRowHeight = 32,
    this.yearTextStyle,
    this.navIconSize = 20,
    this.navButtonSize = const Size(30, 30),
    this.previousIcon = Icons.chevron_left,
    this.nextIcon = Icons.chevron_right,
    this.navButtonStyle,
    this.mouseCursor = SystemMouseCursors.click,
  });

  /// 面板宽度（含内边距）。
  final double width;

  /// 面板圆角。
  final double radius;

  /// 投影高度（直接交给 `Material.elevation`）。
  final double elevation;

  /// 面板内边距。
  final EdgeInsets padding;

  /// 面板底色；不传用 `ColorScheme.surface`。
  final Color? backgroundColor;

  /// 标题行（年月 + 两颗翻月按钮）的高度。
  final double headerHeight;

  /// 「2026年11月」的文字样式；颜色由状态决定（展开年份列表时用主色），
  /// 这里只用来改字号 / 字重 / 字体。
  final TextStyle? headerTextStyle;

  /// 标题右边那个提示「可展开年份」的小箭头尺寸。
  final double headerIconSize;

  /// 星期表头那一行的高度。
  final double weekdayHeight;

  /// 星期表头文字样式（「周一」…）；不传 11 号、`onSurface` 55% 透明度。
  final TextStyle? weekdayTextStyle;

  /// 每个日期格子的高度（宽 = 面板宽度 / 7）。
  final double cellHeight;

  /// 选中圆点的直径。
  final double dayCircleSize;

  /// 日期文字样式；不传 13 号。颜色（选中 / 邻月 / 超范围）和选中时的字重
  /// 由组件决定，这里改字号 / 字体。
  final TextStyle? dayTextStyle;

  /// 年份列表每一行的高度。
  final double yearRowHeight;

  /// 年份文字样式；不传 13.5 号。
  final TextStyle? yearTextStyle;

  /// 翻月按钮里图标的尺寸。
  final double navIconSize;

  /// 翻月按钮的点击区域大小。
  final Size navButtonSize;

  /// 上一月图标。
  final IconData previousIcon;

  /// 下一月图标。
  final IconData nextIcon;

  /// 两颗翻月按钮的完整样式；不传就是「主色图标 + 无底色」的紧凑 `IconButton`。
  ///
  /// 想换成实心圆底、换颜色、加边框都改这个（`ButtonStyle` 会叠在默认样式上）：
  ///
  /// ```dart
  /// CalendarStyle(
  ///   navButtonStyle: IconButton.styleFrom(
  ///     backgroundColor: Colors.black.withValues(alpha: 0.06),
  ///     foregroundColor: Colors.black87,
  ///   ),
  /// )
  /// ```
  final ButtonStyle? navButtonStyle;

  /// 面板里所有**能点**的部分的鼠标样式：年月标题（可展开年份时）、范围内的
  /// 日期格子、年份列表条目、两颗翻月按钮。
  ///
  /// 默认 `SystemMouseCursors.click`（小手）。这里必须显式给：Material 的
  /// `InkWell` 默认是 `WidgetStateMouseCursor.adaptiveClickable`，在桌面端
  /// （非 web）解析成**箭头**，所以之前点在日期上光标根本不变。
  ///
  /// 不能点的部分（范围外的日期、范围到头时的翻月按钮、关掉的年月标题）不会
  /// 变小手，免得骗人。桌面端想统一成别的（比如箭头 `SystemMouseCursors.basic`）
  /// 改这一项即可。
  final MouseCursor mouseCursor;

  /// 星期表头 + 6 行日期的高度。
  double get bodyHeight => weekdayHeight + cellHeight * 6;

  /// 面板整体高度（标题 + 表头 + 网格 + 上下内边距）。
  double get panelHeight => headerHeight + bodyHeight + padding.vertical;

  /// 派生一份新样式。
  CalendarStyle copyWith({
    double? width,
    double? radius,
    double? elevation,
    EdgeInsets? padding,
    Color? backgroundColor,
    double? headerHeight,
    TextStyle? headerTextStyle,
    double? headerIconSize,
    double? weekdayHeight,
    TextStyle? weekdayTextStyle,
    double? cellHeight,
    double? dayCircleSize,
    TextStyle? dayTextStyle,
    double? yearRowHeight,
    TextStyle? yearTextStyle,
    double? navIconSize,
    Size? navButtonSize,
    IconData? previousIcon,
    IconData? nextIcon,
    ButtonStyle? navButtonStyle,
    MouseCursor? mouseCursor,
  }) {
    return CalendarStyle(
      width: width ?? this.width,
      radius: radius ?? this.radius,
      elevation: elevation ?? this.elevation,
      padding: padding ?? this.padding,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      headerHeight: headerHeight ?? this.headerHeight,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
      headerIconSize: headerIconSize ?? this.headerIconSize,
      weekdayHeight: weekdayHeight ?? this.weekdayHeight,
      weekdayTextStyle: weekdayTextStyle ?? this.weekdayTextStyle,
      cellHeight: cellHeight ?? this.cellHeight,
      dayCircleSize: dayCircleSize ?? this.dayCircleSize,
      dayTextStyle: dayTextStyle ?? this.dayTextStyle,
      yearRowHeight: yearRowHeight ?? this.yearRowHeight,
      yearTextStyle: yearTextStyle ?? this.yearTextStyle,
      navIconSize: navIconSize ?? this.navIconSize,
      navButtonSize: navButtonSize ?? this.navButtonSize,
      previousIcon: previousIcon ?? this.previousIcon,
      nextIcon: nextIcon ?? this.nextIcon,
      navButtonStyle: navButtonStyle ?? this.navButtonStyle,
      mouseCursor: mouseCursor ?? this.mouseCursor,
    );
  }
}

/// 面板里的文案：星期表头、标题上的年月、年份列表。
///
/// 默认中文；[CalendarLabels.of] 会按当前 locale 自动挑（英文环境用 [en]，
/// 其它都是中文）。要加别的语言，继承它覆盖三个方法即可：
///
/// ```dart
/// class _JapaneseLabels extends CalendarLabels {
///   const _JapaneseLabels();
///
///   @override
///   List<String> get weekdays => const ['月', '火', '水', '木', '金', '土', '日'];
///
///   @override
///   String monthYear(int year, int month) => '$year年$month月';
///
///   @override
///   String year(int year) => '$year年';
/// }
/// ```
@immutable
class CalendarLabels {
  const CalendarLabels();

  /// 星期表头，固定 7 个，**从周一开始**；`weekStartsOnMonday: false` 时组件自己
  /// 把它转成周日开头。
  List<String> get weekdays =>
      const <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  /// 标题上的年月，例如 `2026年11月` / `Nov 2026`。
  String monthYear(int year, int month) => '$year年$month月';

  /// 年份列表里的年份，例如 `2026年` / `2026`。
  String year(int year) => '$year年';

  /// 中文（默认）。
  static const CalendarLabels zh = CalendarLabels();

  /// 英文。
  static const CalendarLabels en = _EnglishLabels();

  /// 按 locale 挑一份：`en` 用英文，其它（含 null）用中文。
  static CalendarLabels resolve(Locale? locale) =>
      locale?.languageCode == 'en' ? en : zh;

  /// 按当前 `Localizations` 的 locale 挑一份。
  static CalendarLabels of(BuildContext context) =>
      resolve(Localizations.maybeLocaleOf(context));
}

class _EnglishLabels extends CalendarLabels {
  const _EnglishLabels();

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  List<String> get weekdays => const <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  String monthYear(int year, int month) => '${_months[month - 1]} $year';

  @override
  String year(int year) => '$year';
}

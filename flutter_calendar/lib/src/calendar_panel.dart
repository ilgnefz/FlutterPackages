import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'calendar_style.dart';
import 'calendar_types.dart';

/// 面板本体的 key（弹窗和独立嵌入都能用）。
const Key kCalendarPanelKey = ValueKey<String>('calendar-panel');

/// 年份列表的 key。
const Key kCalendarYearGridKey = ValueKey<String>('calendar-year-grid');

const int _kRows = 6;
const int _kColumns = 7;
const int _kMinYear = 1900;
const int _kMaxYear = 2100;

/// 单月日历面板：月份标题 + 星期表头 + 6 × 7 日期网格。
///
/// 只展示 [month] 这一整个月；前后补格的邻月日期以浅灰显示（可以用
/// [showAdjacentDays] 关掉）。点邻月日期会**先翻到那个月、再选中那一天**
/// （不想这样就把 [selectAdjacentDays] 关掉，它就只翻月）。
///
/// 点击「2026年11月」标题会在面板内展开年份列表（3 列、可滚动），选中年份后
/// 回到月视图。左右箭头切换月份（年份列表展开时切年份）；两颗箭头的位置、图标、
/// 尺寸、样式都在 [CalendarStyle] 里（`navButtonStyle` / `navIconSize` /
/// `navButtonSize` / `previousIcon` / `nextIcon`）。
///
/// ```dart
/// CalendarPanel(
///   month: DateTime(2026, 11),
///   selectedDate: DateTime(2026, 11, 25),
///   onDateSelected: (DateTime date) => print(date),
/// )
/// ```
class CalendarPanel extends StatefulWidget {
  const CalendarPanel({
    super.key,
    required this.month,
    this.selectedDate,
    this.onDateSelected,
    this.onMonthChanged,
    this.firstDate,
    this.lastDate,
    this.enableYearPicker = true,
    this.showAdjacentDays = true,
    this.selectAdjacentDays = true,
    this.weekStartsOnMonday = true,
    this.style = const CalendarStyle(),
    this.labels,
  });

  /// 要显示的月份；只取其中的年和月，日会被忽略。
  final DateTime month;

  /// 当前选中的日期；为 null 时不画选中圆点。
  final DateTime? selectedDate;

  /// 点中日期时回调（已归一化成当天 0 点）。
  ///
  /// 点邻月日期时，[selectAdjacentDays] 开着也会回调——此时面板已经切到那个月。
  final ValueChanged<DateTime>? onDateSelected;

  /// 切换月份 / 年份时回调。
  final ValueChanged<DateTime>? onMonthChanged;

  /// 可选范围下界；为 null 表示不限。
  final DateTime? firstDate;

  /// 可选范围上界；为 null 表示不限。
  final DateTime? lastDate;

  /// 是否允许点标题展开年份列表。
  final bool enableYearPicker;

  /// 是否显示前后补格的邻月日期（浅灰）。
  final bool showAdjacentDays;

  /// 点邻月日期时是否顺手选中它（默认是）。
  ///
  /// 开着：翻到那个月并回调那天，用户点哪就是哪；关掉：只翻月，不选中，保证
  /// 回调永远落在「当前显示的这个月」里。
  final bool selectAdjacentDays;

  /// 一周是否从周一开始；false 则从周日开始。
  final bool weekStartsOnMonday;

  /// 尺寸与文字样式。
  final CalendarStyle style;

  /// 文案（星期表头、年月、年份）；不传按当前 locale 自动选。
  final CalendarLabels? labels;

  @override
  State<CalendarPanel> createState() => _CalendarPanelState();
}

class _CalendarPanelState extends State<CalendarPanel> {
  late DateTime _month = DateTime(widget.month.year, widget.month.month);
  bool _yearMode = false;
  final ScrollController _yearScroll = ScrollController();

  CalendarStyle get _style => widget.style;

  CalendarLabels get _labels =>
      widget.labels ?? CalendarLabels.of(context);

  @override
  void didUpdateWidget(covariant CalendarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final DateTime incoming = DateTime(widget.month.year, widget.month.month);
    final DateTime previous = DateTime(
      oldWidget.month.year,
      oldWidget.month.month,
    );
    // 只有父级**换了**月份才跟过去。父级一直传同一个月份（比如它不关心翻月）
    // 时，不要把它内部翻到的月份拽回来。
    if (incoming != previous && incoming != _month) _month = incoming;
  }

  @override
  void dispose() {
    _yearScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CalendarStyle style = _style;
    return Material(
      key: kCalendarPanelKey,
      color: style.backgroundColor ?? theme.colorScheme.surface,
      elevation: style.elevation,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(style.radius),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: style.width,
        child: Padding(
          padding: style.padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildHeader(theme),
              if (_yearMode) _buildYears(theme) else _buildMonth(theme),
            ],
          ),
        ),
      ),
    );
  }

  // ── 标题 ────────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    final CalendarStyle style = _style;
    final CalendarLabels labels = _labels;
    final bool open = _yearMode;
    // 颜色由「有没有展开年份列表」决定，字号 / 字重留给样式覆盖。
    final TextStyle titleStyle =
        (style.headerTextStyle ??
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))
            .copyWith(color: open ? scheme.primary : scheme.onSurface);

    return SizedBox(
      height: style.headerHeight,
      child: Row(
        children: <Widget>[
          // 整条剩余宽度都给标题。之前这里是 Flexible + Spacer，两个 flex 会
          // 平分剩余空间，标题只拿到一半宽，16 号字直接被省略号吃掉。
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.enableYearPicker ? _toggleYearMode : null,
                  // 关掉年份选择时不给光标：点了没反应就不该变小手。
                  mouseCursor: widget.enableYearPicker
                      ? style.mouseCursor
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            labels.monthYear(_month.year, _month.month),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                        ),
                        if (widget.enableYearPicker)
                          Icon(
                            open ? Icons.expand_more : Icons.chevron_right,
                            size: style.headerIconSize,
                            color: open
                                ? scheme.primary
                                : scheme.onSurface.withValues(alpha: 0.45),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildNavButton(theme, previous: true),
          _buildNavButton(theme, previous: false),
        ],
      ),
    );
  }

  /// 翻月 / 翻年按钮。样式在 [CalendarStyle.navButtonStyle] 里改。
  Widget _buildNavButton(ThemeData theme, {required bool previous}) {
    final CalendarStyle style = _style;
    final int delta = previous ? -1 : 1;
    // 到头了（比如范围只到本月）按钮还在，但点了不会有反应，光标就别变小手。
    final MouseCursor cursor = _canStep(delta)
        ? style.mouseCursor
        : SystemMouseCursors.basic;
    final ButtonStyle base = IconButton.styleFrom(
      foregroundColor: theme.colorScheme.primary,
      minimumSize: style.navButtonSize,
      maximumSize: style.navButtonSize,
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      // 不叠 visualDensity.compact：它会再从 min/maxSize 上减 4，设了 30 却只
      // 拿到 26，尺寸就不受 navButtonSize 控制了。
    ).copyWith(mouseCursor: WidgetStatePropertyAll<MouseCursor>(cursor));
    return IconButton(
      onPressed: previous ? _previous : _next,
      icon: Icon(
        previous ? style.previousIcon : style.nextIcon,
        size: style.navIconSize,
      ),
      style: style.navButtonStyle == null
          ? base
          : base.merge(style.navButtonStyle),
    );
  }

  // ── 月视图 ──────────────────────────────────────────────────────────────

  Widget _buildMonth(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    final CalendarStyle style = _style;
    final List<String> weekdays = _labels.weekdays;
    // 内置文案都是周一开始；周日开头时把它整体转一格。
    final List<String> labels = widget.weekStartsOnMonday
        ? weekdays
        : <String>[weekdays.last, ...weekdays.take(6)];

    final int leading = widget.weekStartsOnMonday
        ? (_month.weekday - DateTime.monday) % 7
        : _month.weekday % 7;
    final DateTime gridStart = DateTime(_month.year, _month.month, 1 - leading);

    final TextStyle weekdayBase =
        style.weekdayTextStyle ?? const TextStyle(fontSize: 11);
    final TextStyle weekdayStyle = weekdayBase.copyWith(
      color:
          weekdayBase.color ?? scheme.onSurface.withValues(alpha: 0.55),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: style.weekdayHeight,
          child: Row(
            children: <Widget>[
              for (final String label in labels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: weekdayStyle,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (int row = 0; row < _kRows; row++)
          Row(
            children: <Widget>[
              for (int col = 0; col < _kColumns; col++)
                Expanded(
                  child: _buildDayCell(
                    theme,
                    DateTime(
                      gridStart.year,
                      gridStart.month,
                      gridStart.day + row * _kColumns + col,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildDayCell(ThemeData theme, DateTime date) {
    final ColorScheme scheme = theme.colorScheme;
    final CalendarStyle style = _style;
    final bool inMonth = date.year == _month.year && date.month == _month.month;
    if (!inMonth && !widget.showAdjacentDays) {
      return SizedBox(height: style.cellHeight);
    }
    final bool enabled = isDateInRange(
      date,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    final bool selected = isSameCalendarDay(date, widget.selectedDate);
    final Color color;
    if (selected) {
      color = scheme.onPrimary;
    } else if (!inMonth) {
      // 邻月日期始终浅一档，跟当月区分开（能不能点由范围决定）。
      color = scheme.onSurface.withValues(alpha: 0.4);
    } else if (!enabled) {
      color = scheme.onSurface.withValues(alpha: 0.3);
    } else {
      color = scheme.onSurface;
    }
    final TextStyle dayStyle = (style.dayTextStyle ??
            const TextStyle(fontSize: 13))
        .copyWith(
          color: color,
          fontWeight: selected ? FontWeight.w600 : null,
        );

    return SizedBox(
      key: calendarDayKey(date),
      height: style.cellHeight,
      child: Center(
        child: SizedBox(
          width: style.dayCircleSize,
          height: style.dayCircleSize,
          child: Material(
            color: selected ? scheme.primary : Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? () => _onDayTap(date, inMonth: inMonth) : null,
              mouseCursor: enabled ? style.mouseCursor : null,
              customBorder: const CircleBorder(),
              child: Center(
                child: Text(
                  '${date.day}',
                  style: dayStyle,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onDayTap(DateTime date, {required bool inMonth}) {
    if (!inMonth) {
      // 邻月日期：先翻到它所在的月，再按开关决定要不要直接选中。
      _changeMonth(date);
      if (widget.selectAdjacentDays) widget.onDateSelected?.call(date);
      return;
    }
    widget.onDateSelected?.call(DateTime(date.year, date.month, date.day));
  }

  // ── 年份视图 ────────────────────────────────────────────────────────────

  Widget _buildYears(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    final CalendarStyle style = _style;
    final CalendarLabels labels = _labels;
    final int startYear = widget.firstDate?.year ?? _kMinYear;
    final int endYear = widget.lastDate?.year ?? _kMaxYear;
    final int count = math.max(0, endYear - startYear + 1);
    final TextStyle yearStyle = style.yearTextStyle ??
        const TextStyle(fontSize: 13.5);
    return SizedBox(
      height: style.bodyHeight,
      child: GridView.builder(
        key: kCalendarYearGridKey,
        controller: _yearScroll,
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisExtent: style.yearRowHeight,
          crossAxisSpacing: 4,
          mainAxisSpacing: 0,
        ),
        itemCount: count,
        itemBuilder: (BuildContext context, int index) {
          final int year = startYear + index;
          final bool selected = year == _month.year;
          return Center(
            child: Material(
              color: selected
                  ? scheme.onSurface.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(style.radius),
              child: InkWell(
                borderRadius: BorderRadius.circular(style.radius),
                mouseCursor: style.mouseCursor,
                onTap: () => _selectYear(year),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    labels.year(year),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: yearStyle.copyWith(
                      fontWeight: selected
                          ? FontWeight.w600
                          : yearStyle.fontWeight,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 导航 ────────────────────────────────────────────────────────────────

  void _previous() => _step(-1);

  void _next() => _step(1);

  /// 往 [delta] 方向翻一格（年份列表展开时翻年，否则翻月）会不会翻出范围。
  bool _canStep(int delta) {
    final DateTime next = _yearMode
        ? DateTime(_month.year + delta, _month.month)
        : DateTime(_month.year, _month.month + delta);
    return isMonthInRange(
      next,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
  }

  void _step(int delta) {
    if (!_canStep(delta)) return;
    final DateTime next = _yearMode
        ? DateTime(_month.year + delta, _month.month)
        : DateTime(_month.year, _month.month + delta);
    setState(() => _month = next);
    widget.onMonthChanged?.call(next);
    if (_yearMode) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollYearIntoView(),
      );
    }
  }

  void _changeMonth(DateTime month) {
    final DateTime next = DateTime(month.year, month.month);
    if (!isMonthInRange(
      next,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    )) {
      return;
    }
    setState(() => _month = next);
    widget.onMonthChanged?.call(next);
  }

  void _selectYear(int year) {
    setState(() {
      _month = DateTime(year, _month.month);
      _yearMode = false;
    });
    widget.onMonthChanged?.call(_month);
  }

  void _toggleYearMode() {
    if (_yearMode) {
      setState(() => _yearMode = false);
      return;
    }
    setState(() => _yearMode = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollYearIntoView());
  }

  /// 打开年份列表时把当前年份滚到可视区中间偏上。
  void _scrollYearIntoView() {
    if (!mounted || !_yearScroll.hasClients) return;
    final int startYear = widget.firstDate?.year ?? _kMinYear;
    final double rowHeight = _style.yearRowHeight;
    final int row = math.max(0, (_month.year - startYear) ~/ 3);
    final double target = row * rowHeight - rowHeight;
    _yearScroll.jumpTo(target.clamp(0.0, _yearScroll.position.maxScrollExtent));
  }
}

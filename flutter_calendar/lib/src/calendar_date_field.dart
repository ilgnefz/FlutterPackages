import 'package:material_ui/material_ui.dart' hide showDatePicker;

import 'calendar_style.dart';
import 'calendar_types.dart';
import 'date_picker_popup.dart';

/// 带标题和日历图标的日期输入框，点一下就在旁边弹出 [CalendarPanel]。
///
/// ```dart
/// CalendarDateField(
///   label: 'Date',
///   initialDate: DateTime(2026, 11, 25),
///   placement: CalendarPlacement.bottom,
///   onChanged: (DateTime date) => print(date),
/// )
/// ```
///
/// 传了 [value] 就是受控模式（以外部值为准）；否则内部自己记选中的日期。
class CalendarDateField extends StatefulWidget {
  const CalendarDateField({
    super.key,
    this.value,
    this.initialDate,
    this.onChanged,
    this.label,
    this.hint = '选择日期',
    this.placement = CalendarPlacement.bottom,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
    this.width = 220,
    this.height = 44,
    this.panelStyle = const CalendarStyle(),
    this.labels,
    this.panelWidth,
    this.radius = 10,
    this.showCalendarIcon = true,
    this.mouseCursor = SystemMouseCursors.click,
    this.formatDate,
  });

  /// 受控值；非 null 时以它为准。
  final DateTime? value;

  /// 非受控模式下的初始值。
  final DateTime? initialDate;

  /// 选中日期后回调。
  final ValueChanged<DateTime>? onChanged;

  /// 输入框上方的标题，比如 `Date`；为 null 时不显示。
  final String? label;

  /// 没有选中日期时的占位文案。
  final String hint;

  /// 弹窗相对输入框的位置。
  final CalendarPlacement placement;

  /// 可选范围下界。
  final DateTime? firstDate;

  /// 可选范围上界。
  final DateTime? lastDate;

  final bool enabled;

  /// 输入框宽度。
  final double width;

  /// 输入框高度。
  final double height;

  /// 弹窗面板的尺寸与文字样式。
  final CalendarStyle panelStyle;

  /// 弹窗里的文案（星期表头 / 年月）；不传按 locale 自动选。
  final CalendarLabels? labels;

  /// 老写法：只改弹窗宽度，等价于 `panelStyle.copyWith(width: ...)`。
  final double? panelWidth;

  /// 输入框圆角。
  final double radius;

  /// 是否显示右侧日历图标。
  final bool showCalendarIcon;

  /// 输入框里日期的显示格式；不传是 `formatCalendarDate`（`2026 / 11 / 25`）。
  ///
  /// 要显示成本地习惯的样子就传一个，比如 `2026年11月25日` 或 `25/11/2026`：
  ///
  /// ```dart
  /// CalendarDateField(
  ///   initialDate: DateTime(2026, 11, 25),
  ///   formatDate: (DateTime d) => '${d.year}年${d.month}月${d.day}日',
  /// )
  /// ```
  final String Function(DateTime date)? formatDate;

  /// 输入框的鼠标样式，默认 `SystemMouseCursors.click`（小手）。
  ///
  /// `enabled: false` 时不会用这个值（保持默认箭头）。弹窗里面板的光标由
  /// [panelStyle] 的 `mouseCursor` 单独控制。
  final MouseCursor mouseCursor;

  @override
  State<CalendarDateField> createState() => _CalendarDateFieldState();
}

class _CalendarDateFieldState extends State<CalendarDateField> {
  late DateTime? _value = widget.value ?? widget.initialDate;

  @override
  void didUpdateWidget(covariant CalendarDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) _value = widget.value;
  }

  Future<void> _open(BuildContext anchorContext) async {
    final DateTime initial = _value ?? DateTime.now();
    final DateTime? picked = await showCalendarDatePicker(
      anchorContext,
      initialDate: initial,
      selectedDate: _value,
      placement: widget.placement,
      style: widget.panelStyle,
      labels: widget.labels,
      panelWidth: widget.panelWidth,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (!mounted || picked == null) return;
    setState(() => _value = picked);
    widget.onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool hasValue = _value != null;
    final Color textColor = widget.enabled
        ? (hasValue
              ? scheme.onSurface
              : scheme.onSurface.withValues(alpha: 0.4))
        : scheme.onSurface.withValues(alpha: 0.35);
    final Color iconColor = widget.enabled
        ? scheme.onSurface.withValues(alpha: 0.55)
        : scheme.onSurface.withValues(alpha: 0.3);
    final Color borderColor = widget.enabled
        ? scheme.outlineVariant
        : scheme.outlineVariant.withValues(alpha: 0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(
            widget.label!,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
        ],
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: Builder(
            builder: (BuildContext anchorContext) {
              return Material(
                color: widget.enabled
                    ? scheme.surface
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(widget.radius),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.enabled ? () => _open(anchorContext) : null,
                  mouseCursor: widget.enabled ? widget.mouseCursor : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.radius),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            hasValue
                                ? (widget.formatDate?.call(_value!) ??
                                      formatCalendarDate(_value!))
                                : widget.hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, color: textColor),
                          ),
                        ),
                        if (widget.showCalendarIcon) ...<Widget>[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: iconColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

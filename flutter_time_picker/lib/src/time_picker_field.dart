import 'package:material_ui/material_ui.dart' hide showTimePicker;

import 'time_picker_popup.dart';
import 'time_picker_style.dart';
import 'time_picker_types.dart';

/// 带标题和时钟图标的输入框，点一下就在旁边弹出紧凑的时间面板。
///
/// ```dart
/// TimePickerField(
///   label: '时间',
///   initialTime: const TimeOfDay(hour: 9, minute: 30),
///   onChanged: (TimeOfDay time) => print(time),
/// )
/// ```
///
/// 传了 [value] 就是受控模式（以外部值为准）；否则内部自己记选中的时间。
class TimePickerField extends StatefulWidget {
  const TimePickerField({
    super.key,
    this.value,
    this.initialTime,
    this.onChanged,
    this.label,
    this.hint = '选择时间',
    this.placement = TimePickerPlacement.bottom,
    this.enabled = true,
    this.use24HourFormat = true,
    this.width = 150,
    this.height = 44,
    this.radius = 10,
    this.panelStyle = const TimePickerStyle(),
    this.labels,
    this.showClockIcon = true,
    this.mouseCursor = SystemMouseCursors.click,
  });

  /// 受控值；非 null 时以它为准。
  final TimeOfDay? value;

  /// 非受控模式下的初始值。
  final TimeOfDay? initialTime;

  /// 点「确定」后回调。
  final ValueChanged<TimeOfDay>? onChanged;

  /// 输入框上方的标题，比如 `时间`；为 null 时不显示。
  final String? label;

  /// 没有选中时间时的占位文案。
  final String hint;

  /// 弹窗相对输入框的位置。
  final TimePickerPlacement placement;

  final bool enabled;

  /// 是否 24 小时制（影响显示文案与面板里的表盘）。
  final bool use24HourFormat;

  /// 输入框宽度。
  final double width;

  /// 输入框高度。
  final double height;

  /// 输入框圆角。
  final double radius;

  /// 弹窗面板的尺寸与文字样式。
  final TimePickerStyle panelStyle;

  /// 弹窗里的文案；不传按 locale 自动选。
  final TimePickerLabels? labels;

  /// 是否显示右侧时钟图标。
  final bool showClockIcon;

  /// 输入框的鼠标样式，默认 `SystemMouseCursors.click`（小手）。
  final MouseCursor mouseCursor;

  @override
  State<TimePickerField> createState() => _TimePickerFieldState();
}

class _TimePickerFieldState extends State<TimePickerField> {
  late TimeOfDay? _value = widget.value ?? widget.initialTime;

  @override
  void didUpdateWidget(covariant TimePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) _value = widget.value;
  }

  Future<void> _open(BuildContext anchorContext) async {
    final TimeOfDay? picked = await showCompactTimePicker(
      anchorContext,
      initialTime: _value ?? TimeOfDay.now(),
      placement: widget.placement,
      use24HourFormat: widget.use24HourFormat,
      style: widget.panelStyle,
      labels: widget.labels,
    );
    if (!mounted || picked == null) return;
    setState(() => _value = picked);
    widget.onChanged?.call(picked);
  }

  String _text(TimePickerLabels labels) {
    final TimeOfDay? value = _value;
    if (value == null) return widget.hint;
    if (widget.use24HourFormat) return formatTimeOfDay(value);
    final String period = value.period == DayPeriod.am ? labels.am : labels.pm;
    return '$period ${formatTimeOfDay(value, use24HourFormat: false)}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool hasValue = _value != null;
    final TimePickerLabels labels = widget.labels ?? TimePickerLabels.of(context);
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
                            _text(labels),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, color: textColor),
                          ),
                        ),
                        if (widget.showClockIcon) ...<Widget>[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.schedule_outlined,
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

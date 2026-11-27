import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'time_dial.dart';
import 'time_picker_style.dart';
import 'time_picker_types.dart';

/// 面板本体的 key（弹窗和独立嵌入都能用）。
const Key kTimePickerPanelKey = ValueKey<String>('time-picker-panel');

/// 小时输入框的 key。
const Key kTimePickerHourFieldKey = ValueKey<String>('time-picker-hour');

/// 分钟输入框的 key。
const Key kTimePickerMinuteFieldKey = ValueKey<String>('time-picker-minute');

/// 紧凑时间面板：**左边是能直接改的时间，右边是表盘**。
///
/// 和 Material 的 `TimePicker` 相比：
///
/// - 不再是全屏对话框，尺寸跟着 [TimePickerStyle.width] / `dialSize` 走；
/// - **没有「切换输入方式」那个按钮**：时间一直显示在左边，点一下就能改；
/// - **表盘两圈同时可用**：外圈改分、内圈改时，不用先选「我现在要调什么」；
/// - 时间下面常驻「上午 / 下午」两段（24 小时制也要它，因为内圈是 12 小时表盘）；
/// - 小时框直接敲 `0..23`（24 小时制）或 `1..12`（12 小时制），回车 / 失焦时
///   自动补零并夹到合法范围。
///
/// ```dart
/// TimePickerPanel(
///   initialTime: const TimeOfDay(hour: 9, minute: 30),
///   onSubmit: (TimeOfDay time) => print(time),
/// )
/// ```
class TimePickerPanel extends StatefulWidget {
  const TimePickerPanel({
    super.key,
    required this.initialTime,
    this.use24HourFormat = true,
    this.onChanged,
    this.onCancel,
    this.onSubmit,
    this.style = const TimePickerStyle(),
    this.labels,
  });

  /// 初始时间。
  final TimeOfDay initialTime;

  /// 是否 24 小时制。
  ///
  /// 只影响**小时怎么显示、怎么输入**：24 小时制显示 `00..23`、框里接受 `0..23`；
  /// 12 小时制显示 `01..12`、框里接受 `1..12`。
  ///
  /// 表盘的内圈永远是 12 小时表盘（`12 1 … 11`），24 小时制时靠下面的「上午 /
  /// 下午」补上那 12 小时 —— 168 直径的表盘塞不下 24 个数字。
  final bool use24HourFormat;

  /// 每次改动都回调（拖表盘时会连续触发）；不需要可以不传。
  final ValueChanged<TimeOfDay>? onChanged;

  /// 点「取消」。传了它（或 [onSubmit]）才会显示底部那行按钮。
  final VoidCallback? onCancel;

  /// 点「确定」。
  final ValueChanged<TimeOfDay>? onSubmit;

  /// 尺寸与文字样式。
  final TimePickerStyle style;

  /// 文案（上午 / 下午 / 时 / 分 / 取消 / 确定）；不传按 locale 自动选。
  final TimePickerLabels? labels;

  @override
  State<TimePickerPanel> createState() => _TimePickerPanelState();
}

class _TimePickerPanelState extends State<TimePickerPanel> {
  late int _hour = widget.initialTime.hour;
  late int _minute = widget.initialTime.minute;
  TimeDialMode _mode = TimeDialMode.hour;

  late final TextEditingController _hourCtrl = TextEditingController(
    text: _hourText,
  );
  late final TextEditingController _minuteCtrl = TextEditingController(
    text: _minuteText,
  );
  final FocusNode _hourFocus = FocusNode(debugLabel: 'time-picker-hour');
  final FocusNode _minuteFocus = FocusNode(debugLabel: 'time-picker-minute');

  TimePickerStyle get _style => widget.style;

  TimePickerLabels get _labels =>
      widget.labels ?? TimePickerLabels.of(context);

  TimeOfDay get _value => TimeOfDay(hour: _hour, minute: _minute);

  bool get _isPm => _hour >= 12;

  /// 小时框里显示的数字：24 小时制是 `00..23`，12 小时制是 `01..12`。
  String get _hourText => widget.use24HourFormat
      ? _hour.toString().padLeft(2, '0')
      : (_hour % 12 == 0 ? 12 : _hour % 12).toString().padLeft(2, '0');

  String get _minuteText => _minute.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    _hourFocus.addListener(_onFocusChanged);
    _minuteFocus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant TimePickerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部换了初始值：整组跟上。
    if (widget.initialTime != oldWidget.initialTime) {
      _hour = widget.initialTime.hour;
      _minute = widget.initialTime.minute;
      _hourCtrl.text = _hourText;
      _minuteCtrl.text = _minuteText;
      return;
    }
    // 只是换了小时制：**别把用户选的时间冲掉**，只改文字格式（正在编辑的那段
    // 先不动，免得打断输入）。
    if (widget.use24HourFormat != oldWidget.use24HourFormat) {
      if (!_hourFocus.hasFocus) _hourCtrl.text = _hourText;
      if (!_minuteFocus.hasFocus) _minuteCtrl.text = _minuteText;
    }
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  /// 焦点落到哪一段，表盘就调哪一项；离开时把数字补齐 / 夹到合法范围。
  void _onFocusChanged() {
    if (!mounted) return;
    if (_hourFocus.hasFocus) {
      setState(() => _mode = TimeDialMode.hour);
      _selectAll(_hourCtrl);
    } else if (_minuteFocus.hasFocus) {
      setState(() => _mode = TimeDialMode.minute);
      _selectAll(_minuteCtrl);
    }
    if (!_hourFocus.hasFocus) _normalizeHour();
    if (!_minuteFocus.hasFocus) _normalizeMinute();
  }

  void _selectAll(TextEditingController controller) {
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  /// 点输入框时：切到对应项，并把内容全选（直接敲数字就是替换，不用先删）。
  void _onFieldTap(TimeDialMode mode) {
    setState(() => _mode = mode);
    // 等 TextField 自己按点击位置放好光标之后再全选。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final FocusNode node = mode == TimeDialMode.hour
          ? _hourFocus
          : _minuteFocus;
      if (!node.hasFocus) return;
      _selectAll(
        mode == TimeDialMode.hour ? _hourCtrl : _minuteCtrl,
      );
    });
  }

  void _normalizeHour() {
    final int? parsed = int.tryParse(_hourCtrl.text);
    final int value = parsed ?? _hour;
    if (widget.use24HourFormat) {
      _setHour(value.clamp(0, 23));
      return;
    }
    // 12 小时制：0 / 13 之类都夹回 1..12，上下午保持不变。
    final int hour12 = value.clamp(1, 12);
    _setHour(hour12 % 12 + (_isPm ? 12 : 0));
  }

  void _normalizeMinute() {
    final int? parsed = int.tryParse(_minuteCtrl.text);
    _setMinute((parsed ?? _minute).clamp(0, 59));
  }

  void _setHour(int hour, {bool syncText = true}) {
    final int next = hour.clamp(0, 23);
    if (next != _hour) {
      setState(() => _hour = next);
      _notify();
    }
    if (syncText) _hourCtrl.text = _hourText;
  }

  void _setMinute(int minute, {bool syncText = true}) {
    final int next = minute.clamp(0, 59);
    if (next != _minute) {
      setState(() => _minute = next);
      _notify();
    }
    if (syncText) _minuteCtrl.text = _minuteText;
  }

  void _notify() => widget.onChanged?.call(_value);

  /// 输入框里敲字：合法就立刻同步到表盘，非法先留着（失焦时再夹）。
  void _onHourTyped(String text) {
    final int? value = int.tryParse(text);
    if (value == null) return;
    if (widget.use24HourFormat) {
      if (value > 23) return;
      _setHour(value, syncText: false);
      return;
    }
    if (value == 0 || value > 12) return;
    _setHour(value % 12 + (_isPm ? 12 : 0), syncText: false);
  }

  void _onMinuteTyped(String text) {
    final int? value = int.tryParse(text);
    if (value == null || value > 59) return;
    _setMinute(value, syncText: false);
  }

  /// 表盘内圈（时）回调：拿到的是 12 小时表盘上的 `1..12`，上下午由面板补。
  void _onDialHour(int hour12) {
    if (_mode != TimeDialMode.hour) setState(() => _mode = TimeDialMode.hour);
    _setHour(hour12 % 12 + (_isPm ? 12 : 0));
  }

  /// 表盘外圈（分）回调：`0..59`，指针可以停在任意一分钟。
  void _onDialMinute(int minute) {
    if (_mode != TimeDialMode.minute) {
      setState(() => _mode = TimeDialMode.minute);
    }
    _setMinute(minute);
  }

  void _setMeridiem(bool pm) {
    if (pm == _isPm) return;
    _setHour((_hour + 12) % 24);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TimePickerStyle style = _style;
    final bool showActions =
        widget.onSubmit != null || widget.onCancel != null;

    return Material(
      key: kTimePickerPanelKey,
      color: style.backgroundColor ?? scheme.surface,
      elevation: style.elevation,
      // M3 会按 elevation 把主色叠到表面上，面板会发紫；弹层要干净的白（或
      // 用户给的 backgroundColor），所以把 surface tint 关掉，只留投影。
      surfaceTintColor: Colors.transparent,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: _buildTimeColumn(theme)),
                  const SizedBox(width: 8),
                  TimeDial(
                    hour: _hour,
                    minute: _minute,
                    mode: _mode,
                    style: style,
                    onHourChanged: _onDialHour,
                    onMinuteChanged: _onDialMinute,
                    // 跨圈拖动时指针换了圈，左边高亮的那段也要跟着走。
                    onModeChanged: (TimeDialMode mode) {
                      if (_mode != mode) setState(() => _mode = mode);
                    },
                  ),
                ],
              ),
              if (showActions) ...<Widget>[
                const SizedBox(height: 8),
                _buildActions(theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── 左边：可直接编辑的时间 ──────────────────────────────────────────────

  Widget _buildTimeColumn(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    final TimePickerStyle style = _style;
    final TimePickerLabels labels = _labels;
    final TextStyle base =
        style.timeTextStyle ??
        const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w500,
          height: 1.1,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        );
    final TextStyle timeStyle = base.copyWith(color: scheme.onSurface);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 窄了整体缩一点，宁可小一点也不要溢出。
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildField(
                theme,
                hour: true,
                textStyle: timeStyle,
                semanticLabel: labels.hour,
              ),
              SizedBox(
                width: 6,
                height: style.fieldHeight,
                child: Center(
                  child: Text(
                    ':',
                    style: timeStyle.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              _buildField(
                theme,
                hour: false,
                textStyle: timeStyle,
                semanticLabel: labels.minute,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // 上午 / 下午常驻：内圈是 12 小时表盘，没有它分不出凌晨 3 点和下午 3 点。
        _buildMeridiem(theme),
      ],
    );
  }

  Widget _buildField(
    ThemeData theme, {
    required bool hour,
    required TextStyle textStyle,
    required String semanticLabel,
  }) {
    final ColorScheme scheme = theme.colorScheme;
    final TimePickerStyle style = _style;
    final TimeDialMode mode = hour ? TimeDialMode.hour : TimeDialMode.minute;
    final bool active = _mode == mode;
    final TextEditingController controller = hour ? _hourCtrl : _minuteCtrl;
    final FocusNode focusNode = hour ? _hourFocus : _minuteFocus;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: style.fieldWidth,
          height: style.fieldHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? style.editBackgroundColor ??
                      scheme.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          // 不再写「时 / 分」小字（谁都知道那是几点几分），语义上仍留个标签，
          // 读屏软件还会念「时 09」。
          child: Semantics(
            label: semanticLabel,
            child: TextField(
              key: hour ? kTimePickerHourFieldKey : kTimePickerMinuteFieldKey,
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              style: textStyle,
              cursorColor: style.textCursorColor ?? scheme.primary,
              cursorWidth: 1.6,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              decoration: const InputDecoration.collapsed(hintText: ''),
              onTap: () => _onFieldTap(mode),
              onChanged: hour ? _onHourTyped : _onMinuteTyped,
              onSubmitted: (String _) =>
                  hour ? _normalizeHour() : _normalizeMinute(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeridiem(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    final TimePickerStyle style = _style;
    final TimePickerLabels labels = _labels;
    // 从主题派生，别用裸样式（会丢字体）。
    final TextStyle base =
        (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
          fontSize: 11.5,
          height: 1.2,
          letterSpacing: 0,
        );
    final TextStyle textStyle = style.meridiemTextStyle == null
        ? base
        : base.merge(style.meridiemTextStyle);

    // 两段等宽，选中块才能整段平移；固定宽度也让切语言时布局不跳。
    const double segWidth = 40;
    const double segRadius = 6;
    const Duration animDuration = Duration(milliseconds: 200);

    Widget segment(String text, bool pm) {
      final bool selected = pm == _isPm;
      return SizedBox(
        width: segWidth,
        child: InkWell(
          onTap: () => _setMeridiem(pm),
          mouseCursor: style.mouseCursor,
          borderRadius: BorderRadius.circular(segRadius),
          child: Center(
            // 文字颜色跟着滑块走：滑到哪边哪边的字变白。
            child: AnimatedDefaultTextStyle(
              duration: animDuration,
              curve: Curves.easeOut,
              style: textStyle.copyWith(
                color: selected
                    ? scheme.onPrimary
                    : scheme.onSurface.withValues(alpha: 0.6),
                fontWeight: selected ? FontWeight.w600 : textStyle.fontWeight,
              ),
              child: Text(text),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        width: segWidth * 2 + 4,
        height: 28,
        child: Stack(
          children: <Widget>[
            // 唯一一块主色底：AM / PM 之间平移，不再靠两段各自变色。
            AnimatedPositioned(
              duration: animDuration,
              curve: Curves.easeOut,
              left: _isPm ? segWidth + 2 : 2,
              top: 2,
              bottom: 2,
              width: segWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(segRadius),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                segment(labels.am, false),
                segment(labels.pm, true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 底部按钮 ────────────────────────────────────────────────────────────

  Widget _buildActions(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    final TimePickerStyle style = _style;
    final TimePickerLabels labels = _labels;
    // 同样从主题派生：ButtonStyle.textStyle 是整条替换，裸样式会丢掉字体。
    final TextStyle base =
        (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          height: 1.2,
          letterSpacing: 0,
        );
    final TextStyle actionStyle = style.actionTextStyle == null
        ? base
        : base.merge(style.actionTextStyle);
    const EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 8,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        if (widget.onCancel != null)
          TextButton(
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(
              padding: padding,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: actionStyle,
            ).copyWith(
              mouseCursor: WidgetStatePropertyAll<MouseCursor>(
                style.mouseCursor,
              ),
            ),
            child: Text(labels.cancel),
          ),
        if (widget.onSubmit != null) ...<Widget>[
          const SizedBox(width: 4),
          FilledButton(
            onPressed: () => widget.onSubmit?.call(_value),
            style: FilledButton.styleFrom(
              padding: padding,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const StadiumBorder(),
              textStyle: actionStyle,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ).copyWith(
              mouseCursor: WidgetStatePropertyAll<MouseCursor>(
                style.mouseCursor,
              ),
            ),
            child: Text(labels.confirm),
          ),
        ],
      ],
    );
  }
}

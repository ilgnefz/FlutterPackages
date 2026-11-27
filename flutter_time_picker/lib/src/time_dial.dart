import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'time_picker_style.dart';
import 'time_picker_types.dart';

/// 表盘本体的 key（面板和测试都用它）。
const Key kTimeDialKey = ValueKey<String>('time-dial');

/// 双层表盘：**外圈调分、内圈调时**，两圈同时可见、同时可点。
///
/// 照着真表盘来：
///
/// - 外圈是分钟刻度 `00 05 … 55`，点 / 拖可以停在任意一分钟（不是只能选 5 的倍数）；
/// - 内圈是 12 小时刻度 `12 1 2 … 11`，也就是表面的「小时盘」；
/// - 当前正在调的那一圈（[mode]）画指针杆 + 实心圆点，另一圈只留一个空心圆点，
///   两个值一眼都能看到，不用先切「现在调什么」；
/// - **按住拖动时指针跟着手指跨圈**：从外圈滑到内圈就改成调小时，滑回外圈就改
///   分钟，不用抬手重新点一圈。
///
/// **内圈永远是 12 小时表盘**：24 小时制的上午 / 下午由面板上的「上午 / 下午」
/// 来选（`12` 点方向在 24 小时制里可能是 `00` 也可能是 `12`，光看表盘分不出来，
/// 所以不硬塞 24 个数字进去——168 直径塞 24 个数字会糊成一圈点）。
///
/// 回调里的小时是表盘上的 `1..12`，换算成 `0..23` 由面板负责。
class TimeDial extends StatefulWidget {
  const TimeDial({
    super.key,
    required this.hour,
    required this.minute,
    required this.mode,
    required this.onHourChanged,
    required this.onMinuteChanged,
    this.onModeChanged,
    this.style = const TimePickerStyle(),
  });

  /// 当前小时（`0..23`，面板内部的真实值；表盘只取 `hour % 12`）。
  final int hour;

  /// 当前分钟（`0..59`）。
  final int minute;

  /// 正在调哪一圈（决定指针画在哪圈、哪圈是实心点）。
  final TimeDialMode mode;

  /// 点内圈拿到的小时（`1..12`，12 小时表盘上的数字）。
  final ValueChanged<int> onHourChanged;

  /// 点外圈拿到的分钟（`0..59`）。
  final ValueChanged<int> onMinuteChanged;

  /// 拖动跨过分界、落点换圈时回调，让面板把 [mode]（以及左边高亮的输入框）
  /// 跟着切过去。点哪一圈不回调——那一次由值回调里的 mode 同步负责。
  final ValueChanged<TimeDialMode>? onModeChanged;

  /// 尺寸与配色。
  final TimePickerStyle style;

  @override
  State<TimeDial> createState() => _TimeDialState();
}

class _TimeDialState extends State<TimeDial> {
  /// 当前这一下判在哪一圈。拖动跨过分界时改这里，并且只在跨圈的那一刻
  /// 回调一次 [TimeDial.onModeChanged]——同一圈里每帧都通知会让面板反复重建。
  late TimeDialMode _activeMode;

  @override
  void initState() {
    super.initState();
    _activeMode = widget.mode;
  }

  @override
  void didUpdateWidget(TimeDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部（点输入框 / 切上下午）改了 mode 就跟着同步；表盘自己拖动时判的圈
    // 不走这里（那时 widget.mode 还是旧值，面板会在收到回调后才更新）。
    if (oldWidget.mode != widget.mode) _activeMode = widget.mode;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double size = widget.style.dialSize;
    final Color hand = widget.style.dialHandColor ?? scheme.primary;
    // 从主题的文字样式派生：直接给一个裸 TextStyle 会把 fontFamily 一起抹掉，
    // 用了自定义字体的应用里表盘数字会掉回默认字体（甚至变方块）。
    final TextStyle base = theme.textTheme.bodyMedium ?? const TextStyle();
    final TextStyle minuteLabel = base
        .copyWith(fontSize: 11.5, fontWeight: FontWeight.w400)
        .merge(widget.style.dialLabelStyle);
    final TextStyle hourLabel = base
        .copyWith(fontSize: 10, fontWeight: FontWeight.w400)
        .merge(widget.style.dialInnerLabelStyle);

    return SizedBox(
      key: kTimeDialKey,
      width: size,
      height: size,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size box = constraints.biggest;
          return MouseRegion(
            cursor: widget.style.mouseCursor,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (TapDownDetails d) => _apply(d.localPosition, box),
              onPanStart: (DragStartDetails d) =>
                  _apply(d.localPosition, box),
              onPanUpdate: (DragUpdateDetails d) =>
                  _apply(d.localPosition, box),
              child: CustomPaint(
                size: box,
                painter: _DialPainter(
                  hour: widget.hour,
                  minute: widget.minute,
                  mode: widget.mode,
                  background:
                      widget.style.dialBackgroundColor ??
                      scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  handColor: hand,
                  labelColor: scheme.onSurface.withValues(alpha: 0.78),
                  selectedLabelColor:
                      widget.style.dialSelectedLabelColor ?? scheme.onPrimary,
                  minuteLabelStyle: minuteLabel,
                  hourLabelStyle: hourLabel,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 按半径判内外圈：内圈改时，外圈改分。分界在两圈数字中间。
  TimeDialMode _targetOf(Offset local, Size box) {
    final Offset center = box.center(Offset.zero);
    final double radius = box.shortestSide / 2;
    return (local - center).distance < radius * _DialPainter.splitRatio
        ? TimeDialMode.hour
        : TimeDialMode.minute;
  }

  /// 把一次点击 / 拖动折算成小时或分钟。
  void _apply(Offset local, Size box) {
    final Offset center = box.center(Offset.zero);
    final Offset v = local - center;
    // 正中心：角度没意义，保持原值。
    if (v.distanceSquared < 1) return;

    // 12 点方向是 0，顺时针一圈是 1。
    double turns = (math.atan2(v.dy, v.dx) + math.pi / 2) / (2 * math.pi);
    turns %= 1;

    // 每一帧都按当前落点判圈：手指跨过分界就从改分切到改时（或反过来）。
    final TimeDialMode mode = _targetOf(local, box);
    if (mode != _activeMode) {
      _activeMode = mode;
      widget.onModeChanged?.call(mode);
    }
    if (mode == TimeDialMode.minute) {
      final int next = (turns * 60).round() % 60;
      if (next != widget.minute) widget.onMinuteChanged(next);
      return;
    }
    final int index = (turns * 12).round() % 12;
    final int next = index == 0 ? 12 : index;
    // 12 和 0 在表盘上是同一格，按 12 取模比，免得每次点 12 都回调一遍。
    if (index != widget.hour % 12) widget.onHourChanged(next);
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.hour,
    required this.minute,
    required this.mode,
    required this.background,
    required this.handColor,
    required this.labelColor,
    required this.selectedLabelColor,
    required this.minuteLabelStyle,
    required this.hourLabelStyle,
  });

  /// 内 / 外圈的分界（占半径的比例）：在这之内算内圈（改时）。
  ///
  /// 两圈数字分别在 [minuteRatio] / [hourRatio]，分界取在中间偏外一点，
  /// 免得想点分钟的时候被吸到小时内圈里。
  static const double splitRatio = 0.67;

  /// 外圈分钟数字离圆心的半径比例。
  static const double minuteRatio = 0.80;

  /// 内圈小时数字离圆心的半径比例。
  ///
  /// 和 [minuteRatio] 拉开 0.42 个半径：两圈数字各自成环，中间留出的空白
  /// 也让「哪个是时、哪个是分」一眼能分开。
  static const double hourRatio = 0.43;

  /// 外圈圆点（分钟）的半径比例。
  static const double _minuteMarker = 0.115;

  /// 内圈圆点（小时）的半径比例。
  static const double _hourMarker = 0.105;

  final int hour;
  final int minute;
  final TimeDialMode mode;
  final Color background;
  final Color handColor;
  final Color labelColor;
  final Color selectedLabelColor;
  final TextStyle minuteLabelStyle;
  final TextStyle hourLabelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;

    canvas.drawCircle(center, radius, Paint()..color = background);

    final double minuteAngle = -math.pi / 2 + minute * math.pi / 30;
    final double hourAngle = -math.pi / 2 + (hour % 12) * math.pi / 6;
    final Offset minutePos = _polar(center, radius * minuteRatio, minuteAngle);
    final Offset hourPos = _polar(center, radius * hourRatio, hourAngle);
    final double minuteMarker = radius * _minuteMarker;
    final double hourMarker = radius * _hourMarker;
    final bool minuteActive = mode == TimeDialMode.minute;

    // 指针杆只画给正在调的那一圈，另一圈留空心点，两个值都看得见又不打架。
    if (minuteActive) {
      _paintHand(canvas, center, minutePos);
    } else {
      _paintHand(canvas, center, hourPos);
    }

    for (int i = 0; i < 12; i++) {
      final double angle = -math.pi / 2 + i * math.pi / 6;
      _drawLabel(
        canvas,
        center,
        radius * minuteRatio,
        angle,
        (i * 5).toString().padLeft(2, '0'),
        minuteLabelStyle,
        minutePos,
        minuteMarker,
      );
      _drawLabel(
        canvas,
        center,
        radius * hourRatio,
        angle,
        i == 0 ? '12' : '$i',
        hourLabelStyle,
        hourPos,
        hourMarker,
      );
    }

    _paintMarker(
      canvas,
      minutePos,
      minuteMarker,
      minute.toString().padLeft(2, '0'),
      style: minuteLabelStyle,
      active: minuteActive,
    );
    _paintMarker(
      canvas,
      hourPos,
      hourMarker,
      hour % 12 == 0 ? '12' : '${hour % 12}',
      style: hourLabelStyle,
      active: !minuteActive,
    );

    canvas.drawCircle(center, 3.5, Paint()..color = handColor);
  }

  Offset _polar(Offset center, double radius, double angle) =>
      center + Offset(math.cos(angle), math.sin(angle)) * radius;

  void _paintHand(Canvas canvas, Offset center, Offset tip) {
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = handColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  /// 数字刻度：和圆点重叠的就不画了（圆点上有更大的白字）。
  void _drawLabel(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    String text,
    TextStyle style,
    Offset markerPos,
    double markerRadius,
  ) {
    final Offset pos = _polar(center, radius, angle);
    // 留出半个字宽：只差一点点的时候宁可这个数字不画，也不要被圆点啃掉一半。
    if ((pos - markerPos).distance <
        markerRadius + (style.fontSize ?? 12) * 0.6) {
      return;
    }
    // 颜色只由组件决定（选中 / 未选中），样式里传的颜色不参与。
    _paintText(canvas, pos, text, style.copyWith(color: labelColor));
  }

  /// 选中值：实心圆点（正在调的一圈）或空心圆点（另一圈），数字放在圆点里。
  void _paintMarker(
    Canvas canvas,
    Offset pos,
    double radius,
    String text, {
    required TextStyle style,
    required bool active,
  }) {
    if (active) {
      canvas.drawCircle(pos, radius, Paint()..color = handColor);
      _paintText(
        canvas,
        pos,
        text,
        style.copyWith(
          color: selectedLabelColor,
          fontWeight: FontWeight.w600,
        ),
      );
      return;
    }
    // 空心点先铺底色，把下面的刻度盖干净。
    canvas.drawCircle(pos, radius, Paint()..color = background);
    canvas.drawCircle(
      pos,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = handColor.withValues(alpha: 0.45),
    );
    _paintText(
      canvas,
      pos,
      text,
      style.copyWith(
        color: handColor.withValues(alpha: 0.75),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  void _paintText(Canvas canvas, Offset center, String text, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) {
    return hour != old.hour ||
        minute != old.minute ||
        mode != old.mode ||
        background != old.background ||
        handColor != old.handColor ||
        labelColor != old.labelColor ||
        selectedLabelColor != old.selectedLabelColor ||
        minuteLabelStyle != old.minuteLabelStyle ||
        hourLabelStyle != old.hourLabelStyle;
  }
}

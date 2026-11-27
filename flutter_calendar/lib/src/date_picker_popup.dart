import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart' hide showDatePicker;

import 'calendar_panel.dart';
import 'calendar_style.dart';
import 'calendar_types.dart';

/// 在任意按钮 / 组件旁边弹出一个日期选择面板。
///
/// 和 Flutter Material 的 `showDatePicker` 同名，方便调用；如果同一个文件里
/// 还导入了 `material_ui` / `material.dart`，可以用本库提供的另一个名字
/// [showCalendarDatePicker]，或者 `hide` 掉系统那个：
///
/// ```dart
/// import 'package:flutter/material.dart' hide showDatePicker;
/// ```
///
/// [context] 只用来定位：取它的 [RenderObject] 作为锚点，所以任何按钮的
/// `Builder` 上下文都能直接用。面板默认显示在锚点下方，空间不够会自动翻到
/// 上方；也可以用 [placement] 强制放在上下左右。
///
/// 面板的尺寸、字号、圆角、翻月按钮样式都在 [style] 里；星期表头与年月的文案
/// 在 [labels] 里（不传按 locale 自动选，`en` 英文、其它中文）。[panelWidth]
/// 是只改宽度的老写法，等价于 `style.copyWith(width: panelWidth)`。
///
/// 返回用户选中的日期；点外部 / Esc / 没选就关闭时返回 null。
Future<DateTime?> showDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? selectedDate,
  CalendarPlacement placement = CalendarPlacement.bottom,
  double gap = 6,
  CalendarStyle style = const CalendarStyle(),
  CalendarLabels? labels,
  DateTime? firstDate,
  DateTime? lastDate,
  bool dismissOnOutsideTap = true,
  bool dismissOnEscape = true,
  Color? barrierColor,
  Duration animationDuration = const Duration(milliseconds: 140),
  double? panelWidth,
}) {
  return showCalendarDatePicker(
    context,
    initialDate: initialDate,
    selectedDate: selectedDate,
    placement: placement,
    gap: gap,
    style: style,
    labels: labels,
    firstDate: firstDate,
    lastDate: lastDate,
    dismissOnOutsideTap: dismissOnOutsideTap,
    dismissOnEscape: dismissOnEscape,
    barrierColor: barrierColor,
    animationDuration: animationDuration,
    panelWidth: panelWidth,
  );
}

/// [showDatePicker] 的另一个名字，避免和 Material 的同名函数混淆。
Future<DateTime?> showCalendarDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? selectedDate,
  CalendarPlacement placement = CalendarPlacement.bottom,
  double gap = 6,
  CalendarStyle style = const CalendarStyle(),
  CalendarLabels? labels,
  DateTime? firstDate,
  DateTime? lastDate,
  bool dismissOnOutsideTap = true,
  bool dismissOnEscape = true,
  Color? barrierColor,
  Duration animationDuration = const Duration(milliseconds: 140),
  double? panelWidth,
}) {
  // `panelWidth` 是老写法，等价于 style.width；两个都给时以它为准。
  final CalendarStyle panelStyle = panelWidth == null
      ? style
      : style.copyWith(width: panelWidth);
  final RenderObject? target = context.findRenderObject();
  if (target is! RenderBox || !target.hasSize) {
    return Future<DateTime?>.value(null);
  }
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  final RenderObject? overlayObject = overlay.context.findRenderObject();
  if (overlayObject is! RenderBox) {
    return Future<DateTime?>.value(null);
  }
  final Rect targetRect = Rect.fromPoints(
    overlayObject.globalToLocal(target.localToGlobal(Offset.zero)),
    overlayObject.globalToLocal(
      target.localToGlobal(target.size.bottomRight(Offset.zero)),
    ),
  );

  final Completer<DateTime?> completer = Completer<DateTime?>();
  late final OverlayEntry entry;
  bool removed = false;

  void close([DateTime? value]) {
    if (removed) return;
    removed = true;
    entry.remove();
    entry.dispose();
    if (!completer.isCompleted) completer.complete(value);
  }

  entry = OverlayEntry(
    builder: (BuildContext overlayContext) => _DatePickerOverlay(
      targetRect: targetRect,
      placement: placement,
      gap: gap,
      style: panelStyle,
      labels: labels,
      initialDate: initialDate ?? selectedDate ?? DateTime.now(),
      selectedDate: selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      dismissOnOutsideTap: dismissOnOutsideTap,
      dismissOnEscape: dismissOnEscape,
      barrierColor: barrierColor,
      animationDuration: animationDuration,
      onClosed: close,
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _DatePickerOverlay extends StatefulWidget {
  const _DatePickerOverlay({
    required this.targetRect,
    required this.placement,
    required this.gap,
    required this.style,
    required this.labels,
    required this.initialDate,
    required this.selectedDate,
    required this.firstDate,
    required this.lastDate,
    required this.dismissOnOutsideTap,
    required this.dismissOnEscape,
    required this.barrierColor,
    required this.animationDuration,
    required this.onClosed,
  });

  final Rect targetRect;
  final CalendarPlacement placement;
  final double gap;
  final CalendarStyle style;
  final CalendarLabels? labels;
  final DateTime initialDate;
  final DateTime? selectedDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool dismissOnOutsideTap;
  final bool dismissOnEscape;
  final Color? barrierColor;
  final Duration animationDuration;
  final void Function(DateTime? value) onClosed;

  @override
  State<_DatePickerOverlay> createState() => _DatePickerOverlayState();
}

class _DatePickerOverlayState extends State<_DatePickerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final DateTime start = widget.selectedDate ?? widget.initialDate;
    _month = DateTime(start.year, start.month);
    _anim = AnimationController(vsync: this, duration: widget.animationDuration)
      ..forward();
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.94,
      end: 1,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (widget.dismissOnEscape &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClosed(null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: <Widget>[
            if (widget.dismissOnOutsideTap || widget.barrierColor != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.dismissOnOutsideTap
                      ? () => widget.onClosed(null)
                      : null,
                  child: widget.barrierColor == null
                      ? const SizedBox.expand()
                      : ColoredBox(color: widget.barrierColor!),
                ),
              ),
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _PopupLayoutDelegate(
                  target: widget.targetRect,
                  placement: widget.placement,
                  gap: widget.gap,
                  padding: media.padding,
                ),
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    alignment: _scaleAlignment(widget.placement),
                    child: CalendarPanel(
                      month: _month,
                      selectedDate: widget.selectedDate,
                      firstDate: widget.firstDate,
                      lastDate: widget.lastDate,
                      style: widget.style,
                      labels: widget.labels,
                      // 面板自己维护翻月状态；这里只记住当前月，
                      // 万一父级重建也不会把面板跳回初始月份。
                      onMonthChanged: (DateTime month) => _month = month,
                      onDateSelected: (DateTime date) => widget.onClosed(date),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Alignment _scaleAlignment(CalendarPlacement placement) {
  switch (placement) {
    case CalendarPlacement.bottom:
      return Alignment.topCenter;
    case CalendarPlacement.top:
      return Alignment.bottomCenter;
    case CalendarPlacement.left:
      return Alignment.centerRight;
    case CalendarPlacement.right:
      return Alignment.centerLeft;
  }
}

class _PopupLayoutDelegate extends SingleChildLayoutDelegate {
  const _PopupLayoutDelegate({
    required this.target,
    required this.placement,
    required this.gap,
    required this.padding,
  });

  final Rect target;
  final CalendarPlacement placement;
  final double gap;
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double left = padding.left;
    final double top = padding.top;
    final double right = size.width - padding.right;
    final double bottom = size.height - padding.bottom;

    final double belowY = target.bottom + gap;
    final double aboveY = target.top - gap - childSize.height;
    final bool fitsBelow = belowY + childSize.height <= bottom;
    final bool fitsAbove = aboveY >= top;
    final double rightX = target.right + gap;
    final double leftX = target.left - gap - childSize.width;
    final bool fitsRight = rightX + childSize.width <= right;
    final bool fitsLeft = leftX >= left;

    double x;
    double y;
    switch (placement) {
      case CalendarPlacement.bottom:
        x = target.center.dx - childSize.width / 2;
        // 首选放下面；放不下就翻到上面，两边都不够就夹回视口。
        y = fitsBelow ? belowY : (fitsAbove ? aboveY : belowY);
        break;
      case CalendarPlacement.top:
        x = target.center.dx - childSize.width / 2;
        y = fitsAbove ? aboveY : (fitsBelow ? belowY : aboveY);
        break;
      case CalendarPlacement.right:
        x = fitsRight ? rightX : (fitsLeft ? leftX : rightX);
        y = target.center.dy - childSize.height / 2;
        break;
      case CalendarPlacement.left:
        x = fitsLeft ? leftX : (fitsRight ? rightX : leftX);
        y = target.center.dy - childSize.height / 2;
        break;
    }

    x = x.clamp(left, math.max(left, right - childSize.width));
    y = y.clamp(top, math.max(top, bottom - childSize.height));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PopupLayoutDelegate oldDelegate) {
    return target != oldDelegate.target ||
        placement != oldDelegate.placement ||
        gap != oldDelegate.gap ||
        padding != oldDelegate.padding;
  }
}

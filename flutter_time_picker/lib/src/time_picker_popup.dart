import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart' hide showTimePicker;

import 'time_picker_panel.dart';
import 'time_picker_style.dart';
import 'time_picker_types.dart';

/// 在任意按钮 / 输入框旁边弹出一个紧凑的时间面板。
///
/// 和 Flutter Material 的 `showTimePicker` 同名，方便调用；如果同一个文件里还
/// 导入了 `material_ui` / `material.dart`，可以用本库的另一个名字
/// [showCompactTimePicker]，或者 `hide` 掉系统那个：
///
/// ```dart
/// import 'package:material_ui/material_ui.dart' hide showTimePicker;
/// ```
///
/// [context] 只用来定位：取它的 [RenderObject] 当锚点，所以任何按钮的 `Builder`
/// 上下文都能直接用。默认显示在锚点下方，放不下会自动翻到上方；也能用
/// [placement] 强制上下左右。
///
/// 返回用户点「确定」时的时间；点外部 / Esc / 取消关闭时返回 null。
Future<TimeOfDay?> showTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
  TimePickerPlacement placement = TimePickerPlacement.bottom,
  double gap = 6,
  bool use24HourFormat = true,
  TimePickerStyle style = const TimePickerStyle(),
  TimePickerLabels? labels,
  bool dismissOnOutsideTap = true,
  bool dismissOnEscape = true,
  Color? barrierColor,
  Duration animationDuration = const Duration(milliseconds: 140),
}) {
  return showCompactTimePicker(
    context,
    initialTime: initialTime,
    placement: placement,
    gap: gap,
    use24HourFormat: use24HourFormat,
    style: style,
    labels: labels,
    dismissOnOutsideTap: dismissOnOutsideTap,
    dismissOnEscape: dismissOnEscape,
    barrierColor: barrierColor,
    animationDuration: animationDuration,
  );
}

/// [showTimePicker] 的另一个名字，避免和 Material 的同名函数混淆。
Future<TimeOfDay?> showCompactTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
  TimePickerPlacement placement = TimePickerPlacement.bottom,
  double gap = 6,
  bool use24HourFormat = true,
  TimePickerStyle style = const TimePickerStyle(),
  TimePickerLabels? labels,
  bool dismissOnOutsideTap = true,
  bool dismissOnEscape = true,
  Color? barrierColor,
  Duration animationDuration = const Duration(milliseconds: 140),
}) {
  final RenderObject? target = context.findRenderObject();
  if (target is! RenderBox || !target.hasSize) {
    return Future<TimeOfDay?>.value(null);
  }
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  final RenderObject? overlayObject = overlay.context.findRenderObject();
  if (overlayObject is! RenderBox) {
    return Future<TimeOfDay?>.value(null);
  }
  final Rect targetRect = Rect.fromPoints(
    overlayObject.globalToLocal(target.localToGlobal(Offset.zero)),
    overlayObject.globalToLocal(
      target.localToGlobal(target.size.bottomRight(Offset.zero)),
    ),
  );

  final Completer<TimeOfDay?> completer = Completer<TimeOfDay?>();
  late final OverlayEntry entry;
  bool removed = false;

  void close([TimeOfDay? value]) {
    if (removed) return;
    removed = true;
    entry.remove();
    entry.dispose();
    if (!completer.isCompleted) completer.complete(value);
  }

  entry = OverlayEntry(
    builder: (BuildContext overlayContext) => _TimePickerOverlay(
      targetRect: targetRect,
      placement: placement,
      gap: gap,
      use24HourFormat: use24HourFormat,
      style: style,
      labels: labels,
      initialTime: initialTime,
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

class _TimePickerOverlay extends StatefulWidget {
  const _TimePickerOverlay({
    required this.targetRect,
    required this.placement,
    required this.gap,
    required this.use24HourFormat,
    required this.style,
    required this.labels,
    required this.initialTime,
    required this.dismissOnOutsideTap,
    required this.dismissOnEscape,
    required this.barrierColor,
    required this.animationDuration,
    required this.onClosed,
  });

  final Rect targetRect;
  final TimePickerPlacement placement;
  final double gap;
  final bool use24HourFormat;
  final TimePickerStyle style;
  final TimePickerLabels? labels;
  final TimeOfDay initialTime;
  final bool dismissOnOutsideTap;
  final bool dismissOnEscape;
  final Color? barrierColor;
  final Duration animationDuration;
  final void Function(TimeOfDay? value) onClosed;

  @override
  State<_TimePickerOverlay> createState() => _TimePickerOverlayState();
}

class _TimePickerOverlayState extends State<_TimePickerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
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
                    child: TimePickerPanel(
                      initialTime: widget.initialTime,
                      use24HourFormat: widget.use24HourFormat,
                      style: widget.style,
                      labels: widget.labels,
                      onCancel: () => widget.onClosed(null),
                      onSubmit: (TimeOfDay time) => widget.onClosed(time),
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

Alignment _scaleAlignment(TimePickerPlacement placement) {
  switch (placement) {
    case TimePickerPlacement.bottom:
      return Alignment.topCenter;
    case TimePickerPlacement.top:
      return Alignment.bottomCenter;
    case TimePickerPlacement.left:
      return Alignment.centerRight;
    case TimePickerPlacement.right:
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
  final TimePickerPlacement placement;
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
      case TimePickerPlacement.bottom:
        x = target.center.dx - childSize.width / 2;
        // 首选放下面；放不下就翻到上面，两边都不够就夹回视口。
        y = fitsBelow ? belowY : (fitsAbove ? aboveY : belowY);
        break;
      case TimePickerPlacement.top:
        x = target.center.dx - childSize.width / 2;
        y = fitsAbove ? aboveY : (fitsBelow ? belowY : aboveY);
        break;
      case TimePickerPlacement.right:
        x = fitsRight ? rightX : (fitsLeft ? leftX : rightX);
        y = target.center.dy - childSize.height / 2;
        break;
      case TimePickerPlacement.left:
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

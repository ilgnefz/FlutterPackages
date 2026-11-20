import 'package:material_ui/material_ui.dart';

import 'color_picker.dart';
import 'hex.dart';
import 'popover_host.dart';

/// 「一个色块 + 点开弹面板」的组合。
///
/// ```dart
/// ColorPickerButton(
///   initialColor: Colors.deepPurple,
///   onChanged: (Color color) => setState(() => _color = color),
/// )
/// ```
///
/// 弹层是本包自带的 [PopoverHost]（`OverlayEntry` + 坐标换算，不依赖第三方
/// 弹层库），所以整个包只有 Flutter 一个依赖。
///
/// 传 [child] 可以换成任意**外观**（图标、带颜色名的按钮…），点击仍由本组件
/// 接管，面板行为不变；child 里不要再挂自己的 `onPressed` / `onTap`，否则
/// 它的手势会赢下点击、面板打不开（这种「自己的按钮自己调弹出」的场景用
/// `showColorPicker`）。
///
/// 选择器不会在松手时自动收起（拖动中每次松手都算一次结束，自动关会打断
/// 连续调色），点空白处 / 按 Esc 关闭，和桌面软件的习惯一致。
class ColorPickerButton extends StatefulWidget {
  const ColorPickerButton({
    super.key,
    this.value,
    this.initialColor = const Color(0xFF2B7FFF),
    this.onChanged,
    this.onChangeEnd,
    this.size = 32,
    this.borderRadius,
    this.child,
    this.enabled = true,
    this.mouseCursor,
    this.placement = ColorPickerPlacement.bottom,
    this.align = ColorPickerAlign.start,
    this.panelWidth = 260,
    this.panelPadding = const EdgeInsets.all(12),
    this.panelRadius = 16,
    this.panelColor,
    this.showHexField = true,
    this.hexFormat = ColorHexFormat.hashRgb,
    this.onOpenChanged,
  });

  /// 当前颜色；传 null 时由组件自己记（非受控）。
  final Color? value;

  /// 非受控模式下的初始颜色。
  final Color initialColor;

  /// 拖动 / 输入时按帧回调（每秒几十次）。
  ///
  /// 参数是 `0xAARRGGBB` 的整数（`0xFF2B7FFF` 这种，等价 `color.toARGB32()`）。
  /// 别在这里做重活（改全局主题、整页重建、写库），否则滑块会卡到松手才
  /// 跳到位；那些放 [onChangeEnd]。
  final ValueChanged<int>? onChanged;

  /// 松手 / 提交时回调一次；同样是 `0xAARRGGBB` 的整数。
  final ValueChanged<int>? onChangeEnd;

  /// 默认触发器（色块）的边长。
  final double size;

  /// 默认触发器的圆角；不传用 8。
  final double? borderRadius;

  /// 自定义触发器；给了就忽略 [size] / [borderRadius]。
  ///
  /// 只管外观：点击由本组件接管（内部套了 `GestureDetector`），所以 child 里
  /// 别自己再挂 `onTap` / `onPressed` —— 那会抢走手势、面板打不开。
  final Widget? child;

  /// 为 false 时触发器变灰、点不开面板。
  final bool enabled;

  /// 触发器上的鼠标指针；不传时启用为手型、禁用为普通箭头。
  final MouseCursor? mouseCursor;

  /// 面板相对触发器的首选方向（放不下会自动翻到对面）。
  final ColorPickerPlacement placement;

  /// 面板在交叉轴上的对齐方式。
  final ColorPickerAlign align;

  /// 面板宽度，透传给 [ColorPicker.width]。
  final double panelWidth;

  /// 面板卡片的内边距。
  final EdgeInsets panelPadding;

  /// 面板卡片圆角。
  final double panelRadius;

  /// 面板卡片底色；不传用主题的 `colorScheme.surface`。
  final Color? panelColor;

  /// 是否显示面板底部的当前色 + hex 输入。
  final bool showHexField;

  /// hex 的显示格式（`#RRGGBB` 或 `0xFFRRGGBB`）。
  final ColorHexFormat hexFormat;

  /// 面板展开 / 收起时回调。
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<ColorPickerButton> createState() => _ColorPickerButtonState();
}

class _ColorPickerButtonState extends State<ColorPickerButton> {
  final GlobalKey<PopoverHostState> _popoverKey = GlobalKey<PopoverHostState>(
    debugLabel: 'ColorPickerButton.popover',
  );

  late Color _color = widget.value ?? widget.initialColor;

  @override
  void didUpdateWidget(covariant ColorPickerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Color? value = widget.value;
    if (value != null && value != _color) _color = value;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget trigger =
        widget.child ??
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.enabled ? _color : _color.withAlpha(90),
            borderRadius: BorderRadius.circular(widget.borderRadius ?? 8),
            border: Border.all(color: scheme.onSurface.withAlpha(26)),
          ),
        );

    return PopoverHost(
      key: _popoverKey,
      enabled: widget.enabled,
      placement: widget.placement,
      align: widget.align,
      width: widget.panelWidth,
      padding: widget.panelPadding,
      radius: widget.panelRadius,
      backgroundColor: widget.panelColor,
      onOpenChanged: widget.onOpenChanged,
      contentBuilder: (BuildContext context) => ColorPicker(
        value: _color,
        width: widget.panelWidth,
        showHexField: widget.showHexField,
        hexFormat: widget.hexFormat,
        onChanged: (int argb) {
          setState(() => _color = Color(argb));
          widget.onChanged?.call(argb);
        },
        onChangeEnd: widget.onChangeEnd,
      ),
      child: MouseRegion(
        cursor:
            widget.mouseCursor ??
            (widget.enabled ? SystemMouseCursors.click : MouseCursor.defer),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _popoverKey.currentState?.toggle(),
          child: trigger,
        ),
      ),
    );
  }
}

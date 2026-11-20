part of 'anchored_dropdown.dart';

/// 随展开进度旋转 180° 的箭头，可放进任意触发组件里。
///
/// 配合 [AnchoredDropdown.triggerBuilder] 拿到的 `progress` 使用：
/// ```dart
/// triggerBuilder: (context, isOpen, progress) => Row(
///   children: [const Icon(Icons.image), AnchoredDropdownArrow(progress: progress)],
/// )
/// ```
class AnchoredDropdownArrow extends StatelessWidget {
  const AnchoredDropdownArrow({
    super.key,
    required this.progress,
    this.icon = Icons.keyboard_arrow_down,
    this.size = 18.0,
    this.color,
  });

  /// 展开进度 0 → 1；减弱动效时直接给 0 或 1 即可。
  final double progress;

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: progress.clamp(0.0, 1.0) * math.pi,
    child: Icon(icon, size: size, color: color),
  );
}

/// 一个「圆角边框 + 文字 + 旋转箭头」的便捷触发组件。
///
/// 只是普通 Widget，完全可以替换成 Icon、Image 或任意自定义组件；
/// 触发组件本身不由 [AnchoredDropdown] 绘制任何装饰。
class AnchoredDropdownField extends StatelessWidget {
  const AnchoredDropdownField({
    super.key,
    required this.label,
    this.progress = 0.0,
    this.height = 40.0,
    this.color,
    this.borderColor,
    this.foreground,
    this.muted,
    this.isHint = false,
    this.padding,
    this.radius = 12.0,
    this.style,
  });

  /// 显示的文字（通常是当前选中项或占位文案）。
  final String label;

  /// 展开进度，交给 [AnchoredDropdownArrow]。
  final double progress;

  final double height;

  /// 触发器背景 / 边框 / 前景色；为 null 时分别取 [DropdownStyle] 的
  /// `backgroundColor` / `borderColor` / `foreground` / `muted`，
  /// 所以不传也能跟随明暗主题。
  final Color? color;
  final Color? borderColor;
  final Color? foreground;
  final Color? muted;

  /// 为 true 时用 [muted] 颜色（未选中时的占位态）。
  final bool isHint;

  /// 文字 / 箭头到边框的距离；为 null 时取 [DropdownStyle.fieldPadding]。
  final EdgeInsetsGeometry? padding;
  final double radius;

  /// 可选：直接复用下拉框的 [DropdownStyle] 配色；为 null 时跟随明暗主题
  /// （[DropdownStyle.of]）。
  final DropdownStyle? style;

  @override
  Widget build(BuildContext context) {
    final DropdownStyle s = style ?? DropdownStyle.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? s.backgroundColor,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        border: Border.all(color: borderColor ?? s.borderColor),
      ),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: padding ?? s.fieldPadding,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: isHint
                        ? muted ?? s.muted
                        : foreground ?? s.foreground,
                  ),
                ),
              ),
              AnchoredDropdownArrow(progress: progress, color: s.muted),
            ],
          ),
        ),
      ),
    );
  }
}

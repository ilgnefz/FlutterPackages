part of 'anchored_dropdown.dart';

/// 浮层外观：阴影 → 整体淡入 → 裁切 → 圆角本体 → 行内容。
///
/// 阴影刻意放在 `ClipPath` **之外**：如果画在裁切子树里，动画途中会被
/// 整圈切掉，等 p = 1 移除裁切时才突然冒出一整圈阴影。现在颜色 alpha
/// 随进度渐强，首尾都不会硬切。
class _DropdownPanel extends StatelessWidget {
  const _DropdownPanel({
    required this.frame,
    required this.style,
    required this.reveal,
    required this.menu,
  });

  final _Frame frame;
  final DropdownItemStyle style;
  final DropdownReveal reveal;

  /// 已经构建好的列表内容（内置选项列表）。
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.all(Radius.circular(style.radius));

    Widget body = DecoratedBox(
      key: kDropdownBodyKey,
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: radius,
        border: Border.all(color: style.borderColor),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Opacity(
          opacity: frame.rowsOpacity,
          child: Transform.translate(
            offset: Offset(0, frame.rowsOffsetY),
            child: menu,
          ),
        ),
      ),
    );

    // p 到 1 后整块去掉裁切；此时 clipper 本身也是同一个圆角外框，
    // 移除不会造成形状跳变。
    if (!frame.reduce && frame.p < 1.0) {
      body = ClipPath(
        key: kDropdownClipKey,
        clipper: DropdownRevealClipper(
          progress: frame.p,
          reveal: reveal,
          radius: style.radius,
          lip: style.lip,
          placedAbove: frame.placedAbove,
        ),
        child: body,
      );
    }

    return DecoratedBox(
      key: kDropdownShadowKey,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: style.shadowColor.withValues(
              alpha: style.shadowOpacity * frame.shadow,
            ),
            blurRadius: style.shadowBlurRadius,
            offset: style.shadowOffset,
          ),
        ],
      ),
      child: Opacity(opacity: frame.opacity, child: body),
    );
  }
}

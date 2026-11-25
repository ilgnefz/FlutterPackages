part of '../flutter_context_menu.dart';

// ── 多级菜单：层级状态 + 单级浮层视图 ─────────────────────────────────────

/// 打开着的一级菜单。`_levels[0]` 是根菜单，末尾是最深的一级。
class _MenuLevel<T extends Object> {
  _MenuLevel({
    required this.items,
    required this.placement,
    required this.parentIndex,
    required this.panelKey,
  });

  /// 本级条目；items 变化时原地更新（保持 State 与高亮）。
  List<ContextMenuItem<T>> items;

  /// 本级在 Overlay 坐标系里的位置；重开时根级换成新指针算出的落位。
  ContextMenuPlacement placement;

  /// 上一级里展开出本级的行号；根级为 -1。
  final int parentIndex;

  final GlobalKey<ContextMenuPanelState<T>> panelKey;
}

/// 一级面板：进出场动画 + [ContextMenuPanel]，把交互回调透传给外层 State。
///
/// 每级各自持有 [TweenAnimationBuilder]，所以子菜单展开时也有自己的揭示
/// 动画，根菜单在「二次右键」时也能单独重播。整套动画与 `AnchoredDropdown`
/// 一致，层级由外到内：
///
/// ```
/// Opacity(整体淡入)
///   └ Transform.translate(从锚点方向滑入)
///       └ Transform.scale(轻微放大，锚点是起点角)
///           └ DecoratedBox(投影渐强，画在裁切之外)
///               └ ClipPath(从起点角 / 边揭示，圆角恒定)
///                   └ Opacity + Transform(行内容稍晚淡入)
///                       └ ContextMenuPanel(Material)
/// ```
///
/// 终点 `tween.end` 从 1 → 0 时，同一个进度值递减，所有层自动倒放；
/// 没有任何 AnimationController，业务方法只改 `animationTarget`。
class _ContextMenuLevelView<T extends Object> extends StatelessWidget {
  const _ContextMenuLevelView({
    required this.level,
    required this.items,
    required this.placement,
    required this.panelKey,
    required this.style,
    required this.itemBuilder,
    required this.animationTarget,
    required this.reopening,
    required this.activeSubmenuIndex,
    required this.onSelect,
    required this.onOpenSubmenu,
    required this.onHoverItem,
    this.onAnimationEnd,
  });

  final int level;
  final List<ContextMenuItem<T>> items;
  final ContextMenuPlacement placement;
  final GlobalKey<ContextMenuPanelState<T>> panelKey;
  final ContextMenuStyle style;
  final Widget Function(BuildContext, ContextMenuItem<T>)? itemBuilder;
  final double animationTarget;

  /// 这次退场是「重开」的前半段：时长压到一半，让右键重新弹出不显得拖沓。
  final bool reopening;
  final int? activeSubmenuIndex;
  final ValueChanged<T> onSelect;
  final void Function(int index, ContextMenuItem<T> item) onOpenSubmenu;
  final ValueChanged<int> onHoverItem;
  final VoidCallback? onAnimationEnd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool reduce =
        style.reduceMotion ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    final bool closing = animationTarget == 0;
    // 收起是展开的时间镜像，节奏略快一点（与 AnchoredDropdown 一致取 3/4）；
    // 重开的前半段再压到 1/2，避免「收起 + 重新揭示」两段加起来太慢。
    final int base = style.duration.inMilliseconds;
    final Duration duration = reduce
        ? kContextMenuReduceDuration
        : closing
        ? Duration(milliseconds: reopening ? base ~/ 2 : base * 3 ~/ 4)
        : style.duration;
    final ContextMenuRevealOrigin origin = resolveContextMenuRevealOrigin(
      style.reveal,
      placement,
    );
    final _ContextMenuPalette palette = _resolveContextMenuPalette(
      style,
      theme,
    );
    final BorderRadius radius = BorderRadius.circular(style.radius);

    return Positioned.fromRect(
      rect: placement.rect,
      child: TweenAnimationBuilder<double>(
        // curve 保持线性：u 是「显示 0→1 / 收起 1→0」的时间轴，
        // 缓动在 resolveContextMenuFrame 里按方向选正向 / 镜像曲线。
        tween: Tween<double>(begin: 0, end: animationTarget),
        duration: duration,
        curve: Curves.linear,
        onEnd: onAnimationEnd,
        builder: (BuildContext context, double u, Widget? child) {
          final _ContextMenuFrame frame = _resolveContextMenuFrame(
            u: u,
            closing: closing,
            reduce: reduce,
            origin: origin,
            gap: style.revealGap,
          );

          Widget body = child!;
          if (!frame.reduce && frame.rowsOpacity < 1.0) {
            body = Opacity(
              opacity: frame.rowsOpacity,
              child: Transform.translate(offset: frame.rowsOffset, child: body),
            );
          }
          // p = 1 时整块去掉裁切；此时 clipper 本身也是同一个圆角外框，
          // 移除不会造成形状跳变。
          if (!frame.reduce && frame.p < 1.0) {
            body = ClipPath(
              key: contextMenuClipKey(level),
              clipper: ContextMenuRevealClipper(
                progress: frame.p,
                origin: frame.origin,
                radius: style.radius,
                lip: style.lip,
              ),
              child: body,
            );
          }
          // 投影必须画在 ClipPath 之外：放在裁切子树里，动画途中会被整圈
          // 切掉，等 p = 1 移除裁切时才突然冒出一整圈阴影。
          body = DecoratedBox(
            key: contextMenuShadowKey(level),
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: palette.shadow.withValues(
                    alpha: style.shadowOpacity * frame.shadow,
                  ),
                  blurRadius: style.elevation * 2 + 4,
                  offset: Offset(0, style.elevation / 2),
                ),
              ],
            ),
            child: body,
          );

          return Opacity(
            opacity: frame.opacity,
            child: Transform.translate(
              offset: frame.offset,
              child: Transform.scale(
                scale: frame.scale,
                alignment: placement.growthAlignment,
                child: body,
              ),
            ),
          );
        },
        child: ContextMenuPanel<T>(
          key: panelKey,
          level: level,
          items: items,
          style: style,
          size: placement.size,
          itemBuilder: itemBuilder,
          onSelect: onSelect,
          onOpenSubmenu: onOpenSubmenu,
          onHoverItem: onHoverItem,
          activeSubmenuIndex: activeSubmenuIndex,
        ),
      ),
    );
  }
}

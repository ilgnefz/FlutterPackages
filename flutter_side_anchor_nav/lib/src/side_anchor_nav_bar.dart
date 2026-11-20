part of '../flutter_side_anchor_nav.dart';

// ── 左侧 Tabbar ───────────────────────────────────────────────────────────

/// Tabbar 上切换选中项后，把选中项滚到可视区中间的时长。
const Duration _kTabRevealDuration = Duration(milliseconds: 220);

/// 左侧竖排 Tabbar：直接换位的高亮块 + 左侧会滑动过去的贴边指示条 + Tabs 过多
/// 时可滚动。
///
/// 高亮块（选中底色）**只有一个**，点击后**直接**落到新位置，不做位移过渡；
/// 会动的只有那条贴边指示条（[SideTabStyle.indicatorDuration]）。两者共用同一
/// 份测量结果，所以指示条滑到终点时正好贴在高亮块左侧。
///
/// 位置靠测量每个 Tab 的矩形得来（不是按「等分」算），所以 Tab 高度不一致、
/// Tabs 滚动时也能贴准。测量结果缓存在 [_SideTabBarState] 里，只有选中项 /
/// Tab 数量 / 尺寸变化时才重新测 —— 滚动 Tabbar 不需要重测，因为高亮块、
/// 指示条和 Tabs 一起待在滚动内容里，天然同步移动。
///
/// 选中项变化时先在上一次布局上同步量一次（`didUpdateWidget` 里，那一帧就换到
/// 新位置），post-frame 再量一次兜底。少了这一帧，底色会先在旧位置停一帧再跳，
/// 看起来就是「点了没马上反应」。
class _SideTabBar extends StatefulWidget {
  const _SideTabBar({
    required this.views,
    required this.selectedIndex,
    required this.style,
    required this.onSelected,
    this.tabBuilder,
  });

  final List<SideTabView> views;
  final int selectedIndex;
  final SideTabStyle style;
  final ValueChanged<int> onSelected;
  final SideTabBuilder? tabBuilder;

  @override
  State<_SideTabBar> createState() => _SideTabBarState();
}

class _SideTabBarState extends State<_SideTabBar> {
  final ScrollController _tabScroll = ScrollController();

  /// 滚动内容（Tabs 的 `Stack`）：测量 Tab 位置时的坐标原点。
  final GlobalKey _contentKey = GlobalKey(
    debugLabel: 'side_anchor_nav.bar.content',
  );

  /// 每个 Tab 的 key，用来量它在滚动内容里的矩形。
  final List<GlobalKey> _tabKeys = <GlobalKey>[];

  /// 选中项的矩形（滚动内容坐标系）；还没量到时为 null。
  ///
  /// 高亮块和指示条都从这一份数据来，所以两者永远对齐、同步移动。
  double? _selectedTop;
  double? _selectedHeight;

  @override
  void initState() {
    super.initState();
    _ensureKeys();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _SideTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool countChanged = widget.views.length != oldWidget.views.length;
    if (countChanged) _ensureKeys();

    final bool selectionChanged =
        widget.selectedIndex != oldWidget.selectedIndex;
    final bool metricsChanged =
        countChanged ||
        widget.style.tabHeight != oldWidget.style.tabHeight ||
        widget.style.tabGap != oldWidget.style.tabGap ||
        widget.style.tabItemPadding != oldWidget.style.tabItemPadding ||
        widget.style.tabBarPadding != oldWidget.style.tabBarPadding;

    // 上一帧的布局还在，新选中项的位置直接量得到 —— 这一帧就让底色换过去。
    // 页数同时变了也照量：量不到（新加的 key 还没 context）就自动跳过。
    if (selectionChanged) _measure(notify: false);

    if (selectionChanged || metricsChanged) {
      // 选中项变了：顺便把 Tabbar 滚一下，让选中项露出来。
      _scheduleMeasure(reveal: selectionChanged);
    }
  }

  @override
  void dispose() {
    _tabScroll.dispose();
    super.dispose();
  }

  /// Tab 数量变化时增删 key，而不是全部重建 —— 已有 Tab 的 element / 状态
  /// 能留下来（滚动位置、水波纹都不会因为插入一页而被重置）。
  void _ensureKeys() {
    final int count = widget.views.length;
    if (count > _tabKeys.length) {
      for (int i = _tabKeys.length; i < count; i++) {
        _tabKeys.add(GlobalKey(debugLabel: 'side_anchor_nav.tab.$i'));
      }
    } else if (count < _tabKeys.length) {
      _tabKeys.removeRange(count, _tabKeys.length);
    }
  }

  void _scheduleMeasure({bool reveal = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measure(reveal: reveal);
    });
  }

  /// 量选中项的矩形。
  ///
  /// [notify] 为 true（post-frame 用）时 `setState`；为 false（`didUpdateWidget`
  /// 里用）时只写字段 —— 那个位置紧接着就会 rebuild，不需要再排一帧。
  void _measure({bool notify = true, bool reveal = false}) {
    final int index = widget.selectedIndex;
    if (index < 0 || index >= _tabKeys.length) return;

    final RenderObject? tabObject = _tabKeys[index].currentContext
        ?.findRenderObject();
    final RenderObject? contentObject = _contentKey.currentContext
        ?.findRenderObject();
    if (tabObject is! RenderBox ||
        contentObject is! RenderBox ||
        !tabObject.hasSize ||
        !contentObject.hasSize) {
      return;
    }

    final Offset topLeft = tabObject.localToGlobal(
      Offset.zero,
      ancestor: contentObject,
    );
    final double height = tabObject.size.height;
    final bool changed =
        _selectedTop == null ||
        (_selectedTop! - topLeft.dy).abs() > 0.01 ||
        ((_selectedHeight ?? 0) - height).abs() > 0.01;
    if (changed) {
      if (notify) {
        setState(() {
          _selectedTop = topLeft.dy;
          _selectedHeight = height;
        });
      } else {
        _selectedTop = topLeft.dy;
        _selectedHeight = height;
      }
    }
    if (reveal) _reveal(topLeft.dy, height);
  }

  /// 选中项被切走时（比如外部控制器跳页），把它滚到 Tabbar 可视区中间。
  void _reveal(double top, double height) {
    if (!_tabScroll.hasClients) return;
    final ScrollPosition position = _tabScroll.position;
    final double viewport = position.viewportDimension;
    final double target = (top - (viewport - height) / 2).clamp(
      0.0,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 0.5) return;
    _tabScroll.animateTo(
      target,
      duration: _kTabRevealDuration,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildTab(int index) {
    final SideTabView view = widget.views[index];
    final bool selected = index == widget.selectedIndex;
    final SideTabItemInfo info = SideTabItemInfo(
      index: index,
      view: view,
      selected: selected,
      onSelected: view.enabled ? () => widget.onSelected(index) : null,
      hoverColor: _hoverColorFor(selected),
      // 禁用项钉成普通箭头：全局设了手型也不该让点不动的 Tab 看起来能点。
      mouseCursor: view.enabled
          ? widget.style.tabMouseCursor
          : SystemMouseCursors.basic,
    );
    final Widget tab =
        widget.tabBuilder?.call(context, info) ??
        _SideTabTile(info: info, style: widget.style);
    return KeyedSubtree(key: _tabKeys[index], child: tab);
  }

  /// 悬停 / 聚焦 / 按下时的底色。
  ///
  /// 选中项返回**透明**：它的底色是那块滑动过来的高亮，再叠一层悬停色的话，
  /// 点击后鼠标还停在原地，就会看到一小块更深的底色留在高亮块里 —— 像是点击
  /// 的那个 Tab 把自己的底色「留」在了原处。
  Color? _hoverColorFor(bool selected) {
    if (!widget.style.showTabHover || selected) return Colors.transparent;
    return widget.style.hoverColor ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.06);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final SideTabStyle style = widget.style;

    final double? top = _selectedTop;
    final double? height = _selectedHeight;
    final bool measured = top != null && height != null && height > 0;
    final double indicatorHeight = (height ?? 0) - style.indicatorInset * 2;
    final bool showIndicator =
        style.showIndicator && measured && indicatorHeight > 0;

    // 一条 [BorderSide] 同时管颜色 / 粗细 / 显隐：BorderSide.none 即整条去掉。
    final BorderSide divider =
        style.tabBarDivider ?? BorderSide(color: theme.dividerColor);

    return Container(
      decoration: BoxDecoration(
        color: style.tabBarBackground ?? scheme.surfaceContainerLow,
        border: Border(right: divider),
      ),
      child: SingleChildScrollView(
        controller: _tabScroll,
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: style.tabBarPadding,
          child: Stack(
            key: _contentKey,
            children: <Widget>[
              // 选中底色：**一块**共享的高亮，点击后直接换到新位置 —— 不做位移
              // 动画，只有左边的指示条滑过去。它压在 Tabs 下面，所以文字、水波纹
              // 都还在它之上。
              if (measured)
                Positioned(
                  key: sideTabHighlightKey,
                  left: 0,
                  right: 0,
                  top: top,
                  height: height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: style.selectedColor ?? scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(style.tabRadius),
                    ),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: style.tabGap,
                children: <Widget>[
                  for (int i = 0; i < widget.views.length; i++) _buildTab(i),
                ],
              ),
              // 贴边指示条：和高亮块共用同一份测量结果，所以终点永远对齐；
              // 全场只有它带位移动画。
              if (showIndicator)
                AnimatedPositioned(
                  key: sideTabIndicatorKey,
                  duration: style.indicatorDuration,
                  curve: Curves.easeOutCubic,
                  left: 0,
                  top: top + style.indicatorInset,
                  width: style.indicatorWidth,
                  height: indicatorHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: style.indicatorColor ?? scheme.primary,
                      borderRadius: BorderRadius.circular(
                        style.indicatorRadius,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 默认的 Tab 外观：图标 + 文字，点按有水波纹。
///
/// 底色不在这里画 —— 选中底色是 Tabbar 上那块共享的高亮块，滑过来的。
class _SideTabTile extends StatelessWidget {
  const _SideTabTile({required this.info, required this.style});

  final SideTabItemInfo info;
  final SideTabStyle style;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool selected = info.selected;
    final bool enabled = info.enabled;

    final Color foreground;
    if (!enabled) {
      foreground = scheme.onSurface.withValues(alpha: 0.38);
    } else if (selected) {
      foreground = style.selectedTextColor ?? scheme.onPrimaryContainer;
    } else {
      foreground = style.textColor ?? scheme.onSurfaceVariant;
    }

    final TextStyle baseStyle =
        (selected
            ? style.selectedLabelStyle ?? style.labelStyle
            : style.labelStyle) ??
        theme.textTheme.bodyMedium ??
        const TextStyle();
    final TextStyle labelStyle = baseStyle.copyWith(
      color: baseStyle.color ?? foreground,
      fontWeight: selected
          ? baseStyle.fontWeight ?? FontWeight.w600
          : baseStyle.fontWeight,
    );

    final BorderRadius radius = BorderRadius.circular(style.tabRadius);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: info.onSelected,
        mouseCursor: info.mouseCursor,
        // hover / 聚焦 / 按下共用同一份颜色，选中项那份是透明的。
        // 桌面端点完会留下焦点高亮，如果只处理 hoverColor，鼠标挪开还能看到
        // 一层底色挂在点击过的那一项上 —— 一起交给 [SideTabItemInfo.hoverColor]。
        hoverColor: info.hoverColor,
        focusColor: info.hoverColor,
        highlightColor: info.hoverColor,
        splashColor:
            style.splashColor ?? scheme.primary.withValues(alpha: 0.10),
        child: Container(
          height: style.tabHeight,
          padding: style.tabItemPadding,
          child: Row(
            children: <Widget>[
              if (style.showTabIcons && info.view.icon != null) ...<Widget>[
                Icon(info.view.icon, size: style.iconSize, color: foreground),
                SizedBox(width: style.iconGap),
              ],
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: style.tabColorDuration,
                  curve: Curves.easeOut,
                  style: labelStyle,
                  child: Text(
                    info.view.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

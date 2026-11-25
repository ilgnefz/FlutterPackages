part of '../flutter_context_menu.dart';

// ── 面板：Material 外观 + 键盘高亮状态 ────────────────────────────────────

/// 一级菜单本体。尺寸由 [measureContextMenu] 预定，这里用 [SizedBox] 固定，
/// 保证浮层的命中判定与视觉边界一致。
///
/// 面板由 [Material] 包裹：既拿到主题色 / 投影，也向子树提供
/// `DefaultTextStyle`（`textTheme.bodyMedium`）、`IconTheme` 与墨迹宿主，
/// 菜单文字不再是 Overlay 里那套「原始」的默认样式。
///
/// 键盘事件的**接收**在 `CascadeContextMenu` 的 State 里（全局 HardwareKeyboard
/// handler），因为 Overlay 里的 [Focus] 抢不到路由 FocusScope 的 primaryFocus；
/// 这里只负责高亮光标状态与「激活当前高亮项」。
class ContextMenuPanel<T extends Object> extends StatefulWidget {
  const ContextMenuPanel({
    super.key,
    required this.level,
    required this.items,
    required this.style,
    required this.size,
    required this.itemBuilder,
    required this.onSelect,
    required this.onOpenSubmenu,
    required this.onHoverItem,
    required this.activeSubmenuIndex,
  });

  /// 0 = 根菜单，1 = 子菜单，2 = 孙菜单……
  final int level;

  final List<ContextMenuItem<T>> items;
  final ContextMenuStyle style;
  final Size size;
  final Widget Function(BuildContext, ContextMenuItem<T>)? itemBuilder;

  /// 叶子项被激活。
  final ValueChanged<T> onSelect;

  /// 父项被激活（点击 / Enter / →）：展开下一级。
  final void Function(int index, ContextMenuItem<T> item) onOpenSubmenu;

  /// 指针进入某一行：由外层决定关闭更深的级、或切换到另一个子菜单。
  final ValueChanged<int> onHoverItem;

  /// 本面板里已展开子菜单的行号，用于保持父行高亮。
  final int? activeSubmenuIndex;

  @override
  State<ContextMenuPanel<T>> createState() => ContextMenuPanelState<T>();
}

class ContextMenuPanelState<T extends Object>
    extends State<ContextMenuPanel<T>> {
  /// 当前「活动行」——鼠标 hover 或键盘导航指向的那一行。
  ///
  /// 只有这一份状态。以前 hover 与键盘高亮各存一份（`_hovered` /
  /// `_keyboardHighlight`），键盘走过一次之后指针再移到别的行，两行会同时
  /// 亮：键盘行因为 `_keyboardHighlight` 还在，hover 行因为自己的
  /// `_hovered = true`。行内也不再自持 hover 状态（热重载 / items 原地刷新
  /// 后旧 State 会把高亮留在别的行上，出现无指针的"幽灵 hover"）。
  int? _active;

  int? get highlightedIndex => _active;

  bool _isSelectable(int? index) =>
      index != null &&
      index >= 0 &&
      index < widget.items.length &&
      widget.items[index].isSelectable;

  List<int> get _selectableIndexes => <int>[
    for (int i = 0; i < widget.items.length; i++)
      if (widget.items[i].isSelectable) i,
  ];

  void setHighlight(int? index) {
    if (!mounted || _active == index) return;
    setState(() => _active = index);
  }

  @override
  void didUpdateWidget(covariant ContextMenuPanel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 条目被原地替换（菜单开着时刷新内容）后，旧的活动行可能已经变成别的
    // 东西或不可选，丢掉它，别让高亮挂在无关的行上。
    if (_active != null && !_isSelectable(_active)) _active = null;
  }

  void moveHighlight(int delta) {
    final List<int> indexes = _selectableIndexes;
    if (indexes.isEmpty) return;
    final int current = indexes.indexOf(_active ?? -1);
    final int next = _active == null
        ? (delta > 0 ? 0 : indexes.length - 1)
        : (current + delta).clamp(0, indexes.length - 1);
    setHighlight(indexes[next]);
  }

  void activateHighlighted() {
    final int? index = _active;
    if (index == null || index >= widget.items.length) return;
    final ContextMenuItem<T> item = widget.items[index];
    if (!item.isSelectable) return;
    if (item.hasChildren) {
      widget.onOpenSubmenu(index, item);
    } else if (item.value != null) {
      widget.onSelect(item.value as T);
    }
  }

  void openHighlightedSubmenu() {
    final int? index = _active;
    if (index == null || index >= widget.items.length) return;
    final ContextMenuItem<T> item = widget.items[index];
    if (item.hasChildren && item.enabled) widget.onOpenSubmenu(index, item);
  }

  Widget _buildEntry(
    int index,
    bool reserveIconSpace,
    _ContextMenuPalette palette,
    TextStyle baseTextStyle,
  ) {
    final ContextMenuStyle style = widget.style;
    final ContextMenuItem<T> item = widget.items[index];
    return switch (item.kind) {
      ContextMenuEntryKind.divider => SizedBox(
        key: contextMenuItemKey(index, widget.level),
        height: style.dividerHeight,
        child: Center(child: Container(height: 1, color: palette.divider)),
      ),
      ContextMenuEntryKind.header => SizedBox(
        key: contextMenuItemKey(index, widget.level),
        height: style.headerHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            // 标题跟着操作项的行内边距走，文字左边缘才对得齐。
            padding: EdgeInsets.symmetric(horizontal: style.itemPadding),
            child: Text(
              item.label ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: baseTextStyle
                  .merge(style.headerTextStyle)
                  .copyWith(
                    fontSize:
                        style.headerTextStyle?.fontSize ?? style.fontSize - 1,
                    fontWeight: FontWeight.w600,
                    color: palette.muted,
                  ),
            ),
          ),
        ),
      ),
      ContextMenuEntryKind.action => _ContextMenuItemView<T>(
        item: item,
        index: index,
        level: widget.level,
        style: style,
        baseTextStyle: baseTextStyle,
        palette: palette,
        highlighted: _active == index || widget.activeSubmenuIndex == index,
        reserveIconSpace: reserveIconSpace,
        builder: widget.itemBuilder,
        onHover: (bool hovering) {
          if (hovering) {
            setHighlight(index);
            widget.onHoverItem(index);
          } else if (_active == index) {
            // 换到另一行时 exit / enter 的先后顺序不确定，只清自己那一行。
            setHighlight(null);
          }
        },
        onTap: () {
          if (item.hasChildren) {
            widget.onOpenSubmenu(index, item);
          } else if (item.value != null) {
            widget.onSelect(item.value as T);
          }
        },
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _ContextMenuPalette palette = _resolveContextMenuPalette(
      widget.style,
      theme,
    );
    // Material 会把这个样式作为子树 DefaultTextStyle；行渲染也用同一份基底，
    // 这样 fontFamily / fontWeight / letterSpacing 都跟着主题走。
    final TextStyle baseTextStyle =
        theme.textTheme.bodyMedium ?? const TextStyle();
    final bool reserveIconSpace = widget.items.any(
      (ContextMenuItem<T> item) =>
          item.isAction && (item.icon != null || item.prefix != null),
    );

    return SizedBox(
      key: contextMenuPanelKey(widget.level),
      width: widget.size.width,
      height: widget.size.height,
      child: Material(
        type: MaterialType.card,
        color: palette.background,
        // 投影刻意不画在 Material 上：揭示动画的 ClipPath 是它的祖先，
        // Material 的 elevation 阴影长在圆角外框之外，动画途中会被整圈
        // 裁掉，等 p = 1 移除裁切时又突然冒出来。阴影改由外层
        // DecoratedBox 逐帧渐强地绘制（见 _ContextMenuLevelView）。
        // 这里保留 Material 是为了主题色、DefaultTextStyle、IconTheme 和
        // InkWell 的墨迹宿主，以及圆角 / 边框。
        elevation: 0,
        // 关掉 M3 的 surface tint，否则显式指定的背景色会被染一层主色。
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.style.radius),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        textStyle: widget.style.textStyle ?? baseTextStyle,
        child: Padding(
          padding: EdgeInsets.all(widget.style.padding),
          child: Column(
            key: contextMenuListKey(widget.level),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < widget.items.length; i++)
                _buildEntry(i, reserveIconSpace, palette, baseTextStyle),
            ],
          ),
        ),
      ),
    );
  }
}

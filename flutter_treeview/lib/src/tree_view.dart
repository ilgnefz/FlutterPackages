import 'package:flutter/foundation.dart' show setEquals;
import 'package:material_ui/material_ui.dart';

import 'tree_node.dart';
import 'tree_style.dart';

/// 树的两种形态。常用树由主构造函数创建，勾选树走 [TreeView.checkbox]。
///
/// * [single] —— `TreeView(...)`：整行只有一个「选中」态，箭头在左；
/// * [checkbox] —— `TreeView.checkbox(...)`：每行左边一个（父级三态的）
///   checkbox，箭头在右，勾父级即勾整棵子树。
enum TreeViewMode { single, checkbox }

/// 只关掉桌面平台自动给 `Scrollable` 套的那条 Scrollbar。
///
/// `MaterialScrollBehavior` 在 Windows/macOS/Linux 上会给每个垂直
/// `Scrollable` 再包一条默认 8px 的 Scrollbar，和我们自己那条 4px 的
/// 叠在一起，看起来就是「两条宽度不同的滚动条」。其余滚动行为照旧。
class _TreeScrollBehavior extends MaterialScrollBehavior {
  const _TreeScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

/// 一棵树。
///
/// 两种用法，区别只在「一行里怎么表达选中」：
///
/// ```dart
/// // 1. 常用树：单选 + 箭头在左 + 缩进
/// TreeView<String>(
///   nodes: nodes,
///   selectedId: id,
///   onChanged: (String id) => setState(() => id = id),
/// )
///
/// // 2. 勾选树：父级左边 checkbox、右边箭头，点开是一串左边 checkbox 的子项
/// TreeView.checkbox<String>(
///   nodes: nodes,
///   checkedIds: checked,
///   onCheckedChanged: (Set<String> ids) => setState(() => checked = ids),
/// )
/// ```
///
/// ## 交互约定
///
/// * **箭头**：只负责展开 / 收起，不改变选中或勾选；
/// * **[single]**：点行 = 选中该行并回调 [onChanged]（父节点也一样，不会顺手
///   展开——和 VS Code 的资源管理器一致）；
/// * **[checkbox]**：点行 = 切换这一项的勾选；父级按子树级联（[cascade] 可关），
///   子项部分勾选时父级显示横线。
///
/// 展开状态默认由组件自己维护；传了 [expandedIds] 就变成受控，配合
/// [onExpandChanged] 可以做「全部展开 / 全部收起」。勾选状态同理：传
/// [checkedIds] 即受控。
///
/// 需要滚动时给 [maxHeight]（下拉面板里几乎都要给），组件内部自带
/// [Scrollbar] 与滚动控制器，不再依赖桌面平台自动注入的那条。
class TreeView<T extends Object> extends StatefulWidget {
  /// 常用树：单选、箭头在左。
  const TreeView({
    super.key,
    required this.nodes,
    this.selectedId,
    this.onChanged,
    this.expandedIds,
    this.expandAll = false,
    this.onExpandChanged,
    this.style,
    this.arrowPlacement = TreeArrowPlacement.leading,
    this.maxHeight,
    this.duration = const Duration(milliseconds: 180),
  }) : mode = TreeViewMode.single,
       checkedIds = const <Never>{},
       onCheckedChanged = null,
       cascade = true;

  const TreeView._checkbox({
    super.key,
    required this.nodes,
    this.checkedIds = const <Never>{},
    this.onCheckedChanged,
    this.cascade = true,
    this.expandedIds,
    this.expandAll = false,
    this.onExpandChanged,
    this.style,
    this.arrowPlacement = TreeArrowPlacement.trailing,
    this.maxHeight,
    this.duration = const Duration(milliseconds: 180),
  }) : mode = TreeViewMode.checkbox,
       selectedId = null,
       onChanged = null;

  /// 勾选树：左边 checkbox（父级三态）、右边箭头、子树级联勾选。
  ///
  /// 写法与主构造函数一致，只是多出 [checkedIds] / [onCheckedChanged]：
  ///
  /// ```dart
  /// TreeView.checkbox<String>(
  ///   nodes: nodes,
  ///   checkedIds: checked,
  ///   onCheckedChanged: (Set<String> ids) => setState(() => checked = ids),
  /// )
  /// ```
  static TreeView<T> checkbox<T extends Object>({
    Key? key,
    required List<TreeNode<T>> nodes,
    Set<T> checkedIds = const <Never>{},
    ValueChanged<Set<T>>? onCheckedChanged,
    bool cascade = true,
    Set<T>? expandedIds,
    bool expandAll = false,
    ValueChanged<Set<T>>? onExpandChanged,
    TreeViewStyle? style,
    TreeArrowPlacement arrowPlacement = TreeArrowPlacement.trailing,
    double? maxHeight,
    Duration duration = const Duration(milliseconds: 180),
  }) => TreeView<T>._checkbox(
    key: key,
    nodes: nodes,
    checkedIds: checkedIds,
    onCheckedChanged: onCheckedChanged,
    cascade: cascade,
    expandedIds: expandedIds,
    expandAll: expandAll,
    onExpandChanged: onExpandChanged,
    style: style,
    arrowPlacement: arrowPlacement,
    maxHeight: maxHeight,
    duration: duration,
  );

  /// 根节点列表。
  final List<TreeNode<T>> nodes;

  /// 当前形态。主构造函数是 [TreeViewMode.single]；[TreeView.checkbox] 建的
  /// 是 [TreeViewMode.checkbox]。
  final TreeViewMode mode;

  /// 单选模式下的选中项。
  final T? selectedId;

  /// 单选模式下的选中回调，回传被点节点的 id。
  final ValueChanged<T>? onChanged;

  /// 勾选模式下的已勾选 id 集合。
  ///
  /// 传了即受控：外部改动这个集合（全选 / 清空）后会同步回组件。集合里可以
  /// 只给叶子，父级是否勾选由子树推导；回调里给的是「所有处于勾选态的节点」，
  /// 包含整棵都勾上的父级。
  final Set<T> checkedIds;

  /// 勾选状态变化回调。
  final ValueChanged<Set<T>>? onCheckedChanged;

  /// 勾选是否按子树级联：true（默认）勾父级即勾全部子项、父级显示三态；
  /// false 则每一项各管各的。
  final bool cascade;

  /// 展开中的节点 id。传了即受控，配合 [onExpandChanged] 使用。
  final Set<T>? expandedIds;

  /// 初始是否展开全部父节点（[expandedIds] 为 null 时生效）。
  final bool expandAll;

  /// 展开状态变化回调。
  final ValueChanged<Set<T>>? onExpandChanged;

  /// 外观。为 null 时取 [TreeViewStyle.of]，跟随明暗主题。
  final TreeViewStyle? style;

  /// 箭头在行的左边还是右边。默认：常用树在左，勾选树在右。
  final TreeArrowPlacement arrowPlacement;

  /// 最大高度；给了就在内部滚动。放进下拉面板时一般给 200~300。
  final double? maxHeight;

  /// 展开 / 收起与配色过渡时长。
  final Duration duration;

  @override
  State<TreeView<T>> createState() => _TreeViewState<T>();
}

enum _TreeCheck { unchecked, checked, indeterminate }

class _TreeViewState<T extends Object> extends State<TreeView<T>> {
  static const Duration _kColorDuration = Duration(milliseconds: 120);

  final ScrollController _scroll = ScrollController(debugLabel: 'TreeView');

  late Set<T> _expanded = _initialExpanded();
  late Set<T> _checked = <T>{...widget.checkedIds};
  T? _selected;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void didUpdateWidget(covariant TreeView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部换了勾选集合（全选 / 清空 / 从别处同步）才覆盖内部状态；只是自己
    // 刚才那次回调引起来的重建，两边集合相等，不动。
    if (!setEquals(widget.checkedIds, oldWidget.checkedIds)) {
      _checked = <T>{...widget.checkedIds};
    }
    if (widget.selectedId != oldWidget.selectedId) {
      _selected = widget.selectedId;
    }
    if (!setEquals(widget.expandedIds, oldWidget.expandedIds)) {
      _expanded = <T>{...?widget.expandedIds};
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Set<T> _initialExpanded() {
    final Set<T>? given = widget.expandedIds;
    if (given != null) return <T>{...given};
    if (!widget.expandAll) return <T>{};
    final Set<T> ids = <T>{};
    _walk(widget.nodes, (TreeNode<T> node) {
      if (node.hasChildren) ids.add(node.id);
    });
    return ids;
  }

  void _walk(List<TreeNode<T>> nodes, void Function(TreeNode<T> node) visit) {
    for (final TreeNode<T> node in nodes) {
      visit(node);
      _walk(node.children, visit);
    }
  }

  Iterable<TreeNode<T>> _flatten(List<TreeNode<T>> nodes) sync* {
    for (final TreeNode<T> node in nodes) {
      yield node;
      yield* _flatten(node.children);
    }
  }

  /// 某一项现在应该画成哪种勾选态。父级由子树推导（[TreeView.cascade] 关掉
  /// 时只认自己）。
  _TreeCheck _stateOf(TreeNode<T> node) {
    if (!widget.cascade) {
      return _checked.contains(node.id)
          ? _TreeCheck.checked
          : _TreeCheck.unchecked;
    }
    // 显式勾了父级 = 整棵都勾上（外部直接传父级 id 时也说得通）。
    if (_checked.contains(node.id)) return _TreeCheck.checked;
    if (!node.hasChildren) return _TreeCheck.unchecked;

    int covered = 0;
    bool partial = false;
    for (final TreeNode<T> child in node.children) {
      final _TreeCheck state = _stateOf(child);
      if (state == _TreeCheck.checked) {
        covered++;
      } else if (state == _TreeCheck.indeterminate) {
        covered++;
        partial = true;
      }
    }
    if (covered == 0) return _TreeCheck.unchecked;
    if (covered == node.children.length && !partial) return _TreeCheck.checked;
    return _TreeCheck.indeterminate;
  }

  /// 回调给外部的集合：所有处于「完全勾选」态的节点（含整棵勾上的父级）。
  Set<T> _checkedIds() => <T>{
    for (final TreeNode<T> node in _flatten(widget.nodes))
      if (_stateOf(node) == _TreeCheck.checked) node.id,
  };

  void _toggleExpand(TreeNode<T> node) {
    if (!node.hasChildren) return;
    setState(() {
      if (!_expanded.remove(node.id)) _expanded.add(node.id);
    });
    widget.onExpandChanged?.call(Set<T>.unmodifiable(_expanded));
  }

  void _onRowTap(TreeNode<T> node, List<TreeNode<T>> ancestors) {
    if (!node.enabled) return;
    if (widget.mode == TreeViewMode.checkbox) {
      _toggleCheck(node, ancestors);
      return;
    }
    if (_selected == node.id) return;
    setState(() => _selected = node.id);
    widget.onChanged?.call(node.id);
  }

  void _toggleCheck(TreeNode<T> node, List<TreeNode<T>> ancestors) {
    final bool willCheck = _stateOf(node) != _TreeCheck.checked;
    setState(() {
      if (!widget.cascade) {
        if (willCheck) {
          _checked.add(node.id);
        } else {
          _checked.remove(node.id);
        }
        return;
      }
      _walk(<TreeNode<T>>[node], (TreeNode<T> item) {
        if (willCheck) {
          _checked.add(item.id);
        } else {
          _checked.remove(item.id);
        }
      });
      // 取消勾选时把祖先的「显式整棵勾选」也撤掉，否则父级还会显示成勾上。
      if (!willCheck) {
        for (final TreeNode<T> ancestor in ancestors) {
          _checked.remove(ancestor.id);
        }
      }
    });
    widget.onCheckedChanged?.call(_checkedIds());
  }

  @override
  Widget build(BuildContext context) {
    final TreeViewStyle style = widget.style ?? TreeViewStyle.of(context);
    final Duration duration = _reduce ? Duration.zero : widget.duration;

    Widget content = Padding(
      padding: style.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final TreeNode<T> node in widget.nodes)
            _buildNode(node, 0, <TreeNode<T>>[], style, duration),
        ],
      ),
    );

    if (style.backgroundColor != null || style.borderColor != null) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          color: style.backgroundColor,
          borderRadius: BorderRadius.circular(style.panelRadius),
          border: style.borderColor == null
              ? null
              : Border.all(color: style.borderColor!, width: style.borderWidth),
        ),
        child: content,
      );
    }

    final double? maxHeight = widget.maxHeight;
    if (maxHeight != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        // 局部覆盖滚动行为：只保留我们自己那条（厚度可配），
        // 别让桌面平台再自动注入一条默认厚度的。
        child: ScrollConfiguration(
          behavior: const _TreeScrollBehavior(),
          child: Scrollbar(
            controller: _scroll,
            thickness: style.scrollbarThickness,
            child: SingleChildScrollView(controller: _scroll, child: content),
          ),
        ),
      );
    }
    return content;
  }

  Widget _buildNode(
    TreeNode<T> node,
    int depth,
    List<TreeNode<T>> ancestors,
    TreeViewStyle style,
    Duration duration,
  ) {
    final bool hasChildren = node.hasChildren;
    final bool expanded = hasChildren && _expanded.contains(node.id);
    final bool checkboxMode = widget.mode == TreeViewMode.checkbox;

    final Widget row = _TreeViewRow(
      style: style,
      label: node.label,
      leading: node.leading,
      trailing: node.trailing,
      enabled: node.enabled,
      selected: !checkboxMode && _selected == node.id,
      check: checkboxMode ? _stateOf(node) : _TreeCheck.unchecked,
      showCheckbox: checkboxMode,
      hasChildren: hasChildren,
      expanded: expanded,
      arrowPlacement: widget.arrowPlacement,
      onTap: () => _onRowTap(node, ancestors),
      onToggleExpand: () => _toggleExpand(node),
      colorDuration: _kColorDuration,
    );

    final Widget indented = Padding(
      padding: EdgeInsetsDirectional.only(start: style.indent * depth),
      child: row,
    );

    if (!hasChildren) return indented;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        indented,
        // 展开 / 收起用 AnimatedSize：子级高度动画到 0，不会像
        // AnimatedCrossFade 那样在其中一帧同时占两份高度。
        AnimatedSize(
          duration: duration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: expanded
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final TreeNode<T> child in node.children)
                      _buildNode(
                        child,
                        depth + 1,
                        <TreeNode<T>>[...ancestors, node],
                        style,
                        duration,
                      ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// 一行。自带 hover，不依赖 [InkWell]，所以放进没有 Material 祖先的下拉浮层
/// 里也能正常显示、也能自己定光标。
class _TreeViewRow extends StatefulWidget {
  const _TreeViewRow({
    required this.style,
    required this.label,
    required this.enabled,
    required this.selected,
    required this.check,
    required this.showCheckbox,
    required this.hasChildren,
    required this.expanded,
    required this.arrowPlacement,
    required this.onTap,
    required this.onToggleExpand,
    required this.colorDuration,
    this.leading,
    this.trailing,
  });

  final TreeViewStyle style;
  final String label;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;
  final bool selected;
  final _TreeCheck check;
  final bool showCheckbox;
  final bool hasChildren;
  final bool expanded;
  final TreeArrowPlacement arrowPlacement;
  final VoidCallback onTap;
  final VoidCallback onToggleExpand;
  final Duration colorDuration;

  @override
  State<_TreeViewRow> createState() => _TreeViewRowState();
}

class _TreeViewRowState extends State<_TreeViewRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final TreeViewStyle style = widget.style;
    final Color foreground = widget.enabled
        ? style.foreground
        : style.disabledColor;

    // 高亮底色：选中优先于 hover。
    final bool highlighted = widget.enabled && (widget.selected || _hovered);
    final Color highlight = widget.selected
        ? style.selectedColor
        : style.hoverColor;
    // 关掉高亮时不能用 Colors.transparent：它是「全透明黑」，lerp 到
    // 0xFFF4F4F5 途中 RGB 会从黑往灰爬，中途是一块**比 hover 色还深的灰**
    // （看着像闪了一下深色）。用同色 alpha=0，过渡只在透明度上走，一路都是
    // 浅灰到白。
    final Color background = highlighted
        ? highlight
        : highlight.withValues(alpha: 0);

    final TextStyle labelStyle = (style.textStyle ?? const TextStyle())
        .copyWith(
          fontSize: style.textStyle?.fontSize ?? style.fontSize,
          color: style.textStyle?.color ?? foreground,
        );

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          // 只在「亮起来」这一下做过渡；熄灭时立刻到位。否则鼠标扫过一串行
          // 时，离开的那一行还在 120ms 里慢慢褪色，会和刚落上的这一行同时
          // 发灰（两行一起高亮）。
          duration: highlighted ? widget.colorDuration : Duration.zero,
          curve: Curves.easeOut,
          height: style.rowHeight,
          padding: style.rowPadding,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(style.radius),
          ),
          child: Row(
            children: <Widget>[
              if (widget.arrowPlacement == TreeArrowPlacement.leading)
                _arrow(foreground),
              if (widget.showCheckbox) ...<Widget>[
                _checkbox(),
                SizedBox(width: style.checkboxGap),
              ],
              if (widget.leading != null) ...<Widget>[
                IconTheme.merge(
                  data: IconThemeData(size: style.iconSize, color: foreground),
                  child: widget.leading!,
                ),
                SizedBox(width: style.iconGap),
              ],
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
              if (widget.trailing != null) ...<Widget>[
                SizedBox(width: style.iconGap),
                widget.trailing!,
              ],
              if (widget.arrowPlacement == TreeArrowPlacement.trailing)
                _arrow(foreground),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrow(Color foreground) {
    final TreeViewStyle style = widget.style;
    final double extent = style.arrowSize + style.arrowGap;
    if (!widget.hasChildren) {
      // 叶子行留同样的空位，同层文字才是左对齐的一列。
      return SizedBox(width: extent, height: extent);
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggleExpand,
        child: SizedBox(
          width: extent,
          height: extent,
          child: Center(
            child: AnimatedRotation(
              turns: widget.expanded ? 0.25 : 0,
              duration: widget.colorDuration,
              curve: Curves.easeOutCubic,
              child: Icon(
                style.arrowIcon,
                size: style.arrowSize,
                color: widget.enabled ? style.muted : style.disabledColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _checkbox() {
    final TreeViewStyle style = widget.style;
    final bool checked = widget.check == _TreeCheck.checked;
    final bool indeterminate = widget.check == _TreeCheck.indeterminate;
    final bool filled = checked || indeterminate;
    final Color border = filled
        ? style.accent
        : widget.enabled
        ? style.checkboxBorderColor
        : style.muted.withValues(alpha: 0.5);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedContainer(
        duration: widget.colorDuration,
        curve: Curves.easeOut,
        width: style.checkboxSize,
        height: style.checkboxSize,
        decoration: BoxDecoration(
          // 同样别用 Colors.transparent：取消勾选时从 accent 淡回「透明黑」
          // 会闪一块深色。同色 alpha=0 才是干净的淡出。
          color: filled ? style.accent : style.accent.withValues(alpha: 0),
          border: Border.all(color: border, width: 1.2),
          borderRadius: BorderRadius.circular(style.checkboxRadius),
        ),
        child: checked
            ? Icon(
                style.checkIcon,
                size: style.checkboxSize * 0.74,
                color: style.onAccent,
              )
            : indeterminate
            ? Center(
                child: Container(
                  width: style.checkboxSize * 0.55,
                  height: 1.6,
                  decoration: BoxDecoration(
                    color: style.onAccent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

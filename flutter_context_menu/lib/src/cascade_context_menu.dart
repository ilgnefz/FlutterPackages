part of '../flutter_context_menu.dart';

/// 在 [child] 上右键 / 长按，弹出由 [items] 组成的多级菜单。
///
/// 适合**空白区域**：整块内容区、画布、面板背景 —— 右键哪里都是同一份菜单。
/// 列表 / 表格这种「右键哪一行就该针对哪一行」的场景，用
/// [showContextMenu] 在行自己的手势里按行生成条目更合适。
///
/// ```dart
/// CascadeContextMenu<String>(
///   onSelected: (String v) => print(v),
///   items: const <ContextMenuItem<String>>[
///     ContextMenuItem<String>('copy', label: '复制', icon: Icons.copy),
///     ContextMenuItem<String>.divider(),
///     ContextMenuItem<String>.submenu('导出为', children: <ContextMenuItem<String>>[
///       ContextMenuItem<String>('pdf', label: 'PDF'),
///       ContextMenuItem<String>.submenu('图片', children: <ContextMenuItem<String>>[
///         ContextMenuItem<String>('png', label: 'PNG'),
///       ]),
///     ]),
///   ],
///   child: Text('右键点我'),
/// )
/// ```
class CascadeContextMenu<T extends Object> extends StatefulWidget {
  const CascadeContextMenu({
    super.key,
    required this.child,
    required this.items,
    this.onSelected,
    this.onOpenChange,
    this.enabled = true,
    this.longPressEnabled = true,
    this.style = const ContextMenuStyle(),
    this.edgePadding = 8,
    this.itemBuilder,
  });

  /// 触发区域，可以是任意 Widget。
  final Widget child;

  /// 菜单条目；操作项、子菜单、分隔线、分组标题可以混排。
  final List<ContextMenuItem<T>> items;

  /// 选中某个**叶子项**时回调，随后所有层级一起收起。
  /// 子菜单父项只展开下一级，不触发这里。
  final ValueChanged<T>? onSelected;

  /// 打开 / 关闭状态变化时回调（子菜单展开不算一次开关）。
  final ValueChanged<bool>? onOpenChange;

  /// 禁用整个右键 / 长按响应（已打开的菜单会保持原状）。
  final bool enabled;

  /// 是否同时用长按当作触发器，便于触屏设备使用。默认 true。
  final bool longPressEnabled;

  /// 外观配置。颜色不传时跟随当前 [ThemeData]，暗色主题自动适配。
  final ContextMenuStyle style;

  /// 每一级菜单与屏幕边缘的最小间距。
  final double edgePadding;

  /// 自定义单行内容。返回内容会替换默认行渲染，点击 / 禁用 / 高亮逻辑
  /// 仍由组件管理；需要适配 [ContextMenuStyle.itemHeight]。
  /// 这里的 `context` 来自 Overlay 浮层，不是触发区域的局部子树。
  final Widget Function(BuildContext, ContextMenuItem<T>)? itemBuilder;

  @override
  State<CascadeContextMenu<T>> createState() => _CascadeContextMenuState<T>();
}

class _CascadeContextMenuState<T extends Object>
    extends State<CascadeContextMenu<T>> {
  /// 懒创建：只有真正右键过一次才去查 Overlay。
  _ContextMenuOverlay<T>? _menu;

  @override
  void didUpdateWidget(CascadeContextMenu<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final _ContextMenuOverlay<T>? menu = _menu;
    if (menu == null) return;
    menu
      ..style = widget.style
      ..edgePadding = widget.edgePadding
      ..itemBuilder = widget.itemBuilder;
    // 菜单开着时改 items：刷新内容、位置不变（见 updateItems 内的时机说明）。
    if (!identical(oldWidget.items, widget.items)) {
      menu.updateItems(widget.items);
    }
  }

  @override
  void dispose() {
    _menu?.dispose();
    _menu = null;
    super.dispose();
  }

  _ContextMenuOverlay<T> _ensureMenu() {
    return _menu ??= _ContextMenuOverlay<T>(
      overlay: Overlay.of(context),
      items: widget.items,
      style: widget.style,
      edgePadding: widget.edgePadding,
      // 回调延迟读 widget，父级 rebuild 换了闭包也能生效。
      onSelected: (T value) => widget.onSelected?.call(value),
      onOpenChange: (bool open) => widget.onOpenChange?.call(open),
      itemBuilder: widget.itemBuilder,
    );
  }

  void _open(Offset globalPosition) {
    if (!widget.enabled || widget.items.isEmpty) return;
    _ensureMenu().open(globalPosition);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onSecondaryTapUp: widget.enabled
          ? (TapUpDetails details) => _open(details.globalPosition)
          : null,
      onLongPressStart: widget.enabled && widget.longPressEnabled
          ? (LongPressStartDetails details) => _open(details.globalPosition)
          : null,
      child: widget.child,
    );
  }
}

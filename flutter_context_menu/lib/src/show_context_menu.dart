part of '../flutter_context_menu.dart';

// ── 命令式入口 ────────────────────────────────────────────────────────────
//
// [CascadeContextMenu] 是「包一层就管一块区域」，适合空白处；列表 / 表格 /
// 画布这类一格格的东西需要知道「右键的是谁」，用这里直接给坐标和条目。

/// 同时打开的菜单里，由 [showContextMenu] 创建的那些的关闭句柄。
///
/// 命令式调用没有「父级 State 帮忙收尾」，所以再弹一次时先把上一次收掉，
/// 避免两份菜单叠在一起。
final Set<VoidCallback> _liveShowMenus = <VoidCallback>{};

/// 命令式弹出菜单的句柄。菜单被点击外部 / Esc / 选中项关掉后自动失效，
/// 之后再调用 [close] 不会有任何副作用。
class ContextMenuHandle {
  ContextMenuHandle._(this._close, this._isOpen);

  final VoidCallback _close;
  final bool Function() _isOpen;

  /// 菜单当前是否还在显示（含正在播的退场动画）。
  bool get isOpen => _isOpen();

  /// 收起菜单并播放退场动画；菜单已经关掉时什么都不做。
  void close() => _close();
}

/// 在 [position]（全局坐标）处弹出菜单，不需要在外面包 Widget。
///
/// 适合「右键哪一行就针对哪一行」的场景：在行自己的手势里按行生成
/// [items]，菜单才知道当前选中的是谁。
///
/// ```dart
/// InkWell(
///   onSecondaryTapDown: (TapDownDetails details) => showContextMenu<String>(
///     context,
///     position: details.globalPosition,
///     items: menuItemsFor(file),        // 含 ContextMenuItem.header(file.name)
///     onSelected: (String value) => handle(value, file),
///   ),
///   child: row,
/// )
/// ```
///
/// 行为与 [CascadeContextMenu] 完全一致：同款进场 / 退场动画、边缘翻转、
/// 键盘导航、子菜单。差别只有两点：
///
/// * 菜单开着时在别处再次右键 → 先收起（因为同一个拦截层拿不到新位置该用
///   哪份 [items]），再右键一次才会在目标位置弹出。
/// * 收完自动销毁，调用方不需要管理生命周期；返回的 [ContextMenuHandle]
///   只想提前关掉时才用得上。
///
/// [context] 只用来找 [Overlay]，可以传行自身的 `BuildContext`。
ContextMenuHandle showContextMenu<T extends Object>(
  BuildContext context, {
  required List<ContextMenuItem<T>> items,
  required Offset position,
  ValueChanged<T>? onSelected,
  ValueChanged<bool>? onOpenChange,
  ContextMenuStyle style = const ContextMenuStyle(),
  double edgePadding = 8,
  Widget Function(BuildContext, ContextMenuItem<T>)? itemBuilder,
}) {
  // 上一次的命令式菜单先收掉（走退场动画，新的立刻揭示）。
  for (final VoidCallback close in _liveShowMenus.toList()) {
    close();
  }

  final _ContextMenuOverlay<T> menu = _ContextMenuOverlay<T>(
    overlay: Overlay.of(context),
    items: items,
    style: style,
    edgePadding: edgePadding,
    onSelected: onSelected,
    onOpenChange: onOpenChange,
    itemBuilder: itemBuilder,
    selfOwned: true,
  );

  final VoidCallback close = menu.close;
  _liveShowMenus.add(close);
  menu.onDisposed = () => _liveShowMenus.remove(close);
  menu.open(position);
  // 空 items 之类什么都不会插进去：别把空壳留在登记表里。
  if (!menu.isOpen) menu.dispose();

  return ContextMenuHandle._(close, () => menu.isOpen);
}

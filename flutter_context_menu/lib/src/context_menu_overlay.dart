part of '../flutter_context_menu.dart';

// ── 浮层状态机：打开 / 收起 / 重开、层级、键盘 ─────────────────────────────
//
// 与 Widget 解耦：[CascadeContextMenu] 把右键 / 长按手势换成 [open]，而
// [showContextMenu] 由调用方直接给坐标。两者共用同一份实现，动画、落位、
// 键盘、子菜单行为完全一致。

/// 一次菜单展示的全部状态。一个实例对应一个 [OverlayEntry]，多级菜单共用，
/// 每一级在 [levels] 里是一层。
class _ContextMenuOverlay<T extends Object> {
  _ContextMenuOverlay({
    required this.overlay,
    required this.items,
    required this.style,
    this.edgePadding = 8,
    this.onSelected,
    this.onOpenChange,
    this.itemBuilder,
    this.selfOwned = false,
  });

  /// 菜单挂载的 [Overlay]；所有坐标都在它的局部坐标系里换算。
  final OverlayState overlay;

  /// 根级条目。菜单开着时替换只会刷新内容，位置保持不变。
  List<ContextMenuItem<T>> items;

  ContextMenuStyle style;
  double edgePadding;
  ValueChanged<T>? onSelected;
  ValueChanged<bool>? onOpenChange;
  Widget Function(BuildContext, ContextMenuItem<T>)? itemBuilder;

  /// 由 [showContextMenu] 创建：收完自己销毁，调用方不用持有。
  /// 同时决定「菜单开着时再次右键」的行为（见 [_handleBarrierPointerDown]）。
  final bool selfOwned;

  /// 收完（或外部销毁）时回调，便于命令式入口清理登记表。
  VoidCallback? onDisposed;

  OverlayEntry? _entry;

  /// 打开着的各级菜单；[0] 为根级，末尾为最深一级。
  final List<_MenuLevel<T>> _levels = <_MenuLevel<T>>[];

  bool _closing = false;
  bool _keyHandlerAttached = false;
  bool _disposed = false;
  double _animationTarget = 1;

  /// 菜单已开时再次右键：先按原位置播完收起，再换到新锚点重播进场。
  /// 只记录待落位，不在这里直接改坐标，否则会跳过动画。
  bool _reopening = false;
  ContextMenuPlacement? _pendingPlacement;

  /// 最近一次报给 [onOpenChange] 的状态，避免重开过程中重复触发 true / false。
  bool _openReported = false;

  bool get isOpen => _entry != null && !_disposed;

  /// 根级条目换了：字段直接替换，菜单开着就同步刷新内容并收掉多余层级。
  ///
  /// 调用点可能处在父级 build 阶段（`didUpdateWidget`），直接
  /// `markNeedsBuild` 会撞上「setState() or markNeedsBuild() called during
  /// build」，所以延到帧末。
  void updateItems(List<ContextMenuItem<T>> next) {
    items = next;
    if (_entry == null || _closing || _levels.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _entry == null || _closing || _levels.isEmpty) return;
      _levels[0].items = items;
      _trimLevels(1);
      _entry!.markNeedsBuild();
    });
  }

  // ── 键盘：不依赖焦点树的全局 handler ────────────────────────────────────
  // Overlay 里的 Focus(autofocus) 抢不到路由 FocusScope 的 primaryFocus，
  // 所以 Esc / ↑↓ / Enter 不能直接挂 Focus.onKeyEvent。菜单开着期间挂一个
  // HardwareKeyboard handler，关闭时立刻摘掉，不会影响页面其它输入。

  void _attachKeyHandler() {
    if (_keyHandlerAttached) return;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _keyHandlerAttached = true;
  }

  void _detachKeyHandler() {
    if (!_keyHandlerAttached) return;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _keyHandlerAttached = false;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (_entry == null || _closing || _levels.isEmpty) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final LogicalKeyboardKey key = event.logicalKey;
    // 方向键 / Enter 始终作用于最深的一级。
    final ContextMenuPanelState<T>? panel = _levels.last.panelKey.currentState;
    if (key == LogicalKeyboardKey.escape) {
      close();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      panel?.moveHighlight(1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      panel?.moveHighlight(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      panel?.openHighlightedSubmenu();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _closeSubmenu();
      return true;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      panel?.activateHighlighted();
      return true;
    }
    return false;
  }

  // ── 生命周期 ────────────────────────────────────────────────────────────

  void _trimLevels(int keep) {
    while (_levels.length > keep) {
      _levels.removeLast();
    }
  }

  void _reportOpenChange(bool open) {
    if (_openReported == open) return;
    _openReported = open;
    onOpenChange?.call(open);
  }

  void open(Offset globalPosition) {
    if (_disposed || items.isEmpty) return;
    // Overlay 所在的路由已经销毁（页面切走了）：这里没有任何可挂载的地方。
    if (!overlay.mounted) return;

    final RenderBox? box = overlay.context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final Size menuSize = measureContextMenu<T>(items, style);
    final ContextMenuPlacement placement = resolveContextMenuPlacement(
      anchor: box.globalToLocal(globalPosition),
      viewport: box.size,
      menuSize: menuSize,
      edgePadding: edgePadding,
    );

    if (_entry != null && _levels.isNotEmpty) {
      // 菜单还开着（或正在收起）：不直接换坐标。先把 end 改成 0，让当前
      // 所有层级按原锚点完整收起；_onRootAnimationEnd 再换锚点、把 end
      // 改回 1，于是每次右键都重新播一遍收起 + 揭示。
      // 退场途中重复右键只更新待落位，不打断正在跑的动画。
      _pendingPlacement = placement;
      _reopening = true;
      if (!_closing) {
        _closing = true;
        _animationTarget = 0;
        _entry!.markNeedsBuild();
      }
      return;
    }

    // 防御：若浮层还在却没有层级（异常状态），先摘掉再重新插入。
    _entry?.remove();
    _closing = false;
    _reopening = false;
    _pendingPlacement = null;
    _animationTarget = 1;
    _levels.add(
      _MenuLevel<T>(
        items: items,
        placement: placement,
        parentIndex: -1,
        panelKey: GlobalKey<ContextMenuPanelState<T>>(),
      ),
    );
    _entry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_entry!);
    _attachKeyHandler();
    _reportOpenChange(true);
  }

  /// 展开第 [levelIndex] 级里第 [itemIndex] 行的子菜单。
  void _openSubmenu(int levelIndex, int itemIndex) {
    if (_closing || _entry == null) return;
    if (levelIndex < 0 || levelIndex >= _levels.length) return;
    final _MenuLevel<T> parent = _levels[levelIndex];
    if (itemIndex < 0 || itemIndex >= parent.items.length) return;
    final ContextMenuItem<T> item = parent.items[itemIndex];
    if (!item.hasChildren || !item.enabled) return;
    final List<ContextMenuItem<T>> children = item.children!;

    _trimLevels(levelIndex + 1);
    if (_levels.length > levelIndex + 1 &&
        _levels[levelIndex + 1].parentIndex == itemIndex) {
      return; // 已经展开的正是这一项，避免 hover / tap 重复重建。
    }

    final RenderBox box = overlay.context.findRenderObject()! as RenderBox;
    // 子菜单宽度可以按父项单独指定（ContextMenuItem.width），根菜单不带。
    final Size childSize = measureContextMenu<T>(
      children,
      style,
      width: item.width,
    );
    final ContextMenuPlacement placement = resolveSubmenuPlacement(
      parentRect: parent.placement.rect,
      itemTop: contextMenuItemTop<T>(parent.items, itemIndex, style),
      menuSize: childSize,
      viewport: box.size,
      edgePadding: edgePadding,
      panelPadding: style.padding,
      overlap: style.submenuOverlap,
    );
    _levels.add(
      _MenuLevel<T>(
        items: children,
        placement: placement,
        parentIndex: itemIndex,
        panelKey: GlobalKey<ContextMenuPanelState<T>>(),
      ),
    );
    _entry!.markNeedsBuild();
  }

  /// 指针进入某一行：关掉比它更深的级，必要时换成这一行的子菜单。
  void _onItemHover(int levelIndex, int itemIndex) {
    if (_closing || _entry == null) return;
    if (levelIndex < 0 || levelIndex >= _levels.length) return;
    final _MenuLevel<T> level = _levels[levelIndex];
    if (itemIndex < 0 || itemIndex >= level.items.length) return;
    if (_levels.length > levelIndex + 1 &&
        _levels[levelIndex + 1].parentIndex == itemIndex) {
      return;
    }
    final ContextMenuItem<T> item = level.items[itemIndex];
    _trimLevels(levelIndex + 1);
    if (item.hasChildren && item.enabled) {
      _openSubmenu(levelIndex, itemIndex); // 内部会 markNeedsBuild
    } else {
      _entry!.markNeedsBuild();
    }
  }

  void _closeSubmenu() {
    if (_levels.length < 2) return;
    _trimLevels(_levels.length - 1);
    _entry!.markNeedsBuild();
  }

  /// 开始收起（走完退场动画再摘浮层）。命令式实例收完自动销毁。
  void close() {
    if (_entry == null || _disposed) return;
    // Overlay 已经随路由一起销毁：没有退场可播，直接解引用。
    if (!overlay.mounted) {
      dispose();
      return;
    }
    if (_closing) {
      // 重开的中途被 Esc / 点菜单外打断：取消待重开，按普通收起走完退场。
      if (_reopening) {
        _reopening = false;
        _pendingPlacement = null;
        _reportOpenChange(false);
        _detachKeyHandler();
      }
      return;
    }
    _closing = true;
    _animationTarget = 0;
    _detachKeyHandler();
    _entry!.markNeedsBuild();
    _reportOpenChange(false);
    // 各级 TweenAnimationBuilder 检测到 tween.end 从 1 → 0 会用当前值作为
    // begin 重播退场；根级 onEnd 里同步移除浮层，pumpAndSettle 能自然收敛。
  }

  /// 根级退场播完时的分叉：有待重开就换锚点重播进场，否则摘掉浮层。
  void _onRootAnimationEnd() {
    if (!_closing) return; // 进场播完也会回调一次，无需处理。
    if (_reopening) {
      _applyPendingOpen();
    } else {
      _finalizeClose();
    }
  }

  /// 收起已到 u = 0（面板此刻完全透明），换位置不会看到跳变；把 end 改回 1
  /// 后 TweenAnimationBuilder 以当前值 0 为 begin 重新 forward，进场动画重播。
  void _applyPendingOpen() {
    final ContextMenuPlacement? placement = _pendingPlacement;
    final OverlayEntry? entry = _entry;
    _pendingPlacement = null;
    _reopening = false;
    if (placement == null || entry == null || _levels.isEmpty) {
      _finalizeClose();
      return;
    }
    _levels[0]
      ..items = items
      ..placement = placement;
    _trimLevels(1); // 子 / 孙级已随退场收拢，这里直接摘掉。
    _closing = false;
    _animationTarget = 1;
    _attachKeyHandler();
    entry.markNeedsBuild();
    _reportOpenChange(true);
  }

  void _finalizeClose() {
    if (!_closing) return;
    _detachKeyHandler();
    _entry?.remove();
    _entry = null;
    _closing = false;
    _reopening = false;
    _pendingPlacement = null;
    _levels.clear();
    _reportOpenChange(false);
    if (selfOwned) dispose();
  }

  void _select(T value) {
    onSelected?.call(value);
    close();
  }

  /// 摘掉浮层并放弃所有引用。Widget 方式由 State.dispose 调用；命令式方式在
  /// 收完最后一帧后自己调用。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _detachKeyHandler();
    final OverlayEntry? entry = _entry;
    _entry = null;
    _closing = false;
    _reopening = false;
    _pendingPlacement = null;
    _levels.clear();
    onSelected = null;
    onOpenChange = null;
    itemBuilder = null;
    // 页面销毁时 Overlay 可能已经不在树里，此时只解引用就够了。
    if (entry != null && overlay.mounted) entry.remove();
    onDisposed?.call();
    onDisposed = null;
  }

  // ── 浮层 ────────────────────────────────────────────────────────────────

  void _handleBarrierPointerDown(PointerDownEvent event) {
    if (event.buttons & kSecondaryButton != 0) {
      // 全屏拦截层吞掉了二次右键，这里手动转交 open：不论落在菜单里还是
      // 菜单外，都按「重新打开」处理，保证每次右键都有动画。
      //
      // 命令式菜单（[showContextMenu]）除外：菜单条目由调用处按行 / 按对象
      // 生成，拦住事件后没法知道新位置该用哪份 items，直接收起更稳妥 ——
      // 于是「在别处右键」= 关掉当前菜单，再右键才会弹出目标位置的菜单。
      if (selfOwned) {
        close();
        return;
      }
      open(event.position);
      return;
    }
    final RenderBox box = overlay.context.findRenderObject()! as RenderBox;
    final Offset local = box.globalToLocal(event.position);
    final bool inside = _levels.any(
      (_MenuLevel<T> level) => level.placement.rect.contains(local),
    );
    if (!inside) close();
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    return Positioned.fill(
      child: Listener(
        key: kContextMenuBarrierKey,
        // 模态拦截：点所有菜单之外只收起菜单，不会穿透到下层控件。
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handleBarrierPointerDown,
        child: Stack(
          children: <Widget>[
            for (int i = 0; i < _levels.length; i++) _buildLevel(i),
          ],
        ),
      ),
    );
  }

  Widget _buildLevel(int index) {
    final _MenuLevel<T> level = _levels[index];
    return _ContextMenuLevelView<T>(
      level: index,
      items: level.items,
      placement: level.placement,
      panelKey: level.panelKey,
      style: style,
      itemBuilder: itemBuilder,
      animationTarget: _animationTarget,
      reopening: _reopening,
      activeSubmenuIndex: index + 1 < _levels.length
          ? _levels[index + 1].parentIndex
          : null,
      onSelect: _select,
      onOpenSubmenu: (int itemIndex, ContextMenuItem<T> _) =>
          _openSubmenu(index, itemIndex),
      onHoverItem: (int itemIndex) => _onItemHover(index, itemIndex),
      // 只有根级在退场结束时决定「重播进场」还是「摘掉浮层」。
      onAnimationEnd: index == 0 ? _onRootAnimationEnd : null,
    );
  }
}

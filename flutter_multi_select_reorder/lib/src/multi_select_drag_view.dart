part of '../flutter_multi_select_reorder.dart';

// ── 拖动引擎：list / grid 共用这一份 ─────────────────────────────────────

/// 跟随指针的浮层根节点；留一个稳定 key 方便调试 / 回归测试断言「已消失」。
const ValueKey<String> _multiSelectableFeedbackKey = ValueKey<String>(
  'multi-select-feedback',
);

/// 默认预览里那一项的 key；方便断言「预览与 itemBuilder 是同一个 widget」。
const ValueKey<String> _multiSelectableFeedbackItemKey = ValueKey<String>(
  'multi-select-feedback-item',
);

/// 浮层右下角 `+N` 角标的 key，方便回归测试断言「显示 / 不显示」。
const Key _feedbackBadgeKey = ValueKey<String>('multi-select-feedback-badge');

/// 浮层提供指针样式的 [MouseRegion] 的 key，方便断言「拖动前后光标一致」。
const Key _feedbackCursorKey = ValueKey<String>('multi-select-feedback-cursor');

/// 默认预览的叠卡层 key：`layer == 0` 是最上层（第一个被选中的项）。
Key _feedbackLayerKey(int layer) =>
    ValueKey<String>('multi-select-feedback-layer-$layer');

/// 条目圆角裁剪层的 key，方便回归测试断言「按给点圆角裁了」。
const Key _itemClipKey = ValueKey<String>('multi-select-item-clip');

/// 拖动预览最多叠几层卡片。
const int _maxFeedbackLayers = 4;

/// 叠卡每层相对下一层的偏移。
const double _feedbackLayerStep = 4;

/// `+N` 角标离叠卡外沿的距离。
const double _feedbackBadgeInset = 4;

/// 拾起动画时长，与官方 `_DragInfo.startDrag()` 里的
/// `AnimationController(duration: Duration(milliseconds: 250))` 同值。
///
/// 它同时是「松手后浮层飞向落点」的插值时长（官方 `_finalDropPosition`
/// 的 lerp 就挂在这个 animation 上），所以别只按「阴影淡入」的观感去调。
const Duration _kProxyLiftDuration = Duration(milliseconds: 250);

/// Overlay 左上角在全局坐标里的位置，官方 `_overlayOrigin` 同款。
///
/// [OverlayEntry] 里的 `Positioned` 用的是 **Overlay 自己的坐标系**，而指针
/// 事件给的是全局坐标。两者只在「Overlay 正好贴在屏幕左上角」时相等：根
/// Overlay 通常如此，嵌套 Overlay / `useRootOverlay: false` / 自带标题栏的
/// 窗口里就不成立，不减这个原点，浮层会整体偏移一段，看着就是「不跟手」。
Offset _overlayOrigin(BuildContext overlayContext) {
  final RenderObject? renderObject = overlayContext.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return Offset.zero;
  return renderObject.localToGlobal(Offset.zero);
}

/// 两个公开组件都只是把参数转发到这里，拖动逻辑只实现一次。
class _MultiSelectDragView extends StatefulWidget {
  const _MultiSelectDragView({
    required this.itemCount,
    required this.itemBuilder,
    required this.layout,
    required this.padding,
    this.style = const MultiSelectStyle(),
    this.controller,
    this.itemKeyBuilder,
    this.proxyDecorator,
    this.itemId,
    this.initialSelectedIndices = const <int>[],
    this.scrollController,
    this.onDoubleTap,
    this.onSecondaryTap,
    this.onSelectionChanged,
    this.onReorder,
  });

  /// 条目总数。组件不持有数据，只用它算槽位。
  final int itemCount;
  final MultiSelectItemBuilder itemBuilder;
  final _LayoutSpec layout;
  final EdgeInsets padding;
  final MultiSelectStyle style;
  final MultiSelectController? controller;
  final MultiSelectKeyBuilder? itemKeyBuilder;
  final MultiSelectProxyDecorator? proxyDecorator;

  /// 下标 → 稳定 id；不传时 id 就是下标。见 [MultiSelectItemId]。
  final MultiSelectItemId? itemId;

  /// 初始选中的下标（仅在没有外部 controller、且它还没选中任何项时生效）。
  final List<int> initialSelectedIndices;

  final ScrollController? scrollController;
  final void Function(int index)? onDoubleTap;

  /// 右键（二级点击）回调：`(index, globalPosition)`，见
  /// [MultiSelectSecondaryTapCallback]。不改动选中。
  final MultiSelectSecondaryTapCallback? onSecondaryTap;

  /// 选中变化时把**当前视图可见的下标**回给调用方（按点选顺序）。
  ///
  /// 只是通知，不参与状态：选中的真值永远在 [MultiSelectController] 里。
  /// 「选中集合还有别的用途」（批量重命名、删除…）时，直接用同一个 controller
  /// 的 `selectedIds` / `selectedIndices`，别在外面再存一份。
  final ValueChanged<List<int>>? onSelectionChanged;
  final MultiSelectReorderCallback? onReorder;

  @override
  State<_MultiSelectDragView> createState() => _MultiSelectDragViewState();
}

// 每次拖动都会新建一个 AnimationController，所以要用支持多个 ticker 的 mixin。
class _MultiSelectDragViewState extends State<_MultiSelectDragView>
    with TickerProviderStateMixin {
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _viewportKey = GlobalKey();
  final ValueNotifier<Offset> _dragPosition = ValueNotifier<Offset>(
    Offset.zero,
  );

  ScrollController? _ownScroll;
  MultiSelectController? _ownController;

  /// 条目「外壳」（选中装饰 + 角标 + 指针包裹）的缓存，按原下标索引。
  ///
  /// 比 [_builtItems] 再外一层：那一层只挡住 `itemBuilder`，而让位动画每帧
  /// 仍要重搭 `Listener/IgnorePointer/Material/InkWell` 和 selectedBuilder 的
  /// 角标。这一层把整棵外壳也缓存下来，动画帧里只剩下 `_AnimatedSlot` 的
  /// Positioned/Transform —— 子树 widget 实例不变，Flutter 直接跳过 rebuild。
  /// 失效条件和 [_builtItems] 一致，再加角标序号 / 总数与拖动状态。
  final Map<int, _WrappedItem> _wrappedItems = <int, _WrappedItem>{};

  /// `itemBuilder` 结果的缓存，按**原下标**索引。
  ///
  /// 让位 / 落位动画期间外层每帧都会重建可见条目，但条目本身的数据没变；
  /// 而 `itemBuilder` 里可能做文本测量（AdvanceText 的 TextPainter 二分）、
  /// 建图片树这类昂贵操作，每帧重来就是 Profile 里那串 50~250ms 的 build。
  /// 这里只缓存 `itemBuilder` 的返回值：选中装饰 / 指针包裹仍然每帧重建，
  /// 所以 hover、选中态、拖动中的 IgnorePointer 都不会被缓存冻住。
  ///
  /// 父组件 rebuild（数据、主题改变）会走 [didUpdateWidget] 整体清空；
  /// 选中态变化按 [selected] 单项失效。
  final Map<int, _BuiltItem> _builtItems = <int, _BuiltItem>{};

  /// 当前**已经挂了监听**的 controller。`didUpdateWidget` 里 `_controller`
  /// 已经指向新 widget，不能用它去摘旧监听。
  MultiSelectController? _attachedController;
  MultiSelectLayout? _layout;

  int? _pointer;
  int? _pressedIndex;

  /// Shift 范围选的锚点。
  int? _anchorIndex;

  Offset _pressGlobal = Offset.zero;
  Offset _pointerGlobal = Offset.zero;

  /// 右键按下处的全局坐标：`InkWell.onSecondaryTap` 不带坐标，先在 down 里
  /// 存一份，等这一下被确认为右键单击时再交给 `onSecondaryTap`。
  Offset? _secondaryTapGlobal;

  /// 等双击间隔过去才提交的那次单击。`_pendingTapIndex == null` 表示没有挂起的。
  Timer? _tapTimer;
  int? _pendingTapIndex;
  Offset _pendingTapGlobal = Offset.zero;

  /// [MultiSelectDoubleTapMode.revert] 下单击提交之前的选中快照，双击时回滚用。
  List<int>? _pendingTapSnapshot;

  /// 第二次按下的位置正好是挂起那一项：先把提交冻结，等抬起再确认双击。
  /// 不冻结的话「按住第二下超过 300ms」会先把第一次单击提交掉，双击就失效了。
  bool _doubleTapArmed = false;

  bool _dragging = false;
  List<int> _dragIndices = const <int>[];
  Offset _grabOffset = Offset.zero;

  /// 落点：占位框在「移除被拖条目后的列表」中的插入下标。
  int _targetSlot = 0;

  OverlayEntry? _overlay;
  Timer? _scrollTimer;

  /// 与官方 `ReorderableListView` 一样，在拖起时 0→1、松手时 1→0。
  /// 传给 `proxyDecorator`，可用来做阴影 / 缩放等拾起动画。
  AnimationController? _proxyAnimation;

  /// 全局指针路由是否已注册。新版 Flutter 的 `removeGlobalRoute` 对未注册的
  /// 路由会断言，所以 dispose 不能无条件移除。
  bool _globalRouteAttached = false;

  List<int> _lastEmittedIndices = <int>[];

  /// 松手瞬间：**原下标 → 该条目视觉位置与最终槽位的偏移**。
  ///
  /// 落位后这些条目是新建的元素，没有「旧位置」可以插值，所以把落点作为
  /// 起始偏移传下去，让它们从指针处滑进槽位。只在落位阶段消费。
  Map<int, Offset> _dropOffsets = const <int, Offset>{};

  /// 落位阶段：列表先按「重排后的顺序」重排**旧数据**，播完落位动画才把
  /// `onReorder` 交给父组件。元素是原下标序列，null 表示不在落位阶段。
  ///
  /// 为什么要延迟提交：条目元素默认按**下标**做 key，父组件一重排数据，
  /// 同一下标里的内容就换成了别的条目，按槽位差值插值会让条目「跳到别处
  /// 再滑回来」。先按旧数据把动画播完、再让数据跟上，位置已经到位，换人
  /// 也就看不出来了。
  List<int>? _settleOrder;

  /// 没有自定义 itemId 时，重排后仍要按下标映射选中。
  List<int> _settleSelectedBefore = const <int>[];

  /// 落位阶段结束时才提交的重排信息。
  List<int> _settleOldIndices = const <int>[];
  List<int> _settleNewIndices = const <int>[];
  bool _settleMoved = false;

  /// 落位阶段的计时器：一行「空动画」，只用来在动画帧上等落位动画播完。
  ///
  /// 用 controller 而不是 `Timer`：延迟 / 等待期间也会持续调度帧，`pumpAndSettle`
  /// 之类的等待能正确等到底，也不会和动画时间轴错开。
  AnimationController? _settleAnimation;

  /// 正在播落位动画：此间数据还是旧的，指针事件一律忽略，避免在中间态上
  /// 再发起一次拖动。
  bool get _settling => _settleOrder != null;

  ScrollController get _scroll =>
      widget.scrollController ?? (_ownScroll ??= ScrollController());

  MultiSelectController get _controller => widget.controller ?? _ownController!;

  @override
  void initState() {
    super.initState();
    _ownController = widget.controller == null ? MultiSelectController() : null;
    _controller._bind(widget.itemCount, widget.itemId);
    if (!_controller.hasSelection && widget.initialSelectedIndices.isNotEmpty) {
      _controller.setSelection(widget.initialSelectedIndices);
    }
    _attachedController = _controller;
    _attachedController!.addListener(_onControllerChanged);
    // 初始选中也算一次对外通告；放到帧末，避免父组件在 build 里收到回调。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emitSelection();
    });
  }

  @override
  void didUpdateWidget(covariant _MultiSelectDragView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父组件 rebuild = 数据 / 主题 / builder 可能换了，缓存的整体失效。
    // State 自己的 setState（让位动画、拖动）不走这里，所以动画帧里能复用。
    _builtItems.clear();
    _wrappedItems.clear();
    // 条数在拖动中被外部改动，原下标已失效，直接结束这次拖动。
    final bool abortDrag = _dragging && widget.itemCount != oldWidget.itemCount;
    if (abortDrag) _endDrag();

    // 落位阶段里被外部换了数据：动画用的旧顺序已经失效，直接收尾。
    // 数据是外部改的，这里不再补发 onReorder。
    if (_settling && widget.itemCount != oldWidget.itemCount) {
      _settleAnimation?.dispose();
      _settleAnimation = null;
      _settleOrder = null;
      _settleMoved = false;
      _dropOffsets = const <int, Offset>{};
    }

    final bool controllerChanged = widget.controller != oldWidget.controller;
    if (controllerChanged) {
      _attachedController?.removeListener(_onControllerChanged);
      _ownController?.dispose();
      _ownController = widget.controller == null
          ? MultiSelectController()
          : null;
      _controller._bind(widget.itemCount, widget.itemId);
      if (!_controller.hasSelection &&
          widget.initialSelectedIndices.isNotEmpty) {
        _controller.setSelection(widget.initialSelectedIndices);
      }
      _attachedController = _controller;
      _attachedController!.addListener(_onControllerChanged);
    } else {
      _controller._bind(widget.itemCount, widget.itemId);
    }
    // 条目数变了：_bind 可能已经剪掉越界下标，帧末重新对外发一次。
    if (widget.itemCount != oldWidget.itemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emitSelection();
      });
    }
  }

  /// 视图被摘下（切页面、父组件换子树等）时也先摘浮层。这里不能走
  /// [_endDrag]，因为 deactivate 期间再 setState 不安全，只做静默清理。
  @override
  void deactivate() {
    _detachGlobalRoute();
    _removeOverlay();
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _dragging = false;
    _dragIndices = const <int>[];
    _pointer = null;
    _pressedIndex = null;
    // 落位动画还没走完就被摘下：把重排结果补交给父组件，否则这次拖动白做。
    // 放到帧末以免在 deactivate 期间直接改父级状态。
    if (_settling) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _completeSettle(notify: false);
      });
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _attachedController?.removeListener(_onControllerChanged);
    _settleAnimation?.dispose();
    _settleAnimation = null;
    _detachGlobalRoute();
    _removeOverlay();
    _scrollTimer?.cancel();
    _tapTimer?.cancel();
    _proxyAnimation?.dispose();
    _dragPosition.dispose();
    _ownScroll?.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  void _onControllerChanged() => _emitSelection();

  void _attachGlobalRoute() {
    if (_globalRouteAttached) return;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handleGlobalPointer);
    _globalRouteAttached = true;
  }

  void _detachGlobalRoute() {
    if (!_globalRouteAttached) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(
      _handleGlobalPointer,
    );
    _globalRouteAttached = false;
  }

  /// 选中集合变化时把**下标**回给调用方；内容没变就不重复回调。
  void _emitSelection() {
    if (!mounted) return;
    final List<int> indices = _controller.selectedIndices;
    if (!_sameList<int>(indices, _lastEmittedIndices)) {
      _lastEmittedIndices = indices;
      widget.onSelectionChanged?.call(List<int>.unmodifiable(indices));
    }
  }

  // ── 构建 ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final MultiSelectLayout layout = widget.layout.compute(
          constraints.maxWidth,
          widget.padding,
        );
        _layout = layout;
        final List<int?> slots = _buildSlots();
        return SizedBox(
          key: _viewportKey,
          height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          child: SingleChildScrollView(
            controller: _scroll,
            child: AnimatedBuilder(
              animation: _scroll,
              builder: (BuildContext context, Widget? _) => AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? _) {
                  final double offset = _scroll.hasClients ? _scroll.offset : 0;
                  return SizedBox(
                    key: _contentKey,
                    // 拖动时槽位变少（占位区只占 1 格），内容高度保持不变：
                    // 否则滚动范围会跟着缩，offset 被夹回去，列表会「跳」一下。
                    height: layout.extentFor(
                      math.max(slots.length, widget.itemCount),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: _buildChildren(
                        context,
                        layout,
                        slots,
                        offset,
                        constraints.maxHeight,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// 把「原下标序列」重排成「带占位区的槽位序列」，null 表示落点。
  ///
  /// 拖动时占位区**只占 1 格**：整组拖动不会在列表里留一大片空白。代价是
  /// 落点后面的条目在这一阶段要先上移 `k - 1` 格，松手后再依次后移让回去
  /// （见 [_finishDrag] 的落位阶段）。
  List<int?> _buildSlots() {
    final int count = widget.itemCount;
    // 落位阶段：按重排后的顺序渲染（下标还是旧语义，数据也还是旧的）。
    final List<int>? settle = _settleOrder;
    if (settle != null && settle.length == count) {
      return List<int?>.of(settle);
    }
    if (!_dragging || _dragIndices.isEmpty) {
      return List<int?>.generate(count, (int i) => i);
    }
    final Set<int> dragSet = _dragIndices.toSet();
    final List<int> rest = <int>[
      for (int i = 0; i < count; i++)
        if (!dragSet.contains(i)) i,
    ];
    final int at = _clampInt(_targetSlot, 0, rest.length);
    return <int?>[...rest.take(at), null, ...rest.skip(at)];
  }

  List<Widget> _buildChildren(
    BuildContext context,
    MultiSelectLayout layout,
    List<int?> slots,
    double scrollOffset,
    double viewportHeight,
  ) {
    // 可见区裁剪：上下各多留一行，避免快速滚动时露白。
    final double top = scrollOffset - layout.cellHeight;
    final double bottom =
        scrollOffset +
        (viewportHeight.isFinite ? viewportHeight : 0) +
        layout.cellHeight;

    final List<Widget> children = <Widget>[];
    // 选中序号映射：下标 → 它在选中顺序里的位置。只有在真的配了
    // selectedBuilder 时才建，避免每次 build 都白算一遍（O(k)）。
    final MultiSelectSelectedBuilder? selectedBuilder =
        widget.style.selectedBuilder;
    Map<int, int>? selectionOrder;
    int selectedCount = 0;
    if (selectedBuilder != null) {
      final List<int> picked = _controller.selectedIndices;
      selectedCount = picked.length;
      selectionOrder = <int, int>{};
      for (int i = 0; i < picked.length; i++) {
        selectionOrder[picked[i]] = i;
      }
    }
    for (int slot = 0; slot < slots.length; slot++) {
      final int? index = slots[slot];
      final Offset position = layout.offsetOf(slot);
      if (position.dy + layout.cellHeight < top || position.dy > bottom) {
        continue;
      }
      if (index == null) {
        children.add(
          _buildSlotItem(
            // 固定 key：落点变化时元素能保住，占位框自己滑过去。
            key: const ValueKey<String>('multi-select-placeholder'),
            position: position,
            layout: layout,
            child: _buildDragPlaceholder(context, slots.length),
          ),
        );
        continue;
      }
      // Element key 决定「数据重排后这个元素跟着谁走」，三个来源按优先级：
      // 1. `itemKeyBuilder` 显式指定；
      // 2. 否则直接用 `itemBuilder` 结果自带的 key——写法和普通
      //    [ListView] 完全一样，不必为了排序再写第二份 id；
      // 3. 都没有才按下标：增删 / 重排时元素原地换内容，条目内部 State
      //    保不住，也不会播位移动画。
      final bool selected = _controller.isSelected(index);
      final Widget built = _builtItem(index, selected, context);
      final Key key =
          widget.itemKeyBuilder?.call(index) ??
          _elementKeyOf(built) ??
          ValueKey<int>(index);
      children.add(
        _buildSlotItem(
          key: key,
          position: position,
          layout: layout,
          // 刚松手的条目从这个偏移（落点）滑进自己的槽位。
          dropOffset: _dropOffsets[index],
          child: _wrappedItem(
            index,
            built,
            selected,
            selectedBuilder == null ? 0 : selectionOrder![index] ?? 0,
            selectedCount,
          ),
        ),
      );
    }
    return children;
  }

  /// 取缓存的条目内容；只在数据 / 选中态真的变了时才重新调用 `itemBuilder`。
  Widget _builtItem(int index, bool selected, BuildContext context) {
    final _BuiltItem? cached = _builtItems[index];
    if (cached != null &&
        cached.selected == selected &&
        identical(cached.builder, widget.itemBuilder) &&
        identical(cached.style, widget.style) &&
        cached.itemCount == widget.itemCount) {
      return cached.widget;
    }
    final Widget built = widget.itemBuilder(context, index, selected);
    _builtItems[index] = _BuiltItem(
      builder: widget.itemBuilder,
      selected: selected,
      style: widget.style,
      itemCount: widget.itemCount,
      widget: built,
    );
    return built;
  }

  /// 组装并缓存条目的「外壳」：选中装饰 + 角标 + 指针包裹。
  ///
  /// [built] 来自 [_builtItem]，可能是缓存实例。这里再按影响外观的条件缓存
  /// 整棵外壳；让位动画帧里条件都不变，返回同一个 Widget 实例，Flutter 的
  /// Element 更新发现 `oldWidget == newWidget` 会直接跳过整棵子树的 rebuild。
  Widget _wrappedItem(
    int index,
    Widget built,
    bool selected,
    int selectedIndex,
    int selectedCount,
  ) {
    final MultiSelectSelectedBuilder? selectedBuilder =
        widget.style.selectedBuilder;
    final _WrappedItem? cached = _wrappedItems[index];
    if (cached != null &&
        cached.built == built &&
        cached.selected == selected &&
        cached.selectedIndex == selectedIndex &&
        cached.selectedCount == selectedCount &&
        cached.dragging == _dragging &&
        identical(cached.style, widget.style) &&
        cached.itemCount == widget.itemCount) {
      return cached.widget;
    }

    Widget content = built;
    // 选中项的二次装饰（如左上角序号角标）：只在选中时调用，浮层不走这里。
    if (selected && selectedBuilder != null) {
      content = selectedBuilder(content, index, selectedIndex, selectedCount);
    }
    final Widget wrapped = _wrapPointer(
      index,
      _decorateSelected(selected, content),
    );
    _wrappedItems[index] = _WrappedItem(
      built: built,
      selected: selected,
      selectedIndex: selectedIndex,
      selectedCount: selectedCount,
      dragging: _dragging,
      style: widget.style,
      itemCount: widget.itemCount,
      widget: wrapped,
    );
    return wrapped;
  }

  /// 从 `itemBuilder` 的结果上取 Element key。
  ///
  /// 取到后要**再包一层** [ValueKey] 才能用在让位容器上：条目自己的 key 还
  /// 留在原 widget 上，父子两层用同一个 key 会让 `find.byKey` 找到两个
  /// （`GlobalKey` 更是直接断言重复）。包一层后既保留了「跟着条目走」的
  /// 身份，又不和条目本身冲突。
  Key? _elementKeyOf(Widget built) {
    final Key? key = built.key;
    return key == null ? null : ValueKey<Key>(key);
  }

  /// 单个槽位的定位容器：对齐官方 `ReorderableListView` 的做法，用
  /// [Transform.translate] 做让位动画，而不是每帧该写 `AnimatedPositioned`
  /// 的 left/top 触发 Stack 重新布局。配合 [_AnimatedSlot] 内部「从当前
  /// 视觉位置续接」的插值，快速拖动时不会一顿一顿。
  Widget _buildSlotItem({
    required Key key,
    required Offset position,
    required MultiSelectLayout layout,
    required Widget child,
    Offset? dropOffset,
  }) {
    return _AnimatedSlot(
      key: key,
      position: position,
      duration: widget.style.duration,
      curve: widget.style.curve,
      width: layout.cellWidth,
      height: layout.cellHeight,
      dropOffset: dropOffset,
      // 让位 / 落位只改 Transform，不该重画条目内部：包一层 RepaintBoundary，
      // 条目已经画好的那块（尤其图片）可以直接复用，动画帧里只挪一个 layer。
      // 官方 `SliverChildBuilderDelegate` 默认 `addRepaintBoundaries: true`，
      // 拖动时同样是「挪 layer 不重画」，这是两者动画帧开销的主要差别。
      child: RepaintBoundary(child: child),
    );
  }

  /// 占位框：自定义 builder → 默认虚框。
  Widget _buildDragPlaceholder(BuildContext context, int slotCount) {
    return widget.style.placeholderBuilder?.call(context) ??
        _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    final Color color =
        widget.style.placeholderColor ?? Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        border: Border.all(color: color.withAlpha(90)),
        // 条目的圆角优先：占位框和落进去的卡片形状一致，不会一个圆一个直角。
        borderRadius:
            widget.style.borderRadius ??
            BorderRadius.circular(widget.style.feedbackBorderRadius),
      ),
    );
  }

  /// 给条目加圆角裁剪；没设圆角就原样返回 child。
  ///
  /// 选中底色 / 描边由使用方在 `itemBuilder` 里自己画（`selected` 参数），
  /// 组件不再自带选中装饰。
  Widget _decorateSelected(bool selected, Widget child) {
    final BorderRadius? radius = widget.style.borderRadius;
    if (radius == null) return child;
    return ClipRRect(key: _itemClipKey, borderRadius: radius, child: child);
  }

  Widget _wrapPointer(int index, Widget child) {
    final MultiSelectSecondaryTapCallback? onSecondaryTap =
        widget.onSecondaryTap;
    return Listener(
      // 用 opaque 而不是 deferToChild：拖动期间下面那层 IgnorePointer 会把
      // 子树的命中测试全部关掉，deferToChild 会连 Listener 一起失效，导致
      // 「up 丢了之后靠新的按下兜底收尾」这条安全网也失效。opaque 让
      // Listener 自己始终可命中，只把 InkWell 那层（hover / 指针）摘掉。
      behavior: HitTestBehavior.opaque,
      onPointerDown: (PointerDownEvent event) =>
          _handlePointerDown(event, index),
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      // 拖动期间把条目整体从命中测试里摘掉。鼠标在整个拖动过程中一直悬在
      // 列表上：被拖条目滑过邻居、邻居又被顶到指针底下时，InkWell 会立刻
      // 亮起 hover 高亮（还有 50ms 淡入），和让位动画叠在一起就显得一顿
      // 一顿。IgnorePointer 让 hover 直接「退出」，已有的高亮随之淡出，
      // 也不会再有新的高亮。拖动本身走全局指针路由，不依赖这里的命中测试；
      // 指针样式改由跟随指针的浮层提供（见 [_showOverlay]）。
      child: IgnorePointer(
        ignoring: _dragging,
        // Material 给 InkWell 提供绘制 hover / ripple 的画布；透明类型不改变
        // 条目本身的外观。InkWell 只负责原生 hover 效果与鼠标指针，选中与拖动
        // 仍由外层 Listener 的指针事件统一处理，避免和 itemBuilder 内部手势
        // 重复触发。
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () {},
            // 右键：按下先记位置，等 InkWell 确认「这一下真的是右键单击」
            // （没被拖动 / 划走取消）再回调，位置就是按下处。
            // `onSecondaryTap` 本身不带坐标，所以在 down 里存一份。
            onSecondaryTapDown: onSecondaryTap == null
                ? null
                : (TapDownDetails details) =>
                      _secondaryTapGlobal = details.globalPosition,
            onSecondaryTapCancel: onSecondaryTap == null
                ? null
                : () => _secondaryTapGlobal = null,
            onSecondaryTap: onSecondaryTap == null
                ? null
                : () {
                    final Offset? at = _secondaryTapGlobal;
                    _secondaryTapGlobal = null;
                    if (at != null) onSecondaryTap(index, at);
                  },
            mouseCursor: widget.style.mouseCursor,
            // hover 高亮 / 按下 ripple 也按条目圆角绘制，不然圆角卡片上会
            // 出现一块直角的高亮。
            borderRadius: widget.style.borderRadius,
            child: child,
          ),
        ),
      ),
    );
  }

  // ── 指针 ────────────────────────────────────────────────────────────────

  void _handlePointerDown(PointerDownEvent event, int index) {
    if ((event.buttons & kPrimaryButton) == 0) return;
    if (_settling) {
      // 落位动画还没走完用户又按下来了：先把重排结果提交掉，再把这次按下
      // 的下标映射到新顺序上继续处理。不这样的话连续拖动会被吃掉一截，
      // 手感像是「拖完卡一下」。
      final List<int>? order = _settleOrder;
      _completeSettle();
      final int mapped = order == null ? index : order.indexOf(index);
      if (mapped < 0) return;
      index = mapped;
    }
    if (_dragging) {
      // 同一次手势的重复 down 直接忽略。
      if (event.pointer == _pointer) return;
      // 另一次新的按下说明上一次的 up / cancel 丢了（窗口失焦、事件被
      // 别的层吞掉等）。先强制收尾，避免永久卡在拖动态、浮层一直挂着。
      _endDrag();
    }
    _pointer = event.pointer;
    _pressedIndex = index;
    _pressGlobal = event.position;
    _handlePendingTapOnDown(index, event.position);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer || _dragging) return;
    final int? pressed = _pressedIndex;
    if (pressed == null || !widget.style.enableDrag) return;
    if ((event.position - _pressGlobal).distance < widget.style.dragSlop) {
      return;
    }
    _beginDrag(pressed, event.position);
  }

  void _handlePointerUp(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (_dragging) {
      _finishDrag();
      return;
    }
    final int? pressed = _pressedIndex;
    final bool isDoubleTap = _doubleTapArmed;
    _doubleTapArmed = false;
    _pointer = null;
    _pressedIndex = null;
    if (pressed == null || pressed >= widget.itemCount) {
      _clearPendingTap();
      return;
    }
    if (isDoubleTap) {
      _takeDoubleTap(pressed);
      return;
    }
    _handleTap(pressed, event.position);
  }

  /// 手势被系统打断（窗口失焦等）：放弃这次拖动，不回调 onReorder。
  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    if (_dragging) {
      _endDrag();
      return;
    }
    // 第二次按下被取消：那它就不是双击的第二下，挂起的单击照常落地。
    if (_doubleTapArmed) _flushPendingTap();
    _pointer = null;
    _pressedIndex = null;
  }

  // ── 单击 / 双击 ─────────────────────────────────────────────────────────
  //
  // 指针事件是我们自己解析的（拖动需要绕过手势竞技场），所以双击也得自己
  // 认：两个「按下没拖动就松手」落在同一条目、相距不超过 `kDoubleTapSlop`
  // 且间隔不超过 `kDoubleTapTimeout` 就是双击。单击怎么让路见
  // [MultiSelectDoubleTapMode]。

  /// 一次单击，提交方式取决于有没有配 `onDoubleTap`。
  void _handleTap(int index, Offset global) {
    if (widget.onDoubleTap == null) {
      // 没配双击：单击立刻生效，和以前的时序完全一样。
      _commitTap(index);
      return;
    }
    // 走到这里说明上一次挂起的单击等不到第二下了（计时器已走完或点了别处）。
    _flushPendingTap();

    _pendingTapIndex = index;
    _pendingTapGlobal = global;
    if (widget.style.doubleTapMode != MultiSelectDoubleTapMode.delay) {
      // revert / immediate / selectOnly 都是「先提交」：单击零延迟。
      // revert 留快照，双击时回滚；immediate / selectOnly 不留——前者保持
      // 第一下的结果，后者双击时把被点项强制设为唯一选中。
      if (widget.style.doubleTapMode == MultiSelectDoubleTapMode.revert) {
        _pendingTapSnapshot = _controller.selectedIndices;
      }
      _commitTap(index);
      _tapTimer = Timer(kDoubleTapTimeout, _clearPendingTap);
    } else {
      // 先挂起，间隔过去再提交。
      _tapTimer = Timer(kDoubleTapTimeout, () {
        final int? pending = _pendingTapIndex;
        _clearPendingTap();
        if (pending != null && pending < widget.itemCount) _commitTap(pending);
      });
    }
  }

  /// 第二次按下：是同一项、位置也没跑远，就把挂起的提交冻住，等抬起确认；
  /// 否则上一次单击先落地（用户已经去点别的了）。
  void _handlePendingTapOnDown(int index, Offset global) {
    final int? pending = _pendingTapIndex;
    if (pending == null || widget.onDoubleTap == null) return;
    final bool sameItem =
        pending == index &&
        (global - _pendingTapGlobal).distance <= kDoubleTapSlop;
    if (sameItem) {
      _tapTimer?.cancel();
      _tapTimer = null;
      _doubleTapArmed = true;
      return;
    }
    _flushPendingTap();
  }

  /// 挂起的单击立刻提交（[MultiSelectDoubleTapMode.revert] 下早已提交，只需清状态）。
  void _flushPendingTap() {
    final int? pending = _pendingTapIndex;
    final bool deferred =
        widget.style.doubleTapMode == MultiSelectDoubleTapMode.delay;
    _clearPendingTap();
    if (pending != null && deferred && pending < widget.itemCount) {
      _commitTap(pending);
    }
  }

  void _clearPendingTap() {
    _tapTimer?.cancel();
    _tapTimer = null;
    _pendingTapIndex = null;
    _pendingTapSnapshot = null;
    _doubleTapArmed = false;
  }

  /// 确认双击：丢掉挂起的单击（[MultiSelectDoubleTapMode.revert] 下把选中
  /// 回滚到单击之前；[MultiSelectDoubleTapMode.selectOnly] 下把被双击项设为
  /// 唯一选中），然后回调 `onDoubleTap`。
  void _takeDoubleTap(int index) {
    final List<int>? snapshot = _pendingTapSnapshot;
    final MultiSelectDoubleTapMode mode = widget.style.doubleTapMode;
    _clearPendingTap();
    if (index >= widget.itemCount) return;
    if (mode == MultiSelectDoubleTapMode.revert && snapshot != null) {
      _controller.setSelection(snapshot);
    } else if (mode == MultiSelectDoubleTapMode.selectOnly) {
      // 第一下可能按「再点取消」把这一项清掉了；双击时强制只留它。
      // 没有变化就不通知，避免多一次 rebuild。
      final List<int> current = _controller.selectedIndices;
      if (current.length != 1 || current.first != index) {
        _controller.setSelection(<int>[index]);
      }
    }
    widget.onDoubleTap?.call(index);
  }

  void _commitTap(int index) {
    if (index < 0 || index >= widget.itemCount) return;
    _applyClickSelection(index);
  }

  Set<LogicalKeyboardKey> get _keys =>
      HardwareKeyboard.instance.logicalKeysPressed;

  bool get _ctrlDown =>
      _keys.contains(LogicalKeyboardKey.controlLeft) ||
      _keys.contains(LogicalKeyboardKey.controlRight) ||
      _keys.contains(LogicalKeyboardKey.metaLeft) ||
      _keys.contains(LogicalKeyboardKey.metaRight);

  bool get _shiftDown =>
      _keys.contains(LogicalKeyboardKey.shiftLeft) ||
      _keys.contains(LogicalKeyboardKey.shiftRight);

  void _applyClickSelection(int index) {
    final MultiSelectController controller = _controller;
    if (_shiftDown && _anchorIndex != null) {
      final int from = math.min(_anchorIndex!, index);
      final int to = math.max(_anchorIndex!, index);
      final List<int> ids = controller.selectedIndices;
      for (int i = from; i <= to && i < widget.itemCount; i++) {
        if (!ids.contains(i)) ids.add(i);
      }
      controller.setSelection(ids);
    } else if (_ctrlDown || widget.style.mode == MultiSelectMode.multiple) {
      controller.toggle(index);
    } else if (controller.isSelected(index)) {
      // 单选模式：第一次点击选中，再点同一个条目就是取消选中。
      controller.deselect(index);
    } else {
      controller.setSelection(<int>[index]);
    }
    _anchorIndex = index;
  }

  /// 拖动期间接收全应用范围的指针事件（路由会先拷贝再遍历，可安全移除自身）。
  void _handleGlobalPointer(PointerEvent event) {
    if (!_dragging || event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      _pointerGlobal = event.position;
      _dragPosition.value = event.position;
      _updateTargetSlot();
    } else if (event is PointerUpEvent) {
      _finishDrag();
    } else if (event is PointerCancelEvent) {
      _endDrag();
    }
  }

  // ── 拖动 ────────────────────────────────────────────────────────────────

  void _beginDrag(int index, Offset global) {
    // 真起拖了，上一次单击不可能是双击的第一下：先把它落地，别拖到一半才闪。
    _flushPendingTap();
    final RenderBox? box =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final List<int> indices = _resolveDragIndices(index);

    final MultiSelectLayout layout =
        _layout ?? widget.layout.compute(box.size.width, widget.padding);
    final Offset local = box.globalToLocal(global);
    final Offset slotPosition = layout.offsetOf(index);

    _dragIndices = indices;
    _grabOffset = Offset(
      _clampDouble(local.dx - slotPosition.dx, 0, layout.cellWidth),
      _clampDouble(local.dy - slotPosition.dy, 0, layout.cellHeight),
    );
    // 初始落点 = 按下项在「移除被拖条目后」列表中的位置。
    final Set<int> dragSet = indices.toSet();
    int slot = 0;
    for (int i = 0; i < index; i++) {
      if (!dragSet.contains(i)) slot++;
    }
    _targetSlot = slot;
    _pointerGlobal = global;
    _dragPosition.value = global;
    _dragging = true;
    // 每次拖动重启一次 0→1 的拾起动画，签名与官方 proxyDecorator 对齐。
    // 时长取官方 `_DragInfo.startDrag()` 的 250ms（不是 180ms）：这个值同时
    // 决定松手时浮层飞向落点的插值时长，官方整套都是 250ms。
    _proxyAnimation?.dispose();
    _proxyAnimation = AnimationController(
      vsync: this,
      duration: _kProxyLiftDuration,
    )..forward();

    _showOverlay(layout, indices);
    if (widget.style.enableAutoScroll) _startAutoScroll();
    _attachGlobalRoute();
    setState(() {});
  }

  /// 被拖条目的顺序规则：浮层堆叠、`onReorder` 全部共用这一个结果。
  ///
  /// - 按下的是**已选中**项 → 整组按点选顺序拖走，`first` 固定就是
  ///   「第一个被选中的条目」，与按下的是组内哪一项无关。
  /// - 按下的是**未选中**项 → 只拖它自己（此时它自己就是首张）。
  List<int> _resolveDragIndices(int pressedIndex) {
    final List<int> selected = _controller.selectedIndices;
    if (!selected.contains(pressedIndex)) return <int>[pressedIndex];
    final Set<int> seen = <int>{};
    final List<int> result = <int>[
      for (final int i in selected)
        if (i >= 0 && i < widget.itemCount && seen.add(i)) i,
    ];
    return result.isEmpty ? <int>[pressedIndex] : result;
  }

  /// 把「被拖的原下标 + 落点」换算成完整的新下标顺序。
  ///
  /// 长度恒等于 `itemCount`，每个原下标出现恰好一次；调用方直接
  /// `items = order.map((i) => items[i]).toList()` 即可。
  List<int> _buildOrder(List<int> indices, int target) {
    final Set<int> dragSet = indices.toSet();
    final List<int> rest = <int>[
      for (int i = 0; i < widget.itemCount; i++)
        if (!dragSet.contains(i)) i,
    ];
    final int at = _clampInt(target, 0, rest.length);
    return <int>[...rest.take(at), ...indices, ...rest.skip(at)];
  }

  void _finishDrag() {
    if (!_dragging) return;
    final List<int> indices = List<int>.of(_dragIndices);
    final int target = _targetSlot;
    final List<int> order = _buildOrder(indices, target);
    // 把「动过」定义成「重排结果不是原顺序」，而不是「落点 != 起点」：
    // 整组按点选顺序搬走时，即使落回原来那一格，组内次序也可能从「下标
    // 升序」变成「点选顺序」（选中 2、4、3 拖回第 2 格 → 1,2,4,3,5,6）。
    // 只看落点的话这次拖动会被当成原地放下，列表退回原样，看着就是白拖。
    final bool moved = !_isIdentityOrder(order);
    // newIndex[j] = 第 j 个被拖条目重排后的新下标，与 oldIndex 一一对应。
    final List<int> newIndices = <int>[
      for (final int index in indices) order.indexOf(index),
    ];
    // 落位动画的起点：松手瞬间每个被拖条目画在哪，与它最终槽位的差。
    final Map<int, Offset> dropOffsets = _resolveDropOffsets(order, indices);

    try {
      // 顺序真的变了才回调（`moved` 看的是重排结果，不是落点是否移动）；
      // 取消 / 卸载走 _endDrag，不回调。

      // 进入落位阶段：先按「重排后的顺序」重排**旧数据**播动画——
      // 被拖条目从落点滑进自己的槽位，同时其余条目后移让出那 k - 1 格。
      // 等动画停下来才把 onReorder 交给父组件（见 [_completeSettle]）。
      _settleOrder = order;
      _settleOldIndices = indices;
      _settleNewIndices = newIndices;
      _settleSelectedBefore = _controller.selectedIndices;
      _settleMoved = moved && indices.isNotEmpty;
      _dropOffsets = dropOffsets;
    } finally {
      // 回调里抛异常也必须收干净浮层 / 全局路由，否则列表会卡在拖动态。
      // 注意 _endDrag 会清 _dragIndices，上面几个字段已经先存好了。
      _endDrag(notify: false);
      if (_settleOrder != null) _startSettle();
      if (mounted) setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // 落位起点只给这一帧新建的元素用一次。
        _dropOffsets = const <int, Offset>{};
      });
    }
  }

  /// 落位动画只有一个 `duration`：卡片落位与其余条目后移同时进行。
  /// 零时长（关掉了动画）就直接提交，不多等一帧。
  void _startSettle() {
    _settleAnimation?.dispose();
    _settleAnimation = null;
    final Duration total = widget.style.duration;
    if (total <= Duration.zero) {
      _completeSettle();
      return;
    }
    _settleAnimation = AnimationController(vsync: this, duration: total)
      ..addStatusListener((AnimationStatus status) {
        if (!status.isCompleted) return;
        _settleAnimation?.dispose();
        _settleAnimation = null;
        if (!mounted) return;
        _completeSettle();
      })
      ..forward();
  }

  /// 落位动画结束：把重排结果交给父组件，元素随之按新下标重建。
  ///
  /// 这时所有条目都已经停在最终位置，即使元素换了人也看不出来。
  void _completeSettle({bool notify = true}) {
    _settleAnimation?.dispose();
    _settleAnimation = null;
    final bool moved = _settleMoved;
    final List<int> selected = _settleSelectedBefore;
    final List<int> oldIndices = _settleOldIndices;
    final List<int> newIndices = _settleNewIndices;
    final List<int>? order = _settleOrder;

    _settleOrder = null;
    _settleMoved = false;
    _settleOldIndices = const <int>[];
    _settleNewIndices = const <int>[];
    _settleSelectedBefore = const <int>[];
    _dropOffsets = const <int, Offset>{};

    if (moved && order != null) {
      if (widget.itemId == null) {
        // 没提供稳定 id：选中退化成下标，重排后必须映射成新位置。
        // order 是 0..itemCount-1 的排列，indexOf 不会返回 -1。
        _controller.setSelection(<int>[
          for (final int index in selected) order.indexOf(index),
        ]);
      }
      // 有 itemId 时选中按真实 id 保存，父组件换数据后 _bind 重建映射，
      // 选中自动跟着条目走，不需要这里改。
      widget.onReorder?.call(
        List<int>.unmodifiable(oldIndices),
        List<int>.unmodifiable(newIndices),
      );
    }
    if (notify && mounted) setState(() {});
  }

  /// 计算落位动画的起始偏移：**原下标 → 偏移**。
  ///
  /// 浮层里第 0 层左上角是「指针 - 抓取偏移」，第 l 层再右下各挪
  /// 叠卡偏移；落位后第 l 个被拖条目占 `targetSlot + l` 这一格。
  /// 两者之差就是这个条目要滑过的距离。超出叠卡上限的层没有画出来，
  /// 从最上面那张卡的位置起飞。
  ///
  /// key 用**原下标**：落位阶段列表还是旧数据、按原下标渲染，用新下标查不到。
  Map<int, Offset> _resolveDropOffsets(List<int> order, List<int> indices) {
    final MultiSelectLayout? layout = _layout;
    final RenderBox? box =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (layout == null || box == null || !box.hasSize) {
      return const <int, Offset>{};
    }
    final Offset topLeft = box.globalToLocal(_pointerGlobal) - _grabOffset;
    const double step = _feedbackLayerStep;
    const int layerLimit = _maxFeedbackLayers;
    final Map<int, Offset> offsets = <int, Offset>{};
    for (int layer = 0; layer < indices.length; layer++) {
      final int newIndex = order.indexOf(indices[layer]);
      if (newIndex < 0) continue;
      final int visualLayer = math.min(layer, layerLimit - 1);
      final Offset visual =
          topLeft + Offset(visualLayer * step, visualLayer * step);
      final Offset delta = visual - layout.offsetOf(newIndex);
      if (delta != Offset.zero) offsets[indices[layer]] = delta;
    }
    return offsets;
  }

  void _endDrag({bool notify = true}) {
    _detachGlobalRoute();
    _removeOverlay();
    _scrollTimer?.cancel();
    _scrollTimer = null;
    // 松手时启动 1→0 的回落动画；浮层立刻移除，controller 也随本次拖动结束。
    _proxyAnimation?.reverse();
    _proxyAnimation?.dispose();
    _proxyAnimation = null;
    _dragging = false;
    _dragIndices = const <int>[];
    _pressedIndex = null;
    _pointer = null;
    if (notify && mounted) setState(() {});
  }

  void _updateTargetSlot() {
    final RenderBox? box =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    final MultiSelectLayout? layout = _layout;
    if (box == null || !box.hasSize || layout == null) return;
    final Offset local = box.globalToLocal(_pointerGlobal);
    // 落点是「移除被拖条目后」的插入下标，最大就是剩余条目数。
    final int maxSlot = math.max(0, widget.itemCount - _dragIndices.length);
    final int slot = layout.slotAt(local, maxSlot);
    if (slot != _targetSlot) setState(() => _targetSlot = slot);
  }

  // ── 拖动预览 ────────────────────────────────────────────────────────────

  /// 拖动期间跟随指针的浮层用的鼠标指针。
  ///
  /// 优先用 `style.mouseCursor`：条目上是什么光标，拖起来就还是什么光标，
  /// 不会出现「一拖就变回箭头」。没设时维持原样（默认
  /// `WidgetStateMouseCursor.adaptiveClickable`，与 [InkWell] 的解析一致）。
  MouseCursor get _dragCursor =>
      widget.style.mouseCursor ??
      WidgetStateProperty.resolveAs<MouseCursor>(
        WidgetStateMouseCursor.adaptiveClickable,
        const <WidgetState>{},
      );

  void _showOverlay(MultiSelectLayout layout, List<int> indices) {
    // 幂等：绝不在还挂着旧浮层时覆盖 _overlay 引用，否则旧 OverlayEntry
    // 会永远失去引用、留在 Overlay 最上层变成「幽灵卡片」。
    _removeOverlay();

    // 与官方一致：decorator 拿到的是「已画好的那一项」+ 它的下标 + 拾起动画。
    // 多选时逐层调用，每层对应一个被拖条目；整组下标通过 onReorder 的
    // oldIndex 回传。
    final Animation<double> animation =
        _proxyAnimation?.view ?? const AlwaysStoppedAnimation<double>(1);
    final Widget feedback = _buildFeedback(layout, indices, animation);

    final OverlayState? overlay = Overlay.maybeOf(
      context,
      rootOverlay: widget.style.useRootOverlay,
    );
    if (overlay == null) return;

    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) {
        // 每帧按当时的位置重算：拖动中窗口缩放 / Overlay 被挤动也不会错位。
        // 官方在 `_DragItemProxy.build` 里同样每帧算一次 `_overlayOrigin`。
        final Offset origin = _overlayOrigin(overlay.context);
        return ValueListenableBuilder<Offset>(
          valueListenable: _dragPosition,
          builder: (BuildContext context, Offset position, Widget? child) =>
              Positioned(
                key: _multiSelectableFeedbackKey,
                // 指针位置是**全局**坐标，Positioned 是**Overlay 局部**坐标。
                left: position.dx - origin.dx - _grabOffset.dx,
                top: position.dy - origin.dy - _grabOffset.dy,
                // 拖动期间条目不再参与命中测试（见 [_wrapPointer]），鼠标指针
                // 会退化成默认箭头。浮层跟着指针走，所以由它来提供指针样式，
                // 拖动前后光标保持一致。
                child: MouseRegion(
                  key: _feedbackCursorKey,
                  cursor: _dragCursor,
                  child: IgnorePointer(child: child),
                ),
              ),
          child: feedback,
        );
      },
    );
    // 先 insert 再保存引用：insert 抛异常时不会留下一个「以为已经插进去」
    // 的 entry，后续 remove 也不会误判。
    overlay.insert(entry);
    _overlay = entry;
  }

  /// 拖动预览：按被拖条目逐层叠加，每层都是 `itemBuilder` 画出来的那一项
  /// （按**未选中**构建，选中样式只属于列表里的条目）。
  ///
  /// - 最多叠 4 层，`indices` 按点选顺序；
  /// - [proxyDecorator] 逐层调用，拿到对应层的 `child` / `index` / `animation`；
  ///   没传时走默认不透明 [Material] 背景 + 阴影；
  /// - `layer == 0`（第一个被选中的项）永远在最上层，按下组内哪一项只影响
  ///   抓取偏移，不改变叠卡顺序；
  /// - 超出上限的条目用角标提示。
  Widget _buildFeedback(
    MultiSelectLayout layout,
    List<int> indices,
    Animation<double> animation,
  ) {
    final int layers = math.min(indices.length, _maxFeedbackLayers);
    final double step = _feedbackLayerStep;

    final List<Widget> layerWidgets = <Widget>[];
    for (int layer = 0; layer < layers; layer++) {
      final int index = indices[layer];
      // 固定按「未选中」构建：浮层是拖动样式的舞台，选中样式（底色 / 角标）
      // 由 selectedBuilder 负责，不该跟着卡片一起飞起来。
      final Widget child = widget.itemBuilder(context, index, false);
      layerWidgets.add(
        widget.proxyDecorator?.call(child, index, animation) ??
            _wrapFeedbackMaterial(child, animation, layer: layer),
      );
    }

    // 超出上限的那几项没画进浮层，用右下角的 `+N` 交代一下总数，
    // 否则拖 10 项时看着和拖 4 项一样。
    final int hidden = indices.length - layers;

    return SizedBox(
      key: _multiSelectableFeedbackItemKey,
      width: layout.cellWidth + step * (layers - 1),
      height: layout.cellHeight + step * (layers - 1),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Stack 里后画的在上层，所以倒序放置：第 0 层最后画、压在最上面。
          for (int layer = layers - 1; layer >= 0; layer--)
            Positioned(
              key: _feedbackLayerKey(layer),
              left: layer * step,
              top: layer * step,
              width: layout.cellWidth,
              height: layout.cellHeight,
              child: layerWidgets[layer],
            ),
          if (hidden > 0)
            Positioned(
              key: _feedbackBadgeKey,
              // 落在最底层卡片的右下角（整叠卡的外沿），再往里让出一点间距。
              right: _feedbackBadgeInset,
              bottom: _feedbackBadgeInset,
              child: _buildFeedbackBadge(hidden),
            ),
        ],
      ),
    );
  }

  /// 浮层右下角的 `+N`：只说明「还有几项没画出来」，不带交互。
  Widget _buildFeedbackBadge(int hidden) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    // 浮层直接挂在 Overlay 上、没有 Material 祖先，补一层透明 Material
    // 让文字拿到主题字体，而不是退化成「没 Material 时的黄双下划线」。
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
          // 一圈底色描边：叠卡内容和底色接近时也能看清边界。
          border: Border.all(color: scheme.surface, width: 1),
        ),
        child: Text(
          '+$hidden',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  /// 默认预览的单层：不透明主题背景 + 随 [animation] 变化的阴影。
  /// 顶层用完整 `feedbackElevation`，下面几层减半，避免整叠卡都像浮在空中。
  ///
  /// 阴影用 [Curves.easeOut] 而不是线性：拾起动画的时长按官方取 250ms，
  /// 线性的话前 100ms 阴影都还很淡，观感上像「卡片慢半拍才浮起来」。easeOut
  /// 起步就把大部分阴影推上去，手感和「瞬间拾起」更接近，但动画总长和官方
  /// 一致（`proxyDecorator` 拿到的时间轴、松手飞向落点的插值都不变）。
  Widget _wrapFeedbackMaterial(
    Widget child,
    Animation<double> animation, {
    required int layer,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double full = math.max(
          0,
          1 +
              (widget.style.feedbackElevation - 1) *
                  Curves.easeOut.transform(animation.value),
        );
        return Material(
          elevation: layer == 0 ? full : full * 0.4,
          // 条目设了圆角就跟条目走，否则用预览自己的 feedbackBorderRadius。
          borderRadius:
              widget.style.borderRadius ??
              BorderRadius.circular(widget.style.feedbackBorderRadius),
          clipBehavior: Clip.antiAlias,
          // 关键：不能 transparent，否则浮层会透出下面的列表内容。
          color: Theme.of(context).colorScheme.surface,
          child: child,
        );
      },
      child: child,
    );
  }

  void _removeOverlay() {
    final OverlayEntry? entry = _overlay;
    _overlay = null;
    if (entry == null) return;
    // 不能用 entry.mounted 当判断条件！新版 Flutter 里 mounted 指的是
    // 「entry 对应的 _OverlayEntryWidgetState 已挂载」，刚 insert 但还没
    // 经过一帧 build 时是 false。只要 insert 过就必须 remove 一次。
    entry.remove();
  }

  // ── 边缘自动滚动 ────────────────────────────────────────────────────────

  void _startAutoScroll() {
    _scrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _autoScrollTick(),
    );
  }

  void _autoScrollTick() {
    if (!_dragging || !_scroll.hasClients) return;
    final RenderBox? box =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final Rect viewport = box.localToGlobal(Offset.zero) & box.size;
    final double zone = widget.style.scrollEdgeZone;
    final double dy = _pointerGlobal.dy;

    double delta = 0;
    if (dy < viewport.top + zone) {
      delta =
          -widget.style.maxScrollStep *
          _clampDouble((viewport.top + zone - dy) / zone, 0, 1);
    } else if (dy > viewport.bottom - zone) {
      delta =
          widget.style.maxScrollStep *
          _clampDouble((dy - (viewport.bottom - zone)) / zone, 0, 1);
    }
    if (delta == 0) return;

    final ScrollPosition position = _scroll.position;
    final double target = _clampDouble(
      position.pixels + delta,
      0,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    position.jumpTo(target);
    _updateTargetSlot();
  }
}

/// [itemBuilder] 的一次构建结果，连同使它有效的条件一起存进缓存。
class _BuiltItem {
  const _BuiltItem({
    required this.builder,
    required this.selected,
    required this.style,
    required this.itemCount,
    required this.widget,
  });

  final MultiSelectItemBuilder builder;
  final bool selected;
  final MultiSelectStyle style;
  final int itemCount;
  final Widget widget;
}

/// [_wrappedItem] 的一次组装结果，连同使它有效的条件。
class _WrappedItem {
  const _WrappedItem({
    required this.built,
    required this.selected,
    required this.selectedIndex,
    required this.selectedCount,
    required this.dragging,
    required this.style,
    required this.itemCount,
    required this.widget,
  });

  final Widget built;
  final bool selected;
  final int selectedIndex;
  final int selectedCount;
  final bool dragging;
  final MultiSelectStyle style;
  final int itemCount;
  final Widget widget;
}

/// 单个条目的让位容器，对齐官方 `ReorderableListView` 的 `_ReorderableItem`：
///
/// - 用 [Transform.translate] 改绘制偏移，不写 Stack 的 left/top，避免每次
///   落点变化都触发整棵 Stack 重新布局（这是「一顿一顿」的主因）；
/// - 目标位置变化时，从**当前视觉位置**续接动画而不是从 0 重来，连续跨多格
///   拖动也平滑；
/// - 位置通过 [Positioned] 固定在 Stack 里，再用 Transform 做相对偏移：这样
///   绘制顺序 / 尺寸仍由 Stack 管，只是把「移到哪」交给便宜的 transform；
/// - 松手那一帧用 [dropOffset] 指定落位起点：被拖条目在元素层面可能是新建的、
///   也可能复用了别的条目的元素，两种情况都统一「从落点滑进自己的槽位」；
/// - 落位阶段所有条目同时归位：被拖条目从落点飞向槽位，其余条目同时后移
///   让出那 `k - 1` 格，整块一起收拢，只花一个 [duration]。
class _AnimatedSlot extends StatefulWidget {
  const _AnimatedSlot({
    required super.key,
    required this.position,
    required this.duration,
    required this.curve,
    required this.width,
    required this.height,
    required this.child,
    this.dropOffset,
  });

  /// 目标左上角坐标（相对内容区 Stack）。
  final Offset position;
  final Duration duration;
  final Curve curve;
  final double width;
  final double height;

  /// 落位起点偏移（相对 [position]）：松手那一刻条目视觉位置与最终槽位的差。
  ///
  /// 只在元素首次挂载时消费；null 表示直接落在槽位上，不做动画。
  final Offset? dropOffset;

  final Widget child;

  @override
  State<_AnimatedSlot> createState() => _AnimatedSlotState();
}

// 用 TickerProviderStateMixin 而不是 SingleTickerProviderStateMixin：动画跑完
// 后 controller 会被销毁，下一次落点变化会再新建一个，同一个 State 累计会创建
// 多个 ticker，Single 版本会直接断言失败。
class _AnimatedSlotState extends State<_AnimatedSlot>
    with TickerProviderStateMixin {
  /// 动画起点 / 终点，都是相对 [widget.position] 的**偏移量**。
  /// 稳定态时两者都是 Offset.zero，即正好落在目标位置。
  Offset _startOffset = Offset.zero;
  Offset _targetOffset = Offset.zero;
  AnimationController? _offsetAnimation;

  @override
  void initState() {
    super.initState();
    // 落位：元素刚建出来，视觉位置就是传进来的落点，动画到 0。
    // 这一帧本来就是首次 build，不需要再 setState 通知一次。
    _dropTo(widget.dropOffset, notify: false);
  }

  @override
  void didUpdateWidget(covariant _AnimatedSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 落位阶段：元素可能是复用的、内容却换成了被拖条目，优先按落点起飞。
    final Offset? drop = widget.dropOffset;
    if (drop != null && drop != Offset.zero) {
      _dropTo(drop);
      return;
    }
    if (oldWidget.position == widget.position) return;

    // 稳定态终点恒为 0（正好落在 Positioned 的目标位置）。位置变化时，
    // 起点要设成「旧位置 - 新位置」，这样第一帧视觉上仍在旧位置，再滑到 0。
    // Positioned 本身直接跳到新位置，中间的位移交给便宜的 Transform。
    final Offset slotDelta = oldWidget.position - widget.position;
    final Offset currentVisualOffset = _offset; // 打断前的当前偏移
    _startOffset = currentVisualOffset + slotDelta;
    _targetOffset = Offset.zero;

    if (widget.duration <= Duration.zero) {
      // 零时长：直接落到目标，不做动画。
      _offsetAnimation?.dispose();
      _offsetAnimation = null;
      _startOffset = Offset.zero;
      return;
    }

    _run();
    _rebuild();
  }

  /// 从 [from] 起飞滑到槽位；[from] 为 null 或零偏移时直接落位。
  void _dropTo(Offset? from, {bool notify = true}) {
    _offsetAnimation?.dispose();
    _offsetAnimation = null;
    _targetOffset = Offset.zero;
    _startOffset = from ?? Offset.zero;
    if (_startOffset == Offset.zero || widget.duration <= Duration.zero) {
      _startOffset = Offset.zero;
      if (notify) _rebuild();
      return;
    }
    _run();
    if (notify) _rebuild();
  }

  /// 起（或续接）一次「起点偏移 → 0」的动画。
  void _run() {
    if (_offsetAnimation == null) {
      _offsetAnimation =
          AnimationController(vsync: this, duration: widget.duration)
            ..addListener(_rebuild)
            ..addStatusListener((AnimationStatus status) {
              if (status.isCompleted) {
                _startOffset = Offset.zero;
                _offsetAnimation?.dispose();
                _offsetAnimation = null;
              }
            })
            ..forward();
    } else {
      // 动画被打断：从当前视觉位置续接，避免跳变（官方同款做法）。
      _offsetAnimation!.duration = widget.duration;
      _offsetAnimation!.forward(from: 0.0);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// 当前相对目标位置的绘制偏移。
  ///
  /// 没有动画在跑时画在 [_startOffset]：稳定态它已经归零；刚被打断时它
  /// 等于「旧位置 - 新位置」，条目就停在当前视觉位置上。
  Offset get _offset {
    final AnimationController? animation = _offsetAnimation;
    if (animation == null) return _startOffset;
    final double t = widget.curve.transform(animation.value);
    return Offset.lerp(_startOffset, _targetOffset, t)!;
  }

  @override
  void dispose() {
    _offsetAnimation?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      width: widget.width,
      height: widget.height,
      child: Transform.translate(offset: _offset, child: widget.child),
    );
  }
}

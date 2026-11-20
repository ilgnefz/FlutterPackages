part of '../flutter_split_pane.dart';

// ── 分割线 ────────────────────────────────────────────────────────────────

/// 两次点击间隔超过这个时间就算两次独立的点击。
const Duration _kDoubleTapWindow = Duration(milliseconds: 300);

/// 两次点击的位置相差超过这个距离就不算双击。
const double _kDoubleTapRadius = 3.0;

/// 指针按下到抬起之间最多允许移动多少像素还算「点击」。
///
/// 鼠标用 1px（点击时指针几乎不动，超过 1px 就当成在拖），触摸用 6px
/// （手指按下会有点抖）。
const double _kMouseTapSlop = 1.0;
const double _kTouchTapSlop = 6.0;

/// 分割线本体：命中区域、悬停 / 拖动状态、键盘调整与无障碍语义。
///
/// 这里**不**做任何尺寸换算，只把「指针沿主轴的位置」原样抛给外层
/// （[SplitPane]），换算成面板尺寸的事留给外层处理。
class _SplitPaneDivider extends StatefulWidget {
  const _SplitPaneDivider({
    super.key,
    required this.axis,
    required this.style,
    required this.insetStart,
    required this.insetEnd,
    required this.builder,
    required this.resizable,
    required this.ratio,
    required this.index,
    required this.bandKey,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDoubleTap,
    required this.onStep,
    required this.onStepToEdge,
  });

  /// 布局方向（横向时分割线是竖的）。
  final Axis axis;

  final SplitPaneStyle style;

  /// 可见带子距离命中区**前一侧**边缘的内缩量（主轴方向）。
  ///
  /// 由外层算好传进来：至少是 [SplitPaneStyle.dividerHitPadding]，该侧留白更大
  /// 时就等于留白 —— 这样带子正好落在留白里，命中区也覆盖整段留白。
  final double insetStart;

  /// 可见带子距离命中区**后一侧**边缘的内缩量（主轴方向）。
  ///
  /// 两侧分开给，留白不对称时带子就不是居中的：命中区仍然贴着带子两侧。
  final double insetEnd;

  /// 自定义分割线内容；为空时画默认那条带子。
  final SplitPaneDividerBuilder? builder;

  /// 是否可拖动。
  final bool resizable;

  /// 当前位置的比例，只用于无障碍读数。
  final double ratio;

  /// 第几条分割线（0 是最靠前的那条）。
  final int index;

  /// 可见分割带的 key（便于测试与外部定位）。
  final Key? bandKey;

  /// 拖动开始（参数是指针沿主轴的位置）。
  final ValueChanged<double> onDragStart;

  /// 拖动中（参数是当前指针沿主轴的位置）。
  final ValueChanged<double> onDragUpdate;

  /// 拖动结束。
  final VoidCallback onDragEnd;

  /// 双击（为空时不处理）。
  final VoidCallback? onDoubleTap;

  /// 键盘调整一档（参数是逻辑像素增量，可正可负）。
  final ValueChanged<double> onStep;

  /// 键盘调整到边界（true = 最小，false = 最大）。
  final ValueChanged<bool> onStepToEdge;

  @override
  State<_SplitPaneDivider> createState() => _SplitPaneDividerState();
}

class _SplitPaneDividerState extends State<_SplitPaneDivider> {
  bool _hovered = false;
  bool _dragging = false;
  bool _focused = false;

  /// 按下位置 + 这次手势里最大的位移，用来判断是「点一下」还是「拖一下」。
  Offset? _downPosition;
  double _maxMove = 0;

  /// 上一次点击的时间与位置，用来识别双击。
  DateTime? _lastTapAt;
  Offset? _lastTapPosition;

  SplitPaneDividerState get _state {
    if (_dragging) return SplitPaneDividerState.dragging;
    if (_hovered) return SplitPaneDividerState.hover;
    return SplitPaneDividerState.idle;
  }

  void _startDrag(double position) {
    setState(() => _dragging = true);
    widget.onDragStart(position);
  }

  void _updateDrag(double position) => widget.onDragUpdate(position);

  void _endDrag() {
    if (!_dragging) return;
    setState(() => _dragging = false);
    widget.onDragEnd();
  }

  /// 手动识别双击：拖动识别器用了 [DragStartBehavior.down]，会立刻抢走手势，
  /// 标准的 `onDoubleTap` 永远不会触发，所以自己按时间判断。
  void _handlePointerDown(PointerDownEvent event) {
    _downPosition = event.position;
    _maxMove = 0;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final Offset? down = _downPosition;
    if (down == null) return;
    final double moved = (event.position - down).distance;
    if (moved > _maxMove) _maxMove = moved;
  }

  void _handlePointerUp(PointerUpEvent event) {
    final Offset? down = _downPosition;
    _downPosition = null;
    final double slop = event.kind == PointerDeviceKind.touch
        ? _kTouchTapSlop
        : _kMouseTapSlop;

    // 拖过就不是点击：把待定的第一次点击作废。
    //
    // 这一条很关键 —— 否则「连续两次微调」会被当成双击，触发复位，
    // 分割线就自己跳回原位了。
    if (down == null || _maxMove > slop) {
      _lastTapAt = null;
      _lastTapPosition = null;
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime? last = _lastTapAt;
    final Offset? lastPosition = _lastTapPosition;
    if (last != null &&
        lastPosition != null &&
        now.difference(last) < _kDoubleTapWindow &&
        (event.position - lastPosition).distance <= _kDoubleTapRadius) {
      _lastTapAt = null;
      _lastTapPosition = null;
      widget.onDoubleTap?.call();
    } else {
      _lastTapAt = now;
      _lastTapPosition = event.position;
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final double step = widget.style.resizeStep;
    final bool horizontal = widget.axis == Axis.horizontal;
    final LogicalKeyboardKey key = event.logicalKey;

    if (horizontal) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        widget.onStep(-step);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        widget.onStep(step);
        return KeyEventResult.handled;
      }
    } else {
      if (key == LogicalKeyboardKey.arrowUp) {
        widget.onStep(-step);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        widget.onStep(step);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.home) {
      widget.onStepToEdge(true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      widget.onStepToEdge(false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Color _lineColor(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SplitPaneStyle style = widget.style;
    if (_focused) {
      return style.focusColor ?? theme.colorScheme.primary;
    }
    return switch (_state) {
      SplitPaneDividerState.idle => style.idleColor ?? theme.dividerColor,
      SplitPaneDividerState.hover =>
        style.hoverColor ?? theme.colorScheme.primary,
      SplitPaneDividerState.dragging =>
        style.draggingColor ?? theme.colorScheme.primary,
    };
  }

  /// 分割带的内容。
  ///
  /// 这条带子**就是分割线**：它始终用分割线颜色填满，所以两个面板之间是
  /// 紧挨着的、中间没有空隙。
  ///
  /// * 主轴方向：带宽正好 [SplitPaneStyle.dividerThickness]，居中在命中区里；
  /// * 交叉轴方向：默认填满（贯穿父组件），可用
  ///   [SplitPaneStyle.dividerExtent] 指定长度、或
  ///   [SplitPaneStyle.dividerMargin] 两端留白，二者都会让它居中（extent
  ///   还能用 [SplitPaneStyle.dividerCrossAxisAlignment] 改位置）。
  ///
  /// 自定义 [builder] 的内容画在带子**之上**（带子底色保留），这样即使自定义
  /// 内容只画一条细线，面板之间也不会露出空隙。
  ///
  /// 外面还套了一层更宽的**命中区**（宽度 =
  /// `dividerThickness + insetStart + insetEnd`），两侧会盖在面板上或落在
  /// [SplitPaneStyle.dividerSpace] 的留白里 —— 分割线只有几像素宽也照样好抓。
  Widget _buildContent(BuildContext context, Color color) {
    final bool horizontal = widget.axis == Axis.horizontal;
    final SplitPaneStyle style = widget.style;

    // 可见带子先按交叉轴规则定长度，再统一内缩主轴方向的命中区余量。
    Widget band = ColoredBox(key: widget.bandKey, color: color);

    final double? extent = style.dividerExtent;
    final EdgeInsetsGeometry? margin = style.dividerMargin;
    if (extent != null) {
      // 固定长度：按 dividerCrossAxisAlignment 摆放（默认居中）。
      band = Align(
        alignment: style.dividerCrossAxisAlignment,
        child: SizedBox(
          // 交叉轴固定长度；主轴必须撑满，否则 SizedBox 会把宽度 / 高度
          // 交给 loose 约束，ColoredBox 没有 child，会被压成 0。
          width: horizontal ? double.infinity : extent,
          height: horizontal ? extent : double.infinity,
          child: band,
        ),
      );
    } else if (margin != null) {
      // 只取交叉轴方向的两侧留白；主轴方向交给 dividerThickness。
      final EdgeInsets resolved = margin.resolve(
        Directionality.maybeOf(context) ?? TextDirection.ltr,
      );
      band = Padding(
        padding: horizontal
            ? EdgeInsets.only(top: resolved.top, bottom: resolved.bottom)
            : EdgeInsets.only(left: resolved.left, right: resolved.right),
        child: band,
      );
    }

    band = Padding(
      padding: horizontal
          ? EdgeInsets.only(left: widget.insetStart, right: widget.insetEnd)
          : EdgeInsets.only(top: widget.insetStart, bottom: widget.insetEnd),
      child: band,
    );

    final List<Widget> layers = <Widget>[band];
    final SplitPaneDividerBuilder? builder = widget.builder;
    if (builder != null) {
      layers.add(
        Center(
          child: builder(
            context,
            SplitPaneDividerInfo(
              axis: widget.axis,
              state: _state,
              index: widget.index,
              viewIndex: widget.index,
            ),
          ),
        ),
      );
    }
    // passthrough：把命中区的约束原样传给带子。正常布局下这里是 tight 约束，
    // 带子会撑满并按上面的 Align / Padding 收窄；主轴无界的兜底分支里也不会
    // 因为 StackFit.expand 强制无限尺寸而报错。
    return Stack(
      fit: StackFit.passthrough,
      alignment: Alignment.center,
      children: layers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final SplitPaneStyle style = widget.style;
    final bool horizontal = widget.axis == Axis.horizontal;
    final Color color = _lineColor(context);
    final double hit =
        style.dividerThickness + widget.insetStart + widget.insetEnd;

    Widget content = _buildContent(context, color);

    // 命中区：比可见带宽更宽，向两侧各扩展 dividerHitPadding。
    content = SizedBox(
      width: horizontal ? hit : null,
      height: horizontal ? null : hit,
      child: content,
    );

    return MouseRegion(
      cursor: widget.resizable
          ? (horizontal
                ? SystemMouseCursors.resizeColumn
                : SystemMouseCursors.resizeRow)
          : MouseCursor.defer,
      onEnter: (_) {
        if (!_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 用 down：手势一按下就开始认领，分割线才能严格跟手（start 会把起手
        // 那十几像素吃掉，拖完分割线会落在指针后面）。
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: horizontal && widget.resizable
            ? (DragStartDetails d) => _startDrag(d.globalPosition.dx)
            : null,
        onHorizontalDragUpdate: horizontal && widget.resizable
            ? (DragUpdateDetails d) => _updateDrag(d.globalPosition.dx)
            : null,
        onHorizontalDragEnd: horizontal && widget.resizable
            ? (DragEndDetails _) => _endDrag()
            : null,
        onVerticalDragStart: !horizontal && widget.resizable
            ? (DragStartDetails d) => _startDrag(d.globalPosition.dy)
            : null,
        onVerticalDragUpdate: !horizontal && widget.resizable
            ? (DragUpdateDetails d) => _updateDrag(d.globalPosition.dy)
            : null,
        onVerticalDragEnd: !horizontal && widget.resizable
            ? (DragEndDetails _) => _endDrag()
            : null,
        child: Listener(
          // 用 opaque：不管自定义内容能不能命中，原始指针事件都要收到
          // （默认的 deferToChild 在内容是 0 尺寸时就收不到）。
          behavior: HitTestBehavior.opaque,
          // 拖动识别器用 down 会立刻抢走手势，标准 onDoubleTap 不会再触发，
          // 所以点击 / 双击自己按原始指针事件判断。
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          child: Focus(
            onFocusChange: (bool focused) {
              if (_focused != focused) setState(() => _focused = focused);
            },
            onKeyEvent: _onKey,
            child: Semantics(
              container: true,
              label: style.dividerSemanticLabel,
              value: '${(widget.ratio * 100).round()}%',
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

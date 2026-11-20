/// # AnchoredOverlay —— 锚定浮层：一个内核，两个门面
///
/// [Popover] 和 [SmartTooltip] 是**同一个组件**的两种预设，共用同一套定位、
/// 形状、浮层与动画实现；`import 'package:flutter_anchored_overlay/flutter_anchored_overlay.dart'`
/// 一行就能同时用两个。`anchored_overlay` 概括二者：都是锚定在触发
/// 组件上的浮层，Tooltip 只是更轻量的预设。
///
/// | 门面 | 定位 | 典型用法 |
/// |---|---|---|
/// | [Popover] | 可交互气泡 | tap 打开、内容里放表单 / 按钮、外部点击 / Esc 关闭 |
/// | [SmartTooltip] | 轻量提示 | hover 延迟显示、纯文本、鼠标移走自动收起 |
///
/// 两者差异**只在默认值和少量触发参数**（[Popover.waitDuration]、
/// [Popover.showDuration]、[Popover.interactive] 等），底层完全一样：
///
/// | 文件 | 职责 |
/// |---|---|
/// | `flutter_anchored_overlay.dart` | 统一入口：库文档、[Popover] 实现、part 指令 |
/// | `src/overlay_types.dart` | 公开枚举、[PopoverPosition]、[PopoverStyle]、[PopoverController] |
/// | `src/overlay_layout.dart` | **唯一**的定位内核 [_resolveCore]；两个公开纯函数都委托给它 |
/// | `src/overlay_bubble.dart` | [PopoverShapeBorder]（带箭头的圆角形状）、气泡外观、尺寸上报 |
/// | `src/overlay_tooltip.dart` | [SmartTooltip] 门面 + Tooltip 兼容类型 / 纯函数 / 控制器 |
///
/// ## 为什么能合并
///
/// 原先两份实现的定位算法逐行等价（flip → 主轴定位 → 侧轴 shift/clamp →
/// 箭头反算），只是坐标系不同：Tooltip 用 Overlay 绝对坐标，Popover 用相对
/// 触发器的位移。现在内核统一用绝对坐标，Popover 把结果减掉 `triggerOrigin`
/// 即可，[computeTooltipPlacement] 则原样返回。
///
/// ## 定位
///
/// 用 `OverlayPortal` + `CompositedTransformTarget/Follower`，不能直接放
/// `Stack`：父级 `RenderBox.hitTest` 会因为点落在自身尺寸外而拒绝下沉，
/// 气泡里的按钮会点不到。Follower 的两个 anchor 都固定 `Alignment.topLeft`，
/// 最终位置由 [PopoverPosition.offset] 一次算出；页面滚动时 LayerLink 会
/// 自动带着浮层跟随，不需要每帧重测（这比 Tooltip 原来手动监听
/// `ScrollPosition` 再重算稳）。
///
/// 气泡尺寸是内容决定的，没法提前假定，所以布局后由 `_SizeReporter` 把真实
/// 尺寸上报，再据此做视口夹取与箭头对齐。测量完成前不绘制气泡，避免出现在
/// 错位置一帧。
///
/// ## 尺寸要求
///
/// 触发器需要有界尺寸；气泡默认最大 320 × 320，内容更高请自行放滚动组件。
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart' show RenderBox, RenderProxyBox;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

part 'src/overlay_types.dart';
part 'src/overlay_layout.dart';
part 'src/overlay_bubble.dart';
part 'src/overlay_tooltip.dart';

/// 指向 [Popover.child] 的气泡浮层。
///
/// ```dart
/// Popover(
///   placement: PopoverPlacement.bottom,
///   align: PopoverAlign.center,
///   child: const Icon(Icons.info_outline),
///   content: const SizedBox(
///     width: 220,
///     child: Text('这里可以放任意内容，比如说明文字、表单或一组按钮。'),
///   ),
/// )
/// ```
///
/// 需要外部控制时传 [controller]；它是开关的唯一数据源，组件内部点击、
/// 外部点击、Esc 都会写回，读 `controller.isOpen` 始终是最新状态。
class Popover extends StatefulWidget {
  const Popover({
    super.key,
    required this.child,
    this.content,
    this.contentBuilder,
    this.controller,
    this.placement = PopoverPlacement.bottom,
    this.align = PopoverAlign.center,
    this.autoFlip = true,
    this.constrainToViewport = true,
    this.triggerMode = PopoverTriggerMode.tap,
    this.dismissOnOutsideTap = true,
    this.dismissOnEscape = true,
    this.barrierColor,
    this.onOpenChange,
    this.onPositionChanged,
    this.initialOpen = false,
    this.enabled = true,
    this.reduceMotion = false,
    this.style = const PopoverStyle(),
    this.edgePadding = 8.0,
    this.semanticsLabel,
    this.semanticsTooltip,
    this.semanticsButton = true,
    this.excludeFromSemantics = false,
    this.hoverCloseDelay = const Duration(milliseconds: 140),
    this.waitDuration = Duration.zero,
    this.showDuration,
    this.interactive = true,
    this.enableLongPress = false,
    this.hideOnTap = false,
  }) : assert(
         content != null || contentBuilder != null,
         'Popover needs either `content` or `contentBuilder`.',
       );

  /// 触发组件，可以是 Icon、Button、任意组合 Widget。
  ///
  /// tap 模式用指针事件而不是 GestureDetector.onTap，所以即使触发器自带
  /// InkWell（`ElevatedButton` 之类）也不会把手势抢走；按钮自己的
  /// `onPressed` 仍然照常执行。
  final Widget child;

  /// 气泡内容（任意 Widget）。[contentBuilder] 存在时被忽略。
  final Widget? content;

  /// 随构建提供气泡内容；优先于 [content]。
  ///
  /// 注意：这里的 `context` 来自 Overlay（浮层所在树），不是触发器所在的
  /// 局部子树；需要页面局部的 InheritedWidget 时请在闭包里自行捕获。
  final WidgetBuilder? contentBuilder;

  /// 外部控制器；不给时组件内部自己维护一个。
  final PopoverController? controller;

  /// 首选方向；空间不够且 [autoFlip] 打开时自动翻到对称一侧。
  final PopoverPlacement placement;

  /// 交叉轴对齐；[PopoverAlign.start] / [end] 在水平交叉轴上按
  /// [Directionality] 镜像。
  final PopoverAlign align;

  /// 首选方向放不下、且对面空间更大时翻到对面。
  final bool autoFlip;

  /// 把气泡整体夹取到视口内（留 [edgePadding] 边距）。
  final bool constrainToViewport;

  /// 打开方式：点击 / 悬停 / 纯控制器。
  final PopoverTriggerMode triggerMode;

  /// 点气泡和触发器之外的地方是否收起。
  final bool dismissOnOutsideTap;

  /// Esc 是否收起。
  final bool dismissOnEscape;

  /// 非 null 时在气泡下面铺一层半透明遮罩，点它也会收起（模态感）。
  final Color? barrierColor;

  /// 展开 / 收起状态变化时回调。
  final ValueChanged<bool>? onOpenChange;

  /// 每次位置解算结果变化时回调（在 post-frame 里抛，不会打断 build）。
  /// 一般用于「气泡里再放一个跟着箭头走的装饰」这类高级定制。
  final ValueChanged<PopoverPosition>? onPositionChanged;

  /// 初始是否展开；传了 [controller] 时以控制器的初始状态为准。
  final bool initialOpen;

  /// 禁用：触发器不响应，已在展示的气泡会收起。
  final bool enabled;

  /// 强制走减弱动效（只淡入淡出，无缩放 / 位移）。也会自动跟随
  /// `MediaQuery.disableAnimations`。
  final bool reduceMotion;

  /// 外观配置。
  final PopoverStyle style;

  /// 气泡贴到视口边缘时保留的最小留白。
  final double edgePadding;

  /// 触发器的无障碍标签；为 null 时不覆盖子组件自带语义。
  final String? semanticsLabel;

  /// 触发器的无障碍 tooltip 文案（[SmartTooltip] 用它把提示内容交给读屏）。
  final String? semanticsTooltip;

  /// 是否把触发器标记为语义按钮；[SmartTooltip] 是纯提示，会关掉它。
  final bool semanticsButton;

  /// 不为触发器额外添加语义节点；子组件自带语义仍然保留。
  final bool excludeFromSemantics;

  /// hover 模式下，鼠标离开触发器 / 气泡后延迟多久收起。移进气泡会取消计时。
  final Duration hoverCloseDelay;

  /// hover 模式下，鼠标进入触发器后**延迟多久才打开**（Tooltip 的悬停延迟）。
  /// 默认 [Duration.zero]，即进入即开，保持 [Popover] 原本的手感。
  final Duration waitDuration;

  /// 打开后自动收起的时长；null 表示一直开到被手动关闭。
  final Duration? showDuration;

  /// 气泡是否接收指针事件。
  ///
  /// `true`（[Popover] 默认）：气泡里的按钮 / 输入框可点，鼠标移进气泡不会
  /// 触发关闭计时。`false`（[SmartTooltip] 默认）：气泡对鼠标透明，鼠标一
  /// 离开触发器就开始收起计时 —— 这正是轻量 Tooltip 的行为。
  final bool interactive;

  /// 是否支持长按触发器打开（移动端没有 hover 时的替代方式）。
  final bool enableLongPress;

  /// 点击触发器时是否立刻收起气泡（桌面端常见：点完不想被气泡挡着）。
  /// 用指针事件实现，不会和触发器自带的 InkWell 抢手势。
  final bool hideOnTap;

  @override
  State<Popover> createState() => _PopoverState();
}

class _PopoverState extends State<Popover>
    with SingleTickerProviderStateMixin {
  final GlobalKey _triggerKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();
  final FocusNode _triggerFocus = FocusNode(debugLabel: 'Popover.trigger');
  /// null 表示「这一轮还没量到尺寸」，此时先不画，避免出现在错位置。
  final ValueNotifier<Size?> _popupSize = ValueNotifier<Size?>(null);

  /// 触发器与气泡共用 groupId：点气泡里的按钮不会被 `onTapOutside`
  /// 当成「点在外面」提前关掉。
  final Object _tapGroup = Object();

  /// 没传 controller 时用它；总是创建，这样运行中换 controller 也不用重建。
  late final PopoverController _internalController = PopoverController(
    open: widget.initialOpen,
  );

  PopoverController? _attached;
  Timer? _hoverTimer;
  Timer? _waitTimer;
  Timer? _autoHideTimer;
  PopoverPosition? _lastPosition;

  /// 主键按下的位置，用来把「点一下」和「按下拖走」区分开。
  Offset? _pressPosition;

  /// 本次按下已经由长按打开了气泡，抬手时不要再让 `hideOnTap` 关掉它。
  bool _skipHideOnTap = false;

  late AnimationController _anim;
  late CurvedAnimation _progress;
  bool _reduce = false;
  Size _screenSize = Size.zero;
  TextDirection _direction = TextDirection.ltr;

  PopoverController get _controller => widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: widget.style.duration,
      reverseDuration: Duration(
        milliseconds: widget.style.duration.inMilliseconds * 3 ~/ 4,
      ),
      value: _controller.isOpen ? 1.0 : 0.0,
    );
    _progress = CurvedAnimation(
      parent: _anim,
      curve: widget.style.curve,
      reverseCurve: FlippedCurve(widget.style.curve),
    );
    _anim.addStatusListener((AnimationStatus status) {
      // 收起动画播完才摘掉浮层，中途气泡仍然可见（正在收回）。
      if (status == AnimationStatus.dismissed) _portal.hide();
    });
    _attached = _controller;
    _attached!.addListener(_onControllerChanged);
    if (_controller.isOpen) {
      _portal.show();
      _scheduleAutoHide();
      if (widget.dismissOnEscape) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _triggerFocus.requestFocus();
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce =
        widget.reduceMotion ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    _screenSize = MediaQuery.maybeSizeOf(context) ?? Size.zero;
    // 在 State 的 context 里读方向：OverlayPortal 的浮层挂在 Overlay 上，
    // 它的 context 不在页面里嵌套的 Directionality 之下。
    _direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    _syncMotion();
  }

  @override
  void didUpdateWidget(Popover oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
    if (_attached != _controller) {
      _attached?.removeListener(_onControllerChanged);
      _attached = _controller;
      _attached!.addListener(_onControllerChanged);
      // 新控制器可能带着完全不同的开关状态，等这一帧过了再同步，
      // 避免在 build / didUpdateWidget 里动 OverlayPortal。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyOpenState(_controller.isOpen);
      });
    }
    if (!widget.enabled && _controller.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.hide();
      });
    }
    if (oldWidget.showDuration != widget.showDuration && _controller.isOpen) {
      _scheduleAutoHide();
    }
  }

  void _syncMotion() {
    final Duration open = _reduce
        ? kPopoverReduceDuration
        : widget.style.duration;
    _anim.duration = open;
    _anim.reverseDuration = _reduce
        ? open
        : Duration(milliseconds: widget.style.duration.inMilliseconds * 3 ~/ 4);
    _progress.curve = widget.style.curve;
    _progress.reverseCurve = FlippedCurve(widget.style.curve);
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _waitTimer?.cancel();
    _autoHideTimer?.cancel();
    _attached?.removeListener(_onControllerChanged);
    _progress.dispose();
    _anim.dispose();
    _triggerFocus.dispose();
    _popupSize.dispose();
    super.dispose();
  }

  // ── 开关 ────────────────────────────────────────────────────────────────

  void _onControllerChanged() {
    _applyOpenState(_controller.isOpen);
    widget.onOpenChange?.call(_controller.isOpen);
  }

  void _applyOpenState(bool open) {
    _cancelHoverTimer();
    _cancelWaitTimer();
    if (open) {
      // 内容可能换了，重新量一次；量完之前不画，量完才淡入。
      _popupSize.value = null;
      _portal.show();
      _anim.forward();
      _scheduleAutoHide();
      // 只有需要 Esc 关闭时才抢焦点：Tooltip 靠 hover 打开，如果每次悬停都
      // requestFocus，会把用户正在输入的 TextField 打断。
      if (widget.dismissOnEscape) _triggerFocus.requestFocus();
    } else {
      _cancelAutoHideTimer();
      _anim.reverse();
    }
  }

  void _cancelHoverTimer() {
    if (_hoverTimer == null) return;
    _hoverTimer!.cancel();
    _hoverTimer = null;
  }

  void _cancelWaitTimer() {
    if (_waitTimer == null) return;
    _waitTimer!.cancel();
    _waitTimer = null;
  }

  void _cancelAutoHideTimer() {
    if (_autoHideTimer == null) return;
    _autoHideTimer!.cancel();
    _autoHideTimer = null;
  }

  /// 打开后计时自动收起（[Popover.showDuration]）。
  void _scheduleAutoHide() {
    _cancelAutoHideTimer();
    final Duration? duration = widget.showDuration;
    if (duration == null || !_controller.isOpen) return;
    _autoHideTimer = Timer(duration, () {
      _autoHideTimer = null;
      if (mounted) _controller.hide();
    });
  }

  void _scheduleHoverClose() {
    _cancelHoverTimer();
    _hoverTimer = Timer(widget.hoverCloseDelay, () {
      _hoverTimer = null;
      if (mounted) _controller.hide();
    });
  }

  /// hover / 长按共用的打开入口；[Popover.waitDuration] 为 0 时立即打开。
  void _openAfterDelay() {
    _cancelHoverTimer();
    if (_controller.isOpen) return;
    if (widget.waitDuration <= Duration.zero) {
      _cancelWaitTimer();
      _controller.show();
      return;
    }
    _cancelWaitTimer();
    _waitTimer = Timer(widget.waitDuration, () {
      _waitTimer = null;
      if (mounted) _controller.show();
    });
  }

  void _onHoverExit() {
    _cancelWaitTimer();
    if (_controller.isOpen) _scheduleHoverClose();
  }

  void _onPopupSize(Size size) {
    if (!mounted || size == _popupSize.value) return;
    // 即使内容真的是 0×0，也记一次「已测量」，否则会永远停在不可见状态。
    _popupSize.value = size;
  }

  void _notifyPosition(PopoverPosition position) {
    if (widget.onPositionChanged == null || position == _lastPosition) return;
    _lastPosition = position;
    final ValueChanged<PopoverPosition> callback = widget.onPositionChanged!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback(position);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (widget.dismissOnEscape &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _controller.isOpen) {
      _controller.hide();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── 解算 ────────────────────────────────────────────────────────────────

  PopoverPosition _resolvePosition(Size popupSize) {
    final RenderBox? box =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final bool hasBox = box != null && box.hasSize;
    final Size triggerSize = hasBox ? box.size : Size.zero;
    final Offset triggerOrigin = hasBox
        ? box.localToGlobal(Offset.zero)
        : Offset.zero;
    final PopoverPosition position = resolvePopoverPosition(
      placement: widget.placement,
      align: widget.align,
      autoFlip: widget.autoFlip,
      showArrow: widget.style.showArrow,
      triggerSize: triggerSize,
      popupSize: popupSize,
      triggerOrigin: triggerOrigin,
      viewport: _screenSize,
      gap: widget.style.gap,
      arrowWidth: widget.style.arrowWidth,
      arrowHeight: widget.style.arrowHeight,
      radius: widget.style.radius,
      edgePadding: widget.edgePadding,
      direction: _direction,
      constrainToViewport: widget.constrainToViewport,
    );
    _notifyPosition(position);
    return position;
  }

  double _maxWidth() {
    final double viewportWidth = _screenSize.width > 0
        ? math.max(0.0, _screenSize.width - widget.edgePadding * 2)
        : widget.style.maxWidth;
    return math.max(0.0, math.min(widget.style.maxWidth, viewportWidth));
  }

  _Frame _frame(PopoverArrowSide arrowSide) {
    final double u = _anim.value;
    final double p = (_reduce ? u : _progress.value).clamp(0.0, 1.0);
    return _popoverFrame(
      u: u,
      p: p,
      reduce: _reduce,
      arrowSide: arrowSide,
      scaleBegin: widget.style.scaleBegin,
      slideDistance: widget.style.slideDistance,
    );
  }

  // ── 构建 ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _tapGroup,
      onTapOutside: (PointerDownEvent _) {
        if (widget.dismissOnOutsideTap && _controller.isOpen) {
          _controller.hide();
        }
      },
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildOverlay,
        child: Focus(
          focusNode: _triggerFocus,
          onKeyEvent: _onKey,
          child: _buildSemantics(
            _buildInteraction(
              CompositedTransformTarget(
                key: _triggerKey,
                link: _layerLink,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSemantics(Widget trigger) {
    if (widget.excludeFromSemantics) return trigger;
    return Semantics(
      button: widget.enabled && widget.semanticsButton,
      enabled: widget.enabled,
      label: widget.semanticsLabel,
      tooltip: widget.semanticsTooltip,
      child: trigger,
    );
  }

  Widget _buildInteraction(Widget trigger) {
    Widget result;
    switch (widget.triggerMode) {
      case PopoverTriggerMode.manual:
        result = trigger;
      case PopoverTriggerMode.tap:
        // 不能用 GestureDetector.onTap：触发器自身若带 InkWell（ElevatedButton
        // 之类），它的 TapGestureRecognizer 会在手势竞技场里赢走这次点击，
        // 气泡就打不开了。Listener 不参与竞技场，按下 / 抬起都会照常收到，
        // 同时按钮自己的 onPressed 也仍然生效。
        result = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (PointerDownEvent event) {
            // 1 == kPrimaryButton；右键 / 中键不当作打开手势。
            _pressPosition = event.buttons == 1 ? event.position : null;
          },
          onPointerUp: (PointerUpEvent event) {
            final Offset? start = _pressPosition;
            _pressPosition = null;
            if (!widget.enabled || start == null) return;
            if ((event.position - start).distance > kPopoverPressSlop) return;
            _controller.toggle();
          },
          onPointerCancel: (PointerCancelEvent _) => _pressPosition = null,
          child: trigger,
        );
      case PopoverTriggerMode.hover:
        // opaque 保证触发器是纯 Container 时也能收到 enter / exit；
        // 焦点由 _applyOpenState 统一处理，这里不需要额外的手势层。
        result = MouseRegion(
          hitTestBehavior: HitTestBehavior.opaque,
          onEnter: widget.enabled
              ? (PointerEnterEvent _) => _openAfterDelay()
              : null,
          onExit: widget.enabled
              ? (PointerExitEvent _) => _onHoverExit()
              : null,
          child: trigger,
        );
    }

    // 点击立刻收起 / 长按打开都是「附加」手势，用 Listener 而不是
    // GestureDetector.onTap，避免和触发器自带的 InkWell 抢竞技场。
    if (widget.hideOnTap || widget.enableLongPress) {
      result = Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: (PointerDownEvent _) => _skipHideOnTap = false,
        onPointerUp: widget.hideOnTap
            ? (PointerUpEvent _) {
                // 长按打开的那次抬手不算「点击」，否则气泡刚出现就被关掉。
                if (_skipHideOnTap) {
                  _skipHideOnTap = false;
                  return;
                }
                if (widget.enabled && _controller.isOpen) {
                  _cancelWaitTimer();
                  _controller.hide();
                }
              }
            : null,
        child: result,
      );
    }
    if (widget.enableLongPress) {
      result = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: widget.enabled
            ? () {
                _skipHideOnTap = true;
                _cancelHoverTimer();
                // 长按没有「悬停等待」的概念，直接打开。
                _cancelWaitTimer();
                _controller.show();
              }
            : null,
        child: result,
      );
    }
    return result;
  }

  /// 气泡的指针层。[Popover.interactive] 为 false 时整块气泡对鼠标完全透明，
  /// 连 `MouseRegion` 都不挂 —— 否则它会占住命中区，挡住气泡下面的内容。
  Widget _buildBubbleInteraction(Widget bubble) {
    if (!widget.interactive) {
      return IgnorePointer(ignoring: true, child: bubble);
    }
    return MouseRegion(
      onEnter: (PointerEnterEvent _) {
        if (_controller.isOpen) {
          _cancelHoverTimer();
          // 鼠标已经进气泡了，就别再按 showDuration 自动收起（和原 Tooltip
          // 的 interactive 行为一致：进了气泡就把 hideTimer 取消）。
          _cancelAutoHideTimer();
        }
      },
      onExit: (PointerExitEvent _) {
        if (widget.triggerMode == PopoverTriggerMode.hover &&
            _controller.isOpen) {
          _scheduleHoverClose();
        }
      },
      child: IgnorePointer(ignoring: !_controller.isOpen, child: bubble),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return ValueListenableBuilder<Size?>(
      valueListenable: _popupSize,
      builder: (BuildContext context, Size? measuredSize, Widget? _) {
        final Size popupSize = measuredSize ?? Size.zero;
        return AnimatedBuilder(
          animation: _anim,
          builder: (BuildContext context, Widget? _) {
            final PopoverPosition position = _resolvePosition(popupSize);
            final _Frame frame = _frame(position.arrowSide);
            // 未测量时不画：initialOpen 的动画已经跑完（opacity 1），
            // 若不遮住，第一帧会在触发器左上角亮一下再跳到正确位置。
            final _Frame visibleFrame = measuredSize == null
                ? _Frame(
                    opacity: 0,
                    scale: frame.scale,
                    slide: frame.slide,
                    alignment: frame.alignment,
                  )
                : frame;
            final double maxWidth = _maxWidth();
            return Positioned.fill(
              child: Stack(
                children: <Widget>[
                  if (widget.barrierColor != null && _controller.isOpen)
                    Positioned.fill(
                      key: kPopoverBarrierKey,
                      child: GestureDetector(
                        onTap: () => _controller.hide(),
                        child: ColoredBox(color: widget.barrierColor!),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: CompositedTransformFollower(
                      link: _layerLink,
                      showWhenUnlinked: false,
                      targetAnchor: Alignment.topLeft,
                      followerAnchor: Alignment.topLeft,
                      offset: position.offset,
                      child: TapRegion(
                        groupId: _tapGroup,
                        child: Focus(
                          // 焦点落在气泡里的 TextField 时，Esc 仍能冒泡到这里。
                          onKeyEvent: _onKey,
                          child: _buildBubbleInteraction(
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: math.min(
                                  widget.style.minWidth,
                                  maxWidth,
                                ),
                                maxWidth: maxWidth,
                                maxHeight: widget.style.maxHeight,
                              ),
                              child: _PopoverBubble(
                                frame: visibleFrame,
                                style: widget.style,
                                position: position,
                                onSize: _onPopupSize,
                                child: widget.contentBuilder?.call(context) ??
                                    widget.content!,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

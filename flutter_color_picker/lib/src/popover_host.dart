import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// 卡片相对触发组件出现在哪一侧。
///
/// 这是**首选**方向：这一侧放不下、对面更宽敞时会自动翻过去。
enum ColorPickerPlacement {
  /// 触发器上方。
  top,

  /// 触发器下方（默认）。
  bottom,

  /// 触发器左侧。
  left,

  /// 触发器右侧。
  right,
}

/// 卡片在**交叉轴**上如何对齐触发组件。
///
/// 主轴是上下时交叉轴是水平方向，反之亦然。
enum ColorPickerAlign {
  /// 贴触发器的起始边（左 / 上）。
  start,

  /// 居中。
  center,

  /// 贴触发器的结束边（右 / 下）。
  end,
}

/// 卡片距视口边缘的最小距离：卡片不贴着窗口边。
const double kPopoverViewportMargin = 8;

/// 按首选方向算卡片落点（**Overlay 局部坐标**）。
///
/// 输入都是布局算完之后的值：卡片尺寸、触发器的矩形、视口尺寸。逻辑与
/// [PopoverHost] 内部完全一致——放不下就翻到对面，最后夹进视口，卡片比视口
/// 还大时贴住左上角。
///
/// 抽成纯函数是为了让「命令式弹出」（`showColorPicker`，没有触发器 widget）
/// 和 [PopoverHost]（有触发器 widget）共用同一套定位，行为不会分叉。
Offset resolvePopoverOffset({
  required Size card,
  required Rect anchor,
  required Size viewport,
  required ColorPickerPlacement placement,
  required ColorPickerAlign align,
  double gap = 6,
}) {
  const double margin = kPopoverViewportMargin;

  ColorPickerPlacement resolved = placement;
  if (placement == ColorPickerPlacement.bottom &&
      anchor.bottom + gap + card.height > viewport.height - margin &&
      anchor.top - gap - card.height >= margin) {
    resolved = ColorPickerPlacement.top;
  } else if (placement == ColorPickerPlacement.top &&
      anchor.top - gap - card.height < margin &&
      anchor.bottom + gap + card.height <= viewport.height - margin) {
    resolved = ColorPickerPlacement.bottom;
  } else if (placement == ColorPickerPlacement.right &&
      anchor.right + gap + card.width > viewport.width - margin &&
      anchor.left - gap - card.width >= margin) {
    resolved = ColorPickerPlacement.left;
  } else if (placement == ColorPickerPlacement.left &&
      anchor.left - gap - card.width < margin &&
      anchor.right + gap + card.width <= viewport.width - margin) {
    resolved = ColorPickerPlacement.right;
  }

  final bool vertical =
      resolved == ColorPickerPlacement.top ||
      resolved == ColorPickerPlacement.bottom;
  double left;
  double top;
  if (vertical) {
    top = resolved == ColorPickerPlacement.bottom
        ? anchor.bottom + gap
        : anchor.top - gap - card.height;
    left = switch (align) {
      ColorPickerAlign.start => anchor.left,
      ColorPickerAlign.center => anchor.center.dx - card.width / 2,
      ColorPickerAlign.end => anchor.right - card.width,
    };
  } else {
    left = resolved == ColorPickerPlacement.right
        ? anchor.right + gap
        : anchor.left - gap - card.width;
    top = switch (align) {
      ColorPickerAlign.start => anchor.top,
      ColorPickerAlign.center => anchor.center.dy - card.height / 2,
      ColorPickerAlign.end => anchor.bottom - card.height,
    };
  }

  // 卡片比视口还大时，两个上限都会小于下限，用 max 兜住。
  final double maxLeft = math.max(margin, viewport.width - card.width - margin);
  final double maxTop = math.max(
    margin,
    viewport.height - card.height - margin,
  );
  return Offset(left.clamp(margin, maxLeft), top.clamp(margin, maxTop));
}

/// 浮层卡片外壳：圆角 + 阴影 + 主题底色 + 固定内边距。
///
/// [PopoverHost] 与命令式弹层（`showColorPicker`）共用它，保证两条链路里的
/// 卡片长得一模一样。
Widget buildPopoverCard({
  Key? key,
  required BuildContext context,
  required Widget child,
  double? width,
  EdgeInsets padding = const EdgeInsets.all(12),
  double radius = 16,
  Color? backgroundColor,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return Material(
    key: key,
    color: backgroundColor ?? scheme.surface,
    elevation: 8,
    borderRadius: BorderRadius.circular(radius),
    clipBehavior: Clip.antiAlias,
    // 不让 M3 的 surfaceTint 给卡片染上一层主题色，颜色面板要保持中性。
    surfaceTintColor: Colors.transparent,
    child: Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width ?? double.infinity,
          minWidth: width ?? 0,
        ),
        child: child,
      ),
    ),
  );
}

/// 锚定在触发组件旁的浮层内核，[ColorPickerButton] 的弹层就是它。
///
/// 只做四件事，全部用 Flutter 自带能力实现（`OverlayEntry` + `RenderBox`
/// 坐标换算），不依赖任何第三方包：
///
/// * 把 [child] 原样画出来（它只是触发器的容器，不改触发器外观）；
/// * [open] 时在它旁边插一块卡片，卡片内容由 [contentBuilder] 每次重建；
/// * 点空白处 / 按 Esc 收起（[close]），触发器自己负责调 [toggle]；
/// * 超出视口时翻转方向、夹取位置，卡片始终完整可见。
///
/// 想用它做别的弹层也可以：把卡片的圆角、内边距、底色换成自己的即可。
class PopoverHost extends StatefulWidget {
  const PopoverHost({
    super.key,
    required this.child,
    required this.contentBuilder,
    this.placement = ColorPickerPlacement.bottom,
    this.align = ColorPickerAlign.start,
    this.width,
    this.padding = const EdgeInsets.all(12),
    this.radius = 16,
    this.gap = 6,
    this.backgroundColor,
    this.enabled = true,
    this.onOpenChanged,
  });

  /// 触发组件。`PopoverHost` 不改它的外观，点它弹出由调用方接线
  /// （一般是 `GestureDetector(onTap: () => key.currentState?.toggle())`）。
  final Widget child;

  /// 卡片内容；卡片每次重建都会重新调用，所以内容可以跟着外部状态走。
  final WidgetBuilder contentBuilder;

  /// 首选方向。
  final ColorPickerPlacement placement;

  /// 交叉轴对齐方式。
  final ColorPickerAlign align;

  /// 卡片内容宽度。给了就固定宽度（内容被这个宽度约束），不给由内容决定。
  final double? width;

  /// 卡片内边距。
  final EdgeInsets padding;

  /// 卡片圆角。
  final double radius;

  /// 卡片与触发器之间的间距。
  final double gap;

  /// 卡片底色；不传用主题的 `colorScheme.surface`。
  final Color? backgroundColor;

  /// 为 false 时 [open] / [toggle] 不生效。
  final bool enabled;

  /// 展开 / 收起时回调，方便触发器画自己的按下态。
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<PopoverHost> createState() => PopoverHostState();
}

/// [PopoverHost] 的状态，外部通过 `GlobalKey<PopoverHostState>` 调用
/// [open] / [close] / [toggle]。
class PopoverHostState extends State<PopoverHost>
    with SingleTickerProviderStateMixin {
  // ── 卡片固定的内边距外的默认外边距见 [kPopoverViewportMargin] ──────────

  /// 卡片本体，用来测量尺寸（首帧量高度才能算落点）。
  final GlobalKey _cardKey = GlobalKey(debugLabel: 'popover.card');

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );

  OverlayEntry? _entry;
  bool _visible = false;
  bool _measureScheduled = false;
  bool _contentDirty = false;

  /// 测量完成后的落点（Overlay 局部坐标）；null = 还在测量帧。
  Offset? _position;

  /// 关闭动画的序号：关闭途中又打开时用它作废上一次的移除。
  int _closeToken = 0;

  /// 是否正在显示（关闭动画期间已经是 false）。
  bool get isOpen => _visible;

  @override
  void didUpdateWidget(covariant PopoverHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    // contentBuilder 通常闭包捕获了外部状态（比如当前颜色），内容要跟着重画。
    // 这里还在 build 阶段，只能等这一帧结束再标记 overlay 重建。
    if (!_visible || _contentDirty) return;
    _contentDirty = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentDirty = false;
      if (mounted && _visible) _entry?.markNeedsBuild();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _entry?.remove();
    _entry = null;
    _fade.dispose();
    super.dispose();
  }

  // ── 开关 ────────────────────────────────────────────────────────────────

  /// 打开；已经打开或 [PopoverHost.enabled] 为 false 时什么也不做。
  void open() {
    if (_visible || !widget.enabled || !mounted) return;
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _closeToken++; // 作废进行中的关闭动画
    _position = null;
    _measureScheduled = false;
    _visible = true;
    _entry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_entry!);
    HardwareKeyboard.instance.addHandler(_handleKey);
    // 淡入等量到尺寸后再起（见 _measureAndPosition）：测量帧卡片是透明的。
    _fade.value = 0;
    widget.onOpenChanged?.call(true);
  }

  /// 收起；没打开时什么也不做。
  void close() {
    if (!_visible) return;
    _visible = false;
    final int token = ++_closeToken;
    HardwareKeyboard.instance.removeHandler(_handleKey);
    widget.onOpenChanged?.call(false);
    _fade.reverse().whenComplete(() {
      if (token == _closeToken && !_visible) _removeEntry();
    });
  }

  /// 打开 / 收起。
  void toggle() => _visible ? close() : open();

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
    _position = null;
  }

  /// Esc 收起。用全局键盘钩子而不是 `Focus`：焦点可能在面板里的输入框，
  /// 也可能已经被点走了，钩子都能收到。
  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      close();
      return true;
    }
    return false;
  }

  // ── 布局 ────────────────────────────────────────────────────────────────

  /// 触发器当前在整个屏幕里的矩形（全局坐标）。
  Rect? _anchorRect() {
    final RenderObject? render = context.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize) {
      return null;
    }
    final Offset globalTopLeft = render.localToGlobal(Offset.zero);
    final RenderObject? overlayRender = Overlay.maybeOf(
      context,
      rootOverlay: true,
    )?.context.findRenderObject();
    final Offset topLeft = overlayRender is RenderBox
        ? overlayRender.globalToLocal(globalTopLeft)
        : globalTopLeft;
    return topLeft & render.size;
  }

  /// 量出卡片尺寸后算落点。
  void _measureAndPosition() {
    if (!mounted || !_visible) return;
    final RenderObject? render = _cardKey.currentContext?.findRenderObject();
    final RenderBox? card = render is RenderBox && render.hasSize
        ? render
        : null;
    final Rect? anchor = _anchorRect();
    if (card == null || anchor == null) {
      // 极少数情况下这一帧还没布置（刚 insert 就量）：让 build 重新注册一次。
      _measureScheduled = false;
      _entry?.markNeedsBuild();
      return;
    }
    final RenderObject? overlayRender = Overlay.maybeOf(
      context,
      rootOverlay: true,
    )?.context.findRenderObject();
    final Size viewport = overlayRender is RenderBox && overlayRender.hasSize
        ? overlayRender.size
        : MediaQuery.sizeOf(context);
    setState(
      () => _position = resolvePopoverOffset(
        card: card.size,
        anchor: anchor,
        viewport: viewport,
        placement: widget.placement,
        align: widget.align,
        gap: widget.gap,
      ),
    );
    _entry?.markNeedsBuild();
    if (_visible) _fade.forward(from: 0);
  }

  // ── 构建 ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => widget.child;

  Widget _buildOverlay(BuildContext overlayContext) {
    final Widget card = buildPopoverCard(
      key: _cardKey,
      context: overlayContext,
      width: widget.width,
      padding: widget.padding,
      radius: widget.radius,
      backgroundColor: widget.backgroundColor,
      child: widget.contentBuilder(overlayContext),
    );

    // 测量帧：先按左上角摆一次（透明且不接受点击）。注意这里**不切换
    // widget 结构**——换包裹组件会让卡片整棵子树卸载重挂，GlobalKey 重挂时
    // 带着 inherited 依赖的子树会直接断言失败；只挪位置就没事。
    if (_position == null && !_measureScheduled) {
      _measureScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _measureScheduled = false;
        _measureAndPosition();
      });
    }

    final Offset position = _position ?? Offset.zero;
    return Stack(
      children: <Widget>[
        _buildBarrier(),
        Positioned(
          left: position.dx,
          top: position.dy,
          child: IgnorePointer(
            ignoring: _position == null,
            child: FadeTransition(opacity: _fade, child: card),
          ),
        ),
      ],
    );
  }

  /// 全屏透明命中层：点卡片外面收起。
  Widget _buildBarrier() {
    return Positioned.fill(
      child: GestureDetector(
        key: const ValueKey<String>('popover-barrier'),
        behavior: HitTestBehavior.opaque,
        onTap: close,
        child: const SizedBox.expand(),
      ),
    );
  }
}

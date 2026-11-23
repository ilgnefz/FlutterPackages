import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'color_picker.dart';
import 'hex.dart';
import 'popover_host.dart';

/// [showColorPicker] 返回的句柄：可以主动收起，也可以查它还在不在。
class ColorPickerPopup {
  ColorPickerPopup._(this._key, this._remove);

  /// 没能打开（没有 Overlay）时返回的句柄：永远「已关闭」。
  ColorPickerPopup._dismissed() : _key = null, _remove = _noop, _closed = true;

  static void _noop() {}

  final GlobalKey<_PopupHostState>? _key;

  /// 直接把 OverlayEntry 摘掉（淡出还没开始 / 面板还没 build 时用）。
  final VoidCallback _remove;

  bool _closed = false;

  /// 面板是否还开着（关闭动画期间已经是 false）。
  bool get isOpen => !_closed;

  /// 收起面板；已经关了什么也不做。
  void close() {
    if (_closed) return;
    final _PopupHostState? state = _key?.currentState;
    _closed = true;
    // 刚 insert、还没 build 就要求关闭：没有 state 可等淡出，直接摘 entry。
    if (state == null) {
      _remove();
      return;
    }
    state.close();
  }

  void _markClosed() => _closed = true;
}

/// 当前打开着的那个弹层：同时只留一个，开新的会先把旧的收掉。
ColorPickerPopup? _active;

/// 命令式弹出颜色面板：**不要求触发器是 [ColorPickerButton]**，自己的按钮、
/// 菜单项、表格单元格……任何地方都能调。
///
/// [context] 只用来定位（取它的矩形当锚点）和找 `Overlay`，所以传**触发按钮
/// 自己的 context**（`Builder` 里那个，或 `State` 的 `context`），不要传页面
/// 根 context —— 那会拿整页的矩形去算落点。
///
/// ```dart
/// IconButton(
///   icon: const Icon(Icons.palette_outlined),
///   // 光标、样式全是你自己的，本包不插手
///   onPressed: () => showColorPicker(
///     context,
///     color: Color(_argb),
///     onChanged: (int argb) => setState(() => _argb = argb),
///   ),
/// );
/// ```
///
/// 想手动定位（比如在鼠标位置弹出）就传 [anchorRect]（**全局坐标**）。
///
/// [onChanged] / [onChangeEnd] 的参数都是 `0xAARRGGBB` 的整数
/// （`0xFF2B7FFF` 这种，等价 `color.toARGB32()`），跟 [color] 传进来的
/// [Color] 不是一回事：进来用 [Color]，出去给 int。
///
/// 返回的 [ColorPickerPopup] 句柄可以 `close()`；点空白处 / Esc 也会收起。
///
/// ## 返回值可以直接丢掉
///
/// **不需要**接住返回值才能关：点面板外面、按 Esc 都会关，用户自己就能收起。
/// 只有想在代码里主动关时才接：
///
/// ```dart
/// final ColorPickerPopup popup = showColorPicker(context, ...);
/// popup.close();   // 比如「确定」按钮、切页面、另一个按钮也要收起它
/// popup.isOpen;    // 还开着吗
/// ```
///
/// 所以最常见的一行写法就够了：`onPressed: () => showColorPicker(context, ...)`。
ColorPickerPopup showColorPicker(
  BuildContext context, {
  Color color = const Color(0xFF2B7FFF),
  ValueChanged<int>? onChanged,
  ValueChanged<int>? onChangeEnd,
  Rect? anchorRect,
  ColorPickerPlacement placement = ColorPickerPlacement.bottom,
  ColorPickerAlign align = ColorPickerAlign.start,
  double panelWidth = 260,
  EdgeInsets panelPadding = const EdgeInsets.all(12),
  double panelRadius = 16,
  double gap = 6,
  Color? panelColor,
  bool showHexField = true,
  bool showOpacity = false,
  ColorHexFormat hexFormat = ColorHexFormat.hashRgb,
}) {
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  assert(overlay != null, 'showColorPicker 需要一个 Overlay 祖先（MaterialApp 自带）');
  if (overlay == null) return ColorPickerPopup._dismissed();

  final Rect anchor = _resolveAnchorRect(context, overlay, anchorRect);
  _active?.close();

  final GlobalKey<_PopupHostState> key = GlobalKey<_PopupHostState>(
    debugLabel: 'showColorPicker',
  );
  late final ColorPickerPopup handle;
  late final OverlayEntry entry;
  bool removed = false;

  void remove() {
    if (removed) return;
    removed = true;
    handle._markClosed();
    entry.remove();
    if (identical(_active, handle)) _active = null;
  }

  entry = OverlayEntry(
    builder: (BuildContext overlayContext) => _PopupHost(
      key: key,
      anchor: anchor,
      gap: gap,
      placement: placement,
      align: align,
      color: color,
      panelWidth: panelWidth,
      panelPadding: panelPadding,
      panelRadius: panelRadius,
      panelColor: panelColor,
      showHexField: showHexField,
      showOpacity: showOpacity,
      hexFormat: hexFormat,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
      onClosed: remove,
    ),
  );
  handle = ColorPickerPopup._(key, remove);
  _active = handle;
  overlay.insert(entry);
  return handle;
}

/// 锚点矩形换算到 **Overlay 局部坐标**（浮层都按这套坐标摆）。
Rect _resolveAnchorRect(
  BuildContext context,
  OverlayState overlay,
  Rect? globalRect,
) {
  final RenderObject? overlayRender = overlay.context.findRenderObject();
  Offset toOverlay(Offset global) =>
      overlayRender is RenderBox ? overlayRender.globalToLocal(global) : global;

  if (globalRect != null) {
    return toOverlay(globalRect.topLeft) & globalRect.size;
  }

  final RenderObject? render = context.findRenderObject();
  if (render is RenderBox && render.attached && render.hasSize) {
    return toOverlay(render.localToGlobal(Offset.zero)) & render.size;
  }

  // 拿不到触发器尺寸（比如 context 是刚插入的）：退化成视口中心的一个点。
  final Size viewport = overlayRender is RenderBox && overlayRender.hasSize
      ? overlayRender.size
      : MediaQuery.sizeOf(context);
  return Rect.fromLTWH(viewport.width / 2, viewport.height / 2, 0, 0);
}

/// 命令式弹层的实际内容：卡片 + 淡入 + 测量定位 + 点空白 / Esc 关闭。
class _PopupHost extends StatefulWidget {
  const _PopupHost({
    super.key,
    required this.anchor,
    required this.gap,
    required this.placement,
    required this.align,
    required this.color,
    required this.panelWidth,
    required this.panelPadding,
    required this.panelRadius,
    required this.showHexField,
    required this.showOpacity,
    required this.hexFormat,
    required this.onClosed,
    this.panelColor,
    this.onChanged,
    this.onChangeEnd,
  });

  /// 触发器矩形（Overlay 局部坐标）。
  final Rect anchor;
  final double gap;
  final ColorPickerPlacement placement;
  final ColorPickerAlign align;
  final Color color;
  final double panelWidth;
  final EdgeInsets panelPadding;
  final double panelRadius;
  final Color? panelColor;
  final bool showHexField;
  final bool showOpacity;
  final ColorHexFormat hexFormat;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onChangeEnd;

  /// 关闭动画播完：由调用方把 `OverlayEntry` 摘掉。
  final VoidCallback onClosed;

  @override
  State<_PopupHost> createState() => _PopupHostState();
}

class _PopupHostState extends State<_PopupHost>
    with SingleTickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey(debugLabel: 'color-picker.popup.card');

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );

  /// 量到卡片尺寸后的落点；null = 还在测量帧。
  Offset? _position;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
    // 首帧卡片是透明且不吃点击的，量完尺寸才定位、淡入。
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _fade.dispose();
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      close();
      return true;
    }
    return false;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _fade.reverse().whenComplete(() {
      if (mounted) widget.onClosed();
    });
  }

  void _measure() {
    if (!mounted || _closed) return;
    final RenderObject? render = _cardKey.currentContext?.findRenderObject();
    final RenderBox? card = render is RenderBox && render.hasSize
        ? render
        : null;
    if (card == null) {
      // 这一帧还没布置（刚 insert 就量）：下一帧再来。
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
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
        anchor: widget.anchor,
        viewport: viewport,
        placement: widget.placement,
        align: widget.align,
        gap: widget.gap,
      ),
    );
    _fade.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final Widget card = buildPopoverCard(
      key: _cardKey,
      context: context,
      width: widget.panelWidth,
      padding: widget.panelPadding,
      radius: widget.panelRadius,
      backgroundColor: widget.panelColor,
      child: ColorPicker(
        initialColor: widget.color,
        width: widget.panelWidth,
        showHexField: widget.showHexField,
        showOpacity: widget.showOpacity,
        hexFormat: widget.hexFormat,
        onChanged: widget.onChanged,
        onChangeEnd: widget.onChangeEnd,
      ),
    );

    final Offset position = _position ?? Offset.zero;
    // 结构固定（测量帧也只挪位置、不换包裹组件）：卡片子树不会卸载重挂。
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey<String>('color-picker-popup-barrier'),
            behavior: HitTestBehavior.opaque,
            onTap: close,
            child: const SizedBox.expand(),
          ),
        ),
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
}

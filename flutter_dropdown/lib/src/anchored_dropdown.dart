/// 通用下拉组件：**任意 Widget 都能当触发器**，下拉列表支持水平对齐、
/// 独立宽度与三种揭示动画。
///
/// 以 `flutter_dropdown.dart` 为公开入口（它同时导出 [TextDropdown]），实现
/// 按职责拆在同目录下的 part 文件：
///
/// | 文件 | 职责 |
/// |---|---|
/// | `dropdown_types.dart` | 公开类型：[DropdownAlignment] / [DropdownWidth] / [DropdownReveal] / [DropdownStyle] / [AnchoredDropdownItem] |
/// | `dropdown_reveal_clipper.dart` | [DropdownRevealClipper]：三种揭示动画的裁切路径 |
/// | `dropdown_panel.dart` | 浮层外观（圆角 / 阴影 / 淡入 / 裁切） |
/// | `dropdown_field.dart` | 可选便捷件：[AnchoredDropdownField] / [AnchoredDropdownArrow] |
///
/// 动画沿用 beUI `components/motion/select` 的「一个进度 p 驱动所有部件」：
/// 列表始终完整尺寸、不缩放内容，四角全程恒定圆角；阴影画在裁切层之外
/// 随 p 渐强，最后一帧不会有硬切。
///
/// 浮层用 `OverlayPortal` + `CompositedTransformTarget/Follower`。直接把面板
/// 放进 `Stack` 虽然能画到边界外，但父级 `RenderBox.hitTest` 会因为点落在
/// 自身尺寸之外而拒绝下沉，选项会点不到。
library;

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

part 'dropdown_types.dart';
part 'dropdown_reveal_clipper.dart';
part 'dropdown_panel.dart';
part 'dropdown_field.dart';

/// 任意触发组件 + 可定制列表的下拉框。
///
/// ```dart
/// AnchoredDropdown<String>(
///   trigger: const Icon(Icons.more_vert),          // Icon / Image / 任意 Widget
///   alignment: DropdownAlignment.center,           // 左 / 中 / 右对齐
///   width: const DropdownWidth.fixed(240),         // 或 .matchTrigger()
///   reveal: DropdownReveal.topLeftToBottomRight,   // 三种揭示动画
///   items: const [AnchoredDropdownItem('a', label: 'Apple')],
///   onChanged: (v) => setState(() => selected = v),
/// )
/// ```
class AnchoredDropdown<T extends Object> extends StatefulWidget {
  const AnchoredDropdown({
    super.key,
    this.trigger,
    this.triggerBuilder,
    this.items = const [],
    this.itemBuilder,
    this.menuBuilder,
    this.value,
    this.onChanged,
    this.onOpenChange,
    this.alignment = DropdownAlignment.left,
    this.width = const DropdownWidth.matchTrigger(),
    this.reveal = DropdownReveal.unfold,
    this.style,
    this.maxMenuHeight = 240.0,
    this.edgePadding = 8.0,
    this.semanticsLabel,
    this.initialOpen = false,
    this.disabled = false,
    this.reduceMotion = false,
    this.duration = kDropdownOpenDuration,
  }) : assert(
         trigger != null || triggerBuilder != null,
         'AnchoredDropdown needs either `trigger` or `triggerBuilder`.',
       );

  /// 触发组件，可以是 Icon、Image、自定义组合等任何 Widget。
  ///
  /// [triggerBuilder] 存在时本字段被忽略。
  final Widget? trigger;

  /// 随展开状态构建触发组件；拿到 `(context, isOpen, progress)`，
  /// `progress` 可直接喂给 [AnchoredDropdownArrow]。优先于 [trigger]。
  final Widget Function(BuildContext context, bool isOpen, double progress)?
  triggerBuilder;

  /// 内置选项列表；[menuBuilder] 存在时不参与渲染。
  final List<AnchoredDropdownItem<T>> items;

  /// 自定义单行内容。返回的行内容会替换默认渲染，点击与禁用逻辑仍由组件管。
  ///
  /// 注意：这里的 `context` 来自 Overlay（浮层所在树），不是触发器所在的
  /// 局部子树；需要页面局部的 InheritedWidget 时请在闭包里自行捕获。
  final Widget Function(
    BuildContext context,
    AnchoredDropdownItem<T> item,
    bool selected,
    bool enabled,
  )?
  itemBuilder;

  /// 完全自定义下拉列表内容（任意 Widget）。存在时忽略 [items] /
  /// [itemBuilder]，超出 [maxMenuHeight] 的滚动由调用方自己处理。
  /// `context` 的说明同 [itemBuilder]。
  final Widget Function(BuildContext context)? menuBuilder;

  /// 当前选中值。
  final T? value;

  /// 选中某项时回调，随后面板自动收起。
  final ValueChanged<T>? onChanged;

  /// 打开 / 关闭状态变化时回调。
  final ValueChanged<bool>? onOpenChange;

  /// 列表相对触发组件的水平对齐。
  final DropdownAlignment alignment;

  /// 列表宽度策略：与触发器同宽（默认）或固定宽度。
  final DropdownWidth width;

  /// 揭示动画。
  final DropdownReveal reveal;

  /// 外观配置。为 null（默认）时取 [DropdownStyle.of]，按当前
  /// [ThemeData.brightness] 自动在浅色 / 深色两套配色之间切换，
  /// 与 [TextDropdown] 的行为一致；只改几项用 `copyWith`。
  final DropdownStyle? style;

  /// 列表内容最大高度（内置选项超出后内部滚动）。
  final double maxMenuHeight;

  /// 列表贴到屏幕左右边缘时保留的最小留白；也用于水平夹取。
  final double edgePadding;

  /// 触发组件的无障碍标签；为 null 时不覆盖子组件自带的语义。
  final String? semanticsLabel;

  /// 初始是否展开。
  final bool initialOpen;

  /// 禁用整个控件。
  final bool disabled;

  /// 强制走减弱动效（只淡入淡出，无位移 / 裁切 / 形变）。
  final bool reduceMotion;

  /// 展开时长；收起自动取 3/4。减弱动效时统一 120ms。
  final Duration duration;

  @override
  State<AnchoredDropdown<T>> createState() => _AnchoredDropdownState<T>();
}

class _AnchoredDropdownState<T extends Object> extends State<AnchoredDropdown<T>>
    with SingleTickerProviderStateMixin {
  final GlobalKey _triggerKey = GlobalKey();
  final FocusNode _triggerFocus = FocusNode(
    debugLabel: 'AnchoredDropdown.trigger',
  );
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();

  /// 触发器与浮层共用 groupId：点列表里的选项不会被 `onTapOutside`
  /// 当成「点在外面」提前关掉。
  final Object _tapGroup = Object();

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    reverseDuration: Duration(
      milliseconds: widget.duration.inMilliseconds * 3 ~/ 4,
    ),
    value: widget.initialOpen ? 1.0 : 0.0,
  );

  /// 展开用无过冲缓出；收起是它的时间镜像。[CurvedAnimation] 的
  /// reverseCurve 直接作用在递减的 parent.value 上，所以用 [FlippedCurve]
  /// 翻转才是时间轴上想要的形状。
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _controller,
    curve: _kRevealCurve,
    reverseCurve: const FlippedCurve(_kRevealCurve),
  );

  late bool _open = widget.initialOpen;
  bool _placedAbove = false;
  bool _reduce = false;
  Size _screenSize = Size.zero;
  Size _triggerSize = Size.zero;
  TextDirection? _direction;

  /// 实际生效的外观：显式传的 style，或按当前明暗主题取的默认值。
  /// 与 [TextDropdown] 一样存成字段，浮层 builder 也读同一份配置。
  late DropdownStyle _style;

  @override
  void initState() {
    super.initState();
    if (widget.initialOpen) _portal.show();
    _controller.addStatusListener((AnimationStatus status) {
      // 收起动画播完才摘掉浮层，中途面板仍然可见（正在折回）。
      if (status == AnimationStatus.dismissed) _portal.hide();
    });
    _scheduleMeasure();
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
    _direction = Directionality.maybeOf(context);
    _style = widget.style ?? DropdownStyle.of(context);
    _syncDuration();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(AnchoredDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDuration();
    _scheduleMeasure();
  }

  void _syncDuration() {
    _controller.duration = _reduce ? kDropdownReduceDuration : widget.duration;
    _controller.reverseDuration = _reduce
        ? kDropdownReduceDuration
        : Duration(milliseconds: widget.duration.inMilliseconds * 3 ~/ 4);
  }

  /// 触发器是任意 Widget，宽度不能靠外部 SizedBox 假定；布局结束后量一次，
  /// 供 `DropdownWidth.matchTrigger` 与边缘夹取使用。
  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RenderBox? box = _currentTriggerBox();
      if (box != null && box.hasSize && box.size != _triggerSize) {
        setState(() => _triggerSize = box.size);
      }
    });
  }

  RenderBox? _currentTriggerBox() =>
      _triggerKey.currentContext?.findRenderObject() as RenderBox?;

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    _triggerFocus.dispose();
    super.dispose();
  }

  void _setOpen(bool next) {
    if (next == _open) return;
    if (next) {
      final RenderBox? box = _currentTriggerBox();
      if (box != null && box.hasSize) _triggerSize = box.size;
      _placedAbove = _resolvePlacement();
      _portal.show();
    }
    setState(() => _open = next);
    if (next) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onOpenChange?.call(next);
  }

  /// 下方剩余空间不够就翻到上方（对应源码 `below < h + 16 && above > below`）。
  bool _resolvePlacement() {
    final RenderBox? box = _currentTriggerBox();
    if (box == null || !box.hasSize || _screenSize.height <= 0) return false;
    final double top = box.localToGlobal(Offset.zero).dy;
    final double below = _screenSize.height - (top + box.size.height);
    final DropdownStyle s = _style;
    final double estimated = widget.menuBuilder != null
        ? widget.maxMenuHeight
        : math.min(
            widget.items.length * s.itemHeight + s.padding * 2 + 2,
            widget.maxMenuHeight,
          );
    return below < estimated + 16 && top > below;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _open) {
      _setOpen(false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  _Frame _frame() {
    // u 是线性时间，p 是缓动后的主线进度。淡入用 u，让显示与隐藏的
    // 首尾都不被曲线压缩；其余派生量用 p，跟着揭示节奏走。
    final double u = _controller.value;
    final double raw = _reduce ? u : _progress.value;
    final double p = raw.clamp(0.0, 1.0);
    final bool above = _placedAbove;
    final double gap = _style.gap;
    final double opacity = _kEaseOut.transform(_remap(u, 0.0, 0.22));
    final double rows = _reduce
        ? 1.0
        : _kEaseOut.transform(_remap(p, 0.10, 0.85));

    return _Frame(
      p: p,
      offsetY: _reduce
          ? 0.0
          : _lerp(
              above ? gap : -gap,
              0.0,
              _kSoftCurve.transform(_remap(p, 0.08, 0.95)),
            ),
      opacity: opacity,
      shadow: _reduce ? opacity : _kEaseOut.transform(_remap(p, 0.6, 1.0)),
      rowsOpacity: rows,
      rowsOffsetY: _reduce ? 0.0 : -4.0 * (1.0 - rows),
      placedAbove: above,
      reduce: _reduce,
    );
  }

  /// 列表最终宽度。优先读当前帧之前的真实触发组件尺寸，量不到再用缓存。
  double _menuWidth() {
    if (!widget.width.matchesTrigger) return widget.width.resolve(0);
    final RenderBox? box = _currentTriggerBox();
    final double measured = box != null && box.hasSize
        ? box.size.width
        : _triggerSize.width;
    return widget.width.resolve(measured);
  }

  /// 对齐后如果列表会越过屏幕左右边缘，就沿 x 平移回来。
  /// [CompositedTransformFollower.offset] 的 dx 是相对「自然对齐位置」的位移。
  double _horizontalShift(double menuWidth, double x) {
    final RenderBox? box = _currentTriggerBox();
    if (box == null || !box.hasSize || _screenSize.width <= 0) return 0.0;
    final double factor = (x + 1.0) / 2.0;
    final double triggerLeft = box.localToGlobal(Offset.zero).dx;
    final double natural = triggerLeft + factor * (box.size.width - menuWidth);
    final double maxLeft = math.max(
      widget.edgePadding,
      _screenSize.width - menuWidth - widget.edgePadding,
    );
    final double clamped = natural
        .clamp(widget.edgePadding, maxLeft)
        .toDouble();
    return clamped - natural;
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _tapGroup,
      onTapOutside: (PointerDownEvent _) {
        if (_open) _setOpen(false);
      },
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildOverlay,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) {
            final _Frame f = _frame();
            return CompositedTransformTarget(
              key: _triggerKey,
              link: _layerLink,
              child: _buildTrigger(context, f),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTrigger(BuildContext context, _Frame f) {
    final Widget trigger =
        widget.triggerBuilder?.call(context, _open, f.p) ?? widget.trigger!;
    return Focus(
      focusNode: _triggerFocus,
      onKeyEvent: _onKey,
      child: Semantics(
        button: true,
        enabled: !widget.disabled,
        label: widget.semanticsLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.disabled
              ? null
              : () {
                  _triggerFocus.requestFocus();
                  _setOpen(!_open);
                },
          child: trigger,
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final _Frame f = _frame();
        final double x = _alignmentX(widget.alignment, _direction);
        final double menuWidth = _menuWidth();
        final double gap = _style.gap;
        return Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment(x, f.placedAbove ? -1.0 : 1.0),
            followerAnchor: Alignment(x, f.placedAbove ? 1.0 : -1.0),
            offset: Offset(
              _horizontalShift(menuWidth, x),
              (f.placedAbove ? -gap : gap) + f.offsetY,
            ),
            child: TapRegion(
              groupId: _tapGroup,
              child: SizedBox(
                key: kDropdownMenuBoxKey,
                width: menuWidth,
                child: IgnorePointer(
                  ignoring: !_open,
                  child: _DropdownPanel(
                    frame: f,
                    style: _style,
                    reveal: widget.reveal,
                    menu: _buildMenu(context),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenu(BuildContext context) {
    final Widget? custom = widget.menuBuilder?.call(context);
    final Widget body = custom ?? _buildItems(context);
    return Padding(
      padding: EdgeInsets.all(_style.padding),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.max(
            0.0,
            widget.maxMenuHeight - _style.padding * 2,
          ),
        ),
        child: custom == null ? SingleChildScrollView(child: body) : body,
      ),
    );
  }

  Widget _buildItems(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final AnchoredDropdownItem<T> item in widget.items)
          _buildItem(context, item),
      ],
    );
  }

  Widget _buildItem(BuildContext context, AnchoredDropdownItem<T> item) {
    final bool selected = item.value == widget.value;
    final bool enabled = item.enabled && !widget.disabled;
    final Widget? custom = widget.itemBuilder?.call(
      context,
      item,
      selected,
      enabled,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: enabled
            ? () {
                widget.onChanged?.call(item.value);
                _setOpen(false);
              }
            : null,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(_style.itemRadius),
          ),
        ),
        child: Container(
          height: _style.itemHeight,
          padding: _style.itemPadding,
          decoration: BoxDecoration(
            color: selected ? _style.selectedColor : null,
            borderRadius: BorderRadius.all(
              Radius.circular(_style.itemRadius),
            ),
          ),
          child:
              custom ?? _defaultItemContent(context, item, selected, enabled),
        ),
      ),
    );
  }

  Widget _defaultItemContent(
    BuildContext context,
    AnchoredDropdownItem<T> item,
    bool selected,
    bool enabled,
  ) {
    final DropdownStyle s = _style;
    final bool customChild = item.child != null;
    final Widget content =
        item.child ??
        Text(
          item.label ?? item.value.toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: enabled ? s.foreground : s.disabledColor,
          ),
        );

    // 自定义 child（Icon / Image / Row…）不能被 Expanded 施加 tight 宽度，
    // 否则会被拉伸变形；但也不能用 Flexible 的 loose 布局 —— 那样未用完的
    // 空间会留在 Row 末尾，选中勾就紧跟在图标后面、贴不到最右边。
    // 用 Expanded 占满剩余宽度，内部再用 Align 还原 loose 约束并靠起始侧。
    final TextDirection direction =
        Directionality.maybeOf(context) ?? TextDirection.ltr;
    final Widget leading = customChild
        ? Expanded(
            child: Align(
              alignment: direction == TextDirection.rtl
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: content,
            ),
          )
        : Expanded(child: content);

    return Row(
      children: <Widget>[
        leading,
        if (selected && s.showCheck)
          Icon(s.checkIcon, size: s.checkSize, color: s.foreground),
      ],
    );
  }
}

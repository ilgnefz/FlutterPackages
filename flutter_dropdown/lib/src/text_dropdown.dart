import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

// DropdownStyle 定义在 anchored_dropdown.dart 的 part 里，两个门面共用同一套外观配置。
import 'anchored_dropdown.dart';

/// beUI `components/motion/select` 里 `#…-trigger` 与 `#…-list` 组合的
/// Flutter 复刻，重点是列表展开 / 折回的显隐动画。
///
/// 与常见的 `ScaleTransition` / `SizeTransition` 不同，这里**只有一个
/// progress 值 p（0 关闭 → 1 打开）**驱动全部部件，列表始终保持完整尺寸：
///
/// * **不缩放内容**：用 clip 从贴着触发器的一条 8px 薄边开始，逐帧缩小 inset
///   把列表「揭开」，所以行高、边框、文字粗细都不变；
/// * **四角恒定**：触发器与下拉框的四个圆角从头到尾都是 12，任何一帧都
///   不会出现直角，也不会有「圆角跟着裁切前沿跑」的假象；
/// * **一个进度多个读者**：裁切、位移、淡入、行内容、箭头、阴影都读同一个 p，
///   但各自用不同的缓动区间，避免所有变化挤在同一瞬间；
/// * **无跳变收尾**：展开 / 收起都用单调、收尾平缓的曲线（不再有过冲被
///   clamp 后「提前到位再空转」的停顿）；阴影画在裁切层之外，颜色透明度
///   随 p 渐强，最后一帧不会突然冒出一整圈阴影；
/// * **静止时移除裁切**，让边框圆角完全由面板本体绘制。
///
/// 面板用 `OverlayPortal` + `CompositedTransformFollower` 浮在触发器旁边：
/// 既不影响周围布局（对应源码里 absolutely positioned 的 field），也保证
/// 超出触发器范围的部分依然能接收点击 —— 直接放在 `Stack` 里虽然能画出去，
/// 但父级 `RenderBox.hitTest` 会因为点落在自身尺寸之外而拒绝下沉。
///
/// 参考实现（React / motion）见 https://beui.dev/components/motion/select 。
///
/// [T] 是选项值的类型（不限 String，enum / int / 自定义对象都行），显示文字
/// 由 [TextDropdownItem.label] 决定，`onChanged` 回传的是 [T] 本身：
///
/// ```dart
/// TextDropdown<LanguageType>(
///   value: current,
///   items: LanguageType.values
///       .map((e) => TextDropdownItem(e, label: e.label))
///       .toList(),
///   onChanged: (v) => setState(() => current = v),
/// )
/// ```
///
/// 外观分两类，各管一块、**不传就自动跟随明暗主题**：
///
/// * [DropdownFieldStyle] 管外面的触发器 —— 宽 / 高 / 圆角 / 边框 /
///   内边距（文字 / 箭头到边框的距离）/ 文字样式。
/// * [DropdownItemStyle] 管下拉面板 + 选项行 —— 圆角 / 间距 / 行高 /
///   行间距 / 阴影 / 全部颜色 / 选项文字样式。
///
/// ```dart
/// TextDropdown<String>(
///   items: items,
///   fieldStyle: DropdownFieldStyle.of(context).copyWith(
///     height: 32,
///     radius: 8,
///   ),
///   itemStyle: DropdownItemStyle.of(context).copyWith(
///     itemGap: 2,
///     borderColor: Colors.black12,
///   ),
/// )
/// ```
///
/// 想改「文字 / 箭头到边框的距离」用 `fieldStyle.padding`；想改「下拉栏里
/// 文字到选项行外框的距离」用 `itemStyle.itemPadding`，两者是不同层。
class TextDropdown<T extends Object> extends StatefulWidget {
  const TextDropdown({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.onOpenChange,
    this.hint = 'Select',
    this.fieldStyle,
    this.itemStyle,
    this.mouseCursor,
    this.initialOpen = false,
    this.disabled = false,
    this.reduceMotion = false,
    this.duration = _kOpenDuration,
  });

  /// 可选项。
  final List<TextDropdownItem<T>> items;

  /// 当前选中值；为 null 时显示 [hint]。用 `==` 和
  /// [TextDropdownItem.value] 比较，所以自定义类型记得实现相等性。
  final T? value;

  /// 选中某项时回调，回传该项的 [TextDropdownItem.value]，随后面板自动收起。
  final ValueChanged<T>? onChanged;

  /// 打开 / 关闭状态变化时回调。
  final ValueChanged<bool>? onOpenChange;

  /// 未选中时的占位文案。
  final String hint;

  /// 触发器（显示在外面的字段）外观：宽 / 高 / 圆角 / 边框 / 内边距 / 文字样式。
  ///
  /// 为 null（默认）时取 [DropdownFieldStyle.of]，自动跟随明暗主题；
  /// 只改几项用 `.copyWith(...)`。
  final DropdownFieldStyle? fieldStyle;

  /// 下拉面板 + 选项行的外观：圆角 / 间距 / 行高 / 阴影 / 全部颜色。
  ///
  /// 为 null（默认）时取 [DropdownItemStyle.of]，自动跟随明暗主题；
  /// 只改几项用 `.copyWith(...)`。选项文字样式也在这里配，单项可用
  /// [TextDropdownItem.textStyle] 再 `merge` 覆盖。
  final DropdownItemStyle? itemStyle;

  /// 鼠标停在触发器 / 选项上时的光标；为 null（默认）时统一用手型
  /// `SystemMouseCursors.click`。禁用整个控件或单个选项时恒为普通箭头。
  /// 传 `MouseCursor.defer` 可交回父级决定。
  final MouseCursor? mouseCursor;

  /// 初始是否展开。
  final bool initialOpen;

  /// 禁用整个控件。
  final bool disabled;

  /// 强制走减弱动效（只有淡入淡出，无位移 / 裁切 / 形变）。
  final bool reduceMotion;

  /// 展开时长；收起自动取它的 3/4。开启「减少动态效果」时统一降为 120ms。
  final Duration duration;

  @override
  State<TextDropdown<T>> createState() => _TextDropdownState<T>();
}

/// 一个选项；`label` 为空时退化成 [value] 的 `toString()`。
///
/// [T] 是选中时回传给 [TextDropdown.onChanged] 的值类型，显示文字与它解耦：
/// 用 enum / 对象当值时传 `label` 指定要显示的文案即可。
@immutable
class TextDropdownItem<T extends Object> {
  const TextDropdownItem(
    this.value, {
    this.label,
    this.enabled = true,
    this.textStyle,
  });

  /// 选中时回传的值，也是判断选中态的依据。
  final T value;

  /// 显示文字（列表行与触发器共用）。
  final String? label;

  /// 是否可点。
  final bool enabled;

  /// 这一项的文字样式，覆盖 [DropdownItemStyle.textStyle]（选项）与
  /// [DropdownFieldStyle.textStyle]（触发器显示选中值时）。
  ///
  /// 用 `merge` 叠加：只写 color 时，字号、字重等仍沿用组件级样式。
  final TextStyle? textStyle;

  /// 显示串：优先 [label]，否则用 [value] 的字符串形式。
  /// `T = String` 时就是原值，和泛型化之前的行为一致。
  String get text => label ?? value.toString();
}

// ── 与 beUI 源码一致的常量 ────────────────────────────────────────────────

// 几何与颜色的默认值统一交给两个 Style 类（默认构造即原来的浅色值），
// 这里只保留「没有对应 style 字段」的常量：公开 UnfoldClipper 的默认参数，
// 以及触发器高度 / 动画时长。
const double _kRadius = 12.0; // RADIUS：四个角全程固定
const double _kLip = 8.0; // LIP：起始时露出的薄边厚度
const Duration _kOpenDuration = Duration(milliseconds: 260);
const Duration _kReduceDuration = Duration(milliseconds: 120);

/// 展开：`cubic-bezier(0.25, 0.46, 0.45, 0.94)`。全程稳定推进、收尾柔和且
/// 无过冲；比强缓出曲线更均匀，不会「前 80ms 就展开完、剩下时间空转」。
const Cubic _kRevealCurve = Cubic(0.25, 0.46, 0.45, 0.94);

/// 分离位移用的对称缓动：`cubic-bezier(0.4, 0, 0.2, 1)`，两头都不突兀。
const Cubic _kSoftCurve = Cubic(0.4, 0.0, 0.2, 1.0);

/// 派生量（淡入、行内容、阴影）的短缓出。
const Cubic _kEaseOut = Cubic(0.16, 1.0, 0.3, 1.0);

const ValueKey<String> _clipKey = ValueKey<String>('text_dropdown_unfold_clip');
const ValueKey<String> _bodyKey = ValueKey<String>('text_dropdown_panel_body');
const ValueKey<String> _shadowKey = ValueKey<String>(
  'text_dropdown_panel_shadow',
);

/// 把面板裁成「贴着触发器的一条薄边 → 完整圆角面板」。
///
/// 对应源码的 `clipPath: inset(…)`。放在 `ClipPath` 上时
/// [CustomClipper.getClip] 收到的 size 就是面板的完整尺寸，因此不需要
/// 额外测高；面板本身不参与布局缩放，行高始终自然。
///
/// 这里不直接给裁切后的可见矩形倒圆角：可见矩形在动画早期只有 8px 高，
/// `RRect.fromRectAndCorners` 会把放不下的半径整体等比缩小，圆角就会
/// 从约 4px 一路「长」到 12px。改用完整面板外框与可见矩形求交，四角始终
/// 是 12，只是暂时被水平裁切线挡住，前沿保持直线。
///
/// [nearRadius] 保留给需要「贴合侧单独设圆角」的自定义场景；内置的
/// [TextDropdown] 把 [radius] 与 [nearRadius] 都传 [TextDropdown.radius]，
/// 保证任何一帧都有圆角。
class UnfoldClipper extends CustomClipper<Path> {
  const UnfoldClipper({
    required this.progress,
    required this.nearRadius,
    required this.placedAbove,
    this.radius = _kRadius,
    this.lip = _kLip,
  });

  /// 已 clamp 的展开进度 0 → 1。
  final double progress;

  /// 贴合侧（朝向触发器那一侧）圆角；内置下拉框里恒等于 [radius]。
  final double nearRadius;

  /// 面板是否翻到触发器上方。
  final bool placedAbove;

  /// 远端圆角。
  final double radius;

  /// p = 0 时保留的薄边厚度。
  final double lip;

  Path _outline(Size size) {
    final Radius near = Radius.circular(nearRadius);
    final Radius far = Radius.circular(radius);
    return Path()..addRRect(
      RRect.fromRectAndCorners(
        Offset.zero & size,
        topLeft: placedAbove ? far : near,
        topRight: placedAbove ? far : near,
        bottomLeft: placedAbove ? near : far,
        bottomRight: placedAbove ? near : far,
      ),
    );
  }

  @override
  Path getClip(Size size) {
    final double p = progress.clamp(0.0, 1.0);
    final Path outline = _outline(size);
    if (p >= 1.0) return outline;
    // CSS: hidden = (height - LIP) * (1 - p)
    //  下方展开 → inset(0 0 hidden 0)：从上往下揭开
    //  上方展开 → inset(hidden 0 0 0)：从下往上揭开
    final double hidden = math.max(0.0, (size.height - lip) * (1.0 - p));
    final Rect visible = placedAbove
        ? Rect.fromLTWH(0, hidden, size.width, size.height - hidden)
        : Rect.fromLTWH(0, 0, size.width, size.height - hidden);
    return Path.combine(
      PathOperation.intersect,
      outline,
      Path()..addRect(visible),
    );
  }

  @override
  bool shouldReclip(UnfoldClipper oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.nearRadius != nearRadius ||
      oldClipper.placedAbove != placedAbove ||
      oldClipper.radius != radius ||
      oldClipper.lip != lip;
}

enum _Placement { bottom, top }

/// 一帧里由同一个 p 推导出的全部参数。
@immutable
class _Frame {
  const _Frame({
    required this.p,
    required this.offsetY,
    required this.opacity,
    required this.shadow,
    required this.rowsOpacity,
    required this.rowsOffsetY,
    required this.angle,
    required this.placedAbove,
  });

  final double p;
  final double offsetY;
  final double opacity;
  final double shadow;
  final double rowsOpacity;
  final double rowsOffsetY;
  final double angle;
  final bool placedAbove;
}

class _TextDropdownState<T extends Object> extends State<TextDropdown<T>>
    with TickerProviderStateMixin {
  final GlobalKey _fieldKey = GlobalKey();
  final FocusNode _triggerFocus = FocusNode(debugLabel: 'TextDropdown.trigger');
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();

  /// 列表的滚动控制器。显式持有有两个用处：
  /// 1. 列表外面那条 [Scrollbar] 必须接到同一个 controller 才画得出来
  ///    （`SingleChildScrollView` 不传 controller 时只会去用
  ///    `PrimaryScrollController`，桌面平台之外未必有）；
  /// 2. 滚动条的行为不再依赖平台 / `ScrollBehavior` 的默认注入。
  final ScrollController _listScroll = ScrollController(
    debugLabel: 'TextDropdown.list',
  );

  /// 触发器与浮层两块区域共用一个 groupId：点列表里的选项不会被
  /// `TapRegion.onTapOutside` 当成「点在外面」提前关掉。
  final Object _tapGroup = Object();

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    reverseDuration: Duration(
      milliseconds: widget.duration.inMilliseconds * 3 ~/ 4,
    ),
    value: widget.initialOpen ? 1.0 : 0.0,
  );

  /// 主线进度。展开用无过冲的缓出；收起是它的时间镜像。
  /// [CurvedAnimation] 的 reverseCurve 直接作用在递减的 parent.value 上，
  /// 所以要用 `FlippedCurve` 翻转，才是时间轴上 1 - c(u) 的形状。
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _controller,
    curve: _kRevealCurve,
    reverseCurve: const FlippedCurve(_kRevealCurve),
  );

  late bool _open = widget.initialOpen;
  _Placement _placement = _Placement.bottom;
  bool _reduce = false;
  double _screenHeight = double.infinity;

  /// 实际生效的两套外观：显式传的 style，或按当前明暗主题取的默认值。
  /// 用字段而不是在 build 里临时解析，是为了让 Overlay 的浮层 builder
  /// 也读到同一份配置（浮层的 context 不一定跟着主树 rebuild）。
  late DropdownFieldStyle _fieldStyle;
  late DropdownItemStyle _itemStyle;

  @override
  void initState() {
    super.initState();
    if (widget.initialOpen) _portal.show();
    _controller.addStatusListener((AnimationStatus status) {
      // 收起动画播完才摘掉浮层，中途面板仍然可见（正在折回）。
      if (status == AnimationStatus.dismissed) _portal.hide();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce =
        widget.reduceMotion ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    _screenHeight = MediaQuery.maybeSizeOf(context)?.height ?? double.infinity;
    _resolveStyle();
    _syncDuration();
  }

  @override
  void didUpdateWidget(TextDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveStyle();
    _syncDuration();
  }

  void _resolveStyle() {
    _fieldStyle = widget.fieldStyle ?? DropdownFieldStyle.of(context);
    _itemStyle = widget.itemStyle ?? DropdownItemStyle.of(context);
  }

  /// 当前选中项（用 `==` 匹配 [TextDropdown.value]），没有时返回 null。
  /// 触发器同时用它的文字和样式，保证与列表里那一行完全一致。
  TextDropdownItem<T>? get _selectedItem {
    final T? value = widget.value;
    if (value == null) return null;
    for (final TextDropdownItem<T> item in widget.items) {
      if (item.value == value) return item;
    }
    return null;
  }

  /// 触发器（和 Semantics）上显示的文字。
  ///
  /// 泛型化后 [TextDropdown.value] 不再是 String，不能直接塞给 `Text`；
  /// 优先取选中项配的 [TextDropdownItem.label]，列表里找不到时退回
  /// `value.toString()`（T = String 时即原值，行为与旧版一致）。
  String get _displayText {
    final TextDropdownItem<T>? item = _selectedItem;
    if (item != null) return item.text;
    final T? value = widget.value;
    return value == null ? widget.hint : value.toString();
  }

  /// 组件级样式（触发器 [DropdownFieldStyle.textStyle] 或选项
  /// [DropdownItemStyle.textStyle]）打底，单项 [TextDropdownItem.textStyle]
  /// 用 merge 覆盖（没写明的字段沿用组件级）。
  TextStyle? _styleFor(TextDropdownItem<T>? item, TextStyle? base) {
    final TextStyle? own = item?.textStyle;
    if (base == null) return own;
    if (own == null) return base;
    return base.merge(own);
  }

  /// 补默认字号与状态色；样式里显式给了 color 就尊重它。
  TextStyle _textStyle(TextStyle? style, Color fallback) =>
      (style ?? const TextStyle(fontSize: 14)).copyWith(
        color: style?.color ?? fallback,
      );

  // clamp 后的外观派生量：radius / itemGap 允许外部随便传，负值在这里收住。
  double get _radius => math.max(0.0, _itemStyle.radius);

  double get _itemGap => math.max(0.0, _itemStyle.itemGap);

  /// 选项行圆角不超过外框，也不超过 style.itemRadius。
  double get _itemRadius => math.min(_radius, _itemStyle.itemRadius);

  /// 可点区域的光标（禁用判断在使用处单独做）。
  MouseCursor get _cursor => widget.mouseCursor ?? SystemMouseCursors.click;

  void _syncDuration() {
    _controller.duration = _reduce ? _kReduceDuration : widget.duration;
    _controller.reverseDuration = _reduce
        ? _kReduceDuration
        : Duration(milliseconds: widget.duration.inMilliseconds * 3 ~/ 4);
  }

  @override
  void dispose() {
    _listScroll.dispose();
    _progress.dispose();
    _controller.dispose();
    _triggerFocus.dispose();
    super.dispose();
  }

  void _setOpen(bool next) {
    if (next == _open) return;
    // 展开前按「下方剩余空间」决定是否翻上去，对应源码的
    // below < h + 16 && above > below。
    if (next) {
      _placement = _resolvePlacement();
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

  _Placement _resolvePlacement() {
    final RenderBox? box =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !_screenHeight.isFinite) {
      return _Placement.bottom;
    }
    final double top = box.localToGlobal(Offset.zero).dy;
    final double below = _screenHeight - (top + box.size.height);
    final int count = widget.items.length;
    final double estimated = math.min(
      count * _itemStyle.itemHeight +
          math.max(0, count - 1) * _itemGap +
          _itemStyle.padding * 2 +
          2,
      _itemStyle.maxHeight,
    );
    return below < estimated + 16 && top > below
        ? _Placement.top
        : _Placement.bottom;
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
    final bool above = _placement == _Placement.top;

    // 整体淡入 / 淡出：前 22% 时间柔和浮现，收起时最后 22% 时间退场。
    final double opacity = _kEaseOut.transform(_remap(u, 0.0, 0.22));
    // 阴影在面板揭开过半后才渐强，避免一开始就有完整轮廓的「幽灵阴影」，
    // 也让 p 到 1 时不再突然冒出一整圈阴影。
    final double shadow = _kEaseOut.transform(_remap(p, 0.6, 1.0));
    // 脱开位移从 p 一开始就连续进行（旧版 0.4 才启动，观感像两段）。
    final double detach = _kSoftCurve.transform(_remap(p, 0.08, 0.95));
    // 行内容与主线同步淡入 / 淡出，不再「内容先消失、空壳再折回」。
    final double rows = _kEaseOut.transform(_remap(p, 0.10, 0.85));

    return _Frame(
      p: p,
      offsetY: _reduce
          ? 0.0
          : _lerp(above ? _itemStyle.gap : -_itemStyle.gap, 0.0, detach),
      opacity: opacity,
      shadow: _reduce ? opacity : shadow,
      rowsOpacity: _reduce ? 1.0 : rows,
      rowsOffsetY: _reduce ? 0.0 : -4.0 * (1.0 - rows),
      angle: _reduce ? (_open ? math.pi : 0.0) : p * math.pi,
      placedAbove: above,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _tapGroup,
      onTapOutside: (PointerDownEvent _) {
        if (_open) _setOpen(false);
      },
      child: SizedBox(
        key: _fieldKey,
        width: _fieldStyle.width,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: _buildOverlay,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? _) {
              return CompositedTransformTarget(
                link: _layerLink,
                child: _buildTrigger(_frame()),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final _Frame f = _frame();
        return Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: f.placedAbove
                ? Alignment.topLeft
                : Alignment.bottomLeft,
            followerAnchor: f.placedAbove
                ? Alignment.bottomLeft
                : Alignment.topLeft,
            // 最终位置的 GAP + 动画中的 y（起始恰好把 GAP 抵消，贴合触发器）。
            offset: Offset(
              0,
              (f.placedAbove ? -_itemStyle.gap : _itemStyle.gap) + f.offsetY,
            ),
            child: TapRegion(
              groupId: _tapGroup,
              child: SizedBox(
                width: _fieldStyle.width,
                child: IgnorePointer(ignoring: !_open, child: _buildPanel(f)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrigger(_Frame f) {
    final BorderRadius radius = BorderRadius.all(
      Radius.circular(math.max(0.0, _fieldStyle.radius)),
    );
    return Focus(
      focusNode: _triggerFocus,
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: widget.disabled ? SystemMouseCursors.basic : _cursor,
        child: GestureDetector(
          onTap: widget.disabled
              ? null
              : () {
                  _triggerFocus.requestFocus();
                  _setOpen(!_open);
                },
          child: Semantics(
            button: true,
            enabled: !widget.disabled,
            label: _displayText,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _fieldStyle.backgroundColor,
                // 四个角恒定，不参与贴合 / 脱开形变。
                borderRadius: radius,
                border: Border.all(color: _fieldStyle.borderColor),
              ),
              child: SizedBox(
                height: _fieldStyle.height,
                child: Padding(
                  padding: _fieldStyle.padding,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _displayText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _textStyle(
                            _styleFor(_selectedItem, _fieldStyle.textStyle),
                            widget.value == null
                                ? _fieldStyle.muted
                                : _fieldStyle.foreground,
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: f.angle,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: _fieldStyle.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(_Frame f) {
    final BorderRadius radius = BorderRadius.all(Radius.circular(_radius));

    Widget body = DecoratedBox(
      key: _bodyKey,
      decoration: BoxDecoration(
        color: _itemStyle.backgroundColor,
        borderRadius: radius,
        border: Border.all(color: _itemStyle.borderColor),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Opacity(
          opacity: f.rowsOpacity,
          child: Transform.translate(
            offset: Offset(0, f.rowsOffsetY),
            child: _buildItems(),
          ),
        ),
      ),
    );

    // p 到 1 后整块去掉裁切；此时 clipper 本身就是同一个圆角外框，
    // 移除不会造成形状跳变。
    if (!_reduce && f.p < 1.0) {
      body = ClipPath(
        key: _clipKey,
        clipper: UnfoldClipper(
          progress: f.p,
          nearRadius: _radius,
          radius: _radius,
          lip: _itemStyle.lip,
          placedAbove: f.placedAbove,
        ),
        child: body,
      );
    }

    // 阴影画在裁切层之外、颜色透明度随进度渐强：clip 不会再把它整圈切掉，
    // 也就没有「最后一帧突然出现阴影」的硬切。
    return DecoratedBox(
      key: _shadowKey,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _itemStyle.shadowColor.withValues(
              alpha: _itemStyle.shadowOpacity * f.shadow,
            ),
            blurRadius: _itemStyle.shadowBlurRadius,
            offset: _itemStyle.shadowOffset,
          ),
        ],
      ),
      child: Opacity(opacity: f.opacity, child: body),
    );
  }

  /// 选项列表 + 贴着面板内边缘的滚动条。
  ///
  /// [Scrollbar] 刻意包在 `Padding` **外面**：它的盒子铺满整条内容区，滑块就画
  /// 在面板内边缘上。反过来（或依赖桌面平台默认注入的那条）滑块会跟着
  /// [DropdownItemStyle.padding] 往里缩；而 [DropdownItemStyle.itemPadding] 只影响行
  /// 内容的缩进，跟滑块位置无关 —— 两者怎么调，滑块都紧挨着边。
  ///
  /// `Scrollbars: false` 关掉平台注入的那条：Windows / macOS 上 Material 的
  /// [ScrollBehavior] 会自动给可滚动区域塞一条 [Scrollbar]，不关掉的话它会和
  /// 这条叠在一起画（两条滑块、粗细翻倍，位置还是跟 padding 走）。
  Widget _buildItems() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      // Material 的滑块默认离边 2px（`_kScrollbarMargin`），这里压成 0：
      // 滑块直接压在面板内边缘上。
      child: ScrollbarTheme(
        data: ScrollbarTheme.of(context).copyWith(crossAxisMargin: 0),
        child: Scrollbar(
          controller: _listScroll,
          child: Padding(
            padding: EdgeInsets.all(_itemStyle.padding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(
                  0.0,
                  _itemStyle.maxHeight - _itemStyle.padding * 2,
                ),
              ),
              child: SingleChildScrollView(
                controller: _listScroll,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: _itemGap,
                  children: <Widget>[
                    for (final TextDropdownItem<T> item in widget.items)
                      _buildItem(item),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(TextDropdownItem<T> item) {
    final bool selected = item.value == widget.value;
    final bool enabled = item.enabled && !widget.disabled;
    final BorderRadius itemRadius = BorderRadius.all(
      Radius.circular(_itemRadius),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      child: InkWell(
        onTap: enabled
            ? () {
                widget.onChanged?.call(item.value);
                _setOpen(false);
              }
            : null,
        mouseCursor: enabled ? _cursor : SystemMouseCursors.basic,
        customBorder: RoundedRectangleBorder(borderRadius: itemRadius),
        child: Container(
          height: _itemStyle.itemHeight,
          padding: _itemStyle.itemPadding,
          decoration: BoxDecoration(
            color: selected ? _itemStyle.selectedColor : Colors.transparent,
            borderRadius: itemRadius,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _textStyle(
                    _styleFor(item, _itemStyle.textStyle),
                    enabled ? _itemStyle.foreground : _itemStyle.disabledColor,
                  ),
                ),
              ),
              if (selected && _itemStyle.showCheck)
                Icon(
                  _itemStyle.checkIcon,
                  size: _itemStyle.checkSize,
                  color: _itemStyle.foreground,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 曲线小工具 ────────────────────────────────────────────────────────────

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// `useTransform(progress, [from, to], [0, 1])`，两端 clamp。
double _remap(double v, double from, double to) =>
    ((v - from) / (to - from)).clamp(0.0, 1.0);

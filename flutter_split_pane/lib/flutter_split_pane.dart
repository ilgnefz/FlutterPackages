/// 可拖动分割线的多视图布局：拖动中间那条分割线就能改变两侧面板的宽度。
///
/// 以 `flutter_split_pane.dart` 为唯一入口，实现按职责拆在 `src/` 的 part 文件：
///
/// | 文件 | 职责 |
/// |---|---|
/// | `src/split_pane_types.dart` | 公开类型：[SplitPaneView] / [SplitPaneStyle] / [SplitPaneDividerState] / 回调 typedef |
/// | `src/split_pane_controller.dart` | [SplitPaneController]：各视图占比的外部数据源 |
/// | `src/split_pane_divider.dart` | 分割线本体：命中区域、悬停 / 拖动状态、键盘调整 |
///
/// ## 基本用法
///
/// 面板之间自动插入分割线，数量是「视图数 - 1」。
///
/// ```dart
/// SplitPane(
///   views: <SplitPaneView>[
///     SplitPaneView(child: const Text('左')),
///     SplitPaneView(child: const Text('中')),
///     SplitPaneView(child: const Text('右')),
///   ],
/// );
/// ```
///
/// ## 占比怎么给
///
/// 占比写在**每个视图自己身上**，不写就由其它视图平分剩下的空间：
///
/// ```dart
/// SplitPane(
///   views: <SplitPaneView>[
///     SplitPaneView(child: const Text('左'), ratio: 0.6),
///     SplitPaneView(child: const Text('右')),          // 分剩下的 40%
///     SplitPaneView(child: const Text('尾'), ratio: 0.2), // 和上面的合计 1
///   ],
/// );
/// ```
///
/// * 全都不写 → 全部平分。
/// * 有的写了 → 没写的平分剩下的那部分。
/// * 声明的比例加起来超过 1 → 按比例整体缩放到 1（没写的视图分不到空间）。
///
/// 之所以把占比挂在视图上、而不是另开一个「占比数组」，是因为两个平行数组
/// 容易长度失配、顺序错位，而且以后想给单个面板加「最小宽度」也没地方放。
///
/// ## 比例的读写
///
/// 比例是「视图占**可用空间减所有分割线**」的份额，0..1。
///
/// * 不给控制器：组件自己维护比例，用 [SplitPane.onRatiosChanged] 抛出去。
/// * 给了 [SplitPane.controller]：控制器是唯一数据源，拖动会写回控制器，
///   外部改 [SplitPaneController.ratios] 组件也会跟着重排。
///
/// [SplitPane.onRatiosChanged] 是**按帧**触发的，只适合「跟着拖动实时反映」的
/// 场景（比如让另一个列表同步变宽高）。想持久化、或者想喂给一棵不该每帧重建
/// 的子树，用 [SplitPane.onRatiosCommitted]：它只在一次调整**结束**时抛一次
/// 最终比例（拖动是松手，键盘调整和双击复位是每次调整完成）。
///
/// ```dart
/// final SplitPaneController controller = SplitPaneController();
/// SplitPane(
///   controller: controller,
///   views: <SplitPaneView>[
///     SplitPaneView(child: const Text('左')),
///     SplitPaneView(child: const Text('右')),
///   ],
/// );
/// controller.setRatio(0, 0.6);
/// ```
///
/// ## 尺寸约束
///
/// [SplitPaneView.minExtent] / [SplitPaneView.maxExtent] 用逻辑像素限制单个
/// 面板的尺寸；拖动时相邻两个面板互相让空间，撞到上限就停。
///
/// ## 交互
///
/// * 拖动分割线改宽度；拖动过程中分割线严格跟手，不会跳。
/// * 鼠标悬停时分割线变主色，按下拖动时同样高亮。
/// * 分割线可以聚焦，方向键每次调整 [SplitPaneStyle.resizeStep] 像素，
///   `Home` / `End` 直接跳到最小 / 最大。
/// * 双击分割线回到初始比例（[SplitPaneStyle.doubleTapToReset] 可关掉）。
///
/// ## 分割线与面板的距离
///
/// 两个面板之间那条**分割带本身就是分割线**：带宽 = [SplitPaneStyle
/// .dividerThickness]，它始终用分割线颜色填满。默认带宽就是全部间距，所以
/// 面板紧贴着分割线（想更细就把带宽调小，1 就是一条发丝线）。想让两侧再留
/// 一段空白，用 [SplitPaneStyle.dividerSpace]：
///
/// ```dart
/// SplitPaneStyle(dividerThickness: 1, dividerSpace: 12)
/// // 面板 │ 12px │ 1px 分割线 │ 12px │ 面板
///
/// SplitPaneStyle(dividerThickness: 1, dividerSpace: 4, dividerSpaceEnd: 20)
/// // 面板 │ 4px │ 1px 分割线 │ 20px │ 面板 —— 只有带文字的一侧多留
/// ```
///
/// [SplitPaneStyle.dividerSpace] 是两侧同值的简写，
/// [SplitPaneStyle.dividerSpaceStart] / [SplitPaneStyle.dividerSpaceEnd] 单独
/// 覆盖某一侧（「前 / 后」按视图顺序：横向 = 左 / 右，竖向 = 上 / 下，不随 RTL
/// 翻转）。
///
/// 这段留白由**布局**承担（每条分割线占
/// `dividerThickness + 前留白 + 后留白`），可用空间先扣掉它、再按占比分给
/// 面板 —— 所以各面板的内容宽度严格按比例，不会出现「给某一侧加 padding 后
/// 两边内容宽度不一样」的问题。给 [SplitPaneView.child] 套 `Padding` 做不到
/// 这一点：padding 是在面板**内部**再缩一圈，两个面板宽度本来就不等，缩完
/// 两边内容宽度差得更明显，而且比例也不再把留白算进去。
///
/// 留白区域同时是**命中区**，在留白里按下拖动一样有效。
///
/// 自定义 [SplitPane.dividerBuilder] 的内容画在带子**之上**，带子底色仍然
/// 保留 —— 即使自定义内容只画一条细线，面板之间也不会露出空隙。
///
/// ## 分割线可以只占中间一段
///
/// 默认分割线沿交叉轴填满（横向布局时是一条贯穿全高的竖线）。想让它短一点、
/// 居中在父组件里，有两种写法：
///
/// ```dart
/// // 固定长度，默认居中
/// SplitPaneStyle(dividerExtent: 64)
///
/// // 两端各留 12px，中间那段填满
/// SplitPaneStyle(dividerMargin: EdgeInsets.symmetric(vertical: 12))
/// ```
///
/// [SplitPaneStyle.dividerMargin] 只吃交叉轴方向的边距：横向布局用
/// `vertical`，竖向布局用 `horizontal`。想把它摆到顶部 / 底部而不是居中，用
/// [SplitPaneStyle.dividerCrossAxisAlignment]（仅对 `dividerExtent` 生效）。
/// 两个都设时以 [SplitPaneStyle.dividerExtent] 为准。
///
/// 注意：变短的是**可见的带子**，命中区仍然沿交叉轴铺满，所以短分割线也一
/// 样好抓；主轴方向依旧紧贴两侧面板，不会露出空隙。
///
/// ## 命中区比可见带宽
///
/// 细分割线不好抓，所以命中区向两侧各扩展 [SplitPaneStyle.dividerHitPadding]
/// （默认 4px），**盖在相邻面板上** —— 视觉上还是一条细线，手感上却好抓得多。
/// 设成 0 就让命中区和可见宽度一致。
///
/// 设了留白（[SplitPaneStyle.dividerSpace] 等）时留白本身已经算在命中区里，
/// 每侧向面板额外扩展的距离是 `max(dividerHitPadding - 该侧留白, 0)`：命中区
/// 不会因为加了留白而变得又宽又盖住内容。
///
/// ## 布局要求
///
/// 主轴（横向时的宽、竖向时的高）需要有界，否则算不出像素尺寸；无界时
/// 组件会退回按 flex 近似分配，比例仍然可用但不精确。
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show DragStartBehavior, PointerDeviceKind;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

part 'src/split_pane_types.dart';
part 'src/split_pane_controller.dart';
part 'src/split_pane_divider.dart';

/// 多个面板 + 面板之间的可拖动分割线。
class SplitPane extends StatefulWidget {
  const SplitPane({
    super.key,
    required this.views,
    this.axis = Axis.horizontal,
    this.controller,
    this.style = const SplitPaneStyle(),
    this.dividerBuilder,
    this.resizable = true,
    this.onRatioChanged,
    this.onRatiosChanged,
    this.onResizeStart,
    this.onResizeEnd,
    this.onRatiosCommitted,
  });

  /// 各个面板；面板之间会自动插入「视图数 - 1」条分割线。
  final List<SplitPaneView> views;

  /// 布局方向。
  final Axis axis;

  /// 占比的外部数据源；给了就以它为唯一数据源。
  final SplitPaneController? controller;

  /// 外观与交互配置。
  final SplitPaneStyle style;

  /// 自定义分割线内容；为空时画默认那条带子。
  final SplitPaneDividerBuilder? dividerBuilder;

  /// 关掉后分割线不可拖动（仍可聚焦、仍可用键盘调整）。
  final bool resizable;

  /// 某个视图的占比变了。
  final SplitPaneRatioChanged? onRatioChanged;

  /// 全部视图的占比变了（拖一次分割线会同时改两个视图）。
  final SplitPaneRatiosChanged? onRatiosChanged;

  /// 开始拖动某条分割线（参数是分割线下标，0 是最靠前的那条）。
  final SplitPaneResizeChanged? onResizeStart;

  /// 结束拖动某条分割线（参数是分割线下标）。
  final SplitPaneResizeChanged? onResizeEnd;

  /// 一次调整**结束**后的最终比例，只在结束时触发一次：
  ///
  /// * 拖动分割线 → 松手时触发（拖动中每帧触发的是 [onRatiosChanged]）；
  /// * 方向键 / `Home` / `End` 调整 → 每按一次触发一次；
  /// * 双击复位 → 复位后触发一次。
  ///
  /// 想把比例存起来（本地持久化、喂给别的列表等）就用它：跟着
  /// [onRatiosChanged] 写状态会让订阅方每帧重建，拖动时整棵子树跟着抖。
  final SplitPaneRatiosCommitted? onRatiosCommitted;

  @override
  State<SplitPane> createState() => _SplitPaneState();
}

/// 第 [index] 条分割线的定位 key（命中区，可能比可见带宽）。
ValueKey<String> splitPaneDividerKey(int index) =>
    ValueKey<String>('split_pane.divider.$index');

/// 第 [index] 条分割线**可见带子**的定位 key（宽度 = dividerThickness）。
ValueKey<String> splitPaneDividerBandKey(int index) =>
    ValueKey<String>('split_pane.divider_band.$index');

/// 把「每个视图声明的占比」解析成一份和为 1 的比例列表。
///
/// * 全都没写 → 平均分；
/// * 有的写了 → 写了 的按声明取值，没写的平分剩下的；
/// * 声明的加起来超过 1 → 按比例整体缩放到 1。
List<double> resolveSplitPaneRatios(List<SplitPaneView> views) {
  final int count = views.length;
  if (count == 0) return const <double>[];

  int specified = 0;
  double sum = 0;
  for (final SplitPaneView view in views) {
    final double? ratio = view.ratio;
    if (ratio == null) continue;
    specified++;
    sum += ratio.clamp(0.0, 1.0);
  }
  if (specified == 0 || sum <= 0) {
    return List<double>.filled(count, 1.0 / count);
  }

  final double scale = sum > 1.0 ? 1.0 / sum : 1.0;
  final List<double> result = <double>[];
  double used = 0;
  for (final SplitPaneView view in views) {
    final double ratio = view.ratio == null
        ? 0.0
        : view.ratio!.clamp(0.0, 1.0) * scale;
    result.add(ratio);
    used += ratio;
  }
  final int rest = count - specified;
  if (rest > 0) {
    final double each = ((1.0 - used) / rest).clamp(0.0, 1.0);
    for (int i = 0; i < count; i++) {
      if (views[i].ratio == null) result[i] = each;
    }
  }
  return result;
}

/// 把比例列表换算成 [Expanded.flex] / [Flexible.flex] 能用的整数权重。
///
/// `flex` 只比较**相对大小**，不要求权重和为 1，所以统一乘 [scale] 再四舍五入
/// 就能保持比例，最大量化误差是 `1 / scale`。
///
/// 每个值至少是 1：`flex: 0` 的 [Expanded] 会拿到 0 宽度，通常不是想要的结果。
///
/// ```dart
/// Row(
///   children: <Widget>[
///     for (final int flex in splitPaneFlex(controller.ratios))
///       Expanded(flex: flex, child: ...),
///   ],
/// );
/// ```
///
/// 注意：`flex` 分配的是**同一行里扣掉固定尺寸后的剩余空间**，只保证这些
/// 组件之间的比例关系；如果 Row 里还有固定宽度的兄弟节点，实际像素不会和
/// [SplitPane] 里完全一致。
List<int> splitPaneFlex(List<double> ratios, {int scale = 1000}) {
  assert(scale > 0, 'scale 必须大于 0');
  return <int>[
    for (final double ratio in ratios)
      ratio.isFinite ? math.max(1, (ratio * scale).round()) : 1,
  ];
}

class _SplitPaneState extends State<SplitPane> {
  /// 当前各视图的比例（内部始终是归一化后的，和为 1）。
  List<double> _ratios = const <double>[];

  SplitPaneController? _attachedController;

  /// 正在把本地比例写回控制器 —— 这时控制器回调过来的通知要忽略。
  bool _syncing = false;

  /// 上一帧算出来的可用空间，拖动时用来把位移换算成比例变化。
  double _lastAvailable = 0;

  /// 拖动起点：指针位置 + 当时的各视图比例。
  ///
  /// 拖动过程中每次都拿「按下那一刻的比例」重新算，而不是在当前比例上
  /// 累加 —— 否则慢速拖动时每一步的位移都会叠加，分割线会越走越远。
  double _dragOrigin = 0;
  List<double> _dragStartRatios = const <double>[];

  /// 本次拖动是否真的改过尺寸（纯点击不算）。
  bool _resizing = false;

  @override
  void initState() {
    super.initState();
    _attachedController = widget.controller;
    _ratios = _initialRatios();
    _pushToController();
    _attachedController?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant SplitPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _attachedController?.removeListener(_onControllerChanged);
      _attachedController = widget.controller;
      _ratios = _initialRatios();
      _pushToController();
      _attachedController?.addListener(_onControllerChanged);
    }
    // 视图数量变了：比例列表长度对不上，重新解析。
    if (widget.views.length != oldWidget.views.length) {
      _ratios = _initialRatios();
      _pushToController();
    }
  }

  @override
  void dispose() {
    _attachedController?.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// 初始比例：控制器里有对得上长度的就用它，否则按视图声明的算。
  List<double> _initialRatios() {
    final List<double> fromController =
        _attachedController?.ratios ?? const <double>[];
    if (fromController.length == widget.views.length &&
        fromController.isNotEmpty) {
      return List<double>.of(fromController);
    }
    return resolveSplitPaneRatios(widget.views);
  }

  void _pushToController() {
    final SplitPaneController? controller = _attachedController;
    if (controller == null) return;
    if (_sameRatios(controller.ratios, _ratios)) return;
    _syncing = true;
    try {
      controller.setRatios(_ratios);
    } finally {
      _syncing = false;
    }
  }

  void _onControllerChanged() {
    if (_syncing) return;
    final SplitPaneController? controller = _attachedController;
    if (controller == null || !mounted) return;
    if (controller.ratios.length != widget.views.length) return;
    setState(() => _ratios = _normalize(controller.ratios));
  }

  /// 归一化：负数按 0 算，再整体缩放到和为 1。
  List<double> _normalize(List<double> ratios) {
    final int count = widget.views.length;
    if (count == 0) return const <double>[];
    double sum = 0;
    for (final double ratio in ratios) {
      sum += math.max(0.0, ratio);
    }
    if (sum <= 0) return List<double>.filled(count, 1.0 / count);
    return <double>[
      for (final double ratio in ratios) math.max(0.0, ratio) / sum,
    ];
  }

  /// 写入一份新比例；返回值表示真的有变化（没变就不触发任何回调）。
  bool _setRatios(List<double> next) {
    final List<double> normalized = _normalize(next);
    if (_sameRatios(_ratios, normalized)) return false;
    final List<int> changed = <int>[];
    for (int i = 0; i < normalized.length; i++) {
      if (i >= _ratios.length || _ratios[i] != normalized[i]) changed.add(i);
    }
    setState(() => _ratios = normalized);
    _pushToController();
    widget.onRatiosChanged?.call(List<double>.unmodifiable(normalized));
    for (final int index in changed) {
      if (index < normalized.length) {
        widget.onRatioChanged?.call(index, normalized[index]);
      }
    }
    return true;
  }

  /// 把「这次调整已经结束」的最终比例抛给外部。
  void _emitCommitted() {
    final SplitPaneRatiosCommitted? callback = widget.onRatiosCommitted;
    if (callback == null) return;
    callback(List<double>.unmodifiable(_normalize(_ratios)));
  }

  // ── 拖动 / 键盘 ────────────────────────────────────────────────────────

  void _handleDragStart(int index, double pointer) {
    _dragOrigin = pointer;
    _dragStartRatios = List<double>.of(_normalize(_ratios));
  }

  void _handleDragUpdate(int index, double pointer) {
    if (!_resizing) {
      _resizing = true;
      widget.onResizeStart?.call(index);
    }
    final double available = _lastAvailable;
    if (available <= 0) return;
    _applyDelta(
      index,
      pointer - _dragOrigin,
      available,
      base: _dragStartRatios,
    );
  }

  void _handleDragEnd(int index) {
    if (!_resizing) return;
    _resizing = false;
    widget.onResizeEnd?.call(index);
    _emitCommitted();
  }

  void _handleStep(int index, double deltaPixels) {
    final double available = _lastAvailable;
    if (available <= 0) return;
    if (_applyDelta(index, deltaPixels, available)) _emitCommitted();
  }

  void _handleStepToEdge(int index, bool toMin) {
    final double available = _lastAvailable;
    if (available <= 0) return;
    final List<double> ratios = _normalize(_ratios);
    if (index < 0 || index + 1 >= ratios.length) return;

    final SplitPaneView left = widget.views[index];
    final SplitPaneView right = widget.views[index + 1];
    final double minLeft = (left.minExtent ?? 0) / available;
    final double maxLeft = (left.maxExtent ?? double.infinity) / available;
    final double minRight = (right.minExtent ?? 0) / available;
    // 右边至少要留 minRight，左边最大能长到 1 - minRight。
    final double hardMax = 1.0 - minRight;
    final double target = toMin
        ? minLeft
        : (maxLeft >= double.infinity ? hardMax : math.min(maxLeft, hardMax));
    final double lo = math.min(minLeft, hardMax);
    final double hi = math.max(minLeft, hardMax);
    if (_applyDelta(index, target.clamp(lo, hi) - ratios[index], available)) {
      _emitCommitted();
    }
  }

  /// 把「像素位移」换算成相邻两个视图的比例变化，并受各自的上下限约束。
  ///
  /// [base] 给了就用它当基准（拖动时用「按下那一刻的比例」，保证结果只跟
  /// 指针位置有关、不会逐帧累加）；不给就在当前比例上增量调整（键盘用）。
  ///
  /// 返回值表示比例是否真的变了。
  bool _applyDelta(
    int index,
    double deltaPixels,
    double available, {
    List<double>? base,
  }) {
    final List<double> source = base ?? _normalize(_ratios);
    final List<double> ratios = _normalize(source);
    if (index < 0 || index + 1 >= ratios.length) return false;
    final double delta = _clampDelta(
      index,
      deltaPixels / available,
      ratios,
      available,
    );
    if (delta == 0) return false;
    final List<double> next = List<double>.of(ratios);
    next[index] += delta;
    next[index + 1] -= delta;
    return _setRatios(next);
  }

  /// 把比例增量夹在相邻两个视图允许的范围内。
  double _clampDelta(
    int index,
    double delta,
    List<double> ratios,
    double available,
  ) {
    final SplitPaneView left = widget.views[index];
    final SplitPaneView right = widget.views[index + 1];
    final double minLeft = (left.minExtent ?? 0) / available;
    final double maxLeft = (left.maxExtent ?? double.infinity) / available;
    final double minRight = (right.minExtent ?? 0) / available;
    final double maxRight = (right.maxExtent ?? double.infinity) / available;

    // 左边能涨多少 / 右边能让出多少。
    final double lo = math.max(
      minLeft - ratios[index],
      ratios[index + 1] - maxRight,
    );
    final double hi = math.min(
      maxLeft - ratios[index],
      ratios[index + 1] - minRight,
    );
    if (lo > hi) return 0;
    return delta.clamp(lo, hi);
  }

  void _reset() {
    final SplitPaneController? controller = _attachedController;
    final List<double> initial =
        controller != null &&
            controller.initialRatios.length == widget.views.length
        ? controller.initialRatios
        : resolveSplitPaneRatios(widget.views);
    if (_setRatios(List<double>.of(initial))) _emitCommitted();
  }

  // ── 构建 ────────────────────────────────────────────────────────────────

  Widget _buildDivider(
    int index,
    double ratio,
    double insetStart,
    double insetEnd,
  ) {
    return _SplitPaneDivider(
      key: splitPaneDividerKey(index),
      bandKey: splitPaneDividerBandKey(index),
      axis: widget.axis,
      style: widget.style,
      insetStart: insetStart,
      insetEnd: insetEnd,
      builder: widget.dividerBuilder,
      resizable: widget.resizable,
      ratio: ratio,
      index: index,
      onDragStart: (double pointer) => _handleDragStart(index, pointer),
      onDragUpdate: (double pointer) => _handleDragUpdate(index, pointer),
      onDragEnd: () => _handleDragEnd(index),
      onDoubleTap: widget.resizable && widget.style.doubleTapToReset
          ? _reset
          : null,
      onStep: (double delta) => _handleStep(index, delta),
      onStepToEdge: (bool toMin) => _handleStepToEdge(index, toMin),
    );
  }

  /// 分割线在布局里占的槽位。
  ///
  /// 槽位宽度是「可见带宽 + 前留白 + 后留白」，所以两个面板之间的空隙正好是
  /// [SplitPaneStyle.dividerSpaceStart] + [SplitPaneStyle.dividerSpaceEnd]
  /// （留白为 0 时就是紧挨着）；真正的**命中区**更宽，通过 [OverflowBox]
  /// 溢出到相邻面板上 —— 细分割线也照样好抓。
  Widget _buildDividerSlot(
    int index,
    double ratio,
    double insetStart,
    double insetEnd,
  ) {
    final Widget divider = _buildDivider(index, ratio, insetStart, insetEnd);
    final double band = widget.style.dividerThickness;
    final double slot =
        band + widget.style.resolvedSpaceStart + widget.style.resolvedSpaceEnd;
    final double hit = band + insetStart + insetEnd;
    final bool horizontal = widget.axis == Axis.horizontal;
    if (horizontal) {
      return SizedBox(
        width: slot,
        child: OverflowBox(
          alignment: Alignment.center,
          maxWidth: hit,
          child: divider,
        ),
      );
    }
    return SizedBox(
      height: slot,
      child: OverflowBox(
        alignment: Alignment.center,
        maxHeight: hit,
        child: divider,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int count = widget.views.length;
        if (count == 0) return const SizedBox.shrink();

        final bool horizontal = widget.axis == Axis.horizontal;
        final double total = horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final bool bounded = total.isFinite;
        final double thickness = widget.style.dividerThickness;
        final double spaceStart = widget.style.resolvedSpaceStart;
        final double spaceEnd = widget.style.resolvedSpaceEnd;
        // 一条分割线占的位置：可见带宽 + 前留白 + 后留白。
        final double slotExtent = thickness + spaceStart + spaceEnd;
        final int dividerCount = count - 1;
        final double available = bounded
            ? math.max(0.0, total - dividerCount * slotExtent)
            : 0.0;
        final List<double> ratios = _normalize(_ratios);

        // 带子距命中区边缘的内缩量：至少是命中区余量，留白更大时留给留白。
        // 两侧分开算，留白不对称时命中区也不会变成「以带子为中心」。
        final double hitPadding = widget.style.dividerHitPadding;
        final double insetStart = math.max(hitPadding, spaceStart);
        final double insetEnd = math.max(hitPadding, spaceEnd);
        final double hit = thickness + insetStart + insetEnd;

        final List<Widget> children = <Widget>[];

        // 主轴无界（外层没给死尺寸）：退回按 flex 近似分配。
        if (!bounded) {
          for (int i = 0; i < count; i++) {
            children.add(
              Flexible(
                flex: math.max(1, (ratios[i] * 1000).round()),
                child: widget.views[i].child,
              ),
            );
            if (i < dividerCount) {
              children.add(
                _buildDividerSlot(i, ratios[i], insetStart, insetEnd),
              );
            }
          }
          return horizontal
              ? Row(children: children)
              : Column(children: children);
        }

        final List<double> extents = <double>[
          for (final double ratio in ratios) ratio * available,
        ];
        _lastAvailable = available;

        final bool boundedCross = horizontal
            ? constraints.hasBoundedHeight
            : constraints.hasBoundedWidth;
        final CrossAxisAlignment cross = boundedCross
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.start;

        // 每条分割线占 slotExtent（带宽 + 前后留白），面板紧贴着它的留白边缘；
        // 命中区可能更宽，作为覆盖层叠在面板上（见 [_buildDividerSlot]）。
        final List<Widget> rowChildren = <Widget>[];
        final List<Widget> overlays = <Widget>[];
        double boundary = 0;
        for (int i = 0; i < count; i++) {
          rowChildren.add(
            horizontal
                ? SizedBox(width: extents[i], child: widget.views[i].child)
                : SizedBox(height: extents[i], child: widget.views[i].child),
          );
          boundary += extents[i];
          if (i < dividerCount) {
            rowChildren.add(
              horizontal
                  ? SizedBox(width: slotExtent)
                  : SizedBox(height: slotExtent),
            );
            // 命中区左边距：槽位起点 + 前留白 - 前内缩（后侧内缩在命中区宽度里）。
            overlays.add(
              horizontal
                  ? Positioned(
                      left: boundary + spaceStart - insetStart,
                      top: 0,
                      bottom: 0,
                      width: hit,
                      child: _buildDivider(i, ratios[i], insetStart, insetEnd),
                    )
                  : Positioned(
                      top: boundary + spaceStart - insetStart,
                      left: 0,
                      right: 0,
                      height: hit,
                      child: _buildDivider(i, ratios[i], insetStart, insetEnd),
                    ),
            );
            boundary += slotExtent;
          }
        }

        final Widget row = horizontal
            ? Row(crossAxisAlignment: cross, children: rowChildren)
            : Column(crossAxisAlignment: cross, children: rowChildren);
        return Stack(children: <Widget>[row, ...overlays]);
      },
    );
  }
}

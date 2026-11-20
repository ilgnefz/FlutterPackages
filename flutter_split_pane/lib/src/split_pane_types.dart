part of '../flutter_split_pane.dart';

// ── 公开类型 ──────────────────────────────────────────────────────────────

/// 一个视图（面板）。
///
/// 占比写在**视图自己身上**，而不是另开一个平行数组 —— 两个数组容易长度
/// 失配、顺序错位，而且以后想加「每个面板的最小宽度」也没地方放。
///
/// ```dart
/// SplitPane(
///   views: <SplitPaneView>[
///     SplitPaneView(child: const Text('左'), ratio: 0.7),
///     SplitPaneView(child: const Text('右')), // 不写就分剩下的 30%
///   ],
/// );
/// ```
@immutable
class SplitPaneView {
  const SplitPaneView({
    required this.child,
    this.ratio,
    this.minExtent,
    this.maxExtent,
  });

  /// 面板内容。
  final Widget child;

  /// 占「可用空间减所有分割线」的比例（0..1）。
  ///
  /// 为 null 时由其它视图平分剩余空间：
  /// * 所有视图都不写 → 全部平分；
  /// * 有的写了 → 没写的平分剩下的那部分。
  ///
  /// 声明的比例加起来超过 1 时会按比例整体缩放到 1（没写的视图就分不到空间）。
  final double? ratio;

  /// 最小尺寸（逻辑像素）。
  final double? minExtent;

  /// 最大尺寸（逻辑像素）。
  final double? maxExtent;
}

/// 分割线的状态。
enum SplitPaneDividerState {
  /// 空闲：指针不在分割线上。
  idle,

  /// 悬停：指针在分割线上但还没按下。
  hover,

  /// 拖动中：正在拖分割线。
  dragging,
}

/// 自定义分割线时拿到的信息。
@immutable
class SplitPaneDividerInfo {
  const SplitPaneDividerInfo({
    required this.axis,
    required this.state,
    this.index = 0,
    this.viewIndex = 0,
  });

  /// 布局方向（横向时分割线是竖的）。
  final Axis axis;

  /// 当前状态。
  final SplitPaneDividerState state;

  /// 这是第几条分割线（0 是最靠前的那条）。
  final int index;

  /// 拖动这条分割线会同时影响哪两个视图（也就是它左侧那个视图的下标）。
  final int viewIndex;
}

/// 自定义分割线；返回值会被摆进分割线那块可点击区域里。
typedef SplitPaneDividerBuilder = Widget Function(
  BuildContext context,
  SplitPaneDividerInfo info,
);

/// 某个视图的占比变了。
typedef SplitPaneRatioChanged = void Function(int index, double ratio);

/// 全部视图的占比变了（拖动一次会同时改两个视图）。
typedef SplitPaneRatiosChanged = void Function(List<double> ratios);

/// 一次调整**结束**后的最终比例。
///
/// 与 [SplitPaneRatiosChanged] 的区别是触发时机：那个在拖动过程中每帧都会
/// 触发，这个只在「这次调整真的结束了」时触发一次 —— 拖动是松手时，键盘
/// 调整和双击复位是每完成一次就触发一次。
typedef SplitPaneRatiosCommitted = void Function(List<double> ratios);

/// 开始 / 结束拖动某条分割线（参数是分割线下标，0 是最靠前的那条）。
typedef SplitPaneResizeChanged = void Function(int dividerIndex);

/// 外观与交互配置。
@immutable
class SplitPaneStyle {
  const SplitPaneStyle({
    this.dividerThickness = 4,
    this.dividerSpace = 0,
    this.dividerSpaceStart,
    this.dividerSpaceEnd,
    this.dividerExtent,
    this.dividerMargin,
    this.dividerCrossAxisAlignment = Alignment.center,
    this.dividerHitPadding = 4,
    this.idleColor,
    this.hoverColor,
    this.draggingColor,
    this.focusColor,
    this.resizeStep = 16,
    this.doubleTapToReset = true,
    this.dividerSemanticLabel = '调整面板宽度',
  }) : assert(dividerSpace >= 0, 'dividerSpace 是分割线两侧的留白，不能为负。'),
       assert(
         dividerSpaceStart == null || dividerSpaceStart >= 0,
         'dividerSpaceStart 不能为负。',
       ),
       assert(
         dividerSpaceEnd == null || dividerSpaceEnd >= 0,
         'dividerSpaceEnd 不能为负。',
       ),
       assert(dividerThickness >= 0, 'dividerThickness 不能为负。');

  /// 分割线的**可见宽度**（逻辑像素），也就是两个面板之间那条带子的宽度。
  ///
  /// 这条带子**就是分割线本身**：它始终用分割线颜色填满，所以两个面板是
  /// **紧挨着**的，中间不会出现空隙（想让两侧留白用 [dividerSpace]）。
  /// 想让分割线更细就把这个值调小（比如 1 就是一条发丝线）。
  final double dividerThickness;

  /// 分割线**两侧**的留白（主轴方向，各留多少逻辑像素），默认 0。
  ///
  /// 这是「两侧同值」的简写，实际生效的值是 [resolvedSpaceStart] /
  /// [resolvedSpaceEnd]；想两侧不等就用 [dividerSpaceStart] / [dividerSpaceEnd]
  /// 单独覆盖某一侧。
  ///
  /// 面板里的文字紧贴着分割线会显得挤，通常会留 8–16px。之所以把它做成
  /// 样式参数而不是给面板内容套 `Padding`，是因为这段留白**由布局承担**：
  /// 每条分割线占的槽位是
  /// `dividerThickness + resolvedSpaceStart + resolvedSpaceEnd`，可用空间先
  /// 扣掉它，再按占比分给面板 —— 于是各面板的内容宽度严格按比例，不会出现
  /// 「给某一侧加 padding 后两边内容宽度不一样」的问题。
  ///
  /// 留白区域**也是命中区**：[dividerHitPadding] 比它小的时候向面板扩展的距离
  /// 会相应减少，保证每侧命中范围不小于对应留白，在留白里按下同样能拖。
  final double dividerSpace;

  /// 分割线**前一侧**的留白，覆盖 [dividerSpace]。
  ///
  /// 「前」指视图顺序里的前一个面板：横向布局是分割线**左侧**，竖向布局是
  /// **上方**。为 null 时用 [dividerSpace]。不随 [TextDirection] 翻转。
  final double? dividerSpaceStart;

  /// 分割线**后一侧**的留白，覆盖 [dividerSpace]。
  ///
  /// 横向布局是分割线**右侧**，竖向布局是**下方**。为 null 时用
  /// [dividerSpace]。不随 [TextDirection] 翻转。
  ///
  /// 常见用法是让「带文字的一侧」多留一点：
  ///
  /// ```dart
  /// SplitPaneStyle(dividerThickness: 1, dividerSpace: 4, dividerSpaceEnd: 20)
  /// ```
  final double? dividerSpaceEnd;

  /// 分割线前一侧实际生效的留白（已处理 null 与负数）。
  double get resolvedSpaceStart =>
      math.max(0.0, dividerSpaceStart ?? dividerSpace);

  /// 分割线后一侧实际生效的留白（已处理 null 与负数）。
  double get resolvedSpaceEnd => math.max(0.0, dividerSpaceEnd ?? dividerSpace);

  /// 分割线在**交叉轴**方向的长度（逻辑像素）。
  ///
  /// 横向布局时是分割线的高度，竖向布局时是宽度。默认 `null` = 填满整个
  /// 交叉轴（贯穿父组件），保持「两条面板之间一条完整隔断」的观感。
  ///
  /// 设成具体值后，分割线会按 [dividerCrossAxisAlignment] 摆放（默认居中），
  /// 视觉上就是从中间截一段的短分割条 —— 类似 IDE 里那种不顶到头的拖动手柄。
  ///
  /// 与 [dividerMargin] 二选一即可：这个给**确切长度**，[dividerMargin] 给
  /// 「两端各留多少」。两个都设时以本参数为准。
  final double? dividerExtent;

  /// 分割线在**交叉轴**方向两端留白。
  ///
  /// 只取交叉轴那一侧的边距，另一侧忽略 —— 主轴方向由 [dividerThickness]
  /// 决定。例如横向布局用 `EdgeInsets.symmetric(vertical: 12)`，就是上下各
  /// 留 12px、中间那段填满；竖向布局则换成 `horizontal`。
  ///
  /// 想精确控制长度用 [dividerExtent]，这个更适合「按比例或固定边距收一点」
  /// 的场景。
  final EdgeInsetsGeometry? dividerMargin;

  /// [dividerExtent] 生效时，分割线在交叉轴上的摆放位置，默认居中。
  ///
  /// [Alignment] 里只有交叉轴方向的分量有意义：横向布局看 y，竖向布局看 x。
  /// 例如横向布局用 [Alignment.topCenter] 贴顶、[Alignment.bottomCenter] 贴底。
  final Alignment dividerCrossAxisAlignment;

  /// 命中区向两侧各扩展多少像素（逻辑像素）。
  ///
  /// 命中区比可见的带子宽，两侧会**盖在面板上**，这样分割线只有
  /// [dividerThickness]  那么细也照样好抓。默认总命中宽度 =
  /// `dividerThickness + dividerHitPadding * 2`（4 + 8 = 12px）。
  ///
  /// 设了留白时留白本身已经算在命中区里，每侧向面板扩展的距离是
  /// `max(dividerHitPadding - 该侧留白, 0)` —— 命中区不会因为加了留白而变得
  /// 又宽又盖住内容。
  ///
  /// 设成 0 就是「命中区和可见宽度一样」。
  final double dividerHitPadding;

  /// 空闲时的分割线颜色；为 null 时取 [ThemeData.dividerColor]。
  final Color? idleColor;

  /// 悬停时的颜色；为 null 时取主题主色。
  final Color? hoverColor;

  /// 拖动时的颜色；为 null 时取主题主色。
  final Color? draggingColor;

  /// 分割线获得键盘焦点时的颜色；为 null 时取主题主色。
  final Color? focusColor;

  /// 键盘调整一档的步长（逻辑像素）。
  final double resizeStep;

  /// 双击分割线是否回到初始比例。
  final bool doubleTapToReset;

  /// 分割线的无障碍标签。
  final String dividerSemanticLabel;
}

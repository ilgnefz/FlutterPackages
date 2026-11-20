part of '../flutter_side_anchor_nav.dart';

// ── 公开类型 ──────────────────────────────────────────────────────────────

/// 一页「TabView」：左边 Tabbar 上的一个入口 + 右侧内容里的一段。
///
/// 标题和内容写在**同一个对象**上，而不是「标题数组 + 内容数组」两个平行数组
/// —— 两个数组容易长度失配、顺序错位，而且以后想给单页加「图标 / 禁用」
/// 这类属性也没地方放。
///
/// ```dart
/// SideTabView(
///   label: '账户',
///   icon: Icons.person_outline,
///   child: const AccountPane(),
/// )
/// ```
@immutable
class SideTabView {
  const SideTabView({
    required this.child,
    required this.label,
    this.icon,
    this.enabled = true,
  });

  /// 这一页的内容。所有页会被从上到下摆进同一个 `Column` 里。
  final Widget child;

  /// Tabbar 上显示的文字；同时用于无障碍标签。
  final String label;

  /// Tabbar 上的图标；[SideTabStyle.showTabIcons] 关掉时不显示。
  final IconData? icon;

  /// 关掉后这一页点不动、也不会被滚动同步选中（内容仍然照常显示）。
  final bool enabled;
}

/// 自定义 Tab 时拿到的信息。
@immutable
class SideTabItemInfo {
  const SideTabItemInfo({
    required this.index,
    required this.view,
    required this.selected,
    this.onSelected,
    this.hoverColor,
    this.mouseCursor,
  });

  /// 这是第几个 Tab（0 起）。
  final int index;

  /// 对应的页面配置。
  final SideTabView view;

  /// 当前是否是选中项。
  final bool selected;

  /// 选中这一页（带动画滚过去）；禁用页为 null。
  ///
  /// [SideTabBuilder] 返回的 Widget 里把它挂到 `onTap` 上即可，不用自己
  /// 维护选中状态。
  final VoidCallback? onSelected;

  /// Tabbar 给这个 Tab 算好的悬停 / 聚焦底色，**选中项是透明的**。
  ///
  /// 选中项的底色由那块滑动的高亮块负责；如果自己再叠一层悬停色，点击后鼠标
  /// 还停在原地，就会看到一小块比高亮块更深的底色留在下面。自定义 Tab 时把它
  /// 直接接到 `InkWell.hoverColor / focusColor / highlightColor` 上即可。
  ///
  /// [SideTabStyle.showTabHover] 关掉时恒为透明。
  final Color? hoverColor;

  /// 这个 Tab 该用的鼠标光标，自定义 Tab 时接到 `InkWell.mouseCursor` 上，
  /// 就能和默认 Tab 保持一致（含禁用项自动退回普通箭头）。
  ///
  /// 值来自 [SideTabStyle.tabMouseCursor]；为 null 表示不干预，交给 InkWell
  /// 的 `adaptiveClickable`（可点为手型）。想按选中 / 单页区分不用加配置项，
  /// 在 [SideTabBuilder] 里判断 [selected] / [index] 即可。
  final MouseCursor? mouseCursor;

  /// 是否可点；等价于 `view.enabled`。
  bool get enabled => view.enabled;
}

/// 自定义 Tab 外观；返回的 Widget 会被放进 Tabbar 里。
///
/// 点击行为用 [SideTabItemInfo.onSelected] 触发：
///
/// ```dart
/// tabBuilder: (BuildContext context, SideTabItemInfo info) => InkWell(
///   onTap: info.onSelected,
///   mouseCursor: info.mouseCursor,
///   child: Text(info.view.label),
/// ),
/// ```
typedef SideTabBuilder = Widget Function(
  BuildContext context,
  SideTabItemInfo info,
);

/// 选中项变了（点击、滚动同步、外部控制器都会触发）。
typedef SideTabChanged = void Function(int index);

/// 外观与交互配置。
@immutable
class SideTabStyle {
  const SideTabStyle({
    this.showTabBar = true,
    this.tabBarWidth = 152,
    this.tabBarPadding = const EdgeInsets.all(8),
    this.tabBarBackground,
    this.tabBarDivider,
    this.tabGap = 4,
    this.tabHeight = 44,
    this.tabItemPadding = const EdgeInsets.symmetric(horizontal: 12),
    this.tabRadius = 10,
    this.tabColorDuration = const Duration(milliseconds: 160),
    this.showTabHover = true,
    this.hoverColor,
    this.tabMouseCursor,
    this.splashColor,
    this.selectedColor,
    this.selectedTextColor,
    this.textColor,
    this.labelStyle,
    this.selectedLabelStyle,
    this.iconSize = 18,
    this.iconGap = 8,
    this.showTabIcons = true,
    this.showIndicator = true,
    this.indicatorColor,
    this.indicatorWidth = 3,
    this.indicatorInset = 10,
    this.indicatorRadius = 2,
    this.indicatorDuration = const Duration(milliseconds: 260),
    this.anchor = 0.0,
    this.duration = const Duration(milliseconds: 340),
    this.curve = Curves.easeOutCubic,
    this.syncSelectionOnScroll = true,
    this.sectionGap = 0,
    this.contentPadding = EdgeInsets.zero,
  });

  /// 是否显示左侧 Tabbar（关掉就只剩一列可以滚动的内容）。
  final bool showTabBar;

  /// Tabbar 宽度（逻辑像素）。
  final double tabBarWidth;

  /// Tabbar 内边距（Tabs 的外围留白，指示条也在这块区域内）。
  final EdgeInsetsGeometry tabBarPadding;

  /// Tabbar 背景色；为 null 时取 `ColorScheme.surfaceContainerLow`。
  final Color? tabBarBackground;

  /// Tabbar 与右侧内容之间的那条竖分隔线。
  ///
  /// 为 null（默认）时取 1px 的 [ThemeData.dividerColor]；想改颜色、粗细、
  /// 线型就传一个 [BorderSide]，想整条去掉传 [BorderSide.none]：
  ///
  /// ```dart
  /// const SideTabStyle(
  ///   tabBarDivider: BorderSide(color: Colors.black12, width: 2),
  /// )
  /// ```
  final BorderSide? tabBarDivider;

  /// 相邻两个 Tab 的间距。
  final double tabGap;

  /// 单个 Tab 的高度。
  final double tabHeight;

  /// 单个 Tab 的内边距。
  final EdgeInsetsGeometry tabItemPadding;

  /// 选中 Tab 背景的圆角。
  final double tabRadius;

  /// Tab 文字色的过渡时长（选中底色不走过渡，点击后直接换位）。
  final Duration tabColorDuration;

  /// 未选中的 Tab 是否在鼠标悬停 / 聚焦时给出底色反馈。
  ///
  /// 选中项**永远**不会有这层底色 —— 它的底色是那块跟着选中项滑动的高亮块，
  /// 再叠一层的话，点击后鼠标还停在原地，就会留下一个比高亮块更深的小色块，
  /// 看起来像高亮块「魂魄」没跟着走。整个 Tabbar 都不想要悬停反馈时把这个
  /// 开关关掉即可。
  final bool showTabHover;

  /// 悬停 / 聚焦 / 按下时的底色；为 null 时取主题主色 6% 透明度。
  final Color? hoverColor;

  /// 所有 Tab 的鼠标光标；为 null（默认）时不干预，沿用 InkWell 的
  /// `adaptiveClickable`：可点的 Tab 是手型，禁用的 Tab 是普通箭头。
  ///
  /// 常见取值：`SystemMouseCursors.basic`（不要手型）、
  /// `SystemMouseCursors.click`、`MouseCursor.defer`（交给父级决定）。
  /// 也可以传 `WidgetStateMouseCursor` 这类能按 hover / focus / disabled
  /// 解析的 [MouseCursor]，InkWell 会用 `WidgetStateProperty.resolveAs` 处理。
  ///
  /// 选中项 / 单页想用不同光标时不用再加配置，交给
  /// [SideAnchorNav.tabBuilder] 按 [SideTabItemInfo.selected] / `index` 判断。
  final MouseCursor? tabMouseCursor;

  /// 点击时的水波纹颜色；为 null 时取主题主色 10% 透明度。
  final Color? splashColor;

  /// 选中 Tab 的背景色；为 null 时取 `ColorScheme.primaryContainer`。
  final Color? selectedColor;

  /// 选中 Tab 的文字色；为 null 时取 `ColorScheme.onPrimaryContainer`。
  final Color? selectedTextColor;

  /// 未选中 Tab 的文字色；为 null 时取 `ColorScheme.onSurfaceVariant`。
  final Color? textColor;

  /// 未选中 Tab 的文字样式。
  final TextStyle? labelStyle;

  /// 选中 Tab 的文字样式（选中时默认再加粗一档）。
  final TextStyle? selectedLabelStyle;

  /// 图标尺寸。
  final double iconSize;

  /// 图标与文字的间距。
  final double iconGap;

  /// 是否显示 [SideTabView.icon]。
  final bool showTabIcons;

  /// 是否显示选中项左侧那条指示条。
  final bool showIndicator;

  /// 指示条颜色；为 null 时取主题主色。
  final Color? indicatorColor;

  /// 指示条宽度。
  final double indicatorWidth;

  /// 指示条上下各缩进多少（高度 = Tab 高度 - 两倍缩进）。
  final double indicatorInset;

  /// 指示条圆角。
  final double indicatorRadius;

  /// 指示条在选中项之间滑动一次的时长（Tabbar 上唯一带位移动画的东西）。
  final Duration indicatorDuration;

  /// 滚动停止后，页面顶部落在视口里的位置。
  ///
  /// * `0`（默认）：页面对齐视口顶部；
  /// * `0.5`：页面居中；
  /// * `1`：页面对齐视口底部。
  ///
  /// 滚动反向同步（[syncSelectionOnScroll]）用的是同一套判定，所以两者不会
  /// 互相打架。
  final double anchor;

  /// 点击 Tab 后滚动过去的时长。
  final Duration duration;

  /// 点击 Tab 后滚动过去的缓动曲线。
  final Curve curve;

  /// 内容被手动滚动时，是否让选中的 Tab 跟着变（滚动联动的「scroll spy」）。
  ///
  /// 关掉后只有点击 / 控制器能改选中项，滚动不会改 —— 适合「Tab 是导航按钮、
  /// 不想被滚动干扰」的场景。
  final bool syncSelectionOnScroll;

  /// 相邻两页之间的间距（默认 0：所有页面就是紧挨着的一个 `Column`）。
  final double sectionGap;

  /// 内容区的内边距。
  final EdgeInsets contentPadding;
}

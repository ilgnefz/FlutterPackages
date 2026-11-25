part of '../flutter_context_menu.dart';

// ── 公开类型 ──────────────────────────────────────────────────────────────

/// 菜单条目种类。分隔线 / 分组标题不参与选择，也不参与键盘导航。
enum ContextMenuEntryKind {
  /// 可点击的操作项。
  action,

  /// 细分隔线。
  divider,

  /// 分组标题（不可点击，颜色更淡）。
  header,
}

/// 一条右键菜单项。带 [children] 的操作项会变成子菜单父项，行尾显示箭头，
/// 悬停 / 点击 / 键盘右方向键展开下一级；[children] 里继续放 `.submenu` 就
/// 是孙级菜单，层数不限。
///
/// ```dart
/// const <ContextMenuItem<String>>[
///   ContextMenuItem<String>('copy', label: '复制', icon: Icons.copy),
///   ContextMenuItem<String>.divider(),
///   ContextMenuItem<String>.submenu('导出为', children: <ContextMenuItem<String>>[
///     ContextMenuItem<String>('pdf', label: 'PDF'),
///   ]),
/// ]
/// ```
///
/// 行高固定为 [ContextMenuStyle.itemHeight]，所以每级菜单的尺寸在打开前
/// 就能精确算出，边界翻转 / 左右选择不需要等布局完成后再测量。
@immutable
class ContextMenuItem<T extends Object> {
  const ContextMenuItem(
    this.value, {
    this.label,
    this.icon,
    this.prefix,
    this.color,
    this.shortcut,
    this.enabled = true,
    this.danger = false,
    this.child,
    this.children,
    this.width,
  }) : kind = ContextMenuEntryKind.action,
       assert(
         label != null || icon != null || prefix != null || child != null,
         'ContextMenuItem needs at least a label, an icon, a prefix or a child.',
       );

  /// 子菜单父项。本身不触发 [CascadeContextMenu.onSelected]，只负责展开
  /// [children]；[value] 恒为 null。
  const ContextMenuItem.submenu(
    this.label, {
    required this.children,
    this.icon,
    this.prefix,
    this.color,
    this.width,
    this.enabled = true,
    this.danger = false,
    this.child,
  }) : kind = ContextMenuEntryKind.action,
       value = null,
       shortcut = null,
       assert(
         children != null,
         'ContextMenuItem.submenu needs a children list.',
       );

  const ContextMenuItem.divider()
    : kind = ContextMenuEntryKind.divider,
      value = null,
      label = null,
      icon = null,
      prefix = null,
      color = null,
      shortcut = null,
      enabled = false,
      danger = false,
      child = null,
      children = null,
      width = null;

  const ContextMenuItem.header(String text)
    : kind = ContextMenuEntryKind.header,
      value = null,
      label = text,
      icon = null,
      prefix = null,
      color = null,
      shortcut = null,
      enabled = false,
      danger = false,
      child = null,
      children = null,
      width = null;

  final ContextMenuEntryKind kind;

  /// 选中时回传给 [CascadeContextMenu.onSelected]；分隔线 / 标题 / 父项为 null。
  final T? value;

  /// 默认渲染的主文案；[child] 存在时被忽略。
  final String? label;

  /// 行首图标。列表里只要有一项带图标（或 [prefix]），所有行都会预留同样的
  /// 图标宽度。
  final IconData? icon;

  /// 行首自定义内容，和 [icon] 抢同一个槽位：传了就不再看 [icon]。
  ///
  /// 用来放 `IconData` 里没有的图标：品牌图标、自绘 SVG、色块、序号……
  /// 渲染时外层有一份 [IconTheme]（尺寸 [ContextMenuStyle.iconSize]、颜色
  /// 跟随本行前景色，含 [color] / [danger]），所以直接塞 `Icon(...)` 也能
  /// 跟着换色。右侧留 [ContextMenuStyle.iconGap] 的间距，和 [icon] 行对齐。
  final Widget? prefix;

  /// 本行前景色（文字 + 行首 [icon] / [prefix]）；null 时按 [danger] 取
  /// [ContextMenuStyle.dangerColor]，都不是就用主题前景色。
  ///
  /// 优先级：禁用 > [color] > [danger] > 主题。行尾的快捷键提示仍用弱化色。
  final Color? color;

  /// 行尾的快捷键提示，如 `'Ctrl+C'`。子菜单父项改显示箭头。
  final String? shortcut;

  /// 为 false 时置灰、不可点、跳过键盘导航，也不会展开子菜单。
  final bool enabled;

  /// 危险操作：文字与图标转成 [ContextMenuStyle.dangerColor]。
  /// 同时传了 [color] 时以 [color] 为准。
  final bool danger;

  /// 自定义行内容，优先于 [label] / [icon] / [shortcut]。
  /// 返回内容需要适配 [ContextMenuStyle.itemHeight]。
  final Widget? child;

  /// 子菜单条目；为空或 null 时这一项就是普通叶子项。
  /// 里面可以继续放子菜单父项，形成孙级 / 曾孙级菜单。
  final List<ContextMenuItem<T>>? children;

  /// 这一项展开的**子菜单**面板宽度；null 时用 [ContextMenuStyle.width]。
  /// 只在 [children] 非空时有意义，根菜单宽度仍由 style 决定。
  final double? width;

  bool get isAction => kind == ContextMenuEntryKind.action;

  bool get isSelectable => isAction && enabled;

  /// 是否真的会回调 [CascadeContextMenu.onSelected]。
  bool get canSelect => isSelectable && !hasChildren && value != null;

  bool get hasChildren => children != null && children!.isNotEmpty;
}

/// 菜单的揭示动画。
///
/// 基本形态：
/// * [corner]：从最靠近锚点的角沿对角线扫到对角，**起点随落位自动镜像**，
///   同时以那个角为锚点轻微放大、朝锚点方向滑入；
/// * [unfold]：只让裁切线沿**垂直轴**推进，面板尺寸和位置从头到尾不变，像
///   下拉面板一样整块展开；菜单翻到锚点上方时改成从下边往上揭；
/// * 四个固定方向：忽略落位，始终从指定角扫到对角。
///
/// 显示与隐藏是同一个动画的正放 / 时间镜像：收起时裁切线退回起点，行文字
/// 先淡出、阴影先撤掉，最后整体淡出。
enum ContextMenuReveal {
  /// 自适应角（默认）：右下 → 左上起步↘、左下 → 右上起步↙、
  /// 右上 → 左下起步↗、左上 → 右下起步↖。
  corner,

  /// 贴边揭开：只推进裁切线，面板不缩放、不位移，从**贴着锚点的上边**整块
  /// 往下展开；菜单放不下、翻到锚点上方时改成从下边往上揭。
  ///
  /// 只走垂直轴，横向翻转不改变方向：
  ///
  /// | 落位 | 锚点所在角 | 揭开的边 | 展开方向 |
  /// |---|---|---|---|
  /// | 右下（默认） | 左上 | 上边 | 往下 |
  /// | 右上 | 左下 | 下边 | 往上 |
  /// | 左下 | 右上 | 上边 | 往下 |
  /// | 左上 | 右下 | 下边 | 往上 |
  ///
  /// 靠近屏幕右边缘右键、菜单翻到指针左侧时，仍然是**往下展开**（锚点落在
  /// 面板右上角，上边照样贴着手指）。子菜单也一样：虽然贴着父菜单的侧边长
  /// 出来，揭开的轴仍取垂直，不因为横向排列就改成左右揭。
  unfold,

  /// 固定：左上角 → 右下角。
  topLeftToBottomRight,

  /// 固定：右上角 → 左下角。
  topRightToBottomLeft,

  /// 固定：左下角 → 右上角。
  bottomLeftToTopRight,

  /// 固定：右下角 → 左上角。
  bottomRightToTopLeft,
}

/// 右键菜单外观。颜色字段为 null 时从当前 [ThemeData] 取（暗色主题自动适配）；
/// 文字样式以 Material 提供的 `Theme.textTheme.bodyMedium` 为基底，
/// [textStyle] / [headerTextStyle] / [shortcutTextStyle] 只覆盖同名字段。
@immutable
class ContextMenuStyle {
  const ContextMenuStyle({
    this.width = 220,
    this.itemHeight = 36,
    this.headerHeight = 28,
    this.dividerHeight = 9,
    this.itemRadius = 6,
    this.padding = 6,
    this.itemPadding = 10,
    this.radius = 10,
    this.iconSize = 18,
    this.iconGap = 8,
    this.fontSize = 13,
    this.mouseCursor = SystemMouseCursors.click,
    this.duration = kContextMenuAnimationDuration,
    this.reveal = ContextMenuReveal.corner,
    this.lip = 8,
    this.revealGap = 6,
    this.shadowOpacity = 0.16,
    this.reduceMotion = false,
    this.elevation = 6,
    this.submenuOverlap = 4,
    this.backgroundColor,
    this.borderColor,
    this.dividerColor,
    this.hoverColor,
    this.foreground,
    this.muted,
    this.disabledColor,
    this.dangerColor,
    this.shadowColor,
    this.textStyle,
    this.headerTextStyle,
    this.shortcutTextStyle,
  });

  /// 每一级菜单的默认宽度；子菜单可以用 [ContextMenuItem.width] 单独覆盖。
  final double width;

  /// 每个操作项的行高。
  final double itemHeight;

  /// 分组标题行高。
  final double headerHeight;

  /// 分隔线占用的总高度（线本身恒为 1px，居中）。
  final double dividerHeight;

  /// 操作项 hover / 键盘高亮时的圆角。
  final double itemRadius;

  /// 面板内边距：菜单外框与**第一行 / 最后一行**之间的距离。
  final double padding;

  /// 行内边距：每一行（操作项与分组标题）的内容与外框之间的左右留白，
  /// 图标、文字、快捷键都从这之后开始。想让内容离行边缘更远就调大它。
  ///
  /// 与 [padding] 的分工：`padding` 管面板四周，`itemPadding` 管每行内部；
  /// 行高固定为 [itemHeight]，所以这里只管左右。
  final double itemPadding;

  /// 面板圆角。
  final double radius;

  final double iconSize;

  /// 行首图标 / [ContextMenuItem.prefix] 与文案之间的间距。没有图标的行预留
  /// 槽位时也用它，所以同级各行的文案始终对齐。
  final double iconGap;

  final double fontSize;

  /// 可点击行（含子菜单父项）的鼠标光标，默认手型
  /// [SystemMouseCursors.click]。禁用行与标题 / 分隔线不受它影响，始终是
  /// 默认箭头。
  final MouseCursor mouseCursor;

  /// 各级菜单进场动画时长；收起自动取 3/4，减弱动效时统一 120ms。
  final Duration duration;

  /// 揭示动画形态，默认 [ContextMenuReveal.corner]（按落位自动选起点角）。
  final ContextMenuReveal reveal;

  /// 揭示动画在 progress = 0 时保留的可见量（像素）：角起点是 `lip × lip`
  /// 的小三角，贴边起点是 `lip` 厚的薄边。调大 = 起始帧露得更多、更像从
  /// 锚点「长出来」；调小则更接近从零面积长开。
  final double lip;

  /// 面板从锚点方向滑入的距离（像素）；[ContextMenuReveal.unfold] 不做位移，
  /// 只对 corner 与固定角方向生效。
  final double revealGap;

  /// 投影最深时的 alpha；投影随进度渐强，画在揭示裁切之外。
  final double shadowOpacity;

  /// 强制减弱动效；不传时也会尊重 `MediaQuery.disableAnimations`。
  final bool reduceMotion;

  /// 投影的模糊半径 / 垂直偏移由它换算。
  final double elevation;

  /// 子菜单与父菜单的水平重叠，避免两级之间出现缝隙。
  final double submenuOverlap;

  final Color? backgroundColor;
  final Color? borderColor;
  final Color? dividerColor;
  final Color? hoverColor;
  final Color? foreground;
  final Color? muted;
  final Color? disabledColor;
  final Color? dangerColor;
  final Color? shadowColor;

  /// 操作项主文案的基础样式，会先与 `bodyMedium` 合并。
  final TextStyle? textStyle;

  /// 分组标题基础样式。
  final TextStyle? headerTextStyle;

  /// 快捷键 / 箭头提示基础样式。
  final TextStyle? shortcutTextStyle;

  /// 复制一份并覆盖指定字段。
  ContextMenuStyle copyWith({
    double? width,
    double? itemHeight,
    double? headerHeight,
    double? dividerHeight,
    double? itemRadius,
    double? padding,
    double? itemPadding,
    double? radius,
    double? iconSize,
    double? iconGap,
    double? fontSize,
    MouseCursor? mouseCursor,
    Duration? duration,
    ContextMenuReveal? reveal,
    double? lip,
    double? revealGap,
    double? shadowOpacity,
    bool? reduceMotion,
    double? elevation,
    double? submenuOverlap,
    Color? backgroundColor,
    Color? borderColor,
    Color? dividerColor,
    Color? hoverColor,
    Color? foreground,
    Color? muted,
    Color? disabledColor,
    Color? dangerColor,
    Color? shadowColor,
    TextStyle? textStyle,
    TextStyle? headerTextStyle,
    TextStyle? shortcutTextStyle,
  }) => ContextMenuStyle(
    width: width ?? this.width,
    itemHeight: itemHeight ?? this.itemHeight,
    headerHeight: headerHeight ?? this.headerHeight,
    dividerHeight: dividerHeight ?? this.dividerHeight,
    itemRadius: itemRadius ?? this.itemRadius,
    padding: padding ?? this.padding,
    itemPadding: itemPadding ?? this.itemPadding,
    radius: radius ?? this.radius,
    iconSize: iconSize ?? this.iconSize,
    iconGap: iconGap ?? this.iconGap,
    fontSize: fontSize ?? this.fontSize,
    mouseCursor: mouseCursor ?? this.mouseCursor,
    duration: duration ?? this.duration,
    reveal: reveal ?? this.reveal,
    lip: lip ?? this.lip,
    revealGap: revealGap ?? this.revealGap,
    shadowOpacity: shadowOpacity ?? this.shadowOpacity,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    elevation: elevation ?? this.elevation,
    submenuOverlap: submenuOverlap ?? this.submenuOverlap,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    borderColor: borderColor ?? this.borderColor,
    dividerColor: dividerColor ?? this.dividerColor,
    hoverColor: hoverColor ?? this.hoverColor,
    foreground: foreground ?? this.foreground,
    muted: muted ?? this.muted,
    disabledColor: disabledColor ?? this.disabledColor,
    dangerColor: dangerColor ?? this.dangerColor,
    shadowColor: shadowColor ?? this.shadowColor,
    textStyle: textStyle ?? this.textStyle,
    headerTextStyle: headerTextStyle ?? this.headerTextStyle,
    shortcutTextStyle: shortcutTextStyle ?? this.shortcutTextStyle,
  );
}

/// 从主题解析出的实际配色，供面板与行渲染共用。
///
@immutable
class _ContextMenuPalette {
  const _ContextMenuPalette({
    required this.background,
    required this.border,
    required this.divider,
    required this.hover,
    required this.foreground,
    required this.muted,
    required this.disabled,
    required this.danger,
    required this.shadow,
  });

  final Color background;
  final Color border;
  final Color divider;
  final Color hover;
  final Color foreground;
  final Color muted;
  final Color disabled;
  final Color danger;
  final Color shadow;
}

/// 内部使用。
_ContextMenuPalette _resolveContextMenuPalette(
  ContextMenuStyle style,
  ThemeData theme,
) {
  final ColorScheme scheme = theme.colorScheme;
  final Color surface = style.backgroundColor ?? scheme.surface;
  return _ContextMenuPalette(
    background: surface,
    border: style.borderColor ?? scheme.outlineVariant,
    divider: style.dividerColor ?? scheme.outlineVariant,
    hover:
        style.hoverColor ??
        Color.alphaBlend(scheme.onSurface.withAlpha(20), surface),
    foreground: style.foreground ?? scheme.onSurface,
    muted: style.muted ?? scheme.onSurfaceVariant,
    disabled: style.disabledColor ?? scheme.onSurface.withAlpha(100),
    danger: style.dangerColor ?? scheme.error,
    shadow: style.shadowColor ?? scheme.shadow,
  );
}

// ── 公开常量 / 调试定位键 ────────────────────────────────────────────────

/// 默认进场时长（收起取 3/4）。揭示裁切需要足够帧数才能看清。
const Duration kContextMenuAnimationDuration = Duration(milliseconds: 220);

/// 减弱动效时长。
const Duration kContextMenuReduceDuration = Duration(milliseconds: 120);

/// 根面板（便于测试与外部定位）。
const ValueKey<String> kContextMenuPanelKey = ValueKey<String>(
  'flutter_context_menu.panel',
);

/// 第 [level] 级面板的揭示裁切层；完全展开 / 减弱动效时不在树里。
ValueKey<String> contextMenuClipKey(int level) =>
    ValueKey<String>('flutter_context_menu.reveal_clip.$level');

/// 第 [level] 级面板的投影层（画在裁切之外）。
ValueKey<String> contextMenuShadowKey(int level) =>
    ValueKey<String>('flutter_context_menu.panel_shadow.$level');

/// 全屏点击拦截层。
const ValueKey<String> kContextMenuBarrierKey = ValueKey<String>(
  'flutter_context_menu.barrier',
);

/// 根面板里的行列表容器。
const ValueKey<String> kContextMenuListKey = ValueKey<String>(
  'flutter_context_menu.list',
);

/// 第 [level] 级面板的 key；0 级保持 [kContextMenuPanelKey] 不变。
ValueKey<String> contextMenuPanelKey(int level) => level == 0
    ? kContextMenuPanelKey
    : ValueKey<String>('flutter_context_menu.panel.$level');

/// 第 [level] 级面板里行列表的 key。
ValueKey<String> contextMenuListKey(int level) => level == 0
    ? kContextMenuListKey
    : ValueKey<String>('flutter_context_menu.list.$level');

/// 第 [level] 级第 [index] 行的 key（分隔线 / 标题同样带）。
/// 省略 [level] 时等价于根面板。
ValueKey<String> contextMenuItemKey(int index, [int level = 0]) => level == 0
    ? ValueKey<String>('flutter_context_menu.item.$index')
    : ValueKey<String>('flutter_context_menu.item.$level.$index');

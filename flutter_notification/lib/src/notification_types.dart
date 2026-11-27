import 'package:material_ui/material_ui.dart';

/// 通知的语义类型：决定默认图标、主色，以及默认是否自动关闭。
///
/// [loading] 默认**不会**自动关闭（`duration: null`），适合「上传中…」这种
/// 由调用方 `handle.update(...)` 或 `handle.close()` 收尾的场景。
enum NotificationKind {
  /// 成功：对勾图标，绿色。
  success,

  /// 失败：感叹号圆圈，取主题的 `error` 色。
  error,

  /// 警告：三角感叹号，琥珀色。
  warning,

  /// 普通信息：i 图标，蓝色。
  info,

  /// 进行中：转圈，取主题 `primary`，默认不自动关闭。
  loading,

  /// 只有文字，不带图标。
  plain,
}

/// 通知停靠的角落。默认取 [NotificationStyle.position]（右上角）。
enum NotificationPosition {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight;

  /// 从上方出现（新通知贴着上边缘，往里堆）。
  bool get isTop =>
      this == NotificationPosition.topLeft ||
      this == NotificationPosition.topCenter ||
      this == NotificationPosition.topRight;

  bool get isBottom => !isTop;

  bool get isCenter =>
      this == NotificationPosition.topCenter ||
      this == NotificationPosition.bottomCenter;

  bool get isLeft =>
      this == NotificationPosition.topLeft ||
      this == NotificationPosition.bottomLeft;

  bool get isRight =>
      this == NotificationPosition.topRight ||
      this == NotificationPosition.bottomRight;
}

/// 自定义操作按钮的外观：拿到包好点击逻辑的 [onPressed]，返回任意 widget。
typedef NotificationActionBuilder =
    Widget Function(BuildContext context, VoidCallback onPressed);

/// 卡片底部右侧的一个操作按钮，比如「撤销」「查看」。
///
/// 一条通知可以带多个（`actions: [...]`），按顺序从左到右排在右下角；屏幕窄时
/// 自动折行。
///
/// 默认是一颗紧凑的 `TextButton`（`isPrimary` 时换成实心 `FilledButton`）。想
/// 换外观有三档：改 [style]、换 [isPrimary]，或者干脆用 [builder] 自己画一个。
@immutable
class NotificationAction {
  const NotificationAction({
    this.label,
    required this.onPressed,
    this.closeOnTap = true,
    this.isPrimary = false,
    this.style,
    this.builder,
  }) : assert(
         label != null || builder != null,
         '要么给 label（默认按钮），要么给 builder（自定义按钮）',
       );

  /// 按钮文字。[builder] 不为空时可以省略。
  final String? label;

  final VoidCallback onPressed;

  /// 点完是否顺手关掉这条通知（默认关）。
  final bool closeOnTap;

  /// 强调这一颗：用实心 `FilledButton` 而不是文字按钮。
  ///
  /// 两颗按钮时给主操作（「重试」「保存」）打开，次操作（「取消」）留默认。
  final bool isPrimary;

  /// 覆盖按钮样式；不传就用紧凑的文字按钮 / 实心按钮。
  final ButtonStyle? style;

  /// 完全自定义这颗按钮的外观；给了它就不再使用 [label] / [isPrimary] / [style]。
  ///
  /// 库只负责把点击包好（先跑 [onPressed]，再按 [closeOnTap] 决定关不关），
  /// 所以直接把拿到的回调接到你的按钮上就行：
  ///
  /// ```dart
  /// NotificationAction(
  ///   onPressed: retry,
  ///   builder: (BuildContext context, VoidCallback onPressed) =>
  ///       IconButton.filledTonal(
  ///         onPressed: onPressed,
  ///         icon: const Icon(Icons.refresh, size: 16),
  ///         tooltip: '重试',
  ///       ),
  /// )
  /// ```
  ///
  /// 外层兜了一个 [MouseRegion]（用 [NotificationStyle.mouseCursor]），你自己的
  /// 按钮要是设了 `mouseCursor` 就以它为准。
  final NotificationActionBuilder? builder;
}

/// 通知的全部外观与行为配置：宽度、圆角、配色、图标、位置、时长……
///
/// 两种用法：
///
/// * 全局：装 [NotificationHost] 时传一份，作用于所有通知；
/// * 单条：`show(style: ...)` 传一份，**整条替换**全局样式。只改一两项时用
///   `NotificationCenter.style.copyWith(...)` 从当前全局样式派生出新的。
@immutable
class NotificationStyle {
  const NotificationStyle({
    this.width = 360,
    this.margin = const EdgeInsets.all(16),
    this.spacing = 16,
    this.maxVisible = 4,
    this.radius = 8,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 6, 12),
    this.position = NotificationPosition.topRight,
    this.duration = const Duration(seconds: 4),
    this.showProgress = true,
    this.dismissOnTap = false,
    this.mouseCursor = SystemMouseCursors.click,
    this.iconSize = 18,
    this.icon,
    this.accentColor,
    this.animationDuration = const Duration(milliseconds: 220),
    this.elevation = 4,
    this.backgroundColor,
    this.actionMinHeight = 32,
    this.actionPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 8,
    ),
    this.actionTextStyle,
    this.titleStyle,
    this.messageStyle,
  });

  /// 卡片宽度；屏幕更窄时自动收窄。
  final double width;

  /// 卡片组到屏幕（含安全区）的留白。
  final EdgeInsets margin;

  /// 同一边堆叠时卡片之间的间距。
  ///
  /// 默认 16：卡片自己带投影（`elevation`），间距太小时上下两张的影子会在
  /// 缝里接上，看着像一条灰带。
  final double spacing;

  /// 同一时间最多显示几条；超出时**最早**那条自动收起。
  final int maxVisible;

  /// 卡片圆角，默认 8。
  ///
  /// 通知卡片本身不大（默认 360 宽、正文两行），圆角太大会显胖，跟 32 高的按钮
  /// 胶囊、3px 的进度条摆在一起也不协调；想要更圆就自己传。
  final double radius;

  /// 卡片内容的内边距。
  final EdgeInsets padding;

  /// 默认停靠位置。
  final NotificationPosition position;

  /// 默认自动关闭时间；`null` 表示默认不自动关闭。
  final Duration? duration;

  /// 是否在卡片底部画一条倒计时进度条。
  final bool showProgress;

  /// 点卡片正文是否关闭（没设 `onTap` 时生效）。
  final bool dismissOnTap;

  /// 通知里可点部分的鼠标样式：整张卡片、关闭按钮、操作按钮。
  ///
  /// 默认 `SystemMouseCursors.click`（小手）；卡片本身没接任何回调（没有
  /// `onTap`、`dismissOnTap` 也是 `false`）时不会变手，免得骗人。桌面端想统一
  /// 成别的（比如 `SystemMouseCursors.basic`）改这一项。
  final MouseCursor mouseCursor;

  /// 图标 / 转圈的尺寸。
  final double iconSize;

  /// 换掉语义类型自带的图标（不影响配色）。
  final IconData? icon;

  /// 换掉语义类型自带的主色（图标、图标底圈、进度条）。
  final Color? accentColor;

  /// 进出场动画时长。
  final Duration animationDuration;

  /// 卡片投影高度，直接交给 `Material.elevation`；`0` 表示不要阴影（纯色块）。
  ///
  /// 默认 4 而不是 Material 的 1 / 8：卡片之间只隔 [spacing]，再高投影就会把
  /// 缝填成一条灰带，看着像卡片底部多了一道边。
  final double elevation;

  /// 卡片底色；不传用 `ColorScheme.surfaceContainerHigh`（深浅色都适配）。
  final Color? backgroundColor;

  /// 操作按钮（那两颗胶囊）的最小高度。
  ///
  /// 默认 32：比 Material 默认的 40 矮一些，免得按钮在一张两百来像素高的卡片
  /// 里显得过重；但也不能更矮，再小文字就顶到胶囊边上了。
  final double actionMinHeight;

  /// 操作按钮的内边距。左右比上下大，胶囊才不至于被文字撑成一颗圆。
  final EdgeInsets actionPadding;

  /// 操作按钮的文字样式；不传用 13 / `w600`（比正文略小、略粗，跟正文区分）。
  final TextStyle? actionTextStyle;

  final TextStyle? titleStyle;
  final TextStyle? messageStyle;

  /// 派生一份新样式。
  ///
  /// [duration] 传 `null` 表示「沿用原值」；要把倒计时去掉（不自动关闭）用
  /// `clearDuration: true`。
  NotificationStyle copyWith({
    double? width,
    EdgeInsets? margin,
    double? spacing,
    int? maxVisible,
    double? radius,
    EdgeInsets? padding,
    NotificationPosition? position,
    Duration? duration,
    bool clearDuration = false,
    bool? showProgress,
    bool? dismissOnTap,
    MouseCursor? mouseCursor,
    double? iconSize,
    IconData? icon,
    Color? accentColor,
    Duration? animationDuration,
    double? elevation,
    Color? backgroundColor,
    double? actionMinHeight,
    EdgeInsets? actionPadding,
    TextStyle? actionTextStyle,
    TextStyle? titleStyle,
    TextStyle? messageStyle,
  }) {
    return NotificationStyle(
      width: width ?? this.width,
      margin: margin ?? this.margin,
      spacing: spacing ?? this.spacing,
      maxVisible: maxVisible ?? this.maxVisible,
      radius: radius ?? this.radius,
      padding: padding ?? this.padding,
      position: position ?? this.position,
      duration: clearDuration ? null : duration ?? this.duration,
      showProgress: showProgress ?? this.showProgress,
      dismissOnTap: dismissOnTap ?? this.dismissOnTap,
      mouseCursor: mouseCursor ?? this.mouseCursor,
      iconSize: iconSize ?? this.iconSize,
      icon: icon ?? this.icon,
      accentColor: accentColor ?? this.accentColor,
      animationDuration: animationDuration ?? this.animationDuration,
      elevation: elevation ?? this.elevation,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      actionMinHeight: actionMinHeight ?? this.actionMinHeight,
      actionPadding: actionPadding ?? this.actionPadding,
      actionTextStyle: actionTextStyle ?? this.actionTextStyle,
      titleStyle: titleStyle ?? this.titleStyle,
      messageStyle: messageStyle ?? this.messageStyle,
    );
  }
}

/// 一条通知的完整数据：内容 + 可选的样式覆盖。对外只读，改内容请用
/// `handle.update(...)`。
@immutable
class NotificationData {
  const NotificationData({
    required this.id,
    this.title,
    this.message,
    this.content,
    this.kind = NotificationKind.info,
    this.actions = const <NotificationAction>[],
    this.onTap,
    this.style,
    this.closing = false,
    this.revision = 0,
  });

  /// 唯一标识：传了 `id` 就是它，否则是自增的内部值。
  final Object id;

  final String? title;
  final String? message;
  final NotificationKind kind;

  /// 自定义内容，接在标题 / 正文下面。
  final Widget? content;

  /// 底部右侧的操作按钮，按顺序排列；空列表表示没有按钮。
  final List<NotificationAction> actions;

  /// 点整张卡片时触发；不影响关闭逻辑（配合 [NotificationStyle.dismissOnTap]）。
  final VoidCallback? onTap;

  /// 这条自己的样式；`null` 表示跟全局走。
  final NotificationStyle? style;

  /// 已经开始退场动画。
  final bool closing;

  /// 每次 `update` 自增，卡片据此重置倒计时。
  final int revision;

  /// 这条实际生效的样式：自己带了就用自己，否则用全局。
  NotificationStyle effectiveStyle(NotificationStyle global) => style ?? global;

  NotificationData copyWith({bool? closing, int? revision}) {
    return NotificationData(
      id: id,
      title: title,
      message: message,
      content: content,
      kind: kind,
      actions: actions,
      onTap: onTap,
      style: style,
      closing: closing ?? this.closing,
      revision: revision ?? this.revision,
    );
  }
}

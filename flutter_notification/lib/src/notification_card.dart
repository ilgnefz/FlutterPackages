import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'notification_center.dart';
import 'notification_types.dart';

/// 单条通知卡片：进出场动画、倒计时（悬停暂停）、进度条、关闭按钮。
///
/// 一般不直接用，交给 [NotificationCenter] + [NotificationHost] 管理；只有在
/// 需要自定义宿主布局时才需要自己摆它。
class NotificationCard extends StatefulWidget {
  const NotificationCard({
    super.key,
    required this.data,
    required this.style,
    required this.onDismissed,
    this.isLast = true,
  });

  final NotificationData data;

  /// 全局样式；这条自己带了样式时以它为准（`margin` / `spacing` 这类成组
  /// 布局的字段仍用这份）。
  final NotificationStyle style;

  /// 退场动画播完时调用，由宿主把这条从列表里删掉。
  final VoidCallback onDismissed;

  /// 组里的最后一条不加底部间距。
  final bool isLast;

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _curve;

  /// 倒计时；不需要自动关闭时为 null。
  AnimationController? _progress;

  bool _closing = false;
  bool _hovered = false;
  bool _dismissReported = false;

  /// 这条实际生效的样式：自己的覆盖优先，否则跟全局。
  NotificationStyle get _style => widget.data.effectiveStyle(widget.style);

  /// 自动关闭时长：`loading` 永远不自己消失，交给调用方收尾。
  Duration? get _duration =>
      widget.data.kind == NotificationKind.loading ? null : _style.duration;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: _style.animationDuration,
    );
    _curve = CurvedAnimation(
      parent: _enter,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _closing = widget.data.closing;
    _createProgress();
    if (_closing) {
      // 宿主挂载前就被关掉了：不播动画，直接报告移除。
      _reportDismissed();
    } else {
      _enter.forward();
      if (!_hovered) _progress?.forward();
    }
  }

  @override
  void didUpdateWidget(covariant NotificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final NotificationData data = widget.data;
    if (data.revision == oldWidget.data.revision) return;

    if (data.closing && !_closing) {
      _closing = true;
      _progress?.stop();
      _enter.reverse().whenCompleteOrCancel(_reportDismissed);
      return;
    }
    if (!data.closing && _closing) {
      _closing = false;
      _enter.forward();
    }

    // 只有「时长 / 语义」变了才重开倒计时（loading → success 这种）。改文案、
    // 刷进度都接手剩下的时间，不重置，否则反复 update 会让通知永远关不掉。
    if (_duration != _durationOf(oldWidget)) {
      _createProgress();
      if (!_closing && !_hovered) _progress?.forward();
    }
  }

  static Duration? _durationOf(NotificationCard card) =>
      card.data.kind == NotificationKind.loading
      ? null
      : card.data.effectiveStyle(card.style).duration;

  @override
  void dispose() {
    _progress?.dispose();
    _enter.dispose();
    super.dispose();
  }

  void _createProgress() {
    _progress?.dispose();
    final Duration? duration = _duration;
    if (duration == null || duration <= Duration.zero) {
      _progress = null;
      return;
    }
    _progress = AnimationController(vsync: this, duration: duration)
      ..addStatusListener(_onProgressStatus);
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_closing) {
      NotificationCenter.dismiss(widget.data.id);
    }
  }

  void _reportDismissed() {
    if (_dismissReported) return;
    _dismissReported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onDismissed();
    });
  }

  void _setHovered(bool hovered) {
    if (_hovered == hovered) return;
    _hovered = hovered;
    if (_progress == null || _closing) return;
    if (hovered) {
      _progress!.stop();
    } else {
      _progress!.forward();
    }
  }

  void _handleTap() {
    widget.data.onTap?.call();
    if (_style.dismissOnTap) NotificationCenter.dismiss(widget.data.id);
  }

  @override
  Widget build(BuildContext context) {
    final NotificationData data = widget.data;
    final NotificationStyle style = _style;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color accent = style.accentColor ?? _accentOf(scheme, data.kind);
    final Color background =
        style.backgroundColor ?? scheme.surfaceContainerHigh;
    final Offset begin = _enterOffset(style.position);
    final Widget? bar = _buildProgressBar(accent, style);
    final List<NotificationAction> actions = data.actions;
    // 有按钮时正文的下内边距收小一点，把按钮当成同一块内容的最后一行。
    final EdgeInsets bodyPadding = actions.isEmpty
        ? style.padding
        : style.padding.copyWith(bottom: 6);
    // 给投影留的余量：裁剪盒比卡片四周各大这么多，阴影才不会被切成直角。
    final double shadowRoom = style.elevation <= 0
        ? 0
        : style.elevation * 2 + 4;

    return AnimatedBuilder(
      animation: _curve,
      // 卡片只在进场那一帧被建一次，后面每帧只是改裁剪盒的高度和层偏移。
      child: Padding(
        padding: EdgeInsets.only(
          bottom: widget.isLast ? 0 : widget.style.spacing,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(_curve),
          child: FadeTransition(
            opacity: _curve,
            // 卡片自己一层：倒计时进度条每帧都在动，不能让它把整棵树带走。
            child: RepaintBoundary(
              child: Semantics(
                liveRegion: true,
                container: true,
                child: Material(
                  // 阴影、圆角、裁剪都交给 Material：投影跟着圆角走，也跟主题的
                  // shadowColor 一致。`surfaceTintColor` 关掉，免得 elevation
                  // 把 style 里指定的背景色染上一层主题色。
                  type: MaterialType.card,
                  color: background,
                  surfaceTintColor: Colors.transparent,
                  elevation: style.elevation,
                  borderRadius: BorderRadius.circular(style.radius),
                  clipBehavior: Clip.antiAlias,
                  child: MouseRegion(
                    onEnter: (_) => _setHovered(true),
                    onExit: (_) => _setHovered(false),
                    child: InkWell(
                      onTap: _handleTap,
                      // 卡片没接任何回调时别变小手：点了什么也不会发生。
                      mouseCursor:
                          data.onTap != null || style.dismissOnTap
                          ? style.mouseCursor
                          : MouseCursor.defer,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Padding(
                            padding: bodyPadding,
                            child: _buildBody(scheme, data, style, accent),
                          ),
                          if (actions.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(
                                // 右下角的按钮自己就是边界，左右用同一个缩进，
                                // 免得胶囊贴着圆角那一段弧线。
                                left: style.padding.left,
                                right: style.padding.left,
                                bottom: math.max(0, style.padding.bottom - 4),
                              ),
                              child: _buildActions(actions, data, style),
                            ),
                          ?bar,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      builder: (BuildContext context, Widget? child) {
        // 用「裁剪 + Align」自己收缩高度，而不是 SizeTransition：后者内部的
        // ClipRect 正好卡在卡片边界上，会把 Material 的投影切成一个直角矩形
        //（底部没阴影、左右是硬边）。
        return ClipRect(
          clipper: _ShadowRoomClip(shadowRoom),
          child: Align(
            alignment: style.position.isTop
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            heightFactor: _curve.value,
            // Align 会给子组件松约束，这里把宽度重新拉满。
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: double.infinity),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    ColorScheme scheme,
    NotificationData data,
    NotificationStyle style,
    Color accent,
  ) {
    final Widget? leading = _buildLeading(data, style, accent);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (leading != null) ...<Widget>[leading, const SizedBox(width: 10)],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 3,
            children: <Widget>[
              if (data.title case final String title)
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style:
                      style.titleStyle ??
                      TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: scheme.onSurface,
                      ),
                ),
              if (data.message case final String message)
                Text(
                  message,
                  style:
                      style.messageStyle ??
                      TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              if (data.content case final Widget content) content,
            ],
          ),
        ),
        const SizedBox(width: 2),
        IconButton(
          onPressed: () => NotificationCenter.dismiss(data.id),
          icon: const Icon(Icons.close_rounded, size: 16),
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          tooltip: '关闭',
          style: IconButton.styleFrom(
            minimumSize: const Size(26, 26),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ).copyWith(
            mouseCursor: WidgetStatePropertyAll<MouseCursor>(style.mouseCursor),
          ),
        ),
      ],
    );
  }

  /// 底部右侧的操作按钮：一个或多个，窄了自动折行。
  ///
  /// 用的是 `TextButton`（主操作换成实心 `FilledButton`），但把 Material 默认
  /// 的 40 高、横向 24 的宽松内边距都收掉了——卡片里没那么多地方。胶囊的高度
  /// 由 [NotificationStyle.actionMinHeight] 和 [NotificationStyle.actionPadding]
  /// 决定，两者一起保证文字上下不会顶到胶囊边上。
  Widget _buildActions(
    List<NotificationAction> actions,
    NotificationData data,
    NotificationStyle style,
  ) {
    final TextStyle textStyle = _actionTextStyle(Theme.of(context), style);
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 6,
        children: <Widget>[
          for (final NotificationAction action in actions)
            if (action.builder case final NotificationActionBuilder builder)
              // 用户自己画的按钮：外层兜个光标，里面自己设了 MouseRegion 就以
              // 里面的为准（光标永远由最内层的 MouseRegion 决定）。
              MouseRegion(
                cursor: style.mouseCursor,
                child: builder(context, () => _runAction(action, data)),
              )
            else if (action.isPrimary)
              FilledButton(
                onPressed: () => _runAction(action, data),
                style: _actionStyle(
                  primary: true,
                  style: style,
                  textStyle: textStyle,
                  override: action.style,
                ),
                child: Text(action.label ?? ''),
              )
            else
              TextButton(
                onPressed: () => _runAction(action, data),
                style: _actionStyle(
                  primary: false,
                  style: style,
                  textStyle: textStyle,
                  override: action.style,
                ),
                child: Text(action.label ?? ''),
              ),
        ],
      ),
    );
  }

  void _runAction(NotificationAction action, NotificationData data) {
    action.onPressed();
    if (action.closeOnTap) NotificationCenter.dismiss(data.id);
  }

  /// 按钮文字：在主题的 `labelLarge` 上收小一号，这样自定义字体（`fontFamily`）
  /// 还能接着用——直接给一个裸 [TextStyle] 会把主题的字体族一起抹掉，文字会掉回
  /// 引擎的默认字体。
  static TextStyle _actionTextStyle(ThemeData theme, NotificationStyle style) {
    final TextStyle base = theme.textTheme.labelLarge ?? const TextStyle();
    if (style.actionTextStyle case final TextStyle custom) {
      return base.merge(custom);
    }
    return base.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.normal,
      height: 1.2,
      letterSpacing: 0,
    );
  }

  static ButtonStyle _actionStyle({
    required bool primary,
    required NotificationStyle style,
    required TextStyle textStyle,
    ButtonStyle? override,
  }) {
    // 胶囊：`StadiumBorder` 显式指定，主题换成方角 / 大圆角时按钮也不会跟着变，
    // 免得两颗按钮和卡片的圆角互相对不上。
    final ButtonStyle base = primary
        ? FilledButton.styleFrom(
            padding: style.actionPadding,
            minimumSize: Size(0, style.actionMinHeight),
            shape: const StadiumBorder(),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: textStyle,
          ).copyWith(
            mouseCursor: WidgetStatePropertyAll<MouseCursor>(style.mouseCursor),
          )
        : TextButton.styleFrom(
            padding: style.actionPadding,
            minimumSize: Size(0, style.actionMinHeight),
            shape: const StadiumBorder(),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: textStyle,
          ).copyWith(
            mouseCursor: WidgetStatePropertyAll<MouseCursor>(style.mouseCursor),
          );
    return override == null ? base : base.merge(override);
  }

  Widget? _buildLeading(
    NotificationData data,
    NotificationStyle style,
    Color accent,
  ) {
    final double iconSize = style.iconSize;
    final double box = iconSize + 12;
    if (data.kind == NotificationKind.loading) {
      return SizedBox(
        width: box,
        height: box,
        child: Center(
          child: SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          ),
        ),
      );
    }
    final IconData? icon = style.icon ?? _defaultIcon(data.kind);
    if (icon == null) return null;
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: iconSize, color: accent),
    );
  }

  Widget? _buildProgressBar(Color accent, NotificationStyle style) {
    final AnimationController? progress = _progress;
    if (progress == null || !style.showProgress) return null;
    // 铺满整条底边，由卡片自己的圆角裁剪收边：底边直线段正好是
    // `[radius, width - radius]`，两端多出来的 `2 * radius` 落在圆角里，顺着弧线
    // 变薄。自己留白（左右各让 radius，长度 = 宽度 - 圆角 * 2）会在两个下角各留
    // 一块卡片底色的缺口，看着像进度条没铺满；端点切平会露出 90° 直角块；端点
    // 做胶囊又会把条缩短。`borderRadius: zero` 是防止主题里给进度条设了圆角。
    const double height = 3;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: AnimatedBuilder(
        animation: progress,
        builder: (BuildContext context, Widget? child) {
          return LinearProgressIndicator(
            value: 1 - progress.value,
            minHeight: height,
            borderRadius: BorderRadius.zero,
            backgroundColor: accent.withValues(alpha: 0.12),
            color: accent,
          );
        },
      ),
    );
  }

  static Color _accentOf(ColorScheme scheme, NotificationKind kind) {
    return switch (kind) {
      NotificationKind.success => const Color(0xFF16A34A),
      NotificationKind.error => scheme.error,
      NotificationKind.warning => const Color(0xFFD97706),
      NotificationKind.info => const Color(0xFF2563EB),
      NotificationKind.loading => scheme.primary,
      NotificationKind.plain => scheme.onSurfaceVariant,
    };
  }

  static IconData? _defaultIcon(NotificationKind kind) {
    return switch (kind) {
      NotificationKind.success => Icons.check_circle_outline_rounded,
      NotificationKind.error => Icons.error_outline_rounded,
      NotificationKind.warning => Icons.warning_amber_rounded,
      NotificationKind.info => Icons.info_outline_rounded,
      NotificationKind.loading => null,
      NotificationKind.plain => null,
    };
  }

  static Offset _enterOffset(NotificationPosition position) {
    return switch (position) {
      NotificationPosition.topLeft ||
      NotificationPosition.bottomLeft => const Offset(-0.12, 0),
      NotificationPosition.topRight ||
      NotificationPosition.bottomRight => const Offset(0.12, 0),
      NotificationPosition.topCenter => const Offset(0, -0.35),
      NotificationPosition.bottomCenter => const Offset(0, 0.35),
    };
  }
}

/// 裁剪盒比组件四处各大 [room]：卡片自己的投影画在边界之外，按原尺寸裁会
/// 被切成一个带直角的矩形（底部没有阴影、左右是硬边）。这里只在进场 / 退场
/// 收缩高度时裁，并且给投影留出余量。
class _ShadowRoomClip extends CustomClipper<Rect> {
  const _ShadowRoomClip(this.room);

  final double room;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-room, -room, size.width + room, size.height + room);

  @override
  bool shouldReclip(_ShadowRoomClip oldClipper) => oldClipper.room != room;
}

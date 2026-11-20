part of '../flutter_anchored_overlay.dart';

// ── 带箭头的形状 ────────────────────────────────────────────────────────────

/// 一个「圆角矩形 + 从某条边伸出来的小三角」的 [ShapeBorder]。
///
/// 之所以写成 ShapeBorder 而不是单独画个三角形贴上去，是因为
/// [ShapeDecoration] 会拿 `getOuterPath` 去画**填充和阴影**：箭头因此和
/// 主体是同一条轮廓，交界处不会有缝，边框也不会在三角底下横穿一条线。
///
/// `rect` 是气泡整体（**包含**箭头占的那一条），主体在 [arrowSide] 那一侧
/// 内缩 [arrowHeight]；[PopoverStyle.padding] 会相应再加一段留白。
@immutable
class PopoverShapeBorder extends ShapeBorder {
  const PopoverShapeBorder({
    this.radius = 12.0,
    this.arrowSide = PopoverArrowSide.none,
    this.arrowWidth = 14.0,
    this.arrowHeight = 7.0,
    this.arrowOffset = 0.0,
    this.side = BorderSide.none,
  });

  /// 圆角半径。
  final double radius;

  /// 箭头在哪条边；[PopoverArrowSide.none] 就是普通圆角矩形。
  final PopoverArrowSide arrowSide;

  /// 三角底边宽度。
  final double arrowWidth;

  /// 三角高度。
  final double arrowHeight;

  /// 三角中心沿该边的坐标，相对 `rect` 的左 / 上边缘。
  final double arrowOffset;

  /// 描边；[BorderSide.none] 表示不画。
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  Path _path(Rect rect) {
    if (rect.width <= 0 || rect.height <= 0) {
      return Path()..addRect(rect);
    }
    final bool hasArrow = arrowSide != PopoverArrowSide.none && arrowHeight > 0;
    // 气泡很矮 / 很窄时别让箭头把主体挤没。
    final double ah = hasArrow
        ? math.min(arrowHeight, (rect.shortestSide / 3.0))
        : 0.0;
    final double aw = math.min(arrowWidth, rect.shortestSide);

    late final Rect body;
    switch (arrowSide) {
      case PopoverArrowSide.top:
        body = Rect.fromLTWH(
          rect.left,
          rect.top + ah,
          rect.width,
          rect.height - ah,
        );
        break;
      case PopoverArrowSide.bottom:
        body = Rect.fromLTWH(
          rect.left,
          rect.top,
          rect.width,
          rect.height - ah,
        );
        break;
      case PopoverArrowSide.left:
        body = Rect.fromLTWH(
          rect.left + ah,
          rect.top,
          rect.width - ah,
          rect.height,
        );
        break;
      case PopoverArrowSide.right:
        body = Rect.fromLTWH(
          rect.left,
          rect.top,
          rect.width - ah,
          rect.height,
        );
        break;
      case PopoverArrowSide.none:
        body = rect;
        break;
    }

    final double r = math.max(
      0.0,
      math.min(radius, math.min(body.width, body.height) / 2.0),
    );
    final Path bodyPath = Path()
      ..addRRect(RRect.fromRectAndRadius(body, Radius.circular(r)));
    if (!hasArrow || ah <= 0 || aw <= 0) return bodyPath;

    final double half = aw / 2.0;
    final Path arrow = Path();
    switch (arrowSide) {
      case PopoverArrowSide.top:
        final double c = rect.left + arrowOffset;
        arrow
          ..moveTo(c - half, body.top)
          ..lineTo(c, rect.top)
          ..lineTo(c + half, body.top)
          ..close();
        break;
      case PopoverArrowSide.bottom:
        final double c = rect.left + arrowOffset;
        arrow
          ..moveTo(c - half, body.bottom)
          ..lineTo(c, rect.bottom)
          ..lineTo(c + half, body.bottom)
          ..close();
        break;
      case PopoverArrowSide.left:
        final double c = rect.top + arrowOffset;
        arrow
          ..moveTo(body.left, c - half)
          ..lineTo(rect.left, c)
          ..lineTo(body.left, c + half)
          ..close();
        break;
      case PopoverArrowSide.right:
        final double c = rect.top + arrowOffset;
        arrow
          ..moveTo(body.right, c - half)
          ..lineTo(rect.right, c)
          ..lineTo(body.right, c + half)
          ..close();
        break;
      case PopoverArrowSide.none:
        break;
    }
    // union 之后是**一条**外轮廓，描边不会在三角底部留下多余的横线。
    return Path.combine(PathOperation.union, bodyPath, arrow);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side == BorderSide.none || side.width <= 0) return;
    canvas.drawPath(
      getOuterPath(rect, textDirection: textDirection),
      side.toPaint(),
    );
  }

  @override
  ShapeBorder scale(double t) => PopoverShapeBorder(
    radius: radius * t,
    arrowSide: arrowSide,
    arrowWidth: arrowWidth * t,
    arrowHeight: arrowHeight * t,
    arrowOffset: arrowOffset,
    side: side.scale(t),
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a == null) return scale(t);
    if (a is PopoverShapeBorder) return PopoverShapeBorder.lerp(a, this, t);
    return null;
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b == null) return scale(1.0 - t);
    if (b is PopoverShapeBorder) return PopoverShapeBorder.lerp(this, b, t);
    return null;
  }

  /// 两个形状之间的线性插值；箭头边不一致时在半程切换，避免画出两个箭头。
  static PopoverShapeBorder lerp(
    PopoverShapeBorder a,
    PopoverShapeBorder b,
    double t,
  ) {
    double mix(double x, double y) => x + (y - x) * t;
    return PopoverShapeBorder(
      radius: mix(a.radius, b.radius),
      arrowSide: t < 0.5 ? a.arrowSide : b.arrowSide,
      arrowWidth: mix(a.arrowWidth, b.arrowWidth),
      arrowHeight: mix(a.arrowHeight, b.arrowHeight),
      arrowOffset: mix(a.arrowOffset, b.arrowOffset),
      side: BorderSide.lerp(a.side, b.side, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PopoverShapeBorder &&
      other.radius == radius &&
      other.arrowSide == arrowSide &&
      other.arrowWidth == arrowWidth &&
      other.arrowHeight == arrowHeight &&
      other.arrowOffset == arrowOffset &&
      other.side == side;

  @override
  int get hashCode => Object.hash(
    radius,
    arrowSide,
    arrowWidth,
    arrowHeight,
    arrowOffset,
    side,
  );

  @override
  String toString() => 'PopoverShapeBorder($arrowSide @ $arrowOffset)';
}

// ── 动画帧 ────────────────────────────────────────────────────────────────

double _remap(double v, double from, double to) =>
    ((v - from) / (to - from)).clamp(0.0, 1.0).toDouble();

double _smooth(double t) => t * t * (3.0 - 2.0 * t);

@immutable
class _Frame {
  const _Frame({
    required this.opacity,
    required this.scale,
    required this.slide,
    required this.alignment,
  });

  final double opacity;
  final double scale;
  final Offset slide;
  final Alignment alignment;
}

/// 一个 u（线性）+ 一个 p（缓动）驱动整块气泡：
/// * 淡入淡出用 u，首尾不被曲线压缩；
/// * 缩放 / 位移用 p，跟揭示节奏走；
/// * 缩放原点放在箭头那条边，气泡看起来是「从触发器长出来」的。
///
/// 淡入特意延后到 18% 才开始：打开后第一帧要测量气泡尺寸才能算准位置，
/// 这段不可见的时间正好让测量结果先落地，不会出现「先出现在错位置、
/// 再跳过去」。
_Frame _popoverFrame({
  required double u,
  required double p,
  required bool reduce,
  required PopoverArrowSide arrowSide,
  required double scaleBegin,
  required double slideDistance,
}) {
  final double opacity = _smooth(_remap(u, 0.18, 0.62));
  final double scale = reduce ? 1.0 : scaleBegin + (1.0 - scaleBegin) * p;
  Offset slide = Offset.zero;
  Alignment alignment = Alignment.center;
  if (!reduce) {
    final double d = slideDistance * (1.0 - p);
    switch (arrowSide) {
      case PopoverArrowSide.top:
        slide = Offset(0, -d);
        alignment = const Alignment(0, -1);
        break;
      case PopoverArrowSide.bottom:
        slide = Offset(0, d);
        alignment = const Alignment(0, 1);
        break;
      case PopoverArrowSide.left:
        slide = Offset(-d, 0);
        alignment = const Alignment(-1, 0);
        break;
      case PopoverArrowSide.right:
        slide = Offset(d, 0);
        alignment = const Alignment(1, 0);
        break;
      case PopoverArrowSide.none:
        break;
    }
  }
  return _Frame(
    opacity: opacity,
    scale: scale,
    slide: slide,
    alignment: alignment,
  );
}

// ── 气泡外观 ──────────────────────────────────────────────────────────────

class _PopoverBubble extends StatelessWidget {
  const _PopoverBubble({
    required this.frame,
    required this.style,
    required this.position,
    required this.onSize,
    required this.child,
  });

  final _Frame frame;
  final PopoverStyle style;
  final PopoverPosition position;
  final ValueChanged<Size> onSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color background =
        style.backgroundColor ?? scheme.surfaceContainerHighest;
    final Color foreground = style.foregroundColor ?? scheme.onSurface;
    final Color border =
        style.borderColor ?? scheme.outline.withValues(alpha: 0.35);
    final Color shadow = style.shadowColor ?? scheme.shadow;

    final double arrowHeight = style.showArrow ? style.arrowHeight : 0.0;
    EdgeInsets arrowPadding = EdgeInsets.zero;
    switch (position.arrowSide) {
      case PopoverArrowSide.top:
        arrowPadding = EdgeInsets.only(top: arrowHeight);
        break;
      case PopoverArrowSide.bottom:
        arrowPadding = EdgeInsets.only(bottom: arrowHeight);
        break;
      case PopoverArrowSide.left:
        arrowPadding = EdgeInsets.only(left: arrowHeight);
        break;
      case PopoverArrowSide.right:
        arrowPadding = EdgeInsets.only(right: arrowHeight);
        break;
      case PopoverArrowSide.none:
        break;
    }

    final BorderSide side = style.borderWidth > 0
        ? BorderSide(color: border, width: style.borderWidth)
        : BorderSide.none;
    final ShapeBorder shape = PopoverShapeBorder(
      radius: style.radius,
      arrowSide: position.arrowSide,
      arrowWidth: style.arrowWidth,
      arrowHeight: arrowHeight,
      arrowOffset: position.arrowOffset,
      side: side,
    );

    return Opacity(
      opacity: frame.opacity,
      child: Transform.translate(
        offset: frame.slide,
        child: Transform.scale(
          scale: frame.scale,
          alignment: frame.alignment,
          // 浮层挂在 Overlay 上：没有 Material 的话，里面的 Text 会拿到
          // 原始样式（黄字带下划线），InkWell 也画不出水波纹。
          child: Material(
            type: MaterialType.transparency,
            textStyle:
                (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
              color: foreground,
            ),
            child: DecoratedBox(
              key: kPopoverBubbleKey,
              decoration: ShapeDecoration(
                color: background,
                shape: shape,
                shadows: <BoxShadow>[
                  BoxShadow(
                    color: shadow.withValues(alpha: style.shadowOpacity),
                    blurRadius: style.shadowBlurRadius,
                    offset: style.shadowOffset,
                  ),
                ],
              ),
              child: _SizeReporter(
                onSize: onSize,
                child: Padding(
                  key: kPopoverContentKey,
                  padding: style.padding.add(arrowPadding),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 尺寸上报 ──────────────────────────────────────────────────────────────

/// 气泡内容是任意 Widget，宽度 / 高度没法提前假定。这里在布局之后把真实
/// 尺寸抛给 State，用来做贴边夹取与箭头对齐。
///
/// 注意不能在 `performLayout` 里直接 setState：那会撞上「build 期间标记
/// 需要 build」。统一丢到 post-frame，且只在尺寸真的变了时通知。
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize: onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter({required this.onSize});

  ValueChanged<Size> onSize;

  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    final RenderBox? childBox = child;
    if (childBox == null) return;
    final Size size = childBox.size;
    if (size == _lastSize) return;
    _lastSize = size;
    final ValueChanged<Size> report = onSize;
    WidgetsBinding.instance.addPostFrameCallback((_) => report(size));
  }
}

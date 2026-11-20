part of 'anchored_dropdown.dart';

/// 三种揭示动画共用的裁切器。
///
/// 关键点：**不给「当前可见的矮矩形」重新倒圆角**。可见矩形在动画早期可能
/// 只有几像素高，`RRect` 会把放不下的半径等比缩小，于是圆角会跟着裁切
/// 前沿一起「长」出来。这里始终用完整面板的圆角外框与可见区域求交：
/// 四角恒为 [radius]，只是暂时被裁切线挡住，前沿保持直线。
///
/// * [DropdownReveal.unfold]：水平裁切线从贴合触发器的一侧推进。
/// * [DropdownReveal.topLeftToBottomRight] /
///   [DropdownReveal.topRightToBottomLeft]：
///   在归一化坐标里用 `u + v <= t` 定义一条斜线，`t` 随 p 从 0 → 2，
///   于是可见区从起始角沿对角线扩展到对角，斜线斜率按面板宽高自适应
///   （不是固定的 45° 像素线）。
class DropdownRevealClipper extends CustomClipper<Path> {
  const DropdownRevealClipper({
    required this.progress,
    this.reveal = DropdownReveal.unfold,
    this.radius = 12.0,
    this.lip = 8.0,
    this.placedAbove = false,
  });

  /// 已 clamp 的展开进度 0 → 1。
  final double progress;

  final DropdownReveal reveal;

  /// 四角半径，全程固定。
  final double radius;

  /// p = 0 时保留的可见量：[DropdownReveal.unfold] 是薄边厚度，斜向模式
  /// 是起始角小三角的两条直角边长（像素）。
  final double lip;

  /// 面板是否翻到触发器上方（只影响 [DropdownReveal.unfold] 的推进方向）。
  final bool placedAbove;

  Path _outline(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    );

  /// [unfold]：CSS `inset(…)` 的水平揭示。
  Path _unfold(Size size, double p) {
    final double hidden = math.max(0.0, (size.height - lip) * (1.0 - p));
    final Rect visible = placedAbove
        ? Rect.fromLTWH(0, hidden, size.width, size.height - hidden)
        : Rect.fromLTWH(0, 0, size.width, size.height - hidden);
    return Path()..addRect(visible);
  }

  /// 斜向揭示。`fromRight = true` 时把归一化横坐标镜像，起点换成右上角。
  Path _diagonal(Size size, double p, bool fromRight) {
    final double w = size.width;
    final double h = size.height;
    // 起始时露出起始角一个 lip × lip 左右的小三角；p = 1 时 t = 2，
    // 刚好覆盖整个矩形（归一化坐标下最大 u + v = 2）。
    final double t0 = (lip / w + lip / h).clamp(0.0, 2.0);
    final double t = _lerp(t0, 2.0, p);

    final List<Offset> unit;
    if (t <= 1.0) {
      // 三角形：(0,0) — (t,0) — (0,t)
      unit = <Offset>[Offset.zero, Offset(t, 0), Offset(0, t)];
    } else {
      // 五边形 = 单位正方形减去靠近 (1,1) 的小三角。
      unit = <Offset>[
        Offset.zero,
        const Offset(1, 0),
        Offset(1, t - 1),
        Offset(t - 1, 1),
        const Offset(0, 1),
      ];
    }

    return Path()..addPolygon(<Offset>[
      for (final Offset o in unit)
        Offset(fromRight ? w * (1.0 - o.dx) : w * o.dx, h * o.dy),
    ], true);
  }

  @override
  Path getClip(Size size) {
    final Path outline = _outline(size);
    if (size.width <= 0 || size.height <= 0) return outline;

    final double p = progress.clamp(0.0, 1.0);
    if (p >= 1.0) return outline; // CSS: clipPath: none

    final Path visible = switch (reveal) {
      DropdownReveal.unfold => _unfold(size, p),
      DropdownReveal.topLeftToBottomRight => _diagonal(size, p, false),
      DropdownReveal.topRightToBottomLeft => _diagonal(size, p, true),
    };
    return Path.combine(PathOperation.intersect, outline, visible);
  }

  @override
  bool shouldReclip(DropdownRevealClipper oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.reveal != reveal ||
      oldClipper.radius != radius ||
      oldClipper.lip != lip ||
      oldClipper.placedAbove != placedAbove;
}

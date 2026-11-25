part of '../flutter_context_menu.dart';

// ── 揭示动画：起点解析 + 裁切器 + 每帧派生量 ──────────────────────────────

/// 揭示动画的**起点**：面板上最靠近锚点（鼠标位置 / 父菜单行）的角或边。
///
/// 四个角对应斜向揭示，两条边对应 `ContextMenuReveal.unfold` 的轴向揭示。
enum ContextMenuRevealOrigin {
  /// 左上角 → 右下角。菜单在锚点的右下方（默认情形）。
  topLeft,

  /// 右上角 → 左下角。菜单被翻到锚点左侧。
  topRight,

  /// 左下角 → 右上角。菜单被翻到锚点上方。
  bottomLeft,

  /// 右下角 → 左上角。菜单被翻到锚点左上方。
  bottomRight,

  /// 从顶边往下揭开（菜单在锚点下方）。
  top,

  /// 从底边往上揭开（菜单在锚点上方）。
  bottom,
}

/// 把「配置的动画 + 实际落位」解析成起点。
///
/// `flippedX = true` 表示菜单落在锚点左侧 → 起点贴右；`flippedY = true`
/// 表示菜单落在锚点上方 → 起点贴下。所以：
///
/// | 落位 | [ContextMenuReveal.corner] 起点 | 展开方向 |
/// |---|---|---|
/// | 右下（默认） | 左上 | ↘ 右下 |
/// | 左下 | 右上 | ↙ 左下 |
/// | 右上 | 左下 | ↗ 右上 |
/// | 左上 | 右下 | ↖ 左上 |
///
/// [ContextMenuReveal.unfold] 也只看纵向落位：菜单在锚点下方从顶边往下揭，
/// 翻到上方从底边往上揭。横向翻不翻都不影响，见 [_resolveUnfoldOrigin]。
ContextMenuRevealOrigin resolveContextMenuRevealOrigin(
  ContextMenuReveal reveal,
  ContextMenuPlacement placement,
) {
  final bool right = placement.flippedX;
  final bool bottom = placement.flippedY;
  return switch (reveal) {
    ContextMenuReveal.corner => switch ((right, bottom)) {
      (false, false) => ContextMenuRevealOrigin.topLeft,
      (true, false) => ContextMenuRevealOrigin.topRight,
      (false, true) => ContextMenuRevealOrigin.bottomLeft,
      (true, true) => ContextMenuRevealOrigin.bottomRight,
    },
    ContextMenuReveal.unfold => _resolveUnfoldOrigin(placement),
    ContextMenuReveal.topLeftToBottomRight => ContextMenuRevealOrigin.topLeft,
    ContextMenuReveal.topRightToBottomLeft => ContextMenuRevealOrigin.topRight,
    ContextMenuReveal.bottomLeftToTopRight =>
      ContextMenuRevealOrigin.bottomLeft,
    ContextMenuReveal.bottomRightToTopLeft =>
      ContextMenuRevealOrigin.bottomRight,
  };
}

/// 「贴边揭开」的起点：**永远走垂直轴**，面板从上边往下、或从下边往上整块
/// 展开，和 `TextDropdown` 在触发器下方展开时一模一样。
///
/// 只有一个轴是刻意的：
///
/// * 菜单落在指针右下方 → 锚点在面板左上角 → 从**上边**往下揭；
/// * 靠近屏幕右边缘、菜单翻到指针**左侧** → 锚点在面板右上角，但上边照样
///   贴着手指，仍然是往下揭。横向翻转只改变面板的位置，不该改变「往下展开」
///   这个读法，否则同一个菜单在屏幕右边会突然变成左右滑进来；
/// * 菜单放不下、翻到**上方** → 锚点在面板左下角 → 从**下边**往上揭；
/// * 子菜单同理：虽然贴着父菜单的侧边横向长出来，揭开的轴仍是垂直的，不因
///   为方向是横向就改成左右揭。
ContextMenuRevealOrigin _resolveUnfoldOrigin(ContextMenuPlacement placement) =>
    placement.flippedY
    ? ContextMenuRevealOrigin.bottom
    : ContextMenuRevealOrigin.top;

/// 与 `dropdown` 同款的揭示裁切器。
///
/// 关键点：**不给「当前可见的矮矩形 / 小三角」重新倒圆角**。始终用完整面板
/// 的圆角外框与可见区域求交，四个圆角在任何一帧都恒为 [radius]，只是暂时
/// 被裁切线挡住，前沿保持直线。
///
/// * 角起点：归一化坐标里用 `u + v <= t` 定义斜线，`t` 随 progress 从
///   `t0` 到 2，于是可见区从起点角沿对角线扫到对角，斜率按面板宽高自适应。
/// * 边起点：沿垂直轴推进的一条裁切线，从贴近锚点的上边 / 下边揭开。
class ContextMenuRevealClipper extends CustomClipper<Path> {
  const ContextMenuRevealClipper({
    required this.progress,
    required this.origin,
    this.radius = 10,
    this.lip = 8,
  });

  /// 已 clamp 的展开进度 0 → 1。收起时由同一个值递减即可，无需反向裁切器。
  final double progress;

  final ContextMenuRevealOrigin origin;

  /// 四角半径，全程固定。
  final double radius;

  /// progress = 0 时保留的可见量：角起点是三角的两条直角边，边起点是薄边厚度。
  final double lip;

  bool get _isCorner => switch (origin) {
    ContextMenuRevealOrigin.topLeft ||
    ContextMenuRevealOrigin.topRight ||
    ContextMenuRevealOrigin.bottomLeft ||
    ContextMenuRevealOrigin.bottomRight => true,
    ContextMenuRevealOrigin.top || ContextMenuRevealOrigin.bottom => false,
  };

  bool get _fromRight => switch (origin) {
    ContextMenuRevealOrigin.topRight ||
    ContextMenuRevealOrigin.bottomRight => true,
    _ => false,
  };

  bool get _fromBottom => switch (origin) {
    ContextMenuRevealOrigin.bottomLeft ||
    ContextMenuRevealOrigin.bottomRight ||
    ContextMenuRevealOrigin.bottom => true,
    _ => false,
  };

  Path _outline(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    );

  /// 斜向揭示：先在单位正方形里从 (0,0) 沿对角线扫开，再按起点角做
  /// 水平 / 垂直镜像，把 (0,0) 映射到面板的那个角。
  Path _diagonal(Size size, double p) {
    final double w = size.width;
    final double h = size.height;
    // progress = 0 时露出起点角一个 lip × lip 的小三角；p = 1 时 t = 2，
    // 刚好覆盖整个矩形（归一化坐标下最大 u + v = 2）。
    final double t0 = (lip / w + lip / h).clamp(0.0, 2.0);
    final double t = _lerp(t0, 2.0, p);

    final List<Offset> unit;
    if (t <= 1.0) {
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
        Offset(
          _fromRight ? w * (1.0 - o.dx) : w * o.dx,
          _fromBottom ? h * (1.0 - o.dy) : h * o.dy,
        ),
    ], true);
  }

  /// 轴向揭示：只沿垂直轴推进裁切线（上边往下 / 下边往上）。
  Path _unfold(Size size, double p) {
    final double w = size.width;
    final double h = size.height;
    final double hidden = math.max(0.0, (h - lip) * (1.0 - p));

    final Rect visible = switch (origin) {
      ContextMenuRevealOrigin.top => Rect.fromLTWH(0, 0, w, h - hidden),
      ContextMenuRevealOrigin.bottom => Rect.fromLTWH(0, hidden, w, h - hidden),
      _ => Offset.zero & size,
    };
    return Path()..addRect(visible);
  }

  @override
  Path getClip(Size size) {
    final Path outline = _outline(size);
    if (size.width <= 0 || size.height <= 0) return outline;

    final double p = progress.clamp(0.0, 1.0);
    if (p >= 1.0) return outline; // 完全展开后不留裁切，形状不会跳变

    final Path visible = _isCorner ? _diagonal(size, p) : _unfold(size, p);
    return Path.combine(PathOperation.intersect, outline, visible);
  }

  @override
  bool shouldReclip(ContextMenuRevealClipper oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.origin != origin ||
      oldClipper.radius != radius ||
      oldClipper.lip != lip;
}

// ── 一帧里由同一个进度推导出的全部动画量 ──────────────────────────────────

/// 展开曲线：全程稳定推进、收尾柔和、无过冲；收起用它的时间镜像。
const Cubic _kMenuRevealCurve = Cubic(0.25, 0.46, 0.45, 0.94);

/// 分离位移用的对称缓动。
const Cubic _kMenuSoftCurve = Cubic(0.4, 0.0, 0.2, 1.0);

/// 淡入 / 行内容 / 阴影的短缓出。
const Cubic _kMenuEaseOut = Cubic(0.16, 1.0, 0.3, 1.0);

const FlippedCurve _kMenuRevealReverse = FlippedCurve(_kMenuRevealCurve);

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// `useTransform(v, [from, to], [0, 1])`，两端 clamp。
double _remap(double v, double from, double to) =>
    ((v - from) / (to - from)).clamp(0.0, 1.0);

/// 起点相对面板中心的单位方向，用来让「位移」「行内容位移」都指向锚点。
Offset _originUnit(ContextMenuRevealOrigin origin) {
  final double x = switch (origin) {
    ContextMenuRevealOrigin.topLeft ||
    ContextMenuRevealOrigin.bottomLeft => -1.0,
    ContextMenuRevealOrigin.topRight ||
    ContextMenuRevealOrigin.bottomRight => 1.0,
    ContextMenuRevealOrigin.top || ContextMenuRevealOrigin.bottom => 0.0,
  };
  final double y = switch (origin) {
    ContextMenuRevealOrigin.topLeft ||
    ContextMenuRevealOrigin.topRight ||
    ContextMenuRevealOrigin.top => -1.0,
    ContextMenuRevealOrigin.bottomLeft ||
    ContextMenuRevealOrigin.bottomRight ||
    ContextMenuRevealOrigin.bottom => 1.0,
  };
  return Offset(x, y);
}

@immutable
class _ContextMenuFrame {
  const _ContextMenuFrame({
    required this.p,
    required this.opacity,
    required this.shadow,
    required this.rowsOpacity,
    required this.offset,
    required this.rowsOffset,
    required this.scale,
    required this.origin,
    required this.reduce,
  });

  /// 缓动后的主线进度：裁切、位移、阴影都跟着它走。
  final double p;

  /// 整体淡入（用线性时间，显示与隐藏的首尾都不被曲线压缩）。
  final double opacity;

  /// 投影渐强，收起时先撤掉，避免收拢过程中残留一整圈阴影。
  final double shadow;

  /// 行内容单独淡入，让文字比面板晚一点出现。
  final double rowsOpacity;

  /// 面板从锚点方向轻微滑入。
  final Offset offset;

  /// 行内容相对面板的轻微位移。
  final Offset rowsOffset;

  final double scale;
  final ContextMenuRevealOrigin origin;
  final bool reduce;
}

/// 起点是「边」而不是「角」时走的是 unfold：只推进裁切线，不做缩放 /
/// 位移，否则主运动和 corner 完全一样，看起来像「reveal 设置没生效」。
bool _isEdgeOrigin(ContextMenuRevealOrigin origin) => switch (origin) {
  ContextMenuRevealOrigin.top || ContextMenuRevealOrigin.bottom => true,
  _ => false,
};

/// [u] 是隐式动画的线性值：展开 0 → 1，收起 1 → 0（TweenAnimationBuilder
/// 在 end 变化时把 begin 设成当前值再 `forward(from: 0)`，所以收起的 u 递减）。
/// 因此收起侧用 [FlippedCurve] 做时间镜像，与 `dropdown` 的
/// `CurvedAnimation.reverseCurve` 等价。
_ContextMenuFrame _resolveContextMenuFrame({
  required double u,
  required bool closing,
  required bool reduce,
  required ContextMenuRevealOrigin origin,
  required double gap,
}) {
  final double linear = u.clamp(0.0, 1.0);
  final double p = reduce
      ? linear
      : closing
      ? _kMenuRevealReverse.transform(linear)
      : _kMenuRevealCurve.transform(linear);

  // unfold：面板尺寸、位置、行内容位置从头到尾都不变，只让裁切线推进，
  // 是纯粹的「展开」；corner 才有以起点角为锚点的放大、滑入与行位移。
  final bool edge = _isEdgeOrigin(origin);
  final double opacity = _kMenuEaseOut.transform(_remap(linear, 0.0, 0.22));
  final double rows = reduce
      ? 1.0
      : _kMenuEaseOut.transform(_remap(p, 0.10, 0.85));
  final Offset unit = _originUnit(origin);
  // 角起点两轴各占一半，边起点只沿主轴，避免位移量看起来不一致。
  final double axisScale = unit.dx != 0 && unit.dy != 0 ? 0.5 : 1.0;
  final double shift = _kMenuSoftCurve.transform(_remap(p, 0.08, 0.95));

  return _ContextMenuFrame(
    p: p.clamp(0.0, 1.0),
    opacity: opacity,
    shadow: reduce ? opacity : _kMenuEaseOut.transform(_remap(p, 0.60, 1.0)),
    rowsOpacity: rows,
    offset: reduce || edge
        ? Offset.zero
        : unit * (gap * axisScale * (1.0 - shift)),
    rowsOffset: reduce || edge ? Offset.zero : unit * (4.0 * (1.0 - rows)),
    scale: reduce || edge ? 1.0 : 0.94 + 0.06 * p,
    origin: origin,
    reduce: reduce,
  );
}

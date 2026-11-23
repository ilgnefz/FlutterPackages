import 'package:material_ui/material_ui.dart';

/// 棋盘格底纹：透明色压在它上面才能看出「透了多少」。
///
/// 包内复用（透明度条、预览圆点、按钮色块），不作为包入口的公开 API 导出。
class CheckerPattern extends StatelessWidget {
  const CheckerPattern({
    super.key,
    this.square = 6,
    this.color = const Color(0xFFC9C9C9),
  });

  /// 单个方格边长。
  final double square;

  /// 深色格子的颜色；浅色格固定为白色。
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CheckerPainter(square: square, color: color),
    child: const SizedBox.expand(),
  );
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter({required this.square, required this.color});

  final double square;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
    final Paint dark = Paint()..color = color;
    final int columns = (size.width / square).ceil();
    final int rows = (size.height / square).ceil();
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        if ((row + col).isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(col * square, row * square, square, square),
            dark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) =>
      oldDelegate.square != square || oldDelegate.color != color;
}

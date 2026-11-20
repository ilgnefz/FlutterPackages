part of '../flutter_split_pane.dart';

// ── 控制器 ────────────────────────────────────────────────────────────────

/// 各个视图占比的外部数据源。
///
/// 给了 [SplitPane.controller] 就以它为唯一数据源：拖动分割线会写回控制器，
/// 外部改比例组件也会跟着重排。没给控制器时组件自己维护比例，并通过
/// [SplitPane.onRatiosChanged] 把新比例抛出去。
///
/// ```dart
/// final SplitPaneController c = SplitPaneController(ratios: <double>[0.3, 0.7]);
/// SplitPane(
///   controller: c,
///   views: <SplitPaneView>[
///     SplitPaneView(child: const Text('左')),
///     SplitPaneView(child: const Text('右')),
///   ],
/// );
/// c.setRatio(0, 0.6);
/// c.reset(); // 回到 0.3 / 0.7
/// ```
class SplitPaneController extends ChangeNotifier {
  SplitPaneController({List<double>? ratios})
    : _ratios = List<double>.unmodifiable(ratios ?? const <double>[]),
      initialRatios = List<double>.unmodifiable(ratios ?? const <double>[]);

  List<double> _ratios;

  /// 构造时的比例列表；[reset] 会回到这里。
  final List<double> initialRatios;

  /// 当前各视图的比例（按视图顺序）。
  List<double> get ratios => _ratios;

  /// 设置第 [index] 个视图的比例；内容没变时不发通知。
  void setRatio(int index, double value) {
    if (index < 0 || index >= _ratios.length) return;
    final List<double> next = List<double>.of(_ratios);
    next[index] = value;
    setRatios(next);
  }

  /// 整体设置比例列表。
  void setRatios(List<double> ratios) {
    final List<double> next = List<double>.unmodifiable(ratios);
    if (_sameRatios(next, _ratios)) return;
    _ratios = next;
    notifyListeners();
  }

  /// 回到 [initialRatios]。
  void reset() => setRatios(initialRatios);
}

bool _sameRatios(List<double> a, List<double> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

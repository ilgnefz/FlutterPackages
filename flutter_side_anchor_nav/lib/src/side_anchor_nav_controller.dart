part of '../flutter_side_anchor_nav.dart';

// ── 控制器 ────────────────────────────────────────────────────────────────

/// 外部控制「选中哪一页」的小控制器。
///
/// 不给控制器时，组件自己维护选中项；给了就以控制器为**唯一数据源**：
/// 点击 Tab、滚动同步都会写回 [index]，外部随时读到的都是当前页。
///
/// ```dart
/// final SideTabController controller = SideTabController();
/// SideTab(controller: controller, views: views);
///
/// controller.select(2); // 滚到第 3 页（带动画）
/// controller.jumpTo(0); // 直接跳回第 1 页（不带动画）
/// ```
class SideTabController extends ChangeNotifier {
  SideTabController({int initialIndex = 0})
    : _index = initialIndex < 0 ? 0 : initialIndex;

  int _index;

  /// 当前选中的页下标（0 起）。
  int get index => _index;

  bool _disposed = false;

  /// 挂着的 [SideAnchorNav]；同一个控制器同时只服务一个组件。
  _SideAnchorNavState? _state;

  /// 当前是否有 [SideAnchorNav] 在用它。
  bool get isAttached => _state != null;

  /// 滚到第 [index] 页（带动画）。
  ///
  /// 越界 / 该页禁用时什么也不做。没有挂载 [SideAnchorNav] 时只记住下标，
  /// 组件挂上来的第一次构建会直接跳过去。
  void select(int index) => _forward(index, animated: true);

  /// 直接跳到第 [index] 页（不带动画）。
  void jumpTo(int index) => _forward(index, animated: false);

  void _forward(int index, {required bool animated}) {
    if (_disposed || index < 0) return;
    final _SideAnchorNavState? state = _state;
    if (state != null && state.mounted) {
      state._select(index, animated: animated);
      return;
    }
    _storeIndex(index);
  }

  /// 由 [SideAnchorNav] 回写当前页；只有真的变了才通知外部。
  void _storeIndex(int index) {
    if (_disposed || index == _index) return;
    _index = index;
    notifyListeners();
  }

  void _attach(_SideAnchorNavState state) => _state = state;

  void _detach(_SideAnchorNavState state) {
    if (identical(_state, state)) _state = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _state = null;
    super.dispose();
  }
}

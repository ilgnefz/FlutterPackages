part of '../flutter_multi_select_reorder.dart';

// ── 选中控制器 ────────────────────────────────────────────────────────────

/// 选中集合的**唯一真值**，并提供程序化选择能力。
///
/// 视图通过 [_bind] 建立 `下标 ↔ id` 映射；内部真正持久保存的是 id（按点选
/// 顺序），对外仍以下标读写。这样 list/grid 切换、或两个视图数据集不同
/// （例如 grid 过滤掉非图片项）时，同一个 controller 里的选中不会因为下标
/// 错位而跳到别的条目上。没提供 `itemId` 时退化为「id 就是下标」，与旧版一致。
///
/// 继承 [ChangeNotifier]，别的组件要跟着选中变化刷新时，包一层
/// [ListenableBuilder]（或 `AnimatedBuilder`）监听同一个实例即可——**不要**
/// 在外面再存一份选中数组，两份真值迟早会不一致。
///
/// ```dart
/// final MultiSelectController c = MultiSelectController();
/// c.select(2);
/// c.toggle(0);
/// final List<int> picked = c.selectedIndices;
/// final List<Object> ids = c.selectedIds;   // 稳定 id，含被过滤掉的
/// c.setIds(<Object>[3, 1]);                 // 从外部改选中（顺序 = 点选顺序）
/// ```
/// 同一时刻只服务一个视图；但可在视图切换时复用，以保留选中。
class MultiSelectController extends ChangeNotifier {
  MultiSelectController({Iterable<Object>? initialSelectedIndices})
    : _pendingIds = initialSelectedIndices?.toList();

  int _itemCount = 0;

  /// 有序的选中 id；用 HashSet 会丢掉点选顺序。
  final LinkedHashSet<Object> _ids = LinkedHashSet<Object>();

  /// 当前视图的 `id → 下标` / `下标 → id`，每次 [_bind] 重建。
  Map<Object, int> _indexById = <Object, int>{};
  Map<int, Object> _idByIndex = <int, Object>{};

  /// 构造时给的初始选中，等视图第一次 [_bind] 时再转成 id。
  List<Object>? _pendingIds;

  /// 由视图在 initState / didUpdateWidget 里调用，同步条目总数与 id 映射。
  /// 这里**不**发通知，避免父组件 build 期间触发额外重建。
  ///
  /// `itemId` 返回每个下标的稳定标识；不传时 id 就是下标（旧行为）。
  void _bind(int itemCount, Object Function(int index)? itemId) {
    _itemCount = itemCount;
    _indexById = <Object, int>{};
    _idByIndex = <int, Object>{};
    for (int i = 0; i < itemCount; i++) {
      final Object id = itemId?.call(i) ?? i;
      _indexById[id] = i;
      _idByIndex[i] = id;
    }
    final List<Object>? pending = _pendingIds;
    if (pending != null) {
      _pendingIds = null;
      _ids
        ..clear()
        ..addAll(pending);
    }
    // 注意：这里**不**删除「当前视图里找不到」的 id。过滤视图（grid 只显示
    // 图片）里不可见的选中项仍要留着，切回全量视图时才会重新出现。
  }

  /// 按点选顺序返回**当前视图可见**的选中下标。
  List<int> get selectedIndices {
    final List<int> result = <int>[];
    for (final Object id in _ids) {
      final int? index = _indexById[id];
      if (index != null) result.add(index);
    }
    return result;
  }

  /// 按点选顺序返回所有选中的 id，包含当前视图被过滤掉的那些。
  List<Object> get selectedIds => _ids.toList(growable: false);

  /// [selectedIndices] 的方法形式。
  List<int> getSelectedIndices() => selectedIndices;

  /// 当前视图可见的选中数。
  int get selectedCount => selectedIndices.length;

  /// 全部选中数（含被过滤掉的）。
  int get allSelectedCount => _ids.length;

  /// 是否有选中（含被过滤掉的）。
  bool get hasSelection => _ids.isNotEmpty;

  bool isSelected(int index) {
    if (index < 0 || index >= _itemCount) return false;
    return _ids.contains(_idOf(index));
  }

  /// 兼容旧 API：按 id 存选中后越界下标不再存在，保留为空操作。
  void prune() {}

  void setSelection(Iterable<int> indices) => _setIds(_idsOf(indices));

  /// 用**稳定 id** 直接替换选中集合（按给定顺序 = 点选顺序）。
  ///
  /// 需要从组件外部改选中时用它：恢复上次的选中、批量选中搜索命中的项、
  /// 或者由别的按钮触发「全选 / 清空」等。当前视图看不见的 id 也会被保留，
  /// 切回能看见它们的视图时照样是选中态。
  ///
  /// ```dart
  /// controller.setIds(<String>['a3', 'f1']);   // 顺序就是角标序号
  /// ```
  void setIds(Iterable<Object> ids) => _setIds(ids);

  void select(int index) {
    if (index < 0 || index >= _itemCount) return;
    if (_ids.add(_idOf(index))) notifyListeners();
  }

  void deselect(int index) {
    if (index < 0 || index >= _itemCount) return;
    if (_ids.remove(_idOf(index))) notifyListeners();
  }

  void toggle(int index) {
    if (index < 0 || index >= _itemCount) return;
    final Object id = _idOf(index);
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
  }

  void selectAll() =>
      _setIds(_idsOf(List<int>.generate(_itemCount, (int i) => i)));

  void clear() => _setIds(const <Object>{});

  Object _idOf(int index) => _idByIndex[index] ?? index;

  Iterable<Object> _idsOf(Iterable<int> indices) => indices
      .where((int i) => i >= 0 && i < _itemCount)
      .map<Object>(_idOf)
      .toSet();

  void _setIds(Iterable<Object> ids) {
    final List<Object> next = <Object>[];
    for (final Object id in ids) {
      if (!next.contains(id)) next.add(id);
    }
    if (_sameList<Object>(_ids.toList(), next)) return;
    _ids
      ..clear()
      ..addAll(next);
    notifyListeners();
  }
}

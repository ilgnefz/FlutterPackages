import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// 树的一个节点。父子关系直接由 [children] 表达，不需要额外的「根列表」类型。
///
/// ```dart
/// const TreeNode<String>('image', label: '图片', children: [
///   TreeNode<String>('png', label: 'png'),
///   TreeNode<String>('jpg', label: 'jpg'),
/// ]);
/// ```
///
/// 泛型 [T] 是节点的 id 类型，[TreeView] 回调（选中 / 勾选 / 展开）拿到的都是
/// 这个 id。id 请用值类型（`String` / `enum` / `int`）——组件内部按 `==` 比较，
/// 用可变对象且没重写 `operator ==` 时，勾选状态会认不出来。
@immutable
class TreeNode<T extends Object> {
  const TreeNode(
    this.id, {
    this.label = '',
    this.leading,
    this.trailing,
    this.children = const <TreeNode<Never>>[],
    this.enabled = true,
  });

  /// 节点唯一标识，同时作为选中 / 勾选 / 展开状态里的键。
  final T id;

  /// 行文字。
  final String label;

  /// 行首图标（`Icon` / `SvgPicture` / 任意 Widget 都行），尺寸由
  /// [TreeViewStyle.iconSize] 统一控制。
  final Widget? leading;

  /// 行尾自定义内容，例如数量徽标。勾选树的展开箭头画在它右边。
  final Widget? trailing;

  /// 子节点。为空即叶子。
  final List<TreeNode<T>> children;

  /// 是否可交互。为 false 时行变灰、点击不再响应（箭头依然可以展开）。
  final bool enabled;

  /// 是否带子节点。
  bool get hasChildren => children.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is TreeNode<T> &&
      other.id == id &&
      other.label == label &&
      other.enabled == enabled &&
      listEquals(other.children, children);

  @override
  int get hashCode => Object.hash(id, label, enabled, Object.hashAll(children));

  @override
  String toString() => 'TreeNode($id, $label)';
}

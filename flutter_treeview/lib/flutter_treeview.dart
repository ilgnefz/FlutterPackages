/// 树形组件：一个 import 拿到两种形态。
///
/// ```dart
/// import 'package:flutter_treeview/flutter_treeview.dart';
///
/// TreeView<String>(...);           // 常用树：单选、箭头在左、缩进分层
/// TreeView.checkbox<String>(...);  // 勾选树：左边三态 checkbox、右边箭头、级联
/// ```
///
/// 两种形态共用同一份数据模型 [TreeNode] 与同一套外观 [TreeViewStyle]：
///
/// * [TreeNode] —— `id` / `label` / `leading` / `trailing` / `children` / `enabled`，
///   纯数据，`const` 构造，可以整棵树写死在代码里，也可以从配置 / 接口拼出来。
/// * [TreeViewStyle] —— 行高、缩进、箭头位置与大小、checkbox 尺寸、各态配色、
///   文字样式，`light()` / `dark()` / `of(context)` / `copyWith()` 与其它几个包
///   保持一致。
/// * [TreeView] —— 展开动画、hover、受控的展开 / 勾选集合、`maxHeight` 内部滚动。
///
/// ## 在 dropdown 里用
///
/// 把 `maxHeight` 给上（下拉面板高度有限），外面照常套下拉面板即可：
///
/// ```dart
/// TreeView.checkbox<String>(
///   nodes: extensionNodes,
///   checkedIds: checked,
///   onCheckedChanged: (Set<String> ids) => setState(() => checked = ids),
///   maxHeight: 240,
///   style: TreeViewStyle.of(context).copyWith(
///     rowHeight: 28,
///     padding: EdgeInsets.symmetric(vertical: 4),
///   ),
/// )
/// ```
///
/// 行不依赖 `InkWell` / `Material`，放进 Overlay 里的浮层面板也不会有水波纹
/// 渗色或光标消失的问题。
library;

export 'src/tree_node.dart';
export 'src/tree_style.dart';
export 'src/tree_view.dart';

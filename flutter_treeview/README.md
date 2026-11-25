# flutter_treeview

一棵树，两种形态：**常用单选树** 和 **勾选树**（父级三态 checkbox + 右侧箭头）。
只依赖 `flutter` 与 `material_ui`，行不用 `InkWell` / `Material`，所以塞进下拉面板、
浮层、没有 Material 祖先的子树里都能正常 hover、也能自己定光标。

```dart
import 'package:flutter_treeview/flutter_treeview.dart';

TreeView<String>(...);          // 常用树：单选、箭头在左、缩进分层
TreeView.checkbox<String>(...); // 勾选树：左边三态 checkbox、右边箭头、级联
```

## 数据

`TreeNode` 是纯数据，`const` 构造，整棵树可以写死，也可以从配置 / 接口拼：

```dart
const List<TreeNode<String>> nodes = <TreeNode<String>>[
  TreeNode<String>(
    'image',
    label: '图片',
    leading: Icon(Icons.image_outlined),
    children: <TreeNode<String>>[
      TreeNode<String>('png', label: 'png'),
      TreeNode<String>('jpg', label: 'jpg'),
    ],
  ),
  TreeNode<String>('noext', label: '无扩展名'),
];
```

字段：`id`（唯一键，回调里拿到的就是它）、`label`、`leading`（行首图标，任意
Widget）、`trailing`（行尾内容，例如数量徽标）、`children`、`enabled`。
`id` 请用值类型（`String` / `enum` / `int`）：内部按 `==` 比较。

## 常用树

```dart
TreeView<String>(
  nodes: nodes,
  selectedId: selected,
  onChanged: (String id) => setState(() => selected = id),
  maxHeight: 220,
);
```

点行 = 选中并回调；**点箭头只展开 / 收起**，不改变选中（和 VS Code 的资源管理器
一致）。箭头默认在左，叶子行留同样的空位，所以同层文字是一列对齐的。

## 勾选树

```dart
TreeView.checkbox<String>(
  nodes: nodes,
  checkedIds: checked,                                        // 受控，可选
  onCheckedChanged: (Set<String> ids) => setState(() => checked = ids),
  maxHeight: 240,
);
```

* 左边 checkbox，右边箭头；
* 勾父级 = 勾整棵子树，取消同理（`cascade: false` 可关掉级联）；
* 子项部分勾选时父级画横线（indeterminate）；
* 回调给的是「所有处于勾选态的节点」：叶子 + 整棵都勾上的父级。给 `checkedIds`
  时也可以只给叶子，父级状态由子树推导。

## 展开状态

默认组件自己维护。传 `expandedIds` 即受控，配合 `onExpandChanged` 就能做
「全部展开 / 全部收起」；`expandAll: true` 是初始全展开。

## 外观

`TreeViewStyle` 一处配置行高、缩进、箭头大小与位置、checkbox 尺寸、各态配色、
文字样式，`light()` / `dark()` / `of(context)` / `copyWith()`：

```dart
TreeViewStyle.of(context).copyWith(
  rowHeight: 28,
  indent: 14,
  padding: const EdgeInsets.symmetric(vertical: 4),
);
```

## 放进下拉面板

给 `maxHeight`（面板高度有限），内部自带 `Scrollbar` 与滚动控制器；
面板自己不留内边距时，把 `style.padding` 收成 `EdgeInsets.zero`，行才贴边：

```dart
SizedBox(
  width: 200,
  child: TreeView.checkbox<String>(
    nodes: nodes,
    checkedIds: checked,
    onCheckedChanged: (Set<String> ids) => setState(() => checked = ids),
    maxHeight: 240,
    style: TreeViewStyle.of(context).copyWith(
      padding: EdgeInsets.zero,
      // 桌面默认 8px，离行尾箭头太近；这里收到 4px（包内默认已是 4）。
      scrollbarThickness: 4,
      // 还嫌近就加大右侧留白，把箭头从滚动条旁挪开。
      rowPadding: EdgeInsets.only(left: 6, right: 12),
    ),
  ),
)
```

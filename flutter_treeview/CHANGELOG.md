## 0.1.1

* `TreeViewStyle.scrollbarThickness`：滚动条厚度，默认 4（桌面 / Web 上
  `Scrollbar` 原本默认 8，离行尾展开箭头太近容易误触）。
* 局部覆盖 `ScrollBehavior`，阻止桌面平台再自动注入一条默认厚度的滚动条
  （之前会和我们这条叠成「两条宽度不同的滚动条」）。

## 0.1.0

首个可用版本。

* `TreeNode`：纯数据节点（`id` / `label` / `leading` / `trailing` / `children` /
  `enabled`），`const` 构造，`List<TreeNode<T>>` 就是整棵树。
* `TreeView`：常用单选树。点行选中，点箭头只展开 / 收起；箭头默认在左，叶子行
  留同样空位，同层文字对齐。展开用 `AnimatedSize`，行自带 hover 与手型光标，
  不依赖 `InkWell` / `Material`。
* `TreeView.checkbox`：勾选树。左边 checkbox（父级三态，子项部分勾选时画横线）、
  右边箭头，勾父级即级联勾整棵子树；`cascade: false` 可关掉级联。
* 受控的 `checkedIds` / `expandedIds` + `onCheckedChanged` / `onExpandChanged`，
  `expandAll` 初始全展开。
* `TreeViewStyle`：行高、缩进、箭头大小与位置、checkbox 尺寸、hover / 选中 / 勾选
  各态配色、文字样式，`light()` / `dark()` / `of(context)` / `copyWith()`。
* `maxHeight`：内部自带 `Scrollbar` 与滚动控制器，直接塞进下拉面板 / 浮层即可，
  不再依赖桌面平台自动注入的滚动条。

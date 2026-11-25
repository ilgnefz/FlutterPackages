## 0.8.1

* **修掉「两行同时高亮」**：面板原来把 hover 与键盘高亮分开存（`_hovered` /
  `_keyboardHighlight`），键盘走过一次之后指针再移到别的行，两行会一起亮。
  现在合并成单一的「活动行」，指针与键盘都只是往同一处写。
* 行渲染不再自持 hover 状态（`_ContextMenuItemView` 改成 Stateless）：以前
  items 原地刷新或热重载后 State 被复用，旧的高亮会留在别的行上，出现没有
  指针的幽灵 hover；之后指针移到正常行就是两行亮。面板在 items 变化时也会
  丢掉已失效的活动行。
* 新增 1 条回归测试：`↓` 高亮第一项后 hover「删除」，断言前一行恢复透明、
  只有指针所在行亮。
* 顺手修了 `_openSubmenu` 里的顺序问题：先 `_trimLevels` 再判断「已经是这一
  项」，判断永远为假成了死代码，点已展开的子菜单父项会重建子菜单、重播一遍
  揭示动画。现在先判断再缩容，点击保持原状。新增 1 条测试用面板 State 的
  identity 守住这一点。

## 0.8.0

* `danger: true` 的默认颜色从 `colorScheme.error` 改成 **`Colors.red`**
  （`#F44336`）。M3 的 error 浅色下是深砖红、深色下是浅粉，跟"删除"惯用的
  鲜红对不上；改成固定值后，和 App 里 `Colors.red` 的删除按钮同色，明暗主题
  表现一致。仍可用 `ContextMenuStyle.dangerColor` 或单行 `color` 覆盖。
* 新增 1 条测试：深色主题下 `colorScheme.error != Colors.red`，而 danger 行
  仍是 `Colors.red`。

## 0.7.0

* **修正 `ContextMenuReveal.unfold` 的方向**：贴边揭开现在只走垂直轴 —— 菜单
  在锚点下方从顶边往下揭、翻到上方从底边往上揭。之前「水平翻转优先」，贴着
  屏幕右边右键（菜单翻到指针左侧）会变成从右往左的横向揭示，看起来像另一套
  动画；现在横向翻转只改位置，方向不变。
* 子菜单的 unfold 一并改成垂直轴：不再因为贴着父菜单侧边就切成左右揭，和
  根菜单保持同一套运动。
* **破坏性变更**：`ContextMenuRevealOrigin` 删掉 `left` / `right`（不再有
  横向轴向揭示），`resolveContextMenuRevealOrigin` 去掉 `horizontalAxis`
  参数。

## 0.6.0

* 新增 `ContextMenuStyle.itemPadding`（默认 10）：每一行内容（图标 / 文字 /
  快捷键）与该行外框之间的左右留白。此前写死 10，`padding` 只能调面板外框
  与首末行的距离。分组标题一起缩进，行高仍由 `itemHeight` 固定。

## 0.5.0

* 新增 `ContextMenuStyle.mouseCursor`（默认 `SystemMouseCursors.click`）：
  统一设置可点击行（含子菜单父项）的鼠标光标。禁用行 / 标题 / 分隔线固定
  回落默认箭头，不会「置灰却还是手型」。

## 0.4.0

* 新增 `ContextMenuItem.color`：单独指定一行的前景色（文字 + 行首 `icon` /
  `prefix`）。`danger` 只是红色的常用语义，别的颜色直接给 `color`；优先级
  为 禁用 > `color` > `danger` > 主题前景色。
* 新增 `ContextMenuStyle.iconGap`（默认 8）：行首图标 / `prefix` 与文案的
  间距，同时决定「没有图标的行」预留的槽位宽度。此前这个间距写死 10。
* `prefix` / `icon` 的右侧留白改为跟随 `iconGap`，同级各行文案仍严格对齐。

## 0.3.0

* `ContextMenuItem.submenu` 新增 `width`：可单独设定展开出的那一级子菜单宽度，
  不受 `ContextMenuStyle.width` 限制；孙级仍回落到 style 的默认宽度。
  普通操作项的构造函数也带这个参数（有 `children` 时才生效）。
* 新增 `ContextMenuItem.prefix`：用任意 Widget 顶替行首的 `IconData`，适合
  `IconData` 里没有的品牌图标 / 自绘 SVG / 色块。与 `icon` 共用槽位，同时
  传时 `prefix` 优先；外面套了 `IconTheme`，禁用 / `danger` 也会正确换色。
  同级「预留图标宽度」的判断一并把 `prefix` 算进去。

## 0.2.0

* 新增命令式入口 `showContextMenu<T>(context, position: ..., items: ...)`：
  按坐标弹出，不需要包 Widget，条目可以按行 / 按对象生成，适合列表、表格
  这类需要知道「右键的是谁」的场景。返回 `ContextMenuHandle`（`isOpen` /
  `close`）。命令式菜单收完自动销毁；连续调用只保留最后一个。
* 浮层状态机抽成 `_ContextMenuOverlay`，组件与命令式入口共用同一份实现
  （动画、落位、键盘、子菜单行为完全一致）。
* **修复 `ContextMenuReveal.unfold` 看起来和 `corner` 一样**：之前两套揭示
  只是裁切方向不同，缩放 / 位移完全共用，主运动相同。现在 unfold 只推进
  裁切线，面板尺寸、位置、行内容全程不动；缩放与滑入只属于 corner 系列。
* `CascadeContextMenu` 文档补充定位：包区域 → 空白处；按行不同 → 用
  `showContextMenu`。

## 0.1.0

首个可用版本，从 `custom_compent` 应用的 `cascade_context_menu` 目录移植而来。

* `CascadeContextMenu<T>`：右键 / 长按触发，支持任意层级子菜单、边缘翻转、
  键盘导航（↑↓ → ← Enter Esc）与揭示动画。
* `ContextMenuItem<T>`：操作项 / 子菜单父项 / 分隔线 / 分组标题混排，
  支持图标、快捷键、禁用、危险色和自定义行内容。
* `ContextMenuStyle`：尺寸 / 间距 / 配色 / 动画配置，颜色不传时跟随 Theme，
  提供 `copyWith`。
* `ContextMenuReveal`：角揭示（随落位镜像）、贴边揭开与四个固定方向。
* 以 `lib/flutter_context_menu.dart` 为唯一入口，实现按职责拆成 `lib/src/`
  下的 part 文件。

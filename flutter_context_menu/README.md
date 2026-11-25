# flutter_context_menu

通用右键菜单：自动处理屏幕边缘翻转，支持任意层级的子菜单、键盘导航和揭示动画。两种入口共用同一套浮层实现：

- `CascadeContextMenu`：包住一块**区域**，右键 / 长按弹出固定菜单 —— 适合空白处（内容区、画布、面板背景）。
- `showContextMenu`：按坐标命令式弹出，条目可以按行 / 按对象生成 —— 适合列表、表格、画布这类「右键哪一行就该针对哪一行」的场景。

## 特性

- **任意层级**：操作项、子菜单父项、分隔线、分组标题混排；子菜单里还能继续放子菜单。
- **自动落位**：根菜单跟着指针，右边 / 下边不够就翻到左 / 上；子菜单优先贴父级右侧，翻不下再换左侧，并尽量与父级行对齐。
- **键盘可用**：↑↓ 移动高亮、→ 展开子菜单、← 收起子菜单、Enter 激活、Esc 关闭。
- **主题自适应**：颜色默认从当前 Theme 取，明暗主题自动适配。
- **两套揭示动画**：斜向角揭示（带轻微放大 / 滑入）与贴边展开（纯裁切推进）；落位翻转时起点自动镜像。尊重 `MediaQuery.disableAnimations`。
- **浮层实现**：用 `OverlayEntry`，可以画到触发 Widget 边界之外，不会被父级裁剪或吞掉点击。

## 开始使用

```yaml
dependencies:
  flutter_context_menu:
    path: ../FlutterPackages/flutter_context_menu
```

依赖 `material_ui`（Theme / Icons / Material 组件统一从它导出）。

## 用法

### 包一块区域：`CascadeContextMenu`

```dart
CascadeContextMenu<String>(
  onSelected: (String value) => debugPrint(value),
  items: const <ContextMenuItem<String>>[
    ContextMenuItem<String>('copy', label: '复制', icon: Icons.copy, shortcut: 'Ctrl+C'),
    ContextMenuItem<String>.divider(),
    ContextMenuItem<String>.header('导出为'),
    ContextMenuItem<String>.submenu(
      '格式',
      children: <ContextMenuItem<String>>[
        ContextMenuItem<String>('pdf', label: 'PDF'),
        ContextMenuItem<String>.submenu(
          '图片',
          children: <ContextMenuItem<String>>[
            ContextMenuItem<String>('png', label: 'PNG'),
            ContextMenuItem<String>('jpg', label: 'JPG'),
          ],
        ),
      ],
    ),
    ContextMenuItem<String>('delete', label: '删除', danger: true),
  ],
  child: const Text('右键点我'),
)
```

`value` 是泛型 `T`，`onSelected` 只在**叶子操作项**被激活时回调；点子菜单父项只展开下一级。

### 按坐标弹出：`showContextMenu`

列表 / 表格里的每一行要用各自的菜单时，别用外层包裹（那种写法菜单不知道点的是谁），改在行自己的手势里直接弹：

```dart
InkWell(
  onSecondaryTapDown: (TapDownDetails details) => showContextMenu<String>(
    context,
    position: details.globalPosition,
    items: <ContextMenuItem<String>>[
      ContextMenuItem<String>.header(file.name),   // 标题里写清「选中的是谁」
      ContextMenuItem<String>('rename', label: '重命名', icon: Icons.drive_file_rename_outline),
      ContextMenuItem<String>('delete', label: '删除', icon: Icons.delete_outline, danger: true),
    ],
    style: const ContextMenuStyle(reveal: ContextMenuReveal.unfold),
    onSelected: (String value) => handleMenuAction(value, file),
  ),
  child: row,
)
```

返回 `ContextMenuHandle`，只在需要提前关掉时用：

```dart
final ContextMenuHandle handle = showContextMenu<String>(...);
handle.isOpen;   // 是否还在显示（含退场动画）
handle.close();  // 收起；已关闭时调用无副作用
```

命令式菜单的生命周期由自己管：选中 / 点击外部 / Esc 之后自动销毁，不需要 `State` 帮忙。两点与组件写法不同：

- **菜单开着时在别处右键 → 先收起**。全屏拦截层拿到新坐标也不知道该用哪份 `items`，所以不在原地重开；再右键一次就会在目标位置弹出。
- **连续调用 `showContextMenu` 只保留最后一个**，不会叠出两份菜单。

### 条目类型

| 构造函数 | 说明 |
|---|---|
| `ContextMenuItem(value, label: ...)` | 可点击的操作项，选中回传 `value` |
| `ContextMenuItem.submenu(label, children: ...)` | 子菜单父项，`value` 恒为 null，行尾显示箭头 |
| `ContextMenuItem.divider()` | 1px 分隔线 |
| `ContextMenuItem.header(text)` | 分组标题 |

操作项还有 `icon`、`prefix`、`color`、`shortcut`、`enabled`、`danger`、`child`（完全自定义行内容）、`width`（子菜单宽度）。

**行首图标**：`icon` 收的是 `IconData`；`IconData` 里没有的图标（品牌图标、自绘 SVG、色块、序号……）用 `prefix` 传一个 Widget —— 两者共用同一个槽位，同时传时 `prefix` 优先。`prefix` 外面套了一份 `IconTheme`（尺寸取 `style.iconSize`、颜色跟随本行前景色），所以直接塞 `Icon(...)` 也能在禁用时变灰、`danger` 时变红；同级只要有一项带 `icon` 或 `prefix`，其它行都会预留同样的宽度。

```dart
ContextMenuItem<String>(
  'brand',
  label: '品牌图标',
  prefix: const SizedBox(width: 18, height: 18, child: MyLogo()),
),
```

**单行颜色**：`danger` 只是「红色」这一类常用语义；要别的颜色就直接给这一行 `color`，文字和行首 `icon` / `prefix` 一起换色。优先级是 **禁用 > `color` > `danger` > 主题前景色**，行尾快捷键提示仍用弱化的 `muted` 色。

```dart
ContextMenuItem<String>(
  'pin',
  label: '置顶',
  icon: Icons.push_pin,
  color: Color(0xFF00897B),   // 图标同色；换主题也不用跟着改
),
```

**行首间距**：`icon` / `prefix` 与文案之间的距离由 `style.iconGap` 控制（默认 8），没有图标的行预留的槽位同步变宽，同级文案始终对齐。行首图标尺寸是 `style.iconSize`。

**鼠标光标**：可点击的行（含子菜单父项）默认是手型 `SystemMouseCursors.click`，用 `style.mouseCursor` 换（比如 `SystemMouseCursors.basic`）。禁用行、分组标题、分隔线始终是默认箭头，不会因为置灰还顶着手型光标。

**子菜单宽度**：根菜单宽度由 `style.width` 决定；某一级子菜单想单独宽一点，就在展开它的父项上写 `width`，只管自己这一级，孙级仍回落到 `style.width`：

```dart
ContextMenuItem<String>.submenu(
  '导出为',
  width: 280,           // 这一级子菜单宽 280，其余层级照旧
  children: <ContextMenuItem<String>>[...],
),
```

### 组件参数

| 参数 | 默认值 | 说明 |
|---|---|---|
| `items` | 必填 | 条目列表 |
| `onSelected` | null | 叶子项选中回调 |
| `onOpenChange` | null | 菜单打开 / 关闭回调（子菜单展开不算一次开关） |
| `enabled` | `true` | 关闭右键 / 长按响应 |
| `longPressEnabled` | `true` | 触屏长按触发 |
| `style` | `ContextMenuStyle()` | 外观配置 |
| `edgePadding` | `8` | 菜单与屏幕边缘的最小间距 |
| `itemBuilder` | null | 自定义单行内容；`context` 来自浮层，不是触发处子树 |

`showContextMenu` 的参数是它的子集加上 `position`：

| 参数 | 说明 |
|---|---|
| `position` | 必填，全局坐标（通常传 `details.globalPosition`） |
| `items` / `onSelected` / `onOpenChange` / `style` / `edgePadding` / `itemBuilder` | 同上 |

### 外观

`ContextMenuStyle` 的尺寸和颜色都可以单独覆盖，用 `copyWith`（`width` 是各级默认宽度，子菜单可用条目的 `width` 覆盖）：

```dart
style: const ContextMenuStyle().copyWith(
  width: 240,
  itemHeight: 40,
  radius: 12,
  itemPadding: 12,      // 每行内容（图标 / 文字 / 快捷键）的左右留白
  iconGap: 10,          // 行首图标 / prefix 与文案的间距
  mouseCursor: SystemMouseCursors.basic,   // 可点行的光标，默认手型
  reveal: ContextMenuReveal.unfold,
  textStyle: TextStyle(fontSize: 14),
)
```

三个间距别混：**`padding`** 是面板外框与首行 / 末行的距离（默认 6）；**`itemPadding`** 是每行内容和该行外框之间的左右留白（默认 10，分组标题跟着一起缩进）；**`iconGap`** 是行首图标 / `prefix` 与文案之间的距离（默认 8，没有图标的行预留同样宽度）。行高由 `itemHeight` 固定，所以后两者只管左右。

`lip`（默认 8）是揭示动画在 progress = 0 时保留的可见量：角揭示是 `lip × lip` 的小三角，`unfold` 是 `lip` 厚的薄边。调大会让起始帧露得更多、更像从锚点「长出来」，调小则更接近从零面积长开——一般不用动。

颜色字段（`backgroundColor` / `borderColor` / `dividerColor` / `hoverColor` / `foreground` / `muted` / `disabledColor` / `dangerColor` / `shadowColor`）默认 null，走当前 Theme；文字样式以 `Theme.textTheme.bodyMedium` 为基底，`textStyle` / `headerTextStyle` / `shortcutTextStyle` 只覆盖同名字段。

`reveal` 可选，两种基础形态是**两套不同的运动**：

- `ContextMenuReveal.corner`（默认）：从最靠近锚点的角斜着扫到对角，同时以那个角为锚点轻微放大（0.94 → 1）、朝锚点方向滑入（`revealGap`）；落位翻转时自动镜像。
- `ContextMenuReveal.unfold`：只让裁切线沿垂直轴推进，面板尺寸、位置、行内容全程不动，像下拉面板一样整块展开；落在锚点下方从上边往下揭，翻到上方则从下边往上揭。横向翻转只改位置、不改方向（贴着屏幕右边右键也一样往下揭），子菜单同样是往下揭。
- `topLeftToBottomRight` / `topRightToBottomLeft` / `bottomLeftToTopRight` / `bottomRightToTopLeft`：固定方向（走 corner 那套运动，但忽略落位）。

### 自定义单行

```dart
itemBuilder: (BuildContext context, ContextMenuItem<String> item) {
  return Row(children: <Widget>[Icon(Icons.star), Text(item.label ?? '')]);
},
```

返回的 Widget 会替换默认行内容，但点击 / 禁用 / 高亮仍由组件管理，需要自己适配 `style.itemHeight`。

## 测试定位键

包内导出了 `kContextMenuPanelKey`、`kContextMenuBarrierKey`、`kContextMenuListKey`、`contextMenuPanelKey(level)`、`contextMenuItemKey(index, level)` 等 key 辅助函数，方便在 widget test 里定位各级面板与行。

## 许可

MIT

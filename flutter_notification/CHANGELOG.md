## 0.4.1

* `radius` 默认 14 → 8。通知卡片不大（默认 360 宽、正文两行），14 的圆角显得
  「胖」，和 32 高的按钮胶囊、3px 的进度条摆在一起比例也不对。想要更圆照旧传
  `radius: 12` / `16`。
* 测试仍 30 条（「默认 8」的断言补进首条用例；原来写死 14 的断言同步改掉）。

## 0.4.0

* 新增 `NotificationAction.builder`：拿到包好点击逻辑的 `onPressed`，返回任意
  widget 就能替换掉默认的 `TextButton` / `FilledButton`（带图标、`OutlinedButton`、
  自绘胶囊都行）。给了 builder 之后 `label` / `isPrimary` / `style` 不再生效。
* `NotificationAction.label` 从必填变成可选（配 builder 时可以不写），构造时断言
  「label 和 builder 至少给一个」。
* 新增 `NotificationStyle.mouseCursor`（默认 `SystemMouseCursors.click`），统一
  管整张卡片、关闭按钮、操作按钮的光标；自定义 builder 外层也兜了 `MouseRegion`。
  卡片本身没接任何回调（没有 `onTap`、`dismissOnTap` 也是 `false`）时保持
  `MouseCursor.defer`，不会假可点。
* 测试 27 → 30 条（builder 换按钮 + 光标三处 + 不可点卡片不变小手）。

## 0.3.1

按钮胶囊调到正常比例，不再「文字顶到胶囊边」。

* 默认尺寸：胶囊高度 24 → **32**，内边距 `10 / 4` → `14 / 8`，文字 13 / `w600`
  并单独给了 `height: 1.2`。上下各留 8，按钮看起来是一颗按钮而不是一块紧绷的
  色块（文字行高只有 ~16，之前 4 的竖内边距等于把字压在边上）。
* 新增 `NotificationStyle.actionMinHeight` / `actionPadding` / `actionTextStyle`，
  按钮的尺寸归到样式里，跟其它装饰项一起配。
* 胶囊形状显式用 `StadiumBorder`：不再跟着主题的 `ButtonStyle.shape` 走，
  换主题时两颗按钮不会一颗圆一颗方。
* 按钮行左右改成同一个缩进（正文那条 14），不再用卡片右侧 6（那是给关闭按钮
  留的列）。之前实心胶囊贴着右下角那段圆角弧线，看着像溢出。
* 修复：按钮文字样式会**抹掉主题的 `fontFamily`**——`ButtonStyle.textStyle` 是
  整条替换而不是合并，给一个裸 `TextStyle` 后自定义字体的应用里按钮会掉回默认
  字体。现在基于主题 `labelLarge` 派生。
* 有按钮时正文下边距 4 → 6。
* 测试 27 条（多按钮用例补：胶囊 32 高、文字上下留白 > 6、右缩进 14）。

## 0.3.0

操作按钮挪到右下角，并支持多个。

* **破坏性**：`show` / `success` / `error` / `warning` / `info` / `custom` /
  `update` / `handle.update` 的 `action`（单个）改成 `actions`（列表）。
  `NotificationData.action` → `NotificationData.actions`，默认空列表。
  单个按钮就是 `actions: [NotificationAction(...)]`。
* 按钮位置：从正文下方左对齐改为**卡片右下角**，多个按钮从左到右排在右下角，
  窄了自动折行（`Wrap`），不再挤正文的列宽。
* 新增 `NotificationAction.isPrimary`：那颗按钮改用实心 `FilledButton`
  强调主操作（默认仍是文字按钮）。卡片底色是 `surfaceContainerHigh`，
  tonal 按钮在上面几乎看不出区别，所以用实心。
* `loading()` 也能传 `actions` 了（配一个「取消」很常见）。
* 测试 24 → 27 条（新增：多按钮同排右对齐 + 实心主按钮 + 取消不关 /
  删除才关；`update` 换按钮与清空；没有按钮时正文下边距不变）。

## 0.2.3

* 调整：底部进度条改成**铺满整条底边**，看起来和卡片一样宽。底边直线段仍是
  `宽度 - 圆角 * 2`，两端多出来的部分落在圆角里、由卡片的圆角裁剪顺着弧线
  收进去；之前的「左右各让出一个 `radius` + 胶囊端点」会在两个下角各留一块
  卡片底色的缺口，看着像进度条没铺满。
* 测试仍是 24 条（进度条用例改为断言满宽 + 端点不带圆角 + 靠卡片裁剪收边）。

## 0.2.2

* 修复：卡片投影被进场动画裁成直角。`SizeTransition` 内部的 `ClipRect` 卡在
  卡片边界上，于是最后一张卡片下方没有阴影、左右两侧是硬边、卡片之间的缝被
  切出一条直角灰带。现在改成「自定义裁剪盒（四周放大 `elevation * 2 + 4`）+
  `Align(heightFactor:)`」，尺寸动画照旧，投影完整。
* 修复：`spacing` 默认 10 → 16。上下两张卡片的影子本来会在 10px 的缝里接上，
  看着像一条灰带。
* 性能：每张卡片包一层 `RepaintBoundary`。倒计时进度条每帧都在动，之前会把
  整棵树（含整个应用的窗口）标脏重绘，进场动画也因此会卡。
* 修复：`adoptStyle` 在样式没换时不再 `_bump()`，避免宿主重建时在别人 build
  阶段把通知层标脏。
* 新增：`NotificationStyle.copyWith(clearDuration: true)`，把倒计时去掉（不再
  自动关闭，也没有进度条）——之前 `duration` 传 `null` 会被当成「沿用原值」。
* 测试 24 条（新增：`show` 之后下一帧就上屏、进场裁剪盒给投影留余量、
  `clearDuration`）。

## 0.2.1

* 卡片外观回到 `Material` 本体：`elevation` 直接交给 `Material.elevation`，圆角、
  裁剪、投影一起由它负责（`surfaceTintColor: Colors.transparent`，elevation 不会
  把 `backgroundColor` 染成主题色）。默认 `elevation` 由 8 降到 4——卡片之间只隔
  `spacing`，8 的投影会把缝填成一条灰带。
* 修复：底部进度条两端改成胶囊圆角（`height / 2`）。之前两端是垂直切平的，底面
  两个角看着就是 90° 的直角块。
* 测试 21 条（新增：卡片用自己的 `Material` 投影）。

## 0.2.0

API 收敛：装饰 / 布局 / 行为参数全部搬进 `NotificationStyle`，底部进度条不再压圆角。

* **破坏性**：`show` / `success` / `error` / `warning` / `info` / `loading` /
  `update` 去掉 `icon` / `color` / `showProgress` / `duration` / `position`，统一
  换成 `style`；单条传入时整条替换全局样式，改一两项用
  `NotificationCenter.style.copyWith(...)`。`icon` / `color` 变成
  `NotificationStyle.icon` / `accentColor`，`duration` 允许为 `null`（不自动关闭）。
* **破坏性**：`child` 改名 `content`，`NotificationData.child` →
  `NotificationData.content`；新增 `NotificationCenter.custom(content, ...)`，
  用于只放自定义内容的通知。
* `show(kind: ...)` 的 `kind` 改为可空：新通知默认 `info`，同 `id` 更新时不传就
  保持原类型。
* 修复：底部进度条左右各让出一个圆角宽度（`radius`），只铺在底边直线段上，
  不再被圆角切出尖角。
* 修复：卡片投影改成自己画的 `BoxShadow`（不再用 `Material.elevation`）。原来多条
  卡片只隔 10px，硬投影叠起来是一条灰带，看着像底部多了一道边。
* 修复：新通知插入时旧卡片被重建、重播进场动画（表现为整列塌下去再展开）。key
  从 `NotificationCard` 挪到 `Column` 的直接子节点 `SizedBox` 上，现在旧卡片只
  平移让位。
* 修复：`update` 不再重置倒计时，只有 `duration` / `kind` 变了才重新计时。
* `NotificationData.effectiveStyle(global)` 暴露单条实际生效的样式。
* 测试 20 条（新增：单条样式覆盖不影响其它条、`custom()`、进度条不侵入圆角、
  旧卡片不重播进场、`update` 不重置计时）。

## 0.1.0

首个版本：全局应用内通知。

* `NotificationCenter` 静态入口：`show` / `success` / `error` / `warning` /
  `info` / `loading` / `dismiss` / `dismissAll`，调用不需要 `BuildContext`。
* `NotificationHost` 挂在 `MaterialApp.builder` 里，通知画在 `Navigator` 之上
  （对话框上层可见），通知层自带 `Overlay`，卡片里可以用 `Tooltip` 等组件。
* 六个停靠位置：`topLeft` / `topCenter` / `topRight` / `bottomLeft` /
  `bottomCenter` / `bottomRight`，可全局配置也可单条覆盖。
* 自动倒计时 + 底部进度条，鼠标悬停暂停；`maxVisible` 超出时最早一条自动收起。
* `NotificationHandle` 支持 `update(...)` / `close()`；同 `id` 的 `show` 等于就地
  更新，适合进度类通知；`loading` 更新成其它类型时自动补上默认时长。
* `NotificationStyle` 统一控制宽度、边距、间距、圆角、阴影、字体、动画时长、
  最大条数、默认位置与时长；`NotificationAction` 支持卡片内按钮。
* 通知层只有卡片参与命中测试，空白区域点击穿透到应用。

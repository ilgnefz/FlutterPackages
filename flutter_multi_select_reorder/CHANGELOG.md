## 0.0.1

* 从 `multi_select_reorder` 迁移为 `flutter_multi_select_reorder`，入口改为
  `package:flutter_multi_select_reorder/flutter_multi_select_reorder.dart`。
  公开组件名（`MultiSelectReorder` / `MultiSelectController` /
  `MultiSelectStyle` 等）保持不变。
* 初始版本：`MultiSelectReorder.list` / `.grid`，支持多选、整组拖动排序、
  自定义预览与占位框。
* 组件不持有业务数据：传 `itemCount` + `itemBuilder(context, index, selected)`，
  `onReorder` 回传一一对应的 `oldIndex` / `newIndex`（只含被拖条目，长度 = 被拖数），
  配套 `applyMultiReorder(items, oldIndex, newIndex)` 完成数据重排。
* 参数名对齐官方 `ReorderableListView` / `GridView`：`padding`、`proxyDecorator`
  （原 `feedbackBuilder`）、`onReorderStart` / `onReorderEnd`；list 用 `spacing`，
  grid 用 `mainAxisSpacing` / `crossAxisSpacing`（原 `MultiSelectStyle` 里的
  `spacing` / `padding` 一并移到形态构造器上）。
* 拖动期间条目自动退出命中测试：鼠标一直悬在列表上，被拖条目滑过邻居、
  邻居被顶到指针底下时 InkWell 会亮起 hover 高亮再灭掉，看着像卡顿。
  现在拖动中不响应 hover，指针样式由跟随指针的浮层接管，松手立即恢复。
  `Listener` 改为 `HitTestBehavior.opaque`，保留「up 丢失后靠新的按下兜底
  收尾」这条安全网。
* `MultiSelectStyle.selectedBuilder` 签名增加 `selectedIndex`：
  `(child, index, selectedIndex) => Widget`，`selectedIndex` 是该项在选中顺序
  里的位置（0 起），可直接用来画「第几个选中」的角标。
* 修正连续拖动时抛 `_AnimatedSlotState is a SingleTickerProviderStateMixin
  but multiple tickers were created`：让位容器的动画 controller 跑完会销毁，
  下次落点变化再新建一个，改用 `TickerProviderStateMixin`。
* `MultiSelectStyle` 新增 `selectionColor` / `selectionBorder`：不自定义
  `itemBuilder` 时也能给选中项一键叠高亮，默认 null 保持旧行为。
* 默认选中语义改为「单击单选 / Ctrl・Cmd 切换 / Shift 范围选」
  （`MultiSelectStyle.mode` 默认 `.single`；旧行为可显式传 `.multiple`）。
* list 的 `spacing` 默认值改为 `0.0`。
* 修正 `selectionColor` 盖住条目内容的问题：底色改画在 `itemBuilder`
  背后；`selectionBorder` 仍画在内容上方，避免被不透明背景遮住。
* 拖动预览按点选顺序把整组叠成多张卡片（每层 `itemBuilder` + 不透明背景
  与阴影），恢复 `maxFeedbackLayers` / `feedbackLayerStep`；顶层固定是第一个
  被选中的项，超出上限用角标 `+N` 提示；`showFeedbackBadge` 改为默认
  `true`，但单条 / 未超上限时不会显示 `+0`。
* 松手不再先弹回原位：拖拽回调放到 `try/finally` 的收尾之前，回调抛错也会
  清掉浮层与全局路由，不再卡在拖动态。
* 松手后补上落位过渡动画：被拖条目从松手位置平滑滑进自己的槽位（时长同
  `MultiSelectStyle.duration`），不再瞬间出现。实现方式是松手时把「落点 →
  目标槽位」的差值传给新建的让位容器；整组拖动时每层各滑到自己的格子。
* 落点占位区回到**只占 1 格**：整组拖动时不会在列表里留一大片空白。松手后
  卡片落位与其余条目后移**同时进行**：被拖的卡片从落点滑进自己的槽位，
  后面的条目同时后移让出整组的 `k - 1` 格，整块一起收拢，只花一个 `duration`。
* 落位动画期间延迟提交：列表先按「重排后的顺序」重排**旧数据**把动画播完，
  再把 `onReorder` 交给父组件。条目元素默认按下标做 key，若数据先变，
  同一下标里的内容会换成别的条目，插值会让条目「跳到别处再滑回来」。
  这期间再按下会先把重排结果提交并映射下标，不会吃掉后续点击 / 拖动。
* `proxyDecorator` 签名改为与官方 `ReorderItemProxyDecorator` 完全一致：
  `(Widget child, int index, Animation<double> animation) -> Widget`，
  并提供拖起 0→1 / 松手 1→0 的 animation；多选时逐层调用。默认预览每层
  都包一层不透明的主题 surface 背景，不再透出下面的列表。
* `MultiSelectStyle` 新增 `hoverColor`：传给每个条目的 `InkWell.hoverColor`，
  默认 null 即 `InkWell` 自身的主题默认效果，传 `Colors.transparent` 可关闭。
* `MultiSelectStyle` 新增 `mouseCursor`：传给自动包裹的 `InkWell.mouseCursor`，
  默认 null 走 `InkWell` 默认的可点击指针；可直接设 `SystemMouseCursors.grab`
  等，不必在每个 `itemBuilder` 里另套 `MouseRegion`。
* `MultiSelectStyle` 新增 `selectedBuilder(child, index, selectedIndex)`：
  选中条目的二次装饰（如左上角「第几个选中」序号角标），只在选中时调用，
  未选中与拖动浮层都不调用。
* 让位动画对齐官方 `ReorderableListView`：内部由 `AnimatedPositioned` 改为
  `Positioned + Transform.translate`，并在落点连续变化时从当前视觉位置续接
  动画，避免快速跨格拖动时一顿一顿。
  点击仍走 `onItemTap` + 选中逻辑，与自动包裹的 `InkWell` 无关（其 onTap 为空）。
* `+N` 角标统一包一层透明 `Material`，默认文字再显式
  `decoration: TextDecoration.none`：避免 Overlay 里裸 `Text` 继承
  `MaterialApp` 传给 `WidgetsApp` 的 `_errorTextStyle`（红色等宽 + 下划线）。
  自定义 `feedbackBadgeBuilder` 的结果同样受这层 `Material` 保护。
* 单击语义补完：单击选中该项，**再点同一个条目取消选中**（不必按 Ctrl）。
  点别的条目仍是单选（清空其它）。
* 条目 key 也会自动读 `itemBuilder` 结果自带的 key：给条目根 widget 加个业务
  key（`key: ValueKey(item.id)`，和普通 `ListView` 一样）就行，不必再额外写
  `itemKeyBuilder`。优先级：`itemKeyBuilder` > 条目自带 key > 按 index 生成。
  让位容器用的是包了一层 `ValueKey<Key>` 的 key，不会和条目自身（含
  `GlobalKey`）重复。
* 新增 `MultiSelectStyle.borderRadius`：一个值同时把圆角应用到条目内容裁剪、
  hover 高亮 / ripple、`selectionColor` / `selectionBorder`、默认拖动预览与
  占位框（优先于 `feedbackBorderRadius`）。不传仍保持原来的直角观感。
* 让位 / 落位动画默认值改为与官方 `ReorderableListView`、`reorderable_grid`
  一致：`duration` 160ms → **250ms**，`curve` `Curves.easeOutCubic` →
  **`Curves.easeInOut`**。原先 160ms + easeOut 起步太猛，快速跨格拖动时邻居
  看起来「一下一下地蹿」；官方那组值慢起慢收，打断续接更连贯。
* 拖动浮层的位置改为「全局坐标 − Overlay 原点 − 抓取偏移」，与官方
  `_DragItemProxy` 的 `_overlayOrigin` 一致。浮层原来是直接用全局坐标放
  `Positioned`，只有 Overlay 正好贴在屏幕左上角时才正确；`useRootOverlay:
  false`（挂在页面自己的 Overlay）或嵌在别的 Overlay 里时会整体偏移一段，
  看上去就是「浮层不跟手 / 和指针错位」。新增嵌套 Overlay 的回归测试。
* 拾起动画时长 180ms → **250ms**，与官方 `_DragInfo.startDrag()` 同值
  （它同时是松手后浮层飞向落点的插值时长）。阴影淡入改用 `Curves.easeOut`
  驱动，起步就把大部分阴影推上去，观感仍是「瞬间拾起」。
* `dragSlop` 默认 6 → **4**（Windows 拖拽阈值 `SM_CXDRAG` 同值）。官方鼠标
  用 1px，但它从专用拖拽把手 / 长按起拖，不会吃掉单击；本组件「按下即可拖」，
  这个阈值同时是单击与拖动、以及「抖动不会把条目挪一格」的分界。
* 补充「浮层跟手」的契约测试：逐帧断言 `浮层位置 == 指针 - 抓取偏移`（list
  与 grid 各一条），防止以后不小心给浮层加上缓动 / 阻尼。
* 新增 `onDoubleTap`（`.list` / `.grid` 同签名）与 `MultiSelectStyle.doubleTapMode`：
  双击判定用官方常量（`kDoubleTapTimeout` 300ms、`kDoubleTapSlop` 100px）自己认，
  不再依赖手势竞技场。`.delay`（默认）先把单击挂起、窗口过去才提交选中，双击
  则完全不改选中；`.revert` 单击立刻提交、双击时用提交前的快照回滚选中（零延迟，
  代价是双击时选中亮一下）。第二次按下落在同一项时会把挂起的提交**冻结**，
  所以「按住第二下超过 300ms 再松手」也认得出是双击；起拖、点了别的项、手势被
  cancel 时都会先把挂起的单击落地。不传 `onDoubleTap` 时单击路径与以前逐字节一致。
* 拖动时的每帧开销对齐官方：每个槽位套一层 `RepaintBoundary`，让位 / 落位只挪
  layer，不再把条目内容（尤其图片）跟着重画 —— 官方
  `SliverChildBuilderDelegate` 默认 `addRepaintBoundaries: true` 是同一个思路。
* 缓存 `itemBuilder` 的结果（按原下标）：让位 / 落位动画每帧都会重建可见条目，
  但条目数据没变时不再重复调用 `itemBuilder`。之前 `itemBuilder` 里做文本测量
  （如 AdvanceText 的 TextPainter 二分）或图片树时，profile 里每帧 build 50~250ms；
  现在只有数据 / 选中态变化那一帧重新构建。父组件 rebuild 走 `didUpdateWidget`
  整体清空缓存，选中态变化只让对应条目失效。新增 3 条回归测试。
* 新增 `MultiSelectDoubleTapMode.immediate`：单击**零延迟**提交，双击只回调
  `onDoubleTap`、保留第一下单击的选中结果（不回滚、不闪烁）。专门解决传了
  `onDoubleTap` 后默认 `.delay` 让单击晚 300ms 才选中的问题；双击打开文件的
  场景（如资源管理器）用它最合适。`.delay` / `.revert` 行为不变。
* 说明为什么不用 `InkWell.onTap` 隔离双击：`GestureDetector` 同时挂 `onTap` +
  `onDoubleTap` 时 `onTap` 本来就要等双击超时，延迟只是挪进框架；且本项目
  起拖走原始指针事件、阈值 4px 小于 `kTouchSlop`，拖动松手可能被框架判成 tap。
* `MultiSelectSelectedBuilder` 增加第 4 个参数 `selectedCount`（当前总选中数）。
  典型用法：只选中一个时不画序号角标（单选时角标没有区分作用）。这是一次
  签名变更，所有 `selectedBuilder` 实现都要加这个参数。
* 拖动性能第二层优化：缓存整棵条目外壳（选中装饰 + 角标 + Listener /
  IgnorePointer / Material / InkWell），缓存命中时返回同一个 Widget 实例，
  Flutter 直接跳过子树 rebuild；让位动画帧里只剩 `_AnimatedSlot` 的
  Positioned / Transform。新增回归测试断言动画帧不再重调 `selectedBuilder`。
* 新增 `MultiSelectDoubleTapMode.selectOnly`：单击零延迟；双击时把被双击项
  强制设为**唯一选中**，不再像 `.revert` 那样把双击前的整份选中恢复回来
  （那会把第一下清掉的其它选中项又选回来）。适合「双击打开文件、同时让它
  成为唯一选中项」。双击已选中项时第一下会先取消、第二下再选中，会闪一下。
* 文档补充「list/grid 切换时保留选中」：两个形态是不同 widget，切换会 unmount
  整棵子树，内部 controller 随之销毁；把 controller 提到外面（provider / 父
  State）让两边共用即可保留选中。新增回归测试锁住这一契约。注意两边下标
  必须同源；数据不同（如 grid 过滤条目）时按 index 存的 controller 不适用。
* 新增 `itemId`（`Object Function(int index)`）：传了之后 controller 内部按
  **稳定 id** 存选中，对外仍以下标读写（保持 API 兼容）。list/grid 切换、或
  grid 过滤掉部分条目时，选中不再因下标错位跳到别的条目；被过滤掉的选中项
  保留在 controller 里，切回全量视图重新出现。新增 `selectedIds` / 
  `allSelectedCount` 读全部选中，`selectedIndices` / `selectedCount` 只算当前
  视图可见。不传 `itemId` 时退化为下标，行为与旧版一致（含重排后的下标映射）。
* 新增**受控模式**：传 `selectedIds`（配合 `itemId`）后，选中集合以外部给的
  为唯一真值，组件只负责渲染 + 通知（`onSelectedIdsChanged` 回传完整 id 集合，
  含当前视图被过滤掉的）。组件点击后先乐观更新再通知外部；外部若没回写新值
  （拒绝这次改动），组件在下一帧静默回滚，界面不会和外部数据不一致。
  不传 `selectedIds` 时行为与旧版完全一致。
* 文档补充「样式由你的组件管」：`selectionColor` / `selectionBorder` 默认都是
  null，组件默认不画选中装饰，样式由 `itemBuilder` 的 `selected` 参数负责；
  `selectedBuilder` 是可选的二次装饰。
* **精简 API 表面**：删掉一批几乎不用、可以由外部接管的参数与回调，行为与核心
  能力（多选、整组拖动排序、让位 / 落位动画、双击、受控模式）完全不变。
  删除清单：
  - `MultiSelectStyle.selectionColor` / `selectionBorder`：组件不再画任何选中
    装饰，选中底色 / 描边由 `itemBuilder` 的 `selected` 自己画（更可控）。
  - `MultiSelectStyle.hoverColor` / `mouseCursor`：走 `InkWell` 自身默认效果。
  - `MultiSelectStyle.showFeedbackBadge` / `feedbackBadgeLabel` /
    `feedbackBadgeBuilder`：拖动预览不再显示角标。
  - `MultiSelectStyle.maxFeedbackLayers` / `feedbackLayerStep`：改为固定 4 层、
    固定 4px 偏移。
  - `MultiSelectStyle.placeholderBuilderWithInfo`（及 `MultiSelectPlaceholderInfo`
    / `MultiSelectPlaceholderBuilder`）：占位框只有 `placeholderBuilder` 一种。
  - `onItemTap` / `onReorderStart` / `onReorderEnd`：只留 `onReorder`。
  `MultiSelectStyle` 的参数从 26 个降到 16 个。
* 保留：`selectedBuilder`（需要点选序号时用）、`borderRadius`、`duration` /
  `curve`、`proxyDecorator`、`placeholderBuilder` / `placeholderColor`、
  `feedbackElevation` / `feedbackBorderRadius`、`useRootOverlay`、`dragSlop`、
  `enableDrag` / `enableAutoScroll`、`mode` / `doubleTapMode`、
  `initialSelectedIndices`，以及全部交互（单击 / 再点取消、Ctrl、Shift、双击、
  整组拖动）。
* 修正「整组拖回原位就白拖」：以前只在「落点 != 起点」时才提交重排，而整组是
  按**点选顺序**搬走的——选中 2、4、3 再拖回第 2 格，组内次序本该变成 2、4、3
  （结果是 `1,2,4,3,5,6`），却被当成原地放下，松手后列表退回原样。现在改成按
  「重排结果是否就是原顺序」判断，落点没变但组内次序变了也照常提交 `onReorder`。
* 拖动浮层改为按**未选中**构建（`itemBuilder` 的 `selected` 在浮层里恒为
  `false`）：以前浮层拿的是「选中态」内容，调用方把选中底色画在 `itemBuilder`
  里时，拖起来的那叠卡片会带着选中色。现在职责明确分开——`itemBuilder` 管默认
  样式、`selectedBuilder` 管选中样式、`proxyDecorator` 管拖动样式，三者互不串味。
  受影响：如果你依赖浮层里的 `selected == true`，改成在 `proxyDecorator` 里画。
* **删掉受控模式**（`selectedIds` / `onSelectedIdsChanged`）：选中集合只有一份
  真值，就在 `MultiSelectController` 里。以前传 `selectedIds` 相当于让 controller
  变成外部数组的缓存，两份真值要靠「乐观更新 + 下一帧没回写就回滚」来对齐，
  组件和调用方都得维护这套补偿逻辑。现在：
  - 读：`controller.selectedIndices`（当前视图可见）/ `selectedIds`（全部，含
    被过滤掉的）/ `allSelectedCount`；别的组件要刷新就 `ListenableBuilder`
    监听同一个 controller。
  - 写：新增 `controller.setIds(<Object>[...])`（按稳定 id 整体替换，顺序 =
    点选顺序），配合已有的 `setSelection` / `select` / `deselect` / `toggle` /
    `selectAll` / `clear`。
  - 校验类需求（最多选 N 个等）在调用 controller 的地方做，不再有「外部拒绝」机制。
  迁移：删掉 `selectedIds:` / `onSelectedIdsChanged:` 两个参数，把外部那份数组
  换成「同一个 controller + `ListenableBuilder`」；`itemId` 照旧。
* 恢复拖动浮层的 `+N` 角标：选中超过 4 项时，叠卡右下角显示「还有几项没画出来」
  （如选 6 项拖起 → `+2`）。之前精简 API 时把 `showFeedbackBadge` 连同这段绘制
  一起删了，右下角一直空着；现在内置、无开关，只在确实有被隐藏的项时出现。
  `proxyDecorator` 只管单层内容，角标仍由组件叠在最上面，自定义预览时
  也能看到「一共拖了几项」。
* 新增 `MultiSelectStyle.mouseCursor`：条目指针样式，同时作用于拖动浮层
  （浮层接管指针区域后沿用同一个 cursor，不会一拖就变回箭头）；不传则保持
  `InkWell` 默认。
* 新增 `onSecondaryTap(index, globalPosition)`：右键单击回调，`index` 是当前
  视图下标、`globalPosition` 是按下处全局坐标（直接喂 `showMenu`）。右键不参与
  选中，也不会起拖（内部指针逻辑只认左键）；不传时不注册右键手势。


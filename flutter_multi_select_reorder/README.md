# flutter_multi_select_reorder

Flutter 的「多选 + 整组拖动排序」列表 / 网格。一次可以选中多项并把它们作为一组拖动，落点只留一个占位框，其余条目平滑让位；松手后卡片落回槽位、其余条目同时后移让出整组的位置。

**组件不持有业务数据**：只接收 `itemCount` 与按坐标取数的 `itemBuilder`，松手后回传一一对应的 `oldIndex` / `newIndex`（只含被拖条目，不是整份顺序），由调用方重排自己的数据。

公开参数名尽量与 Material `ReorderableListView` / `GridView` 对齐：`itemCount`、`itemBuilder`、`itemExtent`、`padding`、`scrollController`、`proxyDecorator`、`onReorder` 含义一致；单列用 `spacing`，网格用 `mainAxisSpacing` / `crossAxisSpacing`。

## 特性

- `MultiSelectReorder.list` 单列列表，`MultiSelectReorder.grid` 多列网格，共用一套实现。
- 单击选中这一项（清空其它），**再点同一个条目取消选中**；Ctrl / Cmd 切换，Shift 从锚点追加一段范围；按住已选中项拖动即整组搬走。需要「点别的条目也能叠加」的旧行为时可显式设 `MultiSelectStyle(mode: MultiSelectMode.multiple)`。
- `onReorder` 回传一一对应的 `oldIndex` / `newIndex`，**只含被拖条目**——几千条数据也只回传几个整数；配套 `applyMultiReorder` 一行完成数据重排。
- 选中集合只有一份真值：`MultiSelectController`（按稳定 id 存、顺序 = 点选顺序）。list / grid 切换、grid 过滤掉一部分条目都不会丢；别的组件用 `ListenableBuilder` 监听同一个 controller 就能拿到最新选中。
- 样式三处各管一段：`itemBuilder` 只管默认样式，`selectedBuilder` 管选中样式（底色 / 序号角标），`proxyDecorator` 管拖动样式。拖动浮层恒按「未选中」内容构建，所以选中底色不会跟着卡片飞起来。`selectedIndex` 是选中顺序里的位置（0 起），`selectedCount` 是当前总选中数（可用来「只选一个就不画角标」）。
- `MultiSelectStyle.borderRadius` 一次把圆角应用到条目内容（裁剪）、hover 高亮、选中底色 / 描边和拖动预览；不传仍是直角。
- 组件会自动给每个 `itemBuilder` 结果包一层 `Material + InkWell`，不用自己再套 `MouseRegion`；hover 高亮与鼠标指针走 `InkWell` 自身的默认效果。
- 落点占位区始终只占 **1 格**：整组拖动也不会在列表里留一大片空白。
- 松手时卡片落位与其余条目后移**同时进行**，只花一个 `duration`：被拖的卡片从落点滑进自己的槽位，后面的条目同时后移让出整组的 `k - 1` 格，整块一起收拢（测试里可直接断言中途两者的位移）。
- 落位动画期间列表仍是旧数据（`onReorder` 等动画停下来才发），这样动画不会因为数据先变而错位；这期间再按下会先把重排结果提交，不会吃掉后续点击 / 拖动。
- 拖动过程中条目会自动退出命中测试，不响应 hover 高亮（否则指针扫过、邻居被顶到指针底下时会亮一下再灭，看着像卡顿），指针样式由跟随指针的浮层接管，松手后立即恢复。
- 拖动预览默认按点选顺序把整组叠成几张卡片（每层不透明背景 + 阴影，最多 4 张），选中超过 4 项时右下角显示 `+N` 交代还有几项没画出来；可用 `proxyDecorator` 逐层自定义；落点占位框可自定义；可关掉拖动或自动滚动。
- 指针与右键：`style.mouseCursor` 定制光标（拖动期间浮层沿用同一个），`onSecondaryTap` 拿右键下标 + 全局坐标弹自己的菜单。

## 性能：掉帧了怎么查

组件里已经做了三件事减少拖动时的每帧开销（都和官方 `ReorderableListView` 对齐）：

1. **只构建可见条目**：上下各多留一行做缓冲，屏幕外的槽位不调 `itemBuilder`；
2. **两层缓存**：让位 / 落位动画期间外层每帧重建，但条目数据没变时直接复用上次 `itemBuilder` 的返回值，以及整棵外壳（选中装饰 / 角标 / `Listener`/`InkWell`）。这点很关键——如果 `itemBuilder` 里做了文本测量（`TextPainter` 二分）、图片树这类昂贵操作，每帧重来就是 profile 里一长串 50～250ms 的 `build`。缓存命中时返回同一个 Widget 实例，Flutter 直接跳过整棵子树的 rebuild，动画帧里只剩 `_AnimatedSlot` 的 `Positioned`/`Transform`。父组件 rebuild（数据 / 主题 / builder 变了）会整体失效，选中态 / 角标序号变化只让那一个条目失效；
3. **每个条目一个 `RepaintBoundary`**：让位 / 落位只改 `Transform`，条目已经画好的内容（尤其图片）可以直接复用，动画帧里只挪一个 layer，不重画。官方 `SliverChildBuilderDelegate` 默认 `addRepaintBoundaries: true` 就是同一个思路。

注意 `build` 和 `raster` 要分开看：`build` 高说明是 Widget 构建 / 布局（上面的缓存就是治这个）；只首帧 `raster` 特别高通常是图片按原尺寸解码或 SVG 首次解析，给 `Image` 设 `cacheWidth/cacheHeight`、避免带 `feFlood` / `feColorMatrix` 这类滤镜的 SVG（`flutter_svg` 不支持，会打 warning 并走慢路径）即可。

还是卡就用数据说话（**debug 模式必然卡，必须 profile**）：

```dart
// main() 里加：
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    for (final FrameTiming t in timings) {
      final int build = t.buildDuration.inMicroseconds;
      final int raster = t.rasterDuration.inMicroseconds;
      // 一帧的预算是 16.7ms（60Hz）/ 8.3ms（120Hz）。
      if (build > 16700 || raster > 16700) {
        debugPrint('[jank] build=${build / 1000}ms raster=${raster / 1000}ms');
      }
    }
  });
  runApp(const MyApp());
}
```

先看是 `build` 超还是 `raster` 超：`build` 超 = Dart 侧 Widget 构建 / 布局太多；`raster` 超 = 光栅化（阴影、裁剪、大图缩放）太重。

更省事的两种：

- `MaterialApp(showPerformanceOverlay: true)`（profile 模式），出现两条柱状图，超过预算会变红，一眼能看出 UI / Raster 哪边超；
- `flutter run --profile` 后用 DevTools 的 **Performance** 页转一次拖动，看 frame chart 里哪一帧变红，再点开看 timeline 里耗时最长的事件。

## 单击与双击

组件自己解析指针事件（拖动要绕过手势竞技场），所以双击也是自己认的：**两次「按下没拖动就松手」落在同一条目、相距不超过 `kDoubleTapSlop`（100px）、间隔不超过 `kDoubleTapTimeout`（300ms）** 就是双击。

双击要不要影响选中，取决于 `MultiSelectStyle.doubleTapMode`：

| | `.delay`（默认） | `.revert` | `.immediate` | `.selectOnly` |
|---|---|---|---|---|
| 单击生效时机 | 晚 300ms（等双击窗口过去） | 立刻 | 立刻 | 立刻 |
| 双击时的选中 | 完全不动（那次单击被丢掉） | 回滚成双击**之前**的整份选中（可能把第一下清掉的其它项又选回来） | 保留第一下单击的结果，不回滚 | 被双击项设为**唯一选中**，其它项保持取消 |
| 视觉 | 无闪烁 | 双击时选中会亮一下再灭 | 无闪烁 | 只双击已选中项时会闪一下（先取消再选中） |
| 双击会不会改选中 | 不会 | 不会（回滚掉了） | 会——等于第一下单击的效果 | 会——只留被双击项 |
| `onSelectionChanged` | 只在单击时触发一次 | 双击时按单击触发，回滚时再触发一次 | 双击时按单击触发一次，不回滚 | 双击时按单击触发一次；强制选中时可能再触发一次 |

怎么选：

- **双击打开文件、并让它成为唯一选中项**（其它选中项在第一下就被清掉、第二下不要选回来）→ `.selectOnly`；
- 双击只是辅助操作、能接受单击晚 300ms → `.delay`（默认，等同 Flutter 原生 `onTap` + `onDoubleTap`，完全不闪）；
- 要求双击**绝对不改选中**、又不想让单击等 300ms → `.revert`（代价是双击时选中闪一下，且被第一下清掉的其它项会回来）；
- 想让双击等于第一下单击的结果、不回滚也不闪 → `.immediate`。

> 为什么不是「把选中放进 `InkWell.onTap` 隔离双击」？`InkWell` / `GestureDetector`
> 同时挂 `onTap` 和 `onDoubleTap` 时，`onTap` 本身就要等双击超时才触发——延迟只是
> 从组件挪进了框架，并不会消失。而且本项目起拖走原始指针事件、阈值 4px 远小于
> 系统的 `kTouchSlop`（18px），拖动松手时框架的 tap recognizer 仍可能判成一次 tap，
> 把选中状态搞乱。所以四种模式都在组件自己的状态机里实现，单击零延迟用的是
> 「先提交」路径，不走手势竞技场。

不传 `onDoubleTap` 时这一段完全不生效，单击立刻选中，和以前一样。

## list / grid 切换时保留选中

`MultiSelectReorder.list` 和 `.grid` 是两个不同的 widget；切换时旧的那棵会被
**整棵 unmount**，内部自建的 controller 也跟着销毁，选中自然就没了。要跨切换
保留选中，把 controller 放到视图外面（StatefulWidget 的字段、provider 等都行），
两个视图都传同一个：

```dart
final selectionControllerProvider = Provider<MultiSelectController>((ref) {
  final controller = MultiSelectController();
  ref.onDispose(controller.dispose);
  return controller;
});

// list 与 grid 的 build 里都：
MultiSelectReorder.grid(
  controller: ref.watch(selectionControllerProvider),
  ...
);
```

### 两个视图数据不同（grid 过滤掉一部分）

下标不再对齐时，再传 `itemId` 给每个视图，用跨视图稳定的 id（如文件 id）
标记条目。controller 内部改按 id 存选中，切换后 id 会归到各自的新下标：

```dart
// list：全量数据
final all = ref.watch(sortListProvider);
MultiSelectReorder.list(
  controller: ref.watch(selectionControllerProvider),
  itemCount: all.length,
  itemId: (int i) => all[i].id,
  ...
);

// grid：只显示图片，是子集且顺序可能不同
final images = all.where(isImage).toList();
MultiSelectReorder.grid(
  controller: ref.watch(selectionControllerProvider),
  itemCount: images.length,
  itemId: (int i) => images[i].id,
  ...
);
```

语义：

- 选中按 **id** 保存，点选顺序保留（不是按当前下标排）；
- grid 里看不见的选中项**不会被清掉**，切回 list 会重新出现；
- `onSelectionChanged` / `controller.selectedIndices` 回传的是**当前视图可见**的
  下标；要拿全部选中项用 `controller.selectedIds`；
- 重排时 `onReorder` 回传的是**当前视图**的下标，视图数据不同时调用方要自己
  映射回自己的数据源。

## 选中真值只在 controller 里

选中集合的**唯一真值**是 `MultiSelectController`：它按点选顺序存稳定 id，
组件只是它的一份视图。所以**不要**在外面再存一份选中数组（`selectedIds` 这类
受控参数已经删掉）——两份真值迟早会不一致，还得配一套「乐观更新 + 下一帧
回滚」来兜底。

```dart
// 一个 controller 用到底（list / grid 共用它，切换视图不丢选中）
final MultiSelectController controller = ref.watch(selectionControllerProvider);

MultiSelectReorder.grid(
  controller: controller,
  itemCount: files.length,
  itemId: (int i) => files[i].id,                  // 稳定 id，跨过滤视图也对得上
  itemBuilder: (context, index, _) => MyTile(file: files[index]),   // 默认样式
  style: MultiSelectStyle(
    selectedBuilder: (child, index, selectedIndex, selectedCount) =>
        SelectionOverlay(child: child),                             // 选中样式
  ),
);

// 别处要用选中：直接读同一个 controller
controller.selectedIndices;   // 当前视图可见的下标（点选顺序）
controller.selectedIds;       // 全部选中的 id，含当前视图被过滤掉的
controller.allSelectedCount;  // 全部选中数
```

**别的组件怎么跟着刷新**：controller 是 `ChangeNotifier`，包一层
`ListenableBuilder`（或 `AnimatedBuilder`）监听同一个实例即可：

```dart
ListenableBuilder(
  listenable: controller,
  builder: (context, _) => Text('已选 ${controller.allSelectedCount} 个'),
)
```

Riverpod 里想保持 provider 风格也可以：把 `selectionControllerProvider` 写成
`ChangeNotifierProvider`（Riverpod 3 里在 `flutter_riverpod/legacy.dart`），再用
一个 `Provider` 派生 `controller.selectedIds` —— 派生的只有读，不会变成第二份真值。

**从外部改选中**：

| 想做的事 | 写法 |
|---|---|
| 按稳定 id 恢复 / 替换（顺序 = 点选顺序） | `controller.setIds(<Object>['a3', 'f1'])` |
| 按当前视图下标 | `controller.setSelection(<int>[1, 3])` |
| 单个增删 / 切换 | `select(i)` / `deselect(i)` / `toggle(i)` |
| 全选 / 清空 | `selectAll()` / `clear()` |

校验类需求（比如「最多选 3 个」「某些项不可选」）建议在**调用 controller 的
地方**做（点击前拦截或在 `ListenableBuilder` 里回退），而不是指望组件回滚——
组件不再有「外部拒绝」这套机制。

## 样式：三处各管一段

组件不画任何选中装饰。样式按「谁在什么状态下负责」分成三份，互不覆盖：

| 钩子 | 管什么 | 什么时候调用 |
|---|---|---|
| `itemBuilder` | 条目的**默认样式**（内容本体） | 每次渲染；`selected` 参数仅供参考，**拖动浮层里恒为 `false`** |
| `selectedBuilder` | **选中样式**（底色、序号角标、描边） | 只在条目被选中时 |
| `proxyDecorator` | 拖动浮层的**拖动样式**（阴影 / 缩放 / 透明度） | 拖起时每层一次，拿到 `animation` |

浮层是拿 `itemBuilder` 的「未选中」内容再套 `proxyDecorator` 拼出来的，`selectedBuilder` 完全不参与——所以选中样式天生只属于列表里的条目，拖起来的那叠卡片永远是「默认样式 + 拖动样式」，不会带着选中底色。

> 早期版本浮层是按「选中」构建的，`itemBuilder` 里画了选中底色就会跟着卡片飞起来；现在已经反过来固定成未选中，这类串色不会再发生。

```dart
itemBuilder: (context, index, selected) => MyItem(file: files[index]),  // 默认样式
proxyDecorator: (child, index, animation) => MyDragStyle(              // 拖动样式
  animation: animation,
  child: child,
),
style: MultiSelectStyle(
  selectedBuilder: (child, index, selectedIndex, selectedCount) =>      // 选中样式
      SelectionOverlay(
        index: selectedCount > 1 ? selectedIndex : null,
        child: child,
      ),
),
```

`selectedBuilder` 是可选的：选中底色画在 `itemBuilder` 里也能工作（浮层不受影响），
但只有这里能拿到 `selectedIndex` / `selectedCount`，画序号角标必须用它；序号也可以
从 controller 里算（`controller.selectedIds.indexOf(id)`，要在 `ListenableBuilder` 里
读才会跟着刷新）。

## 跟手：浮层怎么跟着指针走

浮层位置 = **指针位置 − 抓取偏移 − Overlay 原点**，每个指针事件重算一次，中间**没有**补间、缓动或阻尼：指针走 1px，浮层就走 1px。测试里逐帧断言这个等式（`浮层跟手：每一帧都贴在指针上`），以后想加平滑效果得先改那条测试。

和官方 `ReorderableListView` / `reorderable_grid` 的数值对照：

| 项 | 官方 | 本组件 |
|---|---|---|
| 浮层跟手 | 指针位移 1:1，无插值 | 同（逐帧 0 偏差） |
| 浮层坐标基准 | 全局坐标 − `_overlayOrigin`（Overlay 原点） | 同 |
| 拾起动画（`proxyDecorator` 拿到的 `animation`） | 250ms | 同 |
| 让位 / 落位动画 | 250ms + `Curves.easeInOut` | 同 |
| 起拖阈值 | 鼠标 / 笔 `1`、触摸 `18`（`computeHitSlop`） | `4`（见 `dragSlop` 的说明） |
| 落点判定 | 浮层首尾与条目中线比较 | 指针所在格（过界即换，更直接） |
| 自动滚动 | 边缘速度曲线 | 距边 `scrollEdgeZone` 内按比例加速，每帧最多 `maxScrollStep` |

所以「松手前浮层跟不上指针」不是设计。真遇到时先看 Overlay：`useRootOverlay: false` 或嵌在别的 `Overlay` 里时，浮层用的是 Overlay 自己的坐标系，必须减掉 Overlay 原点，否则会整体偏移一段（看着就像拖不动 / 拖不跟手）；这一点现在与官方一致，也有回归测试。

## 使用

```dart
import 'package:flutter_multi_select_reorder/flutter_multi_select_reorder.dart';

List<String> items = ['A', 'B', 'C', 'D'];

SizedBox(
  height: 300,
  child: MultiSelectReorder.list(
    itemCount: items.length,
    spacing: 8,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    itemBuilder: (context, index, selected) => ListTile(
      // 业务 key（和普通 ListView 一样）：增删条目时后续项会平滑移到新槽位，
      // 条目内部 State（输入内容、展开状态等）也跟着自己的数据走。
      // 不写就按 index 生成 key，增删时元素原地换内容、没有位移动画。
      key: ValueKey(items[index]),
      selected: selected,
      title: Text(items[index]),
    ),
    onReorder: (oldIndex, newIndex) => setState(() {
      items = applyMultiReorder(items, oldIndex, newIndex);
    }),
  ),
)
```

网格形态（`mainAxisSpacing` 是行距，`crossAxisSpacing` 是列距）：

```dart
MultiSelectReorder.grid(
  itemCount: photos.length,
  crossAxisCount: 4,
  mainAxisSpacing: 8,
  crossAxisSpacing: 8,
  itemBuilder: (context, index, selected) =>
      PhotoTile(photo: photos[index], selected: selected),
  onReorder: (old, next) => setState(() => photos = applyMultiReorder(photos, old, next)),
)
```

拿选中项：

```dart
final controller = MultiSelectController();

MultiSelectReorder.list(
  controller: controller,
  itemCount: items.length,
  itemBuilder: (context, index, selected) => Text(items[index]),
);

final picked = controller.selectedIndices; // 按点选顺序的下标
final pickedItems = picked.map((i) => items[i]).toList();
```

不传 controller 时用 `onSelectionChanged` 拿选中下标。

默认单击选中该项，**再点同一个条目取消选中**；点别的条目只保留新点的一项。按住 Ctrl / Cmd 点击可逐项加减，Shift 点击会选中从上次单击位置到当前项的一段范围。

拖动起止（与官方同名同签名，参数是下标）：

```dart
MultiSelectReorder.list(
  itemCount: items.length,
  itemBuilder: (context, index, selected) => Text(items[index]),
  onReorder: (old, next) => setState(() => items = applyMultiReorder(items, old, next)),
)
```

两种形态都需要有界的主轴尺寸（如 `SizedBox` / `Expanded`），因为让位动画使用确定的槽位坐标。

## API 一览

### `MultiSelectReorder.list` / `.grid` 公共参数

| 参数 | 类型 | 默认值 | 意义 |
|---|---|---|---|
| `key` | `Key?` | `null` | Widget key。 |
| `itemCount` | `int` | 必填 | 条目总数。**组件不接收数据本身**，只用它算槽位；必须 ≥ 0。 |
| `itemBuilder` | `MultiSelectItemBuilder` | 必填 | 条目外观（**默认样式**）：`(context, index, selected) => Widget`。按 `index` 从调用方的数据源取内容。`selected` 只为方便，拖动浮层里恒为 `false`——选中底色请放 `selectedBuilder`，否则拖起来会带着选中色。 |
| `controller` | `MultiSelectController?` | `null` | 选中控制器。不传时内部自建，此时用 `onSelectionChanged` 取选中下标。**同一时刻只能挂一个视图**，但可以在 list/grid 切换时复用同一个 controller 来保留选中（视图被 unmount 时 controller 要活在外面，见下）。 |
| `style` | `MultiSelectStyle` | `const MultiSelectStyle()` | 交互与外观配置，见下方 [MultiSelectStyle](#multiselectstyle)。 |
| `padding` | `EdgeInsets?` | `null` | 内容区内边距（对齐官方 `ReorderableListView.padding`）；null 视为 `EdgeInsets.zero`。 |
| `scrollController` | `ScrollController?` | `null` | 外部滚动控制器；不传时内部创建。自动滚动就作用在这个 controller 上。 |
| `itemId` | `MultiSelectItemId?` | `null` | 下标 → 稳定 id。传了之后选中按 id 存，跨视图 / 过滤不丢；不传时 id 就是下标（旧行为）。详见「list / grid 切换时保留选中」。 |
| `itemKeyBuilder` | `MultiSelectKeyBuilder?` | `null` | Element key 的**显式**来源，通常不用传：给 `itemBuilder` 返回的根 widget 加业务 key（`key: ValueKey(item.id)`，和普通 `ListView` 一样）组件会自己读，效果相同。这里传了则以它为准，优先级高于条目自带的 key。两处都没给时按原下标生成，删除 / 插入中间项时元素原地换内容、**不会**有上移 / 下移动画。 |
| `proxyDecorator` | `MultiSelectProxyDecorator?` | `null` | 拖动浮层的**拖动样式**，**签名与官方 `ReorderItemProxyDecorator` 一致**：`(child, index, animation) => Widget`，`child` 是 `itemBuilder` 的「未选中」内容。多选时**逐层调用**，每层对应一个被拖条目，按点选顺序给出；`animation` 拖起 0→1、松手 1→0；整组下标走 `onReorder.oldIndex`。不传时按点选顺序叠加 `itemBuilder` 的结果，每层加不透明主题背景与 `feedbackElevation` 阴影；被拖数超过 4 层时右下角叠一个 `+N` 角标（`proxyDecorator` 只管单层内容，角标仍由组件加）。 |
| `initialSelectedIndices` | `List<int>` | `const []` | 首次构建时预选的下标；只在 controller 尚无选中项时生效。 |
| `onDoubleTap` | `void Function(int index)?` | `null` | 双击回调，参数是被双击条目的原下标。**传了它就等于开启单击 / 双击区分**：默认（`.delay`）单击会晚一个双击间隔（300ms）再提交选中，双击则完全不改选中、只调这个回调；想单击零延迟用 `MultiSelectStyle.doubleTapMode = .selectOnly`（双击打开文件并让它成为唯一选中项）、`.immediate` 或 `.revert`。不传时没有延迟，行为和以前一样。 |
| `onSecondaryTap` | `MultiSelectSecondaryTapCallback?` | `null` | 右键（二级点击）回调：`(index, globalPosition) => …`，`index` 是条目在当前视图里的下标，`globalPosition` 是右键**按下处**的全局坐标（`showMenu` 直接能用）。只在这一下被确认是右键单击时触发，被取消（窗口失焦等）不触发。**不改动选中**——要「先选中它再弹菜单」就在回调里自己调 `controller.setIds` / `toggle`；不传则完全不注册右键手势。 |
| `onSelectionChanged` | `ValueChanged<List<int>>?` | `null` | 选中变化时回调，参数是按点选顺序排列的**当前视图可见**下标。只是通知：真值仍在 controller 里，别用它维护第二份选中数组。 |
| `onReorder` | `MultiSelectReorderCallback?` | `null` | **顺序真的变了**才回调：`(oldIndex, newIndex)`，一一对应、只含被拖条目。原样放下不触发（整组按点选顺序搬回原处时组内次序会变，那也算变了，见下表），是唯一需要落库的回调。落位动画播完才发（比松手晚一个 `duration`），调用方照常用 `applyMultiReorder` 重排即可。 |

`onReorder` 的触发条件：

| 场景 | `onReorder` |
|---|---|
| 单击（没拖动） | — |
| 拖起来、原样放回原位 | — |
| 整组按点选顺序搬回原位（组内次序变了） | ✓ |
| 拖动并换位置 | ✓ |
| 拖动中被 cancel / 卸载 | — |

> 只有 `onReorder` 需要落库，参数是下标而不是完整顺序。
>
> 选中项按 id 存（传了 `itemId` 时），重排后自动跟着条目走，所以 `onReorder` 里只需重排数据，不用手动修正选中。

### 形态专属参数

| 构造器 | 参数 | 类型 | 默认值 | 意义 |
|---|---|---|---|---|
| `.list` | `itemExtent` | `double` | `48` | 固定行高。列表用确定槽位做让位动画，所以需要固定高度。 |
| `.list` | `spacing` | `double` | `0.0` | 行间距（主轴方向）。 |
| `.grid` | `crossAxisCount` | `int?` | `null` | 固定列数。传了就忽略 `maxCellWidth`。 |
| `.grid` | `maxCellWidth` | `double` | `120` | 自适应列数时的单元格最大宽度；容器越宽列数越多。 |
| `.grid` | `aspectRatio` | `double` | `1` | 单元格宽高比，用于推算高度（`宽 / aspectRatio`）。 |
| `.grid` | `mainAxisExtent` | `double?` | `null` | 直接指定单元格高度；传了就忽略 `aspectRatio`。 |
| `.grid` | `mainAxisSpacing` | `double` | `4` | 行间距（主轴方向），对齐官方 `GridView`。 |
| `.grid` | `crossAxisSpacing` | `double` | `4` | 列间距（交叉轴方向），对齐官方 `GridView`。 |

### `MultiSelectStyle`

| 属性 | 类型 | 默认值 | 意义 |
|---|---|---|---|
| `mode` | `MultiSelectMode` | `.single` | 单击语义：默认选中该项、再点取消，点别的条目只保留它；需要「点别的条目也叠加」的旧行为时传 `.multiple`。Ctrl / Cmd 与 Shift 行为不受影响。 |
| `doubleTapMode` | `MultiSelectDoubleTapMode` | `.delay` | 配了 `onDoubleTap` 时单击怎么让路：`.delay` 挂起单击 300ms 后再提交（不闪）；`.revert` 单击立刻生效、双击回滚成双击前的整份选中（零延迟但双击闪一下、其它选中项会回来）；`.immediate` 单击立刻生效、双击保留第一下的结果（零延迟、不闪）；`.selectOnly` 单击立刻生效、双击只留被双击项选中（零延迟，其它选中项不会回来）。详见「单击与双击」。 |
| `dragSlop` | `double` | `4` | 按下后移动超过该距离才算拖动，避免误触。官方 `ReorderableListView` 用 `computeHitSlop`：鼠标 / 笔 `1`、触摸 `18`；官方的 1px 之所以敢用，是因为它从**专用拖拽把手**或长按开始拖，阈值再小也不会把单击吃掉。本组件「按下任意位置就能拖」，这个值同时是「单击 / 拖动」的分界，太小会让鼠标点一下抖动 1–2px 就起拖、并可能把条目挪一格，所以取 `4`（Windows 自己的拖拽阈值 `SM_CXDRAG` 也是 4）。想更贴手可传 `1`，触摸端想更不容易误触可传 `18`。 |
| `duration` | `Duration` | `250ms` | 让位 / 落位动画时长，与官方 `ReorderableListView` / `reorderable_grid` 一致。松手后卡片落位与其余条目后移同时进行，总时长就是这个值。想更柔和可以调到 300–350ms（快速跨多格时滞后感也会更明显）。 |
| `curve` | `Curve` | `Curves.easeInOut` | 让位 / 落位曲线，官方同款。easeInOut 起步平缓，连续跨格被打断后从当前位置续接不会「一下一下地蹿」；换成 easeOut 会更跟手，但接续处显得更急。 |
| `enableDrag` | `bool` | `true` | 关掉后只保留多选，完全不响应拖动。 |
| `enableAutoScroll` | `bool` | `true` | 拖到可视区上下边缘时自动滚动。 |
| `scrollEdgeZone` | `double` | `48` | 距边缘多少像素内开始自动滚动。 |
| `maxScrollStep` | `double` | `18` | 自动滚动每帧最大位移。 |
| `placeholderBuilder` | `WidgetBuilder?` | `null` | 自定义落点占位框；为空时画主题色圆角虚框。拿不到落点信息时用这个。 |
| `placeholderColor` | `Color?` | `null` | 占位框填充 / 边框颜色；不传时跟随 `ThemeData.colorScheme.primary`。 |
| `feedbackElevation` | `double` | `6` | 默认预览顶层卡片的阴影高度；下面几层减半。 |
| `feedbackBorderRadius` | `double` | `4` | 默认预览卡片的圆角，同时用于默认占位框。 |
| `useRootOverlay` | `bool` | `true` | 拖动预览挂根 Overlay（能盖住 dialog）还是最近的 Overlay。 |
| `borderRadius` | `BorderRadius?` | `null` | 条目圆角，一次作用在三处：`itemBuilder` 的内容按它**裁剪**（铺满整格的底色 / 图片不会露直角）、hover 高亮与按下 ripple（`InkWell.borderRadius`）、以及默认拖动预览与占位框（优先于 `feedbackBorderRadius`）。默认 null = 全直角。例：`BorderRadius.circular(10)`。 |
| `selectedBuilder` | `MultiSelectSelectedBuilder?` | `null` | **选中样式**：`(child, index, selectedIndex, selectedCount) => Widget`，`child` 是 `itemBuilder` 画好的内容，`index` 是原下标，`selectedIndex` 是它在**选中顺序**里的位置（0 起，取消前面的选中项后自动前移），`selectedCount` 是当前总选中数（只选一个时常用来不画角标）。只在**选中**时调用；未选中不调用，拖动浮层也不调用——所以选中底色 / 角标放这里不会串到拖动卡片上。传了就替换该条目，通常包一层 `Stack`，但要写成 `Stack(fit: StackFit.expand, children: [child, ...])`——默认 `StackFit.loose` 或套 `Center` 会把紧约束放宽，条目会退回固有尺寸并居中（列表里看不出来，网格里会缩成一条）。 |
| `mouseCursor` | `MouseCursor?` | `null` | 条目上的鼠标指针，同时作用于**拖动浮层**（拖起来后浮层接管指针区域，用同一个 cursor，不会一拖就变回箭头）。默认 null = 交给 `InkWell`（可点击时手型，移动端退化箭头）。例：`mouseCursor: SystemMouseCursors.grab`。 |

### `MultiSelectController`

继承 `ChangeNotifier`，别的组件用它刷新时包一层 `ListenableBuilder` 监听。
**一个 controller 只服务一个视图**（但可以在 list / grid 之间复用，选中不丢）。

构造参数：

| 参数 | 类型 | 意义 |
|---|---|---|
| `initialSelectedIndices` | `Iterable<int>?` | 初始选中的下标，按传入顺序保存。视图绑定后生效。 |

读取：

| 成员 | 类型 | 意义 |
|---|---|---|
| `selectedIndices` | `List<int>` | 按点选顺序返回**当前视图可见**的选中下标。 |
| `selectedIds` | `List<Object>` | 按点选顺序返回全部选中 id（含当前视图被过滤掉的）。 |
| `allSelectedCount` | `int` | 全部选中数（含被过滤掉的）。 |
| `getSelectedIndices()` | `List<int>` | `selectedIndices` 的方法形式。 |
| `selectedCount` | `int` | 选中数量。 |
| `hasSelection` | `bool` | 是否有选中项。 |
| `isSelected(index)` | `bool` | 指定下标是否选中。 |

修改（都会发通知）：

| 方法 | 意义 |
|---|---|
| `prune()` | 保留的空操作（按 id 存选中后没有「越界下标」这个概念）。 |
| `setIds(ids)` | 用**稳定 id** 整体替换选中集合（保留传入顺序 = 点选顺序，去重）。 |
| `setSelection(indices)` | 用一组下标整体替换选中集合（保留传入顺序，去重、过滤越界）。 |
| `select(index)` | 选中指定下标（已选中则不动）。 |
| `deselect(index)` | 取消指定下标的选中。 |
| `toggle(index)` | 反转指定下标的选中状态。 |
| `selectAll()` | 全选（依赖视图绑定的 `itemCount`）。 |
| `clear()` | 清空选中。 |

### 回调与数据类型

| 类型 | 签名 / 字段 | 意义 |
|---|---|---|
| `MultiSelectItemBuilder` | `(BuildContext, int index, bool selected) → Widget` | 渲染单个条目的**默认样式**；按 `index` 从自己的数据源取内容。浮层里 `selected` 恒为 `false`。 |
| `MultiSelectSelectedBuilder` | `(Widget child, int index, int selectedIndex, int selectedCount) → Widget` | **选中样式**；`child` 是已画好的内容，`selectedIndex` 是选中顺序里的位置（0 起），只在选中时调用、不作用于浮层。 |
| `MultiSelectProxyDecorator` | `(Widget child, int index, Animation<double> animation) → Widget` | **拖动样式**；与官方 `ReorderItemProxyDecorator` 同签名，`child` 是 `itemBuilder` 的未选中内容，`index` 是原下标（多选时逐层调用，按点选顺序），`animation` 是拾起 / 回落动画。 |
| `MultiSelectKeyBuilder` | `(int index) → Key` | 条目 Element key 的显式来源；不传时自动用 `itemBuilder` 结果自带的 key。 |
| `MultiSelectReorderCallback` | `(List<int> oldIndex, List<int> newIndex) → void` | 拖拽结束；两组一一对应、只含被拖条目（长度 = 被拖数 k），不是整份顺序。 |
| `MultiSelectSecondaryTapCallback` | `(int index, Offset globalPosition) → void` | 右键单击；`index` 是当前视图下标，`globalPosition` 是按下处全局坐标，不改选中。 |


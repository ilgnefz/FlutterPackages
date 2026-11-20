part of '../flutter_multi_select_reorder.dart';

// ── 公开类型 ──────────────────────────────────────────────────────────────

/// 单击 / 双击的分工方式，见 [MultiSelectStyle.doubleTapMode]。
///
/// 只配了 `onDoubleTap` 时才起作用；没配时单击永远立刻生效。
enum MultiSelectDoubleTapMode {
  /// 单击先挂起，等过了双击间隔（`kDoubleTapTimeout`，300ms）还没有第二次
  /// 点击才提交选中；真来了双击就丢掉挂起的那次，选中**一点不变**。
  ///
  /// 与 Flutter 自己的 `GestureDetector(onTap: …, onDoubleTap: …)` 行为一致，
  /// 不会有选中闪烁。代价：单击选中会晚 300ms 才亮起来。
  delay,

  /// 单击立刻提交（零延迟），同时记住提交之前的选中；真来了双击就把选中
  /// 回滚成双击之前的样子，再调 `onDoubleTap`。
  ///
  /// 手感最跟手（Finder / 资源管理器就是这个模型），代价是双击时会看到选中
  /// 亮一下再灭，并且 `onSelectionChanged` 会先按单击触发一次
  /// （回滚时 `onSelectionChanged` 再触发一次）。
  revert,

  /// 单击立刻提交（零延迟），双击**只回调 `onDoubleTap`、不再改动选中**——
  /// 选中就保留第一次单击的结果，不回滚、不闪烁。
  ///
  /// 这是回调互不干扰的模式：单击响应最快、双击不闪。但要注意双击**会**
  /// 改选中——留下第一下单击的结果（单选模式下双击已选中的项会把它取消、
  /// 双击未选中的项会把它选中）。想让双击完全不动选中、与资源管理器 /
  /// Finder 一致，用 [revert]；代价是双击瞬间选中会闪一下。
  ///
  /// `onSelectionChanged` 在双击时仍会按单击触发一次。
  immediate,

  /// 单击立刻提交（零延迟）；双击时把**被双击的这一项设为唯一选中**，其它
  /// 选中项全部取消，然后回调 `onDoubleTap`。
  ///
  /// 和 [revert] 的区别：revert 会把选中回滚成双击**之前**的样子（可能又把
  /// 第一下清掉的其它项选回来），本模式只保留第一下的「清掉其它项」，并把
  /// 被双击项强制选中——适合「双击打开某个文件，同时让它成为唯一选中项」。
  ///
  /// 代价：如果被双击项本来就是选中的，第一下会先取消它、第二下再选中，
  /// 会闪一下；`onSelectionChanged` 在双击时可能再触发一次。
  selectOnly,
}

/// 松手且没发生拖动时（一次单击）的选中语义。
enum MultiSelectMode {
  /// 单击选中这一项（清空其它），**再点同一个条目取消选中**；
  /// Ctrl / Cmd 切换，Shift 追加一段范围。默认。
  single,

  /// 单击切换这一项；Ctrl / Cmd 同样切换，Shift 追加一段范围。
  /// 只有需要「点别的条目也能叠加选中」的旧行为时才显式指定。
  multiple,
}

/// 条目的稳定标识：把当前视图的下标映射成跨视图不变的 id（如文件 id）。
///
/// 传了它之后，选中按 id 保存：list / grid 切换、或 grid 过滤掉部分条目时，
/// 同一个 controller 里的选中不会因为下标错位而跳到别的条目上；被过滤掉的
/// 选中项会保留，切回全量视图时重新出现。不传时 id 就是下标（旧行为）。
typedef MultiSelectItemId = Object Function(int index);

/// 条目渲染。组件不持有数据，`index` 是当前槽位对应的下标，调用方自己按
/// 下标从数据源取内容。
///
/// **样式分三处管，别混在一起**：
/// - 这里只画**默认样式**（图片 / 文字等本体内容）；
/// - 选中样式（选中底色、序号角标、描边）放 [MultiSelectStyle.selectedBuilder]；
/// - 拖动浮层的样式（阴影、缩放、透明度）放 [MultiSelectStyle.proxyDecorator]，
///   它拿到的是这里画出来的**纯内容**。
///
/// `selected` 会传进来，但它**不参与拖动浮层**：浮层恒按 `false` 构建，再套
/// `proxyDecorator`。所以画在这里的选中视觉不会跟着卡片飞起来，拖动时看到的
/// 永远是「默认样式」——这正是想要的效果，也让两处样式互不牵连。
typedef MultiSelectItemBuilder = Widget Function(
  BuildContext context,
  int index,
  bool selected,
);

/// 自定义跟随指针的拖动预览，**签名与官方 `ReorderItemProxyDecorator`
/// 完全一致**：`(child, index, animation) -> Widget`。
///
/// - `child` 是 `itemBuilder` 已经画好的那一项（**未选中**的纯内容，见
///   [MultiSelectItemBuilder]）；拖动样式加在这一层，不要靠 `itemBuilder` 里的
///   `selected` 区分；
/// - `index` 是它的原下标。多选时**每一层都会调用一次**，按点选顺序给出；
///   超出 4 层的条目不会调用；
/// - `animation` 在拖起时 0→1、松手时 1→0（250ms，与官方 `_DragInfo` 同值），
///   与官方一样可用来驱动阴影 / 缩放；
///
/// 整组下标仍由 `onReorder` 的 `oldIndex` 回传：官方签名里没有整组下标的位置。
typedef MultiSelectProxyDecorator = Widget Function(
  Widget child,
  int index,
  Animation<double> animation,
);

/// 条目的 Element key：`(index) => Key`。
///
/// 决定「数据重排后这个元素跟着谁走」。**通常不用传**——直接在 `itemBuilder`
/// 返回的根 widget 上写 `key: ValueKey(item.id)` 就行，组件会自己读。
/// 只有在 key 不方便挂在条目上时（比如由外层统一提供）才需要这个回调；
/// 传了就以它为准，优先级高于 `itemBuilder` 结果自带的 key。
///
/// 两处都没给时按 `index` 生成：删除 / 插入中间项时元素原地换内容，条目内部
/// `State` 保不住，也不会有上移 / 下移动画。
typedef MultiSelectKeyBuilder = Key Function(int index);

/// 选中条目的二次装饰：`child` 是 `itemBuilder` 已经画好的内容，`index` 是
/// 原下标，`selectedIndex` 是它在**选中顺序**里的位置（0 起），`selectedCount`
/// 是当前总共选中了多少个。
///
/// `selectedCount == 1` 时常用来「只选一个就不显示序号角标」——单选时角标
/// 没有区分作用，多选时才需要。`selectedCount` 至少为 1（本 builder 只在
/// 选中时调用）。
///
/// 只在**选中**时调用，可据此叠角标（如左上角「第几个选中」的序号）、描边等。
/// 返回的 Widget 会替换原条目参与布局，所以通常包一层 [Stack] / [Badge]；
/// 未选中时不调用，条目原样显示。拖动浮层里的条目不会调用它。
typedef MultiSelectSelectedBuilder = Widget Function(
  Widget child,
  int index,
  int selectedIndex,
  int selectedCount,
);

/// 拖拽结束回调，语义对齐官方 `ReorderableListView.onReorder`，扩展到整组。
///
/// [oldIndex] 是被拖条目的原下标，按点选顺序排列；[newIndex] 是**同一批**
/// 条目重排后的新下标，与 [oldIndex] 一一对应。两组长度都是被拖条目数 k，
/// 而不是条目总数 —— 几千条数据也只回传几个整数。
///
/// 整组拖动时同一批条目保持相对顺序、作为一整块落在目标位置，所以
/// [newIndex] 是一段连续下标。调用方按它重排自己的数据：
///
/// ```dart
/// onReorder: (oldIndex, newIndex) => setState(() {
///   items = applyMultiReorder(items, oldIndex, newIndex);
/// }),
/// ```
typedef MultiSelectReorderCallback = void Function(
  List<int> oldIndices,
  List<int> newIndices,
);

/// 条目被**右键完整点一下**时回调（按下后原地抬起，右键拖动 / 中途划走不算）。
///
/// - [index] 是当前视图里的下标，和 `itemBuilder` 拿到的是同一个；
/// - [globalPosition] 是右键按下处的**全局坐标**，直接喂给
///   `showMenu(position: RelativeRect.fromLTRB(...))` 就能在指针处弹菜单；
/// - 回调**不改动选中**：右键通常要「先让这一项被选中再弹菜单」，需要的话在
///   回调里调 `controller.setIds` / `toggle` 自己处理——组件不替你决定右键的
///   选中语义（和资源管理器 / Finder 各有各的规矩）。
typedef MultiSelectSecondaryTapCallback = void Function(
  int index,
  Offset globalPosition,
);

/// 外观与交互配置；两种形态共用。
@immutable
class MultiSelectStyle {
  const MultiSelectStyle({
    this.mode = MultiSelectMode.single,
    this.doubleTapMode = MultiSelectDoubleTapMode.delay,
    this.dragSlop = 4,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeInOut,
    this.enableDrag = true,
    this.enableAutoScroll = true,
    this.scrollEdgeZone = 48,
    this.maxScrollStep = 18,
    this.placeholderBuilder,
    this.placeholderColor,
    this.feedbackElevation = 6,
    this.feedbackBorderRadius = 4,
    this.useRootOverlay = true,
    this.borderRadius,
    this.selectedBuilder,
    this.mouseCursor,
  });

  /// 单击选中语义，见 [MultiSelectMode]。
  final MultiSelectMode mode;

  /// 单击与双击怎么分工，见 [MultiSelectDoubleTapMode]。默认
  /// [MultiSelectDoubleTapMode.delay]。
  ///
  /// 注意：双击判定本身由双击间隔决定（`kDoubleTapTimeout` = 300ms，且两次
  /// 点击要落在同一条目、相距不超过 `kDoubleTapSlop` = 100px）。组件没有
  /// `onDoubleTap` 时这里不起作用，单击永远立刻生效。
  final MultiSelectDoubleTapMode doubleTapMode;

  /// 按下后移动超过该距离才算拖动，避免误触。默认 `4`。
  ///
  /// 官方 `ReorderableListView` 用的阈值是 `computeHitSlop`：鼠标 / 触控笔
  /// `1`、触摸 `18`（`kTouchSlop`）。但官方的拖动是从**专用拖拽把手**或
  /// 长按开始的，阈值再小也不会把「单击」吃掉；本组件是「按下任意位置就能
  /// 拖」，阈值同时充当「点击 / 拖动」的分界：太小的话鼠标点一下抖动
  /// 1–2px 就会起拖，浮层和占位框闪一下，点在格子边界上抖动还可能把条目
  /// 挪一格。所以取 `4` —— Windows 自己的拖拽阈值（`SM_CXDRAG`）也是 4。
  ///
  /// 想更贴手就传 `1`（官方鼠标值）；触摸端想更不容易误触就传 `18`。
  final double dragSlop;

  /// 让位 / 落位动画时长，默认 `250ms` —— 与官方 `ReorderableListView`
  /// （`_ReorderableItemState` 里 `AnimationController(duration: 250ms)`）
  /// 和 `reorderable_grid` 保持一致。调长（如 300–350ms）会更柔和，但快速
  /// 跨多格拖动时「追不上指针」的滞后感也会更明显。
  final Duration duration;

  /// 让位 / 落位动画曲线，默认 [Curves.easeInOut] —— 同样是官方
  /// `ReorderableListView` / `reorderable_grid` 的取值。
  ///
  /// 官方用的是「慢起 → 快 → 慢收」的 easeInOut，而不是 easeOut：连续跨格时
  /// 每次打断都从当前视觉位置重新起跑，easeOut 起步太猛会显得一下一下地蹿；
  /// easeInOut 起步平缓，接续起来更像一条连续的动画。
  final Curve curve;

  /// 关掉后只保留多选、不响应拖动。
  final bool enableDrag;

  /// 拖到可视区上下边缘时自动滚动。
  final bool enableAutoScroll;

  /// 距边缘多少像素内开始自动滚动。
  final double scrollEdgeZone;

  /// 自动滚动每帧最大位移。
  final double maxScrollStep;

  /// 自定义落点占位框（只需要 `BuildContext` 时用这个）；为空时画主题色
  /// 圆角虚框。
  final WidgetBuilder? placeholderBuilder;

  /// 占位框填充 / 边框颜色，不传时跟随 [ThemeData.colorScheme.primary]。
  final Color? placeholderColor;

  /// 默认拖动预览的阴影高度与圆角。
  ///
  /// 未传 `proxyDecorator` 时，预览按被拖条目逐层叠加，每层都是
  /// `itemBuilder` 画出来的那一项（未选中态）+ 不透明的 [Material] 背景与阴影。
  final double feedbackElevation;
  final double feedbackBorderRadius;

  /// 拖动预览挂根 Overlay（盖住 dialog）还是最近的 Overlay。
  final bool useRootOverlay;

  /// 条目圆角，一次性作用在条目相关的所有观感上：
  ///
  /// - `itemBuilder` 画出的内容按这个圆角**裁剪**（铺满整格的图片 / 底色不会
  ///   在四个角露出直角）；
  /// - 鼠标 hover 的高亮、按下 ripple 按这个圆角绘制（[InkWell.borderRadius]）；
  /// - 选中底色 / 描边由 `itemBuilder` 自己画时，也建议用同样的圆角；
  /// - 没自定义 `proxyDecorator` 时，拖动预览与占位框也用它（优先于
  ///   [feedbackBorderRadius]）。
  ///
  /// 默认 null —— 全部保持直角，和以前的观感一致。例：
  /// `borderRadius: BorderRadius.circular(10)`。
  ///
  /// 若条目自己要超出格子（如图标外溢、角标探出边角），设了圆角后会被裁掉；
  /// 这种情况把圆角只画在条目自己的背景上、这里不传即可。
  final BorderRadius? borderRadius;

  /// 选中样式：选中底色、左上角「第几个选中」的序号 / 勾选角标、描边。
  ///
  /// 为什么建议放这里而不是 `itemBuilder` 里：这里能拿到 `selectedIndex` /
  /// `selectedCount`（画序号角标必须），而且它只作用于列表里的条目、不参与拖动
  /// 浮层（浮层恒按未选中构建），两份样式互不影响，改一边不会碰到另一边。
  ///
  /// 只在条目**被选中**时调用，参数是 `itemBuilder` 已经画好的 `child`、原
  /// 下标 `index`，以及它在选中顺序里的位置 `selectedIndex`（0 起）。返回值
  /// 替换该条目（仍按 [borderRadius] 裁剪）。未选中时不调用。
  /// 常配合 [Stack] / `Badge` 在 child 上叠角标。
  ///
  /// **返回值要自己撑满格子**：用 `Stack(fit: StackFit.expand, children: [
  /// child, ...])`，不要再套 `Center` / 默认 `StackFit.loose` 的 [Stack]。
  /// 它们会把紧约束放宽，条目退回自身固有尺寸并居中——列表里可能看不出来
  /// （行高恰好等于内容高），网格里就会缩成一条、图片被压扁。
  final MultiSelectSelectedBuilder? selectedBuilder;

  /// 条目上的鼠标指针样式，默认 null = 沿用 [InkWell] 的默认（可点击时是手型，
  /// 移动端退化成普通箭头）。
  ///
  /// 同时作用于**拖动浮层**：拖起来之后浮层接管了指针区域，用同一个 cursor
  /// 才不会「一拖起来光标就变回箭头」。
  ///
  /// ```dart
  /// style: MultiSelectStyle(mouseCursor: SystemMouseCursors.grab)
  /// ```
  final MouseCursor? mouseCursor;
}

/// 把 `onReorder` 回传的两组下标应用到数据列表，返回重排后的新列表。
///
/// [oldIndex] / [newIndex] 来自 [MultiSelectReorderCallback]，一一对应：
/// 原来在 `oldIndex[j]` 的条目被移动到 `newIndex[j]`。整组拖动时这批下标
/// 连续且保持相对顺序，所以实现上等价于「按点选顺序抽出被拖条目，再整体
/// 插到落点」。
///
/// 若两组长度不等、含越界或重复下标，原样返回 `items`，避免调用方拿到丢项
/// 或重复的列表。
List<T> applyMultiReorder<T extends Object>(
  List<T> items,
  List<int> oldIndex,
  List<int> newIndex,
) {
  if (oldIndex.length != newIndex.length) return items;
  if (oldIndex.isEmpty) return items;
  if (!_allIndicesOnce(oldIndex, items.length)) return items;
  if (!_allIndicesOnce(newIndex, items.length)) return items;

  final Set<int> moved = oldIndex.toSet();
  final List<T> rest = <T>[
    for (int i = 0; i < items.length; i++)
      if (!moved.contains(i)) items[i],
  ];
  // newIndex 是一段连续区间；插入点取最小值即可。
  int at = newIndex.reduce(math.min);
  at = at < 0 ? 0 : (at > rest.length ? rest.length : at);
  final List<T> picked = <T>[for (final int i in oldIndex) items[i]];
  return <T>[...rest.take(at), ...picked, ...rest.skip(at)];
}

/// 校验 [indices] 是否是一组互不重复、且在 `0..count-1` 内的下标。
bool _allIndicesOnce(List<int> indices, int count) {
  final List<bool> used = List<bool>.filled(count, false);
  for (final int index in indices) {
    if (index < 0 || index >= count || used[index]) return false;
    used[index] = true;
  }
  return true;
}

/// [order] 是否就是 `0..n-1` 本身，即「顺序没变」。
///
/// 只比落点是否等于起点是不够的：整组按**点选顺序**搬走时，落回原位也可能
/// 改变组内次序（例如选中顺序 2、4、3 一起搬回第 2 格，结果是
/// `1,2,4,3,5,6`）。那种情况必须算「动过」，否则松手后列表会退回原样。
bool _isIdentityOrder(List<int> order) {
  for (int i = 0; i < order.length; i++) {
    if (order[i] != i) return false;
  }
  return true;
}

bool _sameList<E>(List<E> a, List<E> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

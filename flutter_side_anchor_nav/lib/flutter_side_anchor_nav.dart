/// 左侧竖排 Tabbar + 右侧「所有页面排在一个 `Column` 里」的滚动导航：
/// 点哪个 Tab，右边就滚到哪一页。
///
/// 以 `flutter_side_anchor_nav.dart` 为唯一入口，实现按职责拆在 `src/` 的 part 文件：
///
/// | 文件 | 职责 |
/// |---|---|
/// | `src/side_anchor_nav_types.dart` | 公开类型：[SideTabView] / [SideTabStyle] / [SideTabItemInfo] / 回调 typedef |
/// | `src/side_anchor_nav_controller.dart` | [SideTabController]：选中页的外部数据源 |
/// | `src/side_anchor_nav_bar.dart` | 左侧 Tabbar：直接换位的高亮底色、会滑动的贴边指示条、Tabs 过多时可滚动 |
///
/// ## 基本用法
///
/// ```dart
/// SideTab(
///   views: <SideTabView>[
///     SideTabView(label: '账户', icon: Icons.person_outline, child: const AccountPane()),
///     SideTabView(label: '通知', icon: Icons.notifications_none, child: const NoticePane()),
///   ],
/// );
/// ```
///
/// ## 为什么是「滚动」而不是 IndexedStack
///
/// 所有页面**同时存在**于右侧那一个 `Column` 里（不是只构建当前页），点 Tab
/// 只是滚到对应页面的位置。好处是：页面高度可以各不相同、可以一路滚着读完，
/// 也能反过来做「滚到哪页就高亮哪个 Tab」。
///
/// ## 选中项的两个方向
///
/// * **点击 → 滚动**：点 Tab，右侧 `animateTo` 到该页顶部（[SideTabStyle.duration] /
///   [SideTabStyle.curve] 可调），落点由 [SideTabStyle.anchor] 决定（默认顶部对齐）。
/// * **滚动 → 选中**：手动滚内容时，[SideTabStyle.syncSelectionOnScroll] 打开
///   （默认）会按「最后一个已经越过视口顶部的页面」反过来高亮 Tab。
///
/// 程序化滚动那一小段时间里不会让滚动同步抢走选中项 —— 否则「点到最后一页、
/// 但内容不够长、滚不到顶」时，高亮会当场跳回上一页。落下之后选中的仍是**点
/// 的那一页**，直到用户自己再滚一下才交还给滚动同步。
///
/// ## 最后一页贴不到顶部
///
/// 页面总高度不够时，靠后的页面永远滚不到视口顶部（被 `maxScrollExtent` 卡住）。
/// 这时点击仍然会选中它、并滚到能滚到的最底，不会「点了没反应」。
///
/// ## 控制器
///
/// 想让外部按钮 / 路由参数驱动翻页时给 [SideAnchorNav.controller]：
///
/// ```dart
/// final SideTabController controller = SideTabController();
/// SideTab(controller: controller, views: views);
///
/// controller.select(2); // 滚过去（带动画）
/// controller.jumpTo(0); // 直接跳（不带动画）
/// ```
///
/// 控制器是选中页的唯一数据源：点击、滚动同步都会写回
/// [SideTabController.index]，外部监听它就能知道现在停在哪一页。
///
/// ## 自定义 Tab
///
/// [SideAnchorNav.tabBuilder] 换掉默认的「图标 + 文字 + 选中底色」，返回的 Widget 里
/// 用 [SideTabItemInfo.onSelected] 触发选中即可，选中状态不用自己维护。
/// [SideTabItemInfo.mouseCursor] 是组件给这个 Tab 算好的光标，接到
/// `InkWell.mouseCursor` 上就能和默认 Tab 保持一致（含禁用项退回普通箭头）。
///
/// ## 鼠标光标
///
/// 默认不干预：可点的 Tab 是手型，禁用的是普通箭头（InkWell 的
/// `adaptiveClickable`）。想统一改用 [SideTabStyle.tabMouseCursor]：
///
/// ```dart
/// const SideTabStyle(tabMouseCursor: SystemMouseCursors.basic)
/// ```
///
/// 想按选中 / 单页区分，不用再加配置项 —— [SideAnchorNav.tabBuilder] 里已经
/// 有 `index` / `selected` / `enabled`，一行判断就够：
///
/// ```dart
/// tabBuilder: (context, info) => InkWell(
///   mouseCursor: info.selected ? SystemMouseCursors.basic : info.mouseCursor,
///   onTap: info.onSelected,
///   child: Text(info.view.label),
/// )
/// ```
///
/// `MouseCursor.defer` 交给父级决定，`WidgetStateMouseCursor` 可按
/// hover / focus / disabled 动态解析。
///
/// ## Tabbar 与内容之间的分隔线
///
/// [SideTabStyle.tabBarDivider] 传一个 [BorderSide] 就能改颜色 / 粗细 / 线型，
/// 不传是 1px 的 `ThemeData.dividerColor`，传 [BorderSide.none] 则整条去掉：
///
/// ```dart
/// const SideTabStyle(
///   tabBarDivider: BorderSide(color: Colors.black12, width: 2),
/// )
/// ```
///
/// ## 代价
///
/// 所有页面一次性构建、一次性布局（`SingleChildScrollView` + `Column` 不做懒加载），
/// 页数很多或单页很重时，建议只把「需要一条滚到底」的内容放进来。
///
/// ## 尺寸要求
///
/// 需要一个**高度有界**的父容器（通常就是一整页 / 一个 `SizedBox`）：
/// 左边 Tabbar 要撑满高度，右边内容要有一个固定高度的滚动视口。
library;

import 'package:material_ui/material_ui.dart';

part 'src/side_anchor_nav_types.dart';
part 'src/side_anchor_nav_controller.dart';
part 'src/side_anchor_nav_bar.dart';

/// 选中项左侧那条指示条的定位 key（测量 / 测试时用）。
const Key sideTabIndicatorKey = ValueKey<String>('side_anchor_nav.indicator');

/// 选中项那块高亮底色的定位 key（测量 / 测试时用）。
const Key sideTabHighlightKey = ValueKey<String>('side_anchor_nav.highlight');

/// 左侧竖排 Tabbar + 右侧一列页面的滚动导航。
class SideAnchorNav extends StatefulWidget {
  const SideAnchorNav({
    super.key,
    required this.views,
    this.initialIndex = 0,
    this.controller,
    this.scrollController,
    this.style = const SideTabStyle(),
    this.tabBuilder,
    this.physics,
    this.onChanged,
  });

  /// 所有页面，顺序就是右侧从上到下的顺序。
  final List<SideTabView> views;

  /// 初始选中页（0 起）；给了 [controller] 时以控制器的下标为准。
  final int initialIndex;

  /// 选中页的外部数据源。
  final SideTabController? controller;

  /// 右侧内容的滚动控制器；不给就内部自己建一个。
  final ScrollController? scrollController;

  /// 外观与交互配置。
  final SideTabStyle style;

  /// 自定义 Tab 外观；为空时用默认的「图标 + 文字 + 选中底色」。
  final SideTabBuilder? tabBuilder;

  /// 右侧内容的滚动物理特性。
  final ScrollPhysics? physics;

  /// 选中项变了（点击、滚动同步、控制器都会触发）。
  final SideTabChanged? onChanged;

  @override
  State<SideAnchorNav> createState() => _SideAnchorNavState();
}

class _SideAnchorNavState extends State<SideAnchorNav> {
  /// 当前选中页；控制器存在时它只是镜像，真值以控制器为准。
  late int _index;

  late ScrollController _scrollController;
  bool _ownsScrollController = false;

  SideTabController? _attachedController;

  /// 右侧滚动视口的 key：测量页面位置时的坐标原点。
  final GlobalKey _viewportKey = GlobalKey(
    debugLabel: 'side_anchor_nav.viewport',
  );

  /// 每个页面一个 key，用来量它在内容里的位置。
  final List<GlobalKey> _sectionKeys = <GlobalKey>[];

  /// 正在做程序化滚动：这段时间里滚动的中间帧不该改选中项。
  bool _programmatic = false;

  /// 程序化滚动刚结束：把选中项「锁」在用户点的那一页，直到用户自己滚一下。
  bool _suppressSpy = false;

  /// 程序化滚动的序号：连续点 Tab 时，只有最后一次的完成回调能清状态位。
  int _scrollToken = 0;

  @override
  void initState() {
    super.initState();
    _bindScrollController();
    _ensureSectionKeys();
    _index = _clampIndex(widget.controller?.index ?? widget.initialIndex);
    _attachedController = widget.controller;
    _attachedController?._attach(this);
    _pushIndexToController();
    if (_index > 0) {
      // 首帧之后才能量到页面位置。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToIndex(_index, animated: false);
      });
    }
  }

  @override
  void didUpdateWidget(covariant SideAnchorNav oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.scrollController != oldWidget.scrollController) {
      if (_ownsScrollController) _scrollController.dispose();
      _bindScrollController();
    }

    if (widget.controller != oldWidget.controller) {
      _attachedController?._detach(this);
      _attachedController = widget.controller;
      _attachedController?._attach(this);
      final SideTabController? controller = _attachedController;
      if (controller != null) {
        _index = _clampIndex(controller.index);
      }
      _pushIndexToController();
    }

    if (widget.views.length != oldWidget.views.length) {
      _ensureSectionKeys();
      _index = _clampIndex(_index);
      _pushIndexToController();
    }
  }

  @override
  void dispose() {
    _attachedController?._detach(this);
    if (_ownsScrollController) _scrollController.dispose();
    super.dispose();
  }

  // ── 基础状态 ────────────────────────────────────────────────────────────

  void _bindScrollController() {
    final ScrollController? external = widget.scrollController;
    if (external != null) {
      _scrollController = external;
      _ownsScrollController = false;
    } else {
      _scrollController = ScrollController();
      _ownsScrollController = true;
    }
  }

  int _clampIndex(int index) {
    final int count = widget.views.length;
    if (count == 0) return 0;
    if (index < 0) return 0;
    if (index >= count) return count - 1;
    return index;
  }

  /// 页面数量变化时增删 key（保留已有的），避免整列 element 被重建。
  void _ensureSectionKeys() {
    final int count = widget.views.length;
    if (count > _sectionKeys.length) {
      for (int i = _sectionKeys.length; i < count; i++) {
        _sectionKeys.add(GlobalKey(debugLabel: 'side_anchor_nav.section.$i'));
      }
    } else if (count < _sectionKeys.length) {
      _sectionKeys.removeRange(count, _sectionKeys.length);
    }
  }

  void _pushIndexToController() {
    _attachedController?._storeIndex(_index);
  }

  /// 改选中项（不动滚动位置）。
  void _setIndex(int index, {required bool notify}) {
    if (index == _index) return;
    setState(() => _index = index);
    _pushIndexToController();
    if (notify) widget.onChanged?.call(index);
  }

  // ── 选中 / 滚动 ─────────────────────────────────────────────────────────

  /// 选中第 [index] 页并滚过去（点击 Tab、控制器调用都走这里）。
  void _select(int index, {bool animated = true}) {
    if (index < 0 || index >= widget.views.length) return;
    if (!widget.views[index].enabled) return;
    if (index != _index) {
      setState(() => _index = index);
      _pushIndexToController();
      widget.onChanged?.call(index);
    }
    _scrollToIndex(index, animated: animated);
  }

  /// 滚到第 [index] 页。
  ///
  /// [retry] 用于「第一帧还没挂上 ScrollPosition」的情况：等一帧再试一次。
  void _scrollToIndex(int index, {required bool animated, bool retry = true}) {
    if (!mounted) return;
    if (!_scrollController.hasClients) {
      if (!retry) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToIndex(index, animated: animated, retry: false);
      });
      return;
    }

    final double? target = _targetOffset(index);
    if (target == null) return;

    final ScrollPosition position = _scrollController.position;
    final double clamped = target.clamp(0.0, position.maxScrollExtent);
    final bool reached = (clamped - position.pixels).abs() < 0.5;

    // 先上锁再滚：贴着底边的页面滚不到顶，中间的滚动帧会把选中项抢走。
    _suppressSpy = true;

    if (!animated || reached) {
      if (!reached) _scrollController.jumpTo(clamped);
      return;
    }

    final int token = ++_scrollToken;
    _programmatic = true;
    _scrollController
        .animateTo(
          clamped,
          duration: widget.style.duration,
          curve: widget.style.curve,
        )
        .whenComplete(() {
          if (token == _scrollToken) _programmatic = false;
        });
  }

  /// 页面顶部该滚到的滚动坐标。
  double? _targetOffset(int index) {
    final double? top = _sectionTop(index);
    if (top == null) return null;
    return top -
        widget.style.contentPadding.top -
        _viewportDimension * widget.style.anchor;
  }

  /// 页面顶部在内容坐标系里的位置（滚动坐标，不随当前滚动位置变化）。
  double? _sectionTop(int index) {
    if (!_scrollController.hasClients) return null;
    final RenderObject? section = _sectionKeys[index].currentContext
        ?.findRenderObject();
    final RenderObject? viewport = _viewportKey.currentContext
        ?.findRenderObject();
    if (section is! RenderBox || viewport is! RenderBox) return null;
    if (!section.hasSize || !viewport.hasSize) return null;
    final Offset offset = section.localToGlobal(
      Offset.zero,
      ancestor: viewport,
    );
    return _scrollController.offset + offset.dy;
  }

  double get _viewportDimension => _scrollController.hasClients
      ? _scrollController.position.viewportDimension
      : 0;

  // ── 滚动同步（scroll spy） ─────────────────────────────────────────────

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    if (notification is ScrollStartNotification) {
      // 用户上手（拖拽）就立刻交还控制权：程序化滚动会被它打断。
      if (notification.dragDetails != null || !_programmatic) {
        _suppressSpy = false;
      }
    }

    if (!_programmatic &&
        !_suppressSpy &&
        widget.style.syncSelectionOnScroll &&
        (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification ||
            notification is OverscrollNotification)) {
      _syncIndexFromScroll();
    }
    return false;
  }

  void _syncIndexFromScroll() {
    if (!_scrollController.hasClients) return;
    final int count = widget.views.length;
    if (count == 0) return;

    final ScrollPosition position = _scrollController.position;
    final double offset = position.pixels;

    int next = 0;
    // 滚到最底：直接算最后一页，否则「短的最后一页」永远轮不到高亮。
    if (position.maxScrollExtent > 0 &&
        offset >= position.maxScrollExtent - 1.0) {
      next = count - 1;
    } else {
      for (int i = 0; i < count; i++) {
        final double? anchor = _targetOffset(i);
        if (anchor == null) continue;
        if (anchor <= offset + 1.0) {
          next = i;
        } else {
          break;
        }
      }
    }
    _setIndex(next, notify: true);
  }

  // ── 构建 ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final SideTabStyle style = widget.style;
    if (widget.views.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (style.showTabBar)
          SizedBox(
            width: style.tabBarWidth,
            child: _SideTabBar(
              views: widget.views,
              selectedIndex: _index,
              style: style,
              tabBuilder: widget.tabBuilder,
              onSelected: (int index) => _select(index),
            ),
          ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: SingleChildScrollView(
              key: _viewportKey,
              controller: _scrollController,
              primary: false,
              physics: widget.physics,
              padding: style.contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: style.sectionGap,
                children: <Widget>[
                  for (int i = 0; i < widget.views.length; i++)
                    KeyedSubtree(
                      key: _sectionKeys[i],
                      child: widget.views[i].child,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

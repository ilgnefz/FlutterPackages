# flutter_side_anchor_nav

左侧竖排 Tabbar + 右侧「所有页面排在一个 `Column` 里」的滚动导航：点哪个 Tab，右边就滚到哪一页。

## 用法

```dart
import 'package:flutter_side_anchor_nav/flutter_side_anchor_nav.dart';

SideAnchorNav(
  views: <SideTabView>[
    SideTabView(label: '账户', icon: Icons.person_outline, child: AccountPane()),
    SideTabView(label: '通知', icon: Icons.notifications_none, child: NoticePane()),
  ],
)
```

不是 `IndexedStack`：所有页面同时在右侧那一列 `Column` 里，点 Tab 只是滚过去。
好处是页面高度可以不同、能一路滚着读完，也能反过来「滚到哪页就高亮哪个 Tab」。

## 控制器与自定义

```dart
final SideTabController controller = SideTabController();
SideAnchorNav(controller: controller, views: views);
controller.select(2); // 滚过去（带动画）
controller.jumpTo(0); // 直接跳
```

控制器是选中页的唯一数据源。点击、滚动同步都会写回 `SideTabController.index`。
`SideAnchorNav.tabBuilder` 可换掉默认 Tab 外观；`SideTabItemInfo` 里带 `onSelected`
和算好的 `mouseCursor`，选中状态不用自己维护。

样式走 `SideTabStyle`：动画时长 / 曲线、滚动锚点、`syncSelectionOnScroll`、
Tabbar 宽度与分隔线、Tab 光标等。

> 包入口和主组件叫 `SideAnchorNav`，配套类型沿用 `SideTab*` 前缀（`SideTabView` /
> `SideTabStyle` / `SideTabController`）——它们描述的是左侧 Tabbar，不需要跟包名对齐。

## 尺寸要求

需要一个**高度有界**的父容器（通常就是一整页 / 一个 `SizedBox`）：左边 Tabbar
要撑满高度，右边内容要有一个固定高度的滚动视口。所有页面一次性构建，
页数很多或单页很重时建议只放「需要一条滚到底」的内容。

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'notification_card.dart';
import 'notification_center.dart';
import 'notification_types.dart';

/// 通知宿主：把 [NotificationCenter] 里的通知画在应用内容**上面**。
///
/// 挂在 `MaterialApp.builder` 里，这样弹窗、对话框之上也能看到通知，而且只需
/// 装一次：
///
/// ```dart
/// MaterialApp(
///   builder: (BuildContext context, Widget? child) => NotificationHost(
///     style: const NotificationStyle(position: NotificationPosition.topRight),
///     child: child ?? const SizedBox.shrink(),
///   ),
///   home: const HomePage(),
/// );
/// ```
///
/// 布局用 `Stack`：通知层只有卡片本身参与命中测试，空白处的点击会穿透到应用，
/// 不会挡住下面的按钮。
class NotificationHost extends StatefulWidget {
  const NotificationHost({super.key, required this.child, this.style});

  /// 应用内容（通常是 `MaterialApp.builder` 传进来的 `child`）。
  final Widget child;

  /// 全局样式；不传用 [NotificationStyle] 的默认值。
  final NotificationStyle? style;

  @override
  State<NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends State<NotificationHost> {
  @override
  void initState() {
    super.initState();
    NotificationCenter.adoptStyle(widget.style);
  }

  @override
  void didUpdateWidget(covariant NotificationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.style != oldWidget.style) {
      NotificationCenter.adoptStyle(widget.style);
    }
  }

  @override
  void dispose() {
    // 宿主没了，残留的 closing 条目也不会有人播动画了，清掉避免越积越多。
    for (final NotificationData data in NotificationCenter.items) {
      if (data.closing) NotificationCenter.finishDismiss(data.id);
    }
    NotificationCenter.adoptStyle(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.child,
        Positioned.fill(
          // 通知层单独套一个 Overlay：卡片里的 Tooltip / 菜单这类需要
          // Overlay 祖先的组件才能正常工作，而宿主本身在 Navigator 之上。
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(
                builder: (BuildContext context) => ValueListenableBuilder<int>(
                  valueListenable: NotificationCenter.revisions,
                  builder: (BuildContext context, int revision, Widget? child) {
                    final List<NotificationData> items =
                        NotificationCenter.items;
                    if (items.isEmpty) return const SizedBox.shrink();
                    return _NotificationLayers(
                      items: items,
                      style: NotificationCenter.style,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 按位置分组后的卡片层。
class _NotificationLayers extends StatelessWidget {
  const _NotificationLayers({required this.items, required this.style});

  final List<NotificationData> items;
  final NotificationStyle style;

  @override
  Widget build(BuildContext context) {
    final Map<NotificationPosition, List<NotificationData>> grouped =
        <NotificationPosition, List<NotificationData>>{};
    for (final NotificationData data in items) {
      // 单条可以自带样式，位置以它为准。
      final NotificationPosition position = data.effectiveStyle(style).position;
      (grouped[position] ??= <NotificationData>[]).add(data);
    }
    if (grouped.isEmpty) return const SizedBox.shrink();

    final EdgeInsets safe = MediaQuery.of(context).padding;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    return Stack(
      children: <Widget>[
        for (final MapEntry<NotificationPosition, List<NotificationData>> entry
            in grouped.entries)
          _positioned(entry.key, entry.value, safe, screenWidth),
      ],
    );
  }

  Widget _positioned(
    NotificationPosition position,
    List<NotificationData> items,
    EdgeInsets safe,
    double screenWidth,
  ) {
    final EdgeInsets margin = style.margin;
    final bool center = position.isCenter;
    final double top = margin.top + safe.top;
    final double bottom = margin.bottom + safe.bottom;
    final double left = margin.left + safe.left;
    final double right = margin.right + safe.right;

    // 上方：新的贴边，老的在里侧；下方反过来，新的贴着下边缘。
    final List<NotificationData> ordered = position.isTop
        ? items.reversed.toList(growable: false)
        : items;

    final Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      // 卡片自己带固定宽度（SizedBox），这里不能让 stretch 去撑满
      // Positioned 给的无限宽度。
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < ordered.length; i++)
          SizedBox(
            // key 必须挂在 Column 的直接子节点上：新通知插到队首时，靠 key 让
            // Flutter 挪动旧元素而不是重建；否则每张卡片都会重新播一遍进场
            // 动画（表现为整列塌下去再展开），而不是给新卡片让位。
            key: ValueKey<Object>(ordered[i].id),
            // 宽度也允许单条覆盖；屏幕太窄时统一收窄。
            width: math.min(
              ordered[i].effectiveStyle(style).width,
              math.max(0, screenWidth - left - right),
            ),
            child: NotificationCard(
              data: ordered[i],
              style: style,
              isLast: i == ordered.length - 1,
              onDismissed: () =>
                  NotificationCenter.finishDismiss(ordered[i].id),
            ),
          ),
      ],
    );

    return Positioned(
      top: position.isTop ? top : null,
      bottom: position.isBottom ? bottom : null,
      left: center || position.isLeft ? left : null,
      right: center || position.isRight ? right : null,
      child: column,
    );
  }
}

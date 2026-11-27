/// # flutter_notification —— 全局通知
///
/// 一个 `NotificationCenter` 静态入口 + 一个挂在 `MaterialApp.builder` 里的
/// [NotificationHost]，任何地方都能弹通知，不需要 `BuildContext`：
///
/// ```dart
/// MaterialApp(
///   builder: (BuildContext context, Widget? child) =>
///       NotificationHost(child: child ?? const SizedBox.shrink()),
///   home: const HomePage(),
/// );
/// ```
///
/// 调用只分三类：**内容**、**行为**、**样式**。
///
/// ```dart
/// // 内容 + 行为
/// NotificationCenter.success('已保存', message: '3 个文件已同步');
/// NotificationCenter.error('保存失败', message: '磁盘空间不足');
/// NotificationCenter.info('有可用更新', actions: <NotificationAction>[
///   NotificationAction(label: '稍后', onPressed: later),
///   NotificationAction(label: '立即重启', onPressed: restart, isPrimary: true),
/// ]);
///
/// // 自定义内容
/// NotificationCenter.custom(
///   Row(children: <Widget>[avatar, Expanded(child: Text('新消息'))]),
/// );
///
/// // 样式：位置、时长、配色、图标、宽度、圆角全在 NotificationStyle 里
/// NotificationCenter.info(
///   '右下角',
///   style: NotificationCenter.style.copyWith(
///     position: NotificationPosition.bottomRight,
///   ),
/// );
///
/// // 进行中：默认不自动关闭，改完再 update。
/// final NotificationHandle handle = NotificationCenter.loading('导出中…', id: 'export');
/// await export();
/// handle.update(title: '导出完成', kind: NotificationKind.success);
/// ```
///
/// 特性：
///
/// * 成功 / 失败 / 警告 / 信息 / 进行中五种语义，图标与配色自动带；
/// * 右上、上中、左上、右下、下中、左下六种停靠位置，可全局设也可单条覆盖；
/// * 自动倒计时 + 底部进度条（铺满底边，两端顺着卡片圆角收进去），鼠标悬停暂停；
///   超过 `maxVisible` 时最早一条自动收起；
/// * 新通知进场时，已有卡片只平移让位，不会重播进场动画；
/// * `handle.update(...)` 就地改内容（loading → success 是最常见的用法），
///   倒计时接着走，不会因为改文案被重置；
/// * `id` 相同会就地更新而不是再弹一条，适合进度类通知；
/// * 支持自定义内容 [NotificationData.content]、点击回调；
/// * 卡片右下角可以放 0..n 个按钮 [NotificationAction]（`actions: [...]`），
///   `isPrimary` 区分主次、`style` 改样式、`builder` 完全自定义外观；窄了自动
///   折行；
/// * 桌面端的光标统一由 [NotificationStyle.mouseCursor] 管（卡片、关闭、按钮）。
library;

export 'src/notification_card.dart' show NotificationCard;
export 'src/notification_center.dart'
    show NotificationCenter, NotificationHandle;
export 'src/notification_host.dart' show NotificationHost;
export 'src/notification_types.dart'
    show
        NotificationAction,
        NotificationActionBuilder,
        NotificationData,
        NotificationKind,
        NotificationPosition,
        NotificationStyle;

import 'package:material_ui/material_ui.dart';

import 'notification_types.dart';

/// 一条通知的句柄：用来关闭或就地更新它。
///
/// ```dart
/// final handle = NotificationCenter.loading('上传中…', id: 'upload');
/// await upload();
/// handle.update(title: '上传完成', kind: NotificationKind.success);
/// ```
class NotificationHandle {
  const NotificationHandle._(this.id);

  /// 唯一标识，可用来做去重（同名 id 会就地更新而不是再弹一条）。
  final Object id;

  /// 还在屏幕上（退场动画中算已关闭）。
  bool get isVisible => NotificationCenter.isVisible(id);

  /// 关闭；已经关了就是空操作。
  void close() => NotificationCenter.dismiss(id);

  /// 就地改内容。倒计时接着走，只有 `style.duration` 变了才重新计时。
  ///
  /// `loading` 变成 `success` 时如果不传 [style]，会自动套用全局
  /// [NotificationStyle.duration]，不会停在「永远不关」的状态。
  void update({
    String? title,
    String? message,
    Widget? content,
    NotificationKind? kind,
    List<NotificationAction>? actions,
    VoidCallback? onTap,
    NotificationStyle? style,
  }) {
    NotificationCenter.update(
      id,
      title: title,
      message: message,
      content: content,
      kind: kind,
      actions: actions,
      onTap: onTap,
      style: style,
    );
  }
}

/// 全局通知中心：任何地方都能调用，不需要 `BuildContext`。
///
/// 前提是应用里装了 [NotificationHost]（通常包在 `MaterialApp.builder` 里）：
///
/// ```dart
/// MaterialApp(
///   builder: (BuildContext context, Widget? child) =>
///       NotificationHost(child: child ?? const SizedBox.shrink()),
/// );
/// ```
///
/// 然后：
///
/// ```dart
/// NotificationCenter.success('已保存', message: '3 个文件已同步');
/// NotificationCenter.error('保存失败', message: '磁盘空间不足');
/// final handle = NotificationCenter.loading('导出中…');
/// handle.update(title: '导出完成', kind: NotificationKind.success);
/// NotificationCenter.dismissAll();
/// ```
///
/// 方法只收三类东西：**内容**（`title` / `message` / `content`）、**行为**
/// （`actions` / `onTap`、`id`）、**样式**（`style`）。所有外观、时长、停靠位置都在
/// [NotificationStyle] 里，不再散落在参数上。
///
/// 通知状态放在静态表里，宿主还没挂载时调用也不会丢，挂载后立刻显示。
class NotificationCenter {
  NotificationCenter._();

  /// 当前生效的全局样式，由 [NotificationHost] 写入。
  static NotificationStyle _style = const NotificationStyle();

  /// 按插入顺序保存；`dismiss` 只打 `closing` 标记，等卡片播完退场动画再由
  /// 宿主 [NotificationHost] 真正移除，这样列表能平滑收拢。
  static final Map<Object, NotificationData> _items =
      <Object, NotificationData>{};

  static final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  static int _autoId = 0;

  /// 宿主监听它，任何增 / 删 / 改都会 +1。
  static ValueNotifier<int> get revisions => _revision;

  /// 当前全局样式。给单条改一两个属性就读它再 `copyWith`：
  ///
  /// ```dart
  /// NotificationCenter.info(
  ///   '右下角',
  ///   style: NotificationCenter.style.copyWith(
  ///     position: NotificationPosition.bottomRight,
  ///   ),
  /// );
  /// ```
  static NotificationStyle get style => _style;

  /// 屏幕上所有通知（含正在退场的那几条，动画要靠它）。
  static List<NotificationData> get items =>
      List<NotificationData>.unmodifiable(_items.values);

  /// 弹一条通知。传了 [id] 且已经存在时，等同于对该条做 `update`。
  ///
  /// * [content]：自定义内容，接在标题 / 正文下面；只有内容、没有标题正文时
  ///   用 [custom] 更顺手；
  /// * [kind]：不传时新通知是 `info`，已存在的通知保持原来的类型；
  /// * [actions]：底部右侧的操作按钮，可以给多个（`[撤销, 知道了]`），窄了自动折行；
  /// * [style]：整条替换全局样式，只改一两项时用
  ///   `NotificationCenter.style.copyWith(...)`。
  static NotificationHandle show({
    String? title,
    String? message,
    Widget? content,
    NotificationKind? kind,
    List<NotificationAction>? actions,
    VoidCallback? onTap,
    Object? id,
    NotificationStyle? style,
  }) {
    final Object key = id ?? 'notification-${_autoId++}';
    final NotificationData? existing = _items[key];
    if (existing != null) {
      return _merge(
        existing,
        title: title,
        message: message,
        content: content,
        kind: kind,
        actions: actions,
        onTap: onTap,
        style: style,
      );
    }
    _items[key] = NotificationData(
      id: key,
      title: title,
      message: message,
      content: content,
      kind: kind ?? NotificationKind.info,
      actions: actions ?? const <NotificationAction>[],
      onTap: onTap,
      style: style,
    );
    _trimOverflow();
    _bump();
    return NotificationHandle._(key);
  }

  /// 自定义内容的通知：卡片里塞任意 Widget，适合头像 + 两行文字这种版式。
  ///
  /// ```dart
  /// NotificationCenter.custom(
  ///   Row(children: <Widget>[avatar, Expanded(child: Text('新消息'))]),
  ///   style: NotificationCenter.style.copyWith(
  ///     position: NotificationPosition.bottomRight,
  ///   ),
  /// );
  /// ```
  static NotificationHandle custom(
    Widget content, {
    String? title,
    String? message,
    NotificationKind? kind,
    List<NotificationAction>? actions,
    VoidCallback? onTap,
    Object? id,
    NotificationStyle? style,
  }) {
    return show(
      title: title,
      message: message,
      content: content,
      kind: kind,
      actions: actions,
      onTap: onTap,
      id: id,
      style: style,
    );
  }

  /// 成功提示。参数含义同 [show]。
  static NotificationHandle success(
    String title, {
    String? message,
    Widget? content,
    List<NotificationAction>? actions,
    VoidCallback? onTap,
    Object? id,
    NotificationStyle? style,
  }) {
    return show(
      title: title,
      message: message,
      content: content,
      kind: NotificationKind.success,
      actions: actions,
      onTap: onTap,
      id: id,
      style: style,
    );
  }

  /// 失败提示。参数含义同 [show]。
  static NotificationHandle error(
    String title, {
    String? message,
    Widget? content,
    List<NotificationAction>? actions,
    VoidCallback? onTap,
    Object? id,
    NotificationStyle? style,
  }) {
    return show(
      title: title,
      message: message,
      content: content,
      kind: NotificationKind.error,
      actions: actions,
      onTap: onTap,
      id: id,
      style: style,
    );
  }

  /// 警告提示。参数含义同 [show]。
  static NotificationHandle warning(
    String title, {
    String? message,
    Widget? content,
    List<NotificationAction>? actions,
    VoidCallback? onTap,
    Object? id,
    NotificationStyle? style,
  }) {
    return show(
      title: title,
      message: message,
      content: content,
      kind: NotificationKind.warning,
      actions: actions,
      onTap: onTap,
      id: id,
      style: style,
    );
  }

  /// 普通信息。参数含义同 [show]。
  static NotificationHandle info(
    String title, {
    String? message,
    Widget? content,
    List<NotificationAction>? actions,
    VoidCallback? onTap,
    Object? id,
    NotificationStyle? style,
  }) {
    return show(
      title: title,
      message: message,
      content: content,
      kind: NotificationKind.info,
      actions: actions,
      onTap: onTap,
      id: id,
      style: style,
    );
  }

  /// 进行中：默认不自动关闭，等 `handle.update(...)` / `handle.close()` 收尾。
  ///
  /// 一般会配一个「取消」按钮：`actions: [NotificationAction(label: '取消', onPressed: cancel)]`。
  static NotificationHandle loading(
    String title, {
    String? message,
    Widget? content,
    List<NotificationAction>? actions,
    Object? id,
    NotificationStyle? style,
  }) {
    return show(
      title: title,
      message: message,
      content: content,
      kind: NotificationKind.loading,
      actions: actions,
      id: id,
      style: style,
    );
  }

  /// 就地把某条通知的内容换掉；倒计时不受影响（除非换了 `duration`）。
  static void update(
    Object id, {
    String? title,
    String? message,
    Widget? content,
    NotificationKind? kind,
    List<NotificationAction>? actions,
    VoidCallback? onTap,
    NotificationStyle? style,
  }) {
    final NotificationData? existing = _items[id];
    if (existing == null) return;
    _merge(
      existing,
      title: title,
      message: message,
      content: content,
      kind: kind,
      actions: actions,
      onTap: onTap,
      style: style,
    );
  }

  /// 关掉某一条（走退场动画）；不存在或已在关闭中则忽略。
  static void dismiss(Object id) {
    final NotificationData? data = _items[id];
    if (data == null || data.closing) return;
    _items[id] = data.copyWith(closing: true, revision: data.revision + 1);
    _bump();
  }

  /// 全部关掉。
  static void dismissAll() {
    bool changed = false;
    for (final MapEntry<Object, NotificationData> entry
        in _items.entries.toList()) {
      if (entry.value.closing) continue;
      _items[entry.key] = entry.value.copyWith(
        closing: true,
        revision: entry.value.revision + 1,
      );
      changed = true;
    }
    if (changed) _bump();
  }

  /// 某条是否还在（退场动画中算不在）。
  static bool isVisible(Object id) {
    final NotificationData? data = _items[id];
    return data != null && !data.closing;
  }

  /// 清空所有状态，测试用。
  @visibleForTesting
  static void reset() {
    _items.clear();
    _autoId = 0;
    _style = const NotificationStyle();
    _bump();
  }

  /// 宿主挂载 / 换样式时调用；传 `null` 表示宿主已卸载，回到默认样式。
  static void adoptStyle(NotificationStyle? style) {
    final NotificationStyle next = style ?? const NotificationStyle();
    // 样式没换就不要通知：宿主每次重建都调这里，无谓地 bump 会让通知层
    // 在别人 build 的阶段被标脏。
    if (identical(_style, next)) return;
    _style = next;
    _bump();
  }

  /// 卡片退场动画结束后由宿主调用，真正从表里删掉。
  static void finishDismiss(Object id) {
    if (_items.remove(id) != null) _bump();
  }

  static NotificationHandle _merge(
    NotificationData old, {
    String? title,
    String? message,
    Widget? content,
    NotificationKind? kind,
    List<NotificationAction>? actions,
    VoidCallback? onTap,
    NotificationStyle? style,
  }) {
    _items[old.id] = NotificationData(
      id: old.id,
      title: title ?? old.title,
      message: message ?? old.message,
      content: content ?? old.content,
      kind: kind ?? old.kind,
      actions: actions ?? old.actions,
      onTap: onTap ?? old.onTap,
      style: style ?? old.style,
      // 已经关掉的被重新 update：重新出现。
      revision: old.revision + 1,
    );
    _trimOverflow();
    _bump();
    return NotificationHandle._(old.id);
  }

  /// 超过 `maxVisible` 时，把最早的几条标成关闭。
  static void _trimOverflow() {
    final int max = _style.maxVisible;
    if (max <= 0) return;
    final List<Object> visible = <Object>[
      for (final MapEntry<Object, NotificationData> entry in _items.entries)
        if (!entry.value.closing) entry.key,
    ];
    for (int i = 0; i < visible.length - max; i++) {
      final NotificationData data = _items[visible[i]]!;
      _items[visible[i]] = data.copyWith(
        closing: true,
        revision: data.revision + 1,
      );
    }
  }

  static void _bump() => _revision.value = _revision.value + 1;
}

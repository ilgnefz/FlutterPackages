# flutter_notification

全局通知：一个静态入口 `NotificationCenter` + 一个挂在 `MaterialApp.builder`
里的 `NotificationHost`，**任何地方都能弹，不需要 `BuildContext`**。

成功 / 失败 / 警告 / 信息 / 进行中五种语义，右上、上中、左上、右下、下中、左下
六个停靠位置，自动倒计时（悬停暂停）+ 底部进度条，句柄可以就地更新内容。

调用参数只有三类，好记：

| 类别 | 参数 |
|---|---|
| 内容 | `title` / `message` / `content` |
| 行为 | `id` / `actions` / `onTap` |
| 样式 | `style`（`NotificationStyle`） |

宽度、圆角、配色、图标、字体、停靠位置、自动关闭时长全都收在 `NotificationStyle`
里，不再散落在方法参数上。

## 安装

```yaml
dependencies:
  flutter_notification:
    path: ../FlutterPackages/flutter_notification
```

装一次宿主（包在 `MaterialApp.builder` 里，这样对话框之上也能看到通知）：

```dart
import 'package:flutter_notification/flutter_notification.dart';

MaterialApp(
  builder: (BuildContext context, Widget? child) => NotificationHost(
    style: const NotificationStyle(position: NotificationPosition.topRight),
    child: child ?? const SizedBox.shrink(),
  ),
  home: const HomePage(),
);
```

## 用法

```dart
NotificationCenter.success('已保存', message: '3 个文件已同步');
NotificationCenter.error('保存失败', message: '磁盘空间不足');
NotificationCenter.warning('磁盘快满了', message: '剩余 1.2 GB');
NotificationCenter.info('有可用更新', actions: <NotificationAction>[
  NotificationAction(label: '稍后', onPressed: later),
  NotificationAction(label: '立即重启', onPressed: restart, isPrimary: true),
]);
```

## 操作按钮

按钮排在卡片**右下角**（和系统通知一致），`actions` 是列表，一个两个都行；
窄了自动折行。`isPrimary: true` 的那颗用实心按钮（`FilledButton`）强调主操作。

```dart
// 一个：撤销类
NotificationCenter.info(
  '已删除 1 条记录',
  actions: <NotificationAction>[
    NotificationAction(label: '撤销', onPressed: undo),
  ],
);

// 两个：主次分明，「取消」不关卡片，等用户真的决定
NotificationCenter.warning(
  '删除这 3 个文件？',
  style: NotificationCenter.style.copyWith(clearDuration: true),
  actions: <NotificationAction>[
    NotificationAction(label: '取消', onPressed: () {}, closeOnTap: false),
    NotificationAction(label: '删除', onPressed: delete, isPrimary: true),
  ],
);
```

`NotificationAction` 的三个开关：

| 参数 | 作用 |
|---|---|
| `closeOnTap` | 点完是否顺手关掉这条通知（默认 `true`） |
| `isPrimary` | 用实心按钮强调（默认 `false`，文字按钮） |
| `style` | 单颗覆盖 `ButtonStyle`（比如换色、加图标） |

按钮本身是 Material 的 `TextButton` / `FilledButton`，但尺寸按卡片收小了：默认
**32 高**、左右 14 / 上下 8 的内边距，胶囊用 `StadiumBorder` 固定成圆头。文字
（13 / `w600`）上下各留 8，不会顶到胶囊边。要整体调大调小在样式里改：

```dart
NotificationStyle(actionMinHeight: 36, actionPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10));
```

**完全自定义**：给 `builder` 就不用默认的 `TextButton` / `FilledButton` 了，
库里只负责把点击包好（先跑 `onPressed`，再按 `closeOnTap` 关不关），外观随你：

```dart
NotificationCenter.error(
  '同步失败',
  actions: <NotificationAction>[
    NotificationAction(
      onPressed: retry,
      builder: (BuildContext context, VoidCallback onPressed) => IconButton.filledTonal(
        onPressed: onPressed,
        icon: const Icon(Icons.refresh, size: 16),
        tooltip: '重试',
      ),
    ),
  ],
);
```

给了 `builder` 之后 `label`（可省）、`isPrimary`、`style` 都不再生效。

`handle.update(actions: [...])` 可以换按钮，传 `const []` 就是全去掉。

**进行中 → 完成**，用句柄就地改，不会多弹一条：

```dart
final NotificationHandle handle = NotificationCenter.loading('导出中…', id: 'export');
await export();

handle.update(title: '导出完成', kind: NotificationKind.success);
// 或者 handle.close();
```

`loading` 不会自己消失；一旦 `kind` 改成别的类型，就按样式里的 `duration`
开始倒计时，不会永远挂着。

**同一个 `id` 再 `show` 一次等于 `update`**，适合进度：

```dart
NotificationCenter.show(title: '下载 30%', id: 'download');
NotificationCenter.show(title: '下载 60%', id: 'download'); // 还是同一条
```

**自定义内容**：`content` 接在标题 / 正文下面；只有内容、没有标题正文时用
`custom()`：

```dart
// 标题 + 正文 + 自定义内容
NotificationCenter.show(
  title: '正在同步',
  content: LinearProgressIndicator(value: 0.62),
);

// 整张卡片都给自己的 Widget
NotificationCenter.custom(
  Row(children: <Widget>[avatar, Expanded(child: Text('新消息'))]),
  onTap: openConversation,
);

NotificationCenter.dismissAll();
```

## 停靠位置

位置属于样式，单条覆盖时从全局样式 `copyWith` 出来：

```dart
NotificationCenter.info(
  '左下角',
  style: NotificationCenter.style.copyWith(
    position: NotificationPosition.bottomLeft,
  ),
);
```

| 值 | 位置 | 新通知的方向 |
|---|---|---|
| `topLeft` / `topCenter` / `topRight` | 上排 | 贴着上边缘，往里堆 |
| `bottomLeft` / `bottomCenter` / `bottomRight` | 下排 | 贴着下边缘，往里堆 |

不同位置的通知各自成组，互不影响。宽度取 `NotificationStyle.width`（默认 360），
屏幕更窄时自动收窄。

## 样式

一份 `NotificationStyle` 管全部外观和行为：宽度、边距、间距、圆角、阴影、
内边距、字体、图标、主色、进度条、位置、时长、进出场动画、最大条数。

```dart
NotificationHost(
  style: NotificationStyle(
    width: 380,
    margin: const EdgeInsets.all(20),
    spacing: 16,
    maxVisible: 3,                       // 超出时最早一条自动收起
    position: NotificationPosition.bottomRight,
    duration: const Duration(seconds: 6),
    showProgress: true,                  // 底部倒计时进度条
    dismissOnTap: false,                 // 点卡片是否关闭
    mouseCursor: SystemMouseCursors.click, // 可点部分的光标（卡片/关闭/按钮）
    radius: 8,                          // 卡片圆角
    elevation: 4,                        // Material 投影高度，0 = 不要阴影
    iconSize: 18,
    icon: null,                          // 换图标；不传用语义类型自带的
    accentColor: null,                   // 换主色（图标、底圈、进度条）
    animationDuration: const Duration(milliseconds: 220),
    backgroundColor: null,               // 默认 ColorScheme.surfaceContainerHigh
    actionMinHeight: 32,                 // 操作按钮胶囊的高度
    actionPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    actionTextStyle: null,               // 默认 13 / w600，基于主题 labelLarge
    titleStyle: null,
    messageStyle: null,
  ),
  child: child ?? const SizedBox.shrink(),
);
```

**单条覆盖**：`show(style: ...)` 传一份就**整条替换**全局样式（没写的项用
`NotificationStyle` 的默认值）。只改一两项时从当前全局样式派生：

```dart
NotificationCenter.success(
  '已保存',
  style: NotificationCenter.style.copyWith(
    position: NotificationPosition.bottomRight,
    duration: const Duration(seconds: 8),
  ),
);
```

`margin` / `spacing` / `maxVisible` 是成组布局，单条传了也只在全局侧生效。

配色跟主题走：`error` 用 `ColorScheme.error`，`loading` 用 `primary`；`success`
（绿）/ `warning`（琥珀）/ `info`（蓝）是固定的语义色，`accentColor` 可覆盖。

底部的进度条**铺满整条底边**，看起来和卡片一样宽：直线段正好是
`宽度 - 圆角 * 2`，两端多出来的那点落在圆角里，顺着弧线变薄——收边交给卡片自己
的圆角裁剪，所以既不会在下角留一块缺口，也不会切出 90° 的直角块。

不想要它的话，两条路都行：

```dart
// 1. 只要倒计时、不画进度条
NotificationCenter.success('已保存', style: NotificationCenter.style.copyWith(showProgress: false));

// 2. 不自动关闭（既没有进度条也没有倒计时），由 handle.close() 收尾
NotificationCenter.info('上传中…', style: NotificationCenter.style.copyWith(clearDuration: true));
```

## 行为细节

- **让位动画**：新通知从 0 高度长起来，已有卡片被平移推开；旧卡片不会重建，
  所以不会重播一遍进场动画。
- **倒计时可暂停**：鼠标移进卡片停止计时，移出后从剩下的时间继续（进度条同步）。
- **`update` 不重置计时**：改文案、刷进度都接着走原来的倒计时，只有换了
  `duration` / `kind` 才重新计时。
- **超出条数**：同时最多 `maxVisible` 条，再来新的就把最早那条淡出收起。
- **不挡点击**：通知层只有卡片本身参与命中测试，空白区域的点击照常落到应用上。
- **宿主挂载前调用不丢**：通知存在静态表里，宿主一挂上就显示。
- **入场 / 退场**：滑入 + 淡入 + 高度展开，收起时其余卡片平滑补位；卡片自己
  包了 `RepaintBoundary`，倒计时进度条每帧重绘不会把整棵树（整个窗口）一起
  拖下水。
- **阴影**：就是 `Material` 自己的 elevation，圆角、裁剪、投影全交给它；默认
  `elevation: 4`，`elevation: 0` 变成纯色块。`surfaceTintColor` 关掉了，
  elevation 不会把 `backgroundColor` 染成主题色。
- **投影不会被裁**：进场 / 退场收缩高度时，裁剪盒比卡片四周各大
  `elevation * 2 + 4`，所以卡片四周（含底部两个圆角）的阴影是完整的、
  卡在不在下面都一样；`spacing` 默认 16 是为了不让上下两张的影子在缝里
  接成一条灰带。
- **无障碍**：卡片带 `Semantics(liveRegion: true)`，读屏会播报。
- **鼠标光标**：卡片、关闭按钮、操作按钮统一用 `mouseCursor`（默认小手）；
  卡片自己没接任何回调时不跳小手，`builder` 画出来的按钮外面也兜了一层
  `MouseRegion`。

## 注意

通知层在 `Navigator` **之上**（所以对话框之上也能看到它），这意味着卡片里的
`Navigator.of(context)` 找不到应用的路由；需要在 `onTap` 里跳转时，请自己先把
`NavigatorState` 存下来（或从外部闭包捕获）。卡片内另有一层独立 `Overlay`，
`Tooltip`、菜单这类依赖 Overlay 的组件可以正常使用。

`NotificationCenter` 是全局静态状态，测试里可以用 `NotificationCenter.reset()`
清干净。宿主只装一个，重复装时最后挂载的那个样式生效。

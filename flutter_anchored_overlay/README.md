# flutter_anchored_overlay

锚定在触发组件上的浮层：**一个内核，两个门面**。

| 门面 | 定位 | 典型用法 |
|---|---|---|
| `Popover` | 可交互气泡 | tap / hover 打开，内容放表单或按钮，外部点击 / Esc 关闭 |
| `SmartTooltip` | 轻量提示 | hover 延迟显示、纯文本、鼠标移走自动收起 |

两者共用同一套定位、形状、浮层与动画实现，只差默认值和少量触发参数。

## 用法

```dart
import 'package:flutter_anchored_overlay/flutter_anchored_overlay.dart';

Popover(
  placement: PopoverPlacement.bottom,
  align: PopoverAlign.center,
  child: const Icon(Icons.info_outline),
  content: const SizedBox(
    width: 220,
    child: Text('这里可以放任意内容。'),
  ),
)

SmartTooltip(
  message: '这是一段提示',
  placement: TooltipDirection.down,
  child: const Text('悬停我'),
)
```

`PopoverController` 是开关的唯一数据源；`SmartTooltipController` 是它的子类，
所以同一个控制器可以同时驱动两个门面。`resolvePopoverPosition` /
`computeTooltipPlacement` 是公开的纯定位函数，方便直接写单测。

### 两种 padding

- `padding`：`Popover` 的顶层属性，气泡**内容与边框之间**的内边距，
  非 null 时覆盖 `PopoverStyle.padding`（`SmartTooltip` 对应 `contentPadding`）。
- `edgePadding`：气泡**与视口边缘之间**的最小留白，只在翻转 / 夹取和最大
  宽度计算里起作用；气泡在屏幕中间时改它看不出变化。

```dart
Popover(
  padding: const EdgeInsets.all(24),   // 内容离气泡边框 24
  edgePadding: 8,                      // 气泡离屏幕边缘至少 8
  content: const Text('...'),
  child: const Icon(Icons.info_outline),
)
```

## 实现要点

- `OverlayPortal` + `CompositedTransformTarget/Follower`，页面滚动时浮层自动跟随。
- 位置由 `_resolveCore` 统一解算：flip → 主轴定位 → 侧轴 shift/clamp → 箭头反算。
- 气泡尺寸由 `_SizeReporter` 布局后上报，测量完成前不绘制，避免出现一帧错位置。
- 内容按气泡轮廓（圆角 + 箭头）裁剪：content 自带方角背景 / 图片时也不会露到
  圆角外；阴影由外层 `ShapeDecoration` 绘制，不受裁剪影响。
- 触发器需要有界尺寸；气泡默认最大 320 × 320。

> 原应用里的 `widget/base/tooltip.dart`（`EasyTooltip` / `richTextTooltip`）依赖应用的
> 主题与常量，没有迁进本包；直接用 `SmartTooltip` 即可。

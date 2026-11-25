/// 通用右键菜单：在任意 Widget 上按鼠标右键（触屏可长按）弹出菜单，
/// 菜单出现在指针位置，靠近屏幕边缘时自动翻转，支持任意层级的子 / 孙菜单
/// 与键盘操作。
///
/// 两种入口，共用同一套浮层实现：
///
/// * [CascadeContextMenu]：包住一块**区域**，右键 / 长按即弹出固定的菜单，
///   适合空白处；
/// * [showContextMenu]：按坐标命令式弹出，条目可以按行 / 按对象生成，适合
///   列表、表格、画布这类需要知道「右键的是谁」的场景。
///
/// | 文件 | 职责 |
/// |---|---|
/// | `src/context_menu_types.dart` | 公开类型：[ContextMenuEntryKind] / [ContextMenuItem] / [ContextMenuReveal] / [ContextMenuStyle] / 主题配色 / 定位键 |
/// | `src/context_menu_layout.dart` | 纯函数：尺寸预估、根菜单定位、子菜单左右 / 上下定位 |
/// | `src/context_menu_reveal.dart` | 揭示动画：起点按落位解析、裁切器、每帧派生量 |
/// | `src/context_menu_item.dart` | 单行渲染：图标 / 文案 / 快捷键 / 子菜单箭头 / hover |
/// | `src/context_menu_panel.dart` | 单级面板外观（[Material]）+ 键盘高亮状态 |
/// | `src/context_menu_submenu.dart` | 层级状态 + 单级浮层视图（显示 / 隐藏动画） |
/// | `src/context_menu_overlay.dart` | 浮层状态机：打开 / 收起 / 重开、层级、键盘调度 |
/// | `src/cascade_context_menu.dart` | [CascadeContextMenu]：手势入口 |
/// | `src/show_context_menu.dart` | [showContextMenu] / [ContextMenuHandle]：命令式入口 |
///
/// 浮层用 `OverlayEntry` 而不是 `Stack`：菜单需要画到 child 边界之外，
/// 而父级 `RenderBox.hitTest` 会拒绝落在自身尺寸之外的命中，放进 Stack
/// 会导致菜单项点不到。坐标统一在 Overlay 的 `_RenderTheater` 里换算，
/// 不用假设屏幕原点就是 (0, 0)。
///
/// 多级菜单共用一个 `OverlayEntry`：`_ContextMenuOverlay` 里维护 `_levels`，
/// 每一级对应一个 `Positioned.fromRect`。子菜单优先出现在父菜单右侧，右边
/// 不够就翻到左侧；垂直方向先与父级行对齐，底部溢出再整体上移，最后夹进
/// 可视区。
///
/// 进出场动画与 `AnchoredDropdown` 同一套：整体淡入、投影渐强、行内容稍晚
/// 淡入，以及揭示裁切。落位翻到左 / 上时起点自动镜像。收起是同一个进度的
/// 时间镜像，收起时长取 3/4。
///
/// 揭示形态由 [ContextMenuStyle.reveal] 选，两者是**两套不同的运动**：
/// * [ContextMenuReveal.corner]（默认）：从最靠近锚点的角斜着扫到对角，同时
///   以那个角为锚点轻微放大、朝锚点方向滑入；
/// * [ContextMenuReveal.unfold]：只让裁切线从**贴着锚点的那条边**推进，不做
///   缩放和位移，像下拉面板一样整块「展开」出来。
///
/// 菜单还开着时再次右键不会瞬移：先让当前所有层级按原锚点收起，退场完成的
/// `onEnd` 里换成新指针位置完整重播进场；子 / 孙级也跟着一起收起。重开不算
/// 一次开关，`onOpenChange` 不会重复回调。
///
/// 沿用隐式动画：`TweenAnimationBuilder` 的 `tween.end` 从 1 → 0 重播退场，
/// `onEnd` 再移除浮层；业务方法里没有任何 `AnimationController`。
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

part 'src/context_menu_types.dart';
part 'src/context_menu_layout.dart';
part 'src/context_menu_reveal.dart';
part 'src/context_menu_item.dart';
part 'src/context_menu_panel.dart';
part 'src/context_menu_submenu.dart';
part 'src/context_menu_overlay.dart';
part 'src/cascade_context_menu.dart';
part 'src/show_context_menu.dart';

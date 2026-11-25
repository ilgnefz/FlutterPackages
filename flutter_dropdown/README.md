# flutter_dropdown

一套「揭示式」下拉组件，两个门面共用一个 import：

| | `TextDropdown` | `AnchoredDropdown` |
|---|---|---|
| 触发器 | 组件内部画的字段（`fieldStyle` 管样式） | 外部传入的**任意 Widget** |
| 字段与列表 | 连体：共享一个裁切框，四角全程恒定圆角 | 分离：面板是独立浮层 |
| 布局 | 等宽（取 `fieldStyle.width`），只做上下翻转 | 独立宽度（`itemStyle.width`）+ 5 种水平对齐 |
| 揭示动画 | 单一进度 `p` 的贴边揭开 | `unfold` / 两种斜向，共三种 |

两者都按**选项值的类型**泛型（`TextDropdown<T>` / `AnchoredDropdown<T>`），
`value` / `onChanged` 直接收发 `T`（enum、数字、自定义对象都行），显示文字由
item 的 `label` 决定。

**只依赖 Flutter（和 `material_ui`）**，浮层用 `OverlayPortal` +
`CompositedTransformTarget/Follower` 实现，不依赖任何第三方弹层库。

## 安装

```yaml
dependencies:
  flutter_dropdown:
    path: ../flutter_dropdown        # 或 git: { url: ..., ref: ... }
```

## 用法

### TextDropdown：内置字段 + 连体列表

```dart
TextDropdown<ThemeType>(
  items: ThemeType.values
      .map((ThemeType v) => TextDropdownItem<ThemeType>(v, label: v.label))
      .toList(),
  value: current,                       // null 时显示 hint
  hint: '选择主题',
  onChanged: (ThemeType v) => setState(() => current = v),
  fieldStyle: DropdownFieldStyle.of(context).copyWith(
    width: 220,
    height: 40,
  ),
  itemStyle: DropdownItemStyle.of(context).copyWith(
    itemHeight: 36,
    itemGap: 2,
  ),
  mouseCursor: SystemMouseCursors.click, // 可选；默认就是手型
);
```

字段（外面显示的触发器）和面板 / 选项行各有自己的样式，别混用：

* `fieldStyle` —— `DropdownFieldStyle`：宽度、高度、圆角、边框、背景、内边距、
  文字样式。改「文字 / 箭头到触发器边框的距离」用 `fieldStyle.padding`。
* `itemStyle` —— `DropdownItemStyle`：面板宽度 / 最大高度、间距、行高、行间距、
  圆角、阴影、全部颜色、选项文字样式，以及滚动条厚度。

组件级参数只有 `value` / `onChanged` / `onOpenChange` / `hint` / `fieldStyle` /
`itemStyle` / `mouseCursor` / `initialOpen` / `disabled` / `reduceMotion` /
`duration`；没有 `width` / `height` / `radius` 这类散参数，它们都在两套 style 里。

### AnchoredDropdown：任意 Widget 当触发器

```dart
AnchoredDropdown<String>(
  trigger: const Icon(Icons.more_vert),          // Icon / Image / Row 都行
  alignment: DropdownAlignment.center,          // left / center / right / start / end
  itemStyle: DropdownItemStyle.of(context).copyWith(
    width: const DropdownWidth.fixed(240),       // 或 const DropdownWidth.matchTrigger()（默认）
  ),
  reveal: DropdownReveal.topLeftToBottomRight,  // 默认 unfold
  items: const <AnchoredDropdownItem<String>>[
    AnchoredDropdownItem<String>('a', label: 'Apple'),
    AnchoredDropdownItem<String>('b', label: 'Banana', enabled: false),
  ],
  value: selected,
  onChanged: (String v) => setState(() => selected = v),
);
```

`AnchoredDropdown` 的触发器由调用方绘制，所以**不读** `fieldStyle`；它只读
`itemStyle`（面板 + 选项行）。`itemStyle.width` 是面板宽度策略，默认
`DropdownWidth.matchTrigger()`。

需要跟着展开进度做形变（比如箭头旋转）时用 `triggerBuilder`，拿到的
`progress` 可以直接喂给 `AnchoredDropdownArrow`：

```dart
AnchoredDropdown<int>(
  triggerBuilder: (context, isOpen, progress) => Row(
    children: [
      const Icon(Icons.image),
      AnchoredDropdownArrow(progress: progress),
    ],
  ),
  items: items,
);
```

用内置的 `AnchoredDropdownField` 当触发器时，它自己的 `padding` / `height` /
颜色 / 圆角都能覆盖样式（不传则取 `DropdownFieldStyle.of(context)`）：

```dart
triggerBuilder: (context, isOpen, progress) => AnchoredDropdownField(
  label: selectedLabel,
  progress: progress,
  padding: const EdgeInsets.symmetric(horizontal: 20),
  style: DropdownFieldStyle.of(context),
),
```

### 自定义单行 / 动作项

`itemBuilder` 可自定义单行内容，禁用 / 选中 / 点击逻辑仍由组件管；
`AnchoredDropdownItem.child` 则是更轻量的「只换这一行内容」：

```dart
AnchoredDropdownItem<int>(
  1,
  child: Row(children: [Icon(Icons.image), Text('图片')]),
)
```

选项不传 `onTap` 时是**选择项**：点击回传 `value` 给 `onChanged` 并收起面板。
传了 `onTap` 就是**动作项**：点击执行自己的回调，不回传 `value`、也不显示选中
勾；`closeOnTap: false` 可让面板保持展开。两者可以在同一个列表里混用，

```dart
TextDropdownItem('del', label: '删除', onTap: (ctx) => showConfirm(ctx))
```

动作项的 `onTap` 拿到的 `context` 是门面在主树里的 context，可直接
`showDialog` / 读 provider；树状级联、就地展开子级这类交互由此组合，不必
再另加弹窗选项。

`label` 想单独换个颜色（高亮某个动作、按状态标色）就传 `color`，值项与动作
项都支持：

```dart
AnchoredDropdownItem.action(
  label: '清空筛选',
  color: const Color(0xFFDC2626),
  onTap: (ctx) => clearFilters(),
)
```

优先级：禁用（永远是 `disabledColor`）> 条目的 `color` > 面板
`textStyle.color` > `foreground`。`color` 只作用于内置的 `label` 文字，传了
`child` 就由自己的内容负责配色。

#### 纯动作菜单

整份列表都是动作项时没有「选中值」，用 `AnchoredDropdownItem.action` 构造：
它不带 value，所以不用为每一项编一个占位值，`value` / `onChanged` / 类型参数
都可以不写（`T` 会推成 `Object`）：

```dart
AnchoredDropdown(
  trigger: const Icon(Icons.filter_list_alt),
  items: [
    AnchoredDropdownItem.action(
      label: '只看已勾选',
      closeOnTap: false,                 // 多选筛选：点完不收起
      onTap: (ctx) => toggle(Filter.checked),
    ),
    AnchoredDropdownItem.action(
      label: '只看已改名',
      closeOnTap: false,
      onTap: (ctx) => toggle(Filter.renamed),
    ),
  ],
)
```

动作项不参与选中态，所以「这一项当前是否生效」要自己画：把带勾的行放进
`child`，随筛选状态重建列表即可（面板开着时也会跟着刷新）。

## 外观

```dart
DropdownFieldStyle.of(context)                       // 触发器样式，跟随明暗主题
DropdownFieldStyle.light() / dark()
DropdownFieldStyle.of(context).copyWith(width: 240)  // 只改几项

DropdownItemStyle.of(context)                        // 面板 + 选项行样式
DropdownItemStyle.light() / dark()
DropdownItemStyle.of(context).copyWith(itemGap: 2)
```

不传 style 时取 `of(context)`，**跟随明暗主题**但颜色是包内常量（浅色：白底
`#FFFFFF` / 描边 `#D4D4D8`；深色：`#211F26` / `#49454F`），不会被宿主 App
的主题色带跑。想让下拉框吃自己的主题色，就显式传：

```dart
itemStyle: DropdownItemStyle.of(context).copyWith(
  backgroundColor: scheme.surfaceContainer,
  borderColor: scheme.outline,
  foreground: scheme.onSurface,
  selectedColor: scheme.surfaceContainerHighest,
),
```

## 滚动条

内容超出 `itemStyle.maxHeight` 后列表内部滚动，右侧有一条**贴着面板内边缘**
的滚动条：

* 它的盒子铺满整条内容区（在 `itemStyle.padding` **之外**），滑块直接压在面板
  边框上 —— `padding` 只缩进列表本体、`itemPadding` 只缩进行内容，两者怎么调
  都不会把它往里推；
* **厚度默认 4px**（`itemStyle.scrollbarThickness`，桌面默认 8px 太宽，容易
  误触行尾箭头），圆角 / 颜色跟随 `ScrollbarTheme`，默认只在滚动时出现；
* 平台自动注入的那条（Windows / macOS 上 Material 会给可滚动区域加一条）会被
  关掉，不会叠成两条。

想让滑块常显，套一层 `ScrollbarTheme` 即可（`crossAxisMargin` 已经固定为 0）：

```dart
ScrollbarTheme(
  data: ScrollbarTheme.of(context).copyWith(thumbVisibility: true),
  child: TextDropdown<String>(items: items),
)
```

## 动画

三种揭示动画都基于同一个进度 `p`，且都用「完整圆角外框 ∩ 可见区域」求交，
所以四个圆角在任何一帧都是 `itemStyle.radius`，行高与文字粗细也不会缩放：

* `DropdownReveal.unfold`（默认）：从贴着触发器的一条薄边（`itemStyle.lip`）沿
  垂直方向揭开，翻到上方时从下往上；
* `DropdownReveal.topLeftToBottomRight` / `topRightToBottomLeft`：沿对角线擦除。

阴影画在裁切层**之外**，alpha 随 `p` 渐强，最后一帧不会突然冒出一整圈。
`reduceMotion: true` 或系统开启「减少动态效果」时只做淡入淡出（120ms）。

`duration` 控制展开时长，收起自动取 3/4。

## 注意

* 组件依赖 `Overlay`，需要放在 `MaterialApp` / `WidgetsApp` 之下。
* `itemBuilder` 的 `context` 来自 Overlay（浮层所在的树），不是触发器所在的
  局部子树；要读页面局部的 `InheritedWidget` 请在闭包里自行捕获。动作项的
  `onTap` 则拿到主树的 context。
* `value` 用 `==` 和 item 的 `value` 比较，自定义类型记得实现相等性。
* 面板不会因为父级 `Stack` / `ScrollView` 被裁掉：它挂在 Overlay 上，超出
  触发器范围的部分照样能点到。

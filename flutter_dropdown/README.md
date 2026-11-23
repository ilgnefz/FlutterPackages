# flutter_dropdown

一套「揭示式」下拉组件，两个门面共用一个 import：

| | `TextDropdown` | `AnchoredDropdown` |
|---|---|---|
| 触发器 | 组件内部画的输入框样字段 | 外部传入的**任意 Widget** |
| 字段与列表 | 连体：共享一个裁切框，四角全程恒定圆角 | 分离：面板是独立浮层 |
| 布局 | 等宽，只做上下翻转 | 独立宽度 + 5 种水平对齐 |
| 揭示动画 | 单一进度 `p` 的贴边揭开 | `unfold` / 两种斜向，共三种 |

两者都按**选项值的类型**泛型（`TextDropdown<T>` / `AnchoredDropdown<T>`），
`value` / `onChanged` 直接收发 `T`（enum、数字、自定义对象都行），显示文字由
item 的 `label` 决定。

**只依赖 Flutter（和 `material_ui`）**，浮层用 `OverlayPortal` +
`CompositedTransformFollower` 实现，不依赖任何第三方弹层库。

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
  width: 220,
  height: 40,
  itemGap: 0,                           // 相邻选项的间距
  radius: 12,                           // 外框 / 面板 / 裁切 / 阴影共用
  disabled: false,
  reduceMotion: false,
);
```

`height` / `itemGap` / `radius` / `borderColor` / `textStyle` / `mouseCursor`
是单点快捷覆盖，优先级高于 `style`。

三个「边距」分别控制不同层，别混用：

| 参数 | 控制的是 | 默认值 |
|---|---|---|
| `DropdownStyle.fieldPadding` | 触发器里文字 / 箭头到**触发器边框**的距离 | 水平 12 |
| `DropdownStyle.padding` | 选项行外框到**下拉栏面板边框**的距离 | 4（四边） |
| `DropdownStyle.itemPadding` | 下拉栏里文字 / 打勾图标到**选项行外框**的距离 | 水平 10 |

```dart
TextDropdown<String>(
  items: items,
  style: DropdownStyle.of(context).copyWith(
    fieldPadding: const EdgeInsets.symmetric(horizontal: 20),
    itemPadding: const EdgeInsets.symmetric(horizontal: 16),
    padding: 6,
  ),
)
```

`AnchoredDropdown` 同样读这三个值；用内置 `AnchoredDropdownField` 当触发器时，
它自己的 `padding` 参数仍可覆盖 `fieldPadding`。

### AnchoredDropdown：任意 Widget 当触发器

```dart
AnchoredDropdown<String>(
  trigger: const Icon(Icons.more_vert),          // Icon / Image / Row 都行
  alignment: DropdownAlignment.center,          // left / center / right / start / end
  width: const DropdownWidth.fixed(240),        // 或 const DropdownWidth.matchTrigger()
  reveal: DropdownReveal.topLeftToBottomRight,  // 默认 unfold
  items: const <AnchoredDropdownItem<String>>[
    AnchoredDropdownItem<String>('a', label: 'Apple'),
    AnchoredDropdownItem<String>('b', label: 'Banana', enabled: false),
  ],
  value: selected,
  onChanged: (String v) => setState(() => selected = v),
);
```

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

用内置的 `AnchoredDropdownField` 当触发器时，它自己的 `padding` 参数也能改文字 /
箭头到边框的距离（不传则取 `DropdownStyle.fieldPadding`）：

```dart
triggerBuilder: (context, isOpen, progress) => AnchoredDropdownField(
  label: selectedLabel,
  progress: progress,
  padding: const EdgeInsets.symmetric(horizontal: 20),
  style: DropdownStyle.of(context),
),
```

整块列表都能自定义（`menuBuilder`），单行内容也能自定义（`itemBuilder`，
禁用 / 选中 / 点击逻辑仍由组件管）。

## 外观

两个门面共用 `DropdownStyle`：

```dart
DropdownStyle.of(context)                       // 按 ThemeData.brightness 取 light / dark
DropdownStyle.light()                           // 中性灰表面
DropdownStyle.dark()                            // M3 深色表面
DropdownStyle.of(context).copyWith(radius: 16)  // 只改几项
```

不传 `style` 时默认走 `DropdownStyle.of(context)`，**跟随明暗主题**但颜色是包内
常量（浅色：白底 `#FFFFFF` / 描边 `#D4D4D8`；深色：`#211F26` / `#49454F`），
不会被宿主 App 的主题色带跑。想让下拉框吃自己的主题色，就显式传：

```dart
style: DropdownStyle.of(context).copyWith(
  backgroundColor: scheme.surfaceContainer,
  borderColor: scheme.outline,
  foreground: scheme.onSurface,
  selectedColor: scheme.surfaceContainerHighest,
),
```

## 滚动条

内容超出 `maxPanelHeight`（`AnchoredDropdown` 是 `maxMenuHeight`）后列表内部滚动，
右侧有一条**贴着面板内边缘**的滚动条：

* 它的盒子铺满整条内容区（在 `padding` **之外**），滑块直接压在面板边框上 ——
  `padding` 只缩进列表本体、`itemPadding` 只缩进行内容，两者怎么调都不会把它
  往里推；
* 宽度 / 圆角 / 颜色跟随 `ScrollbarTheme`，默认只在滚动时出现；
* 平台自动注入的那条（Windows / macOS 上 Material 会给可滚动区域加一条）会被
  关掉，不会叠成两条；
* 用 `menuBuilder` 完全自定义内容时滚动归你自己管，也就不带这条。

想让滑块常显，套一层 `ScrollbarTheme` 即可（`crossAxisMargin` 已经固定为 0）：

```dart
ScrollbarTheme(
  data: ScrollbarTheme.of(context).copyWith(thumbVisibility: true),
  child: TextDropdown<String>(items: items),
)
```

## 动画

三种揭示动画都基于同一个进度 `p`，且都用「完整圆角外框 ∩ 可见区域」求交，
所以四个圆角在任何一帧都是 `style.radius`，行高与文字粗细也不会缩放：

* `DropdownReveal.unfold`（默认）：从贴着触发器的一条薄边（`style.lip`）沿垂直
  方向揭开，翻到上方时从下往上；
* `DropdownReveal.topLeftToBottomRight` / `topRightToBottomLeft`：沿对角线擦除。

阴影画在裁切层**之外**，alpha 随 `p` 渐强，最后一帧不会突然冒出一整圈。
`reduceMotion: true` 或系统开启「减少动态效果」时只做淡入淡出（120ms）。

`duration` 控制展开时长，收起自动取 3/4。

## 注意

* 组件依赖 `Overlay`，需要放在 `MaterialApp` / `WidgetsApp` 之下。
* `itemBuilder` / `menuBuilder` 的 `context` 来自 Overlay（浮层所在的树），
  不是触发器所在的局部子树；要读页面局部的 `InheritedWidget` 请在闭包里
  自行捕获。
* `value` 用 `==` 和 item 的 `value` 比较，自定义类型记得实现相等性。
* 面板不会因为父级 `Stack` / `ScrollView` 被裁掉：它挂在 Overlay 上，超出
  触发器范围的部分照样能点到。

## 0.2.2

* `CalendarDateField` 新增 `formatDate`：自定义输入框里日期的显示格式（默认仍是
  `formatCalendarDate` 的 `2026 / 11 / 25`），方便按本地习惯写成年月日 / 日年月。
* README 补了一节**国际化**：locale 三件套怎么配、为什么「什么都没配」反而是
  英文、怎么加第三门语言、`formatDate` 与 `label` / `hint` 这些不在
  `CalendarLabels` 里的文案，以及几个常见坑。

## 0.2.1

* 新增 `CalendarStyle.mouseCursor`（默认 `SystemMouseCursors.click`）：统管年月
  标题、范围内的日期格子、年份列表条目、两颗翻月按钮的光标。
* **修复**：之前桌面端把鼠标移到日期上光标不变。`InkWell` 默认的
  `WidgetStateMouseCursor.adaptiveClickable` 在非 web 平台解析成箭头，必须显式
  给 `mouseCursor` 才是小手。
* 点不了的部分不给小手：范围外的日期、范围到头时的翻月按钮、关掉
  `enableYearPicker` 时的年月标题，保持默认箭头。
* `CalendarDateField` 新增 `mouseCursor`（默认小手），`enabled: false` 时不用。
* 测试 17 → 24 条（日期/标题/翻月/年份的默认小手、范围外与到头不给小手、样式
  整体覆盖、输入框可用/禁用/自定义光标）。

## 0.2.0

弹窗整体收小一号，标题不再被裁，文案可国际化。

* **尺寸**：默认宽度 300 → 268，格子高度 40 → 32，选中圆点 32 → 28，标题行
  48 → 40，表头 28 → 22，字号（标题 16 → 14、日期 15 → 13、星期 12.5 → 11、
  年份 15 → 13.5）。整个面板从约 328×300 收到约 264×268。
* 新增 `CalendarStyle`：宽度、圆角、投影、内边距、四种文字样式、格子/圆点/年份
  行高度、翻月按钮的图标 / 尺寸 / `ButtonStyle` 全在里面。
* **修复**：标题「2026年11月」被裁成省略号。原来是 `Flexible` + `Spacer` 两个
  flex 平分剩余宽度，标题只拿到一半；改成 `Expanded` 独占剩余宽度。
* **修复**：`weekStartsOnMonday: false` 时星期表头不跟着转（还是周一起）。
  现在自带文案整体转一格；同时文案从 `weekdayLabels` 参数挪进 `CalendarLabels`。
* 新增 `CalendarLabels`（`zh` / `en` / `of(context)`）：星期表头与年月 / 年份
  按 locale 自动选，`en` 英文、其它中文；继承即可加语言。
* 行为变更：点邻月日期现在**会翻月并选中那天**（原来只翻月）。要旧行为传
  `selectAdjacentDays: false`。
* **修复**：父级不关心翻月、一直传同一个 `month` 时，面板内部翻到的月份会被
  任意一次父级重建拽回去。现在只有 `month` 真的变了才同步。
* `showDatePicker` / `CalendarDateField` 新增 `style`（或 `panelStyle`）与
  `labels`；`panelWidth` 变成可选的老写法（等价 `style.width`）。
* **破坏性**：`CalendarPanel.width` → `style.width`；`weekdayLabels` →
  `labels`；静态常量 `CalendarPanel.bodyHeight` / `panelHeight` →
  `CalendarStyle.bodyHeight` / `panelHeight`（现在是随样式变的 getter）。
* 测试 11 → 16 条（邻月选中 / 只翻月 / 标题不被裁 / 英文 locale / 周日开头 /
  样式覆盖）。

## 0.1.0

* 首个可用版本：单月日期选择器，从模板 Calculator 替换为实际实现。
* `CalendarDateField`：带标题 / 日历图标的日期输入框，点一下弹出面板，
  支持受控 `value` 与 `initialDate`，显示格式 `2026 / 11 / 25`。
* `CalendarPanel`：6 × 7 单月网格，邻月日期浅灰（`showAdjacentDays` 可关），
  点标题展开可滚动的 3 列年份列表，左右箭头翻月，支持 `firstDate` /
  `lastDate` 范围限制。
* `showDatePicker` / `showCalendarDatePicker`：任意按钮调用，按
  `CalendarPlacement.top/bottom/left/right` 定位，空间不足自动翻到对面并夹回
  视口；点外部 / Esc 关闭返回 null，选中返回当天 0 点。
* 导出工具函数与 key：`formatCalendarDate`、`isSameCalendarDay`、
  `isDateInRange`、`isMonthInRange`、`calendarDayKey`、`kCalendarPanelKey`、
  `kCalendarYearGridKey`。

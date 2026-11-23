import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'checker.dart';
import 'hex.dart';

// ── 尺寸常量 ──────────────────────────────────────────────────────────────

/// 饱和度-明度面板的宽高比（宽 / 高）。
const double _kSatValAspect = 1.5;

/// 面板圆角。
const double _kPanelRadius = 12;

/// 指针 / 滑块的半径（直径 18）。
const double _kThumbRadius = 9;

/// 指针 / 滑块的白描边宽度。
const double _kThumbStroke = 3;

/// 色相条高度。
const double _kHueBarHeight = 14;

/// 色相条那一行的高度：留出手指 / 鼠标的抓取区域，滑块垂直居中。
const double _kHueRowHeight = 24;

/// 面板与色相条、色相条与底行之间的间距。
const double _kRowGap = 12;

/// 底行左侧圆形当前色预览的直径。
const double _kPreviewSize = 36;

/// hex 输入框圆角。
const double _kFieldRadius = 10;

/// 底行高度 = 预览圆直径 = 输入框高度。
const double _kFooterHeight = _kPreviewSize;

/// 底行里透明度读数（`100%`）占的宽度。
///
/// 固定宽度 + 等宽数字：0% / 100% 切换时输入框不会跟着左右抖。
const double _kAlphaLabelWidth = 38;

// ── 测试用 key（同值匹配，不必导出） ────────────────────────────────────

const Key _satValKey = ValueKey<String>('color-picker-sat-val');
const Key _hueKey = ValueKey<String>('color-picker-hue');
const Key _alphaKey = ValueKey<String>('color-picker-alpha');
const Key _hexKey = ValueKey<String>('color-picker-hex');
const Key _alphaLabelKey = ValueKey<String>('color-picker-alpha-label');
const Key _previewKey = ValueKey<String>('color-picker-preview');

/// 取颜色里色相条上的七个停靠色（红 → 黄 → 绿 → 青 → 蓝 → 洋红 → 红）。
final List<Color> _hueStops = <Color>[
  for (int i = 0; i <= 6; i++) HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
];

/// 颜色选择面板：饱和度-明度方块 + 色相条 + 当前色 + hex 输入。
///
/// 只画面板本身，不带弹层——直接塞进任意布局里也能用；要「点一下弹出」用
/// `ColorPickerButton`，它就是「一个色块 + 这个面板」的组合。
///
/// 两种用法：
/// * **非受控**（不传 [value]）：内部自己保存颜色，[initialColor] 是初始值；
/// * **受控**（传 [value]）：颜色由父组件持有，拖动 / 输入时通过 [onChanged]
///   通知，父组件 `setState` 回传新的 [value] 才更新。
///
/// [onChanged] 在拖动过程中按帧触发（用于实时预览），[onChangeEnd] 在松手 /
/// 输入提交时触发一次（用于落库）。只调 [onChanged] 也够用，两个都不传就是
/// 纯展示。
///
/// ## 回调给的是 int，不是 [Color]
///
/// 两个回调的参数都是 `0xAARRGGBB` 的整数，跟 Flutter 代码里写
/// `Color(0xFF2B7FFF)` 的那个值是同一个数（等价 `color.toARGB32()`）：
///
/// ```dart
/// int _argb = 0xFF2B7FFF;                    // 存配置、存数据库都是它
/// ColorPicker(
///   value: Color(_argb),                     // 传进来仍用 Color，能直接给 Colors.xxx
///   onChanged: (int argb) => setState(() => _argb = argb),
///   onChangeEnd: (int argb) => save(argb),
/// );
/// ```
///
/// ## 颜色状态
///
/// 内部真值是 [HSVColor] 而不是 [Color]：饱和度或明度为 0（纯灰 / 纯黑）时
/// `Color` 里已经看不出色相了，来回换算会把色相条拽回红色。这里保留上一次的
/// 色相，所以从蓝色一直拖到黑色，色相条还停在蓝区，再往右拖又回到蓝色。
///
/// ## hex 输入
///
/// 支持 `#RGB`、`#RRGGBB`、`RRGGBB`、`#RRGGBBAA`、`0xRRGGBB`、`0xAARRGGBB`；
/// 回车或失焦时解析，非法输入恢复成当前颜色。输入过程中不会被拖动 / 外部
/// 赋值覆盖（正在输入的文本优先）。
///
/// 聚焦时整体选中框里的文本：点进去直接打字就是整段替换，不用先全删。
///
/// 显示格式由 [hexFormat] 决定：默认 `#RRGGBB`；要粘进 Flutter 代码就传
/// [ColorHexFormat.flutterArgb]，显示成 `0xFFRRGGBB`。
///
/// ## 透明度
///
/// 默认不处理透明度（只画不透明色）。传 `showOpacity: true` 才多出一条透明度
/// 条，输入框右边同时显示百分比：
///
/// * 拖动透明度条即时改 alpha，`onChanged` 给的就是 `0xAARRGGBB`（带上 alpha）；
/// * hex 文本跟着变成带 alpha 的写法（`#RRGGBBAA` / `0xAARRGGBB`），所以粘进
///   代码或者存配置时透明度不会丢；
/// * 输入框里写八位 hex 也能改透明度。
///
/// `showOpacity: false` 时这些都不存在：八位 hex 里的 alpha 会被丢掉、按不透明
/// 处理，等于输入框也控制不了透明度。
class ColorPicker extends StatefulWidget {
  const ColorPicker({
    super.key,
    this.value,
    this.initialColor = const Color(0xFF2B7FFF),
    this.onChanged,
    this.onChangeEnd,
    this.width = 260,
    this.showHexField = true,
    this.showOpacity = false,
    this.hexFormat = ColorHexFormat.hashRgb,
    this.mouseCursor,
    this.enabled = true,
  });

  /// 当前颜色。传 null 表示由组件内部管理（非受控）。
  final Color? value;

  /// 非受控模式下的初始颜色。
  final Color initialColor;

  /// 颜色变化时回调；拖动过程中按帧触发（每秒几十次）。
  ///
  /// 参数是 `0xAARRGGBB` 的整数（等价 `color.toARGB32()`），也就是代码里的
  /// `0xFF2B7FFF` 这种写法；要变成 [Color] 用 `Color(argb)`。
  ///
  /// **别在这里做重活**——改全局主题、整页 `setState`、写库、发请求都不行：
  /// 每一次回调都夹在「指针移动 → 本帧绘制」之间，重活会让滑块看起来卡住
  /// （松手才跳到位）。落库 / 换主题用 [onChangeEnd]。
  final ValueChanged<int>? onChanged;

  /// 一次操作结束时回调：面板 / 色相条松手、hex 提交。适合落库。
  ///
  /// 同样是 `0xAARRGGBB` 的整数。
  final ValueChanged<int>? onChangeEnd;

  /// 面板内容宽度（也是整个控件的宽度）。
  final double width;

  /// 是否显示底部一行（当前色圆点 + hex 输入框）。
  final bool showHexField;

  /// 是否显示透明度控制（色相条下的透明度条 + 输入框右侧的百分比）。
  ///
  /// 默认 `false`：面板只处理不透明色。此时输入框里写八位 hex
  /// （`#RRGGBBAA` / `0xAARRGGBB`）也会被当成不透明，等于连输入框都改不了
  /// 透明度。
  ///
  /// 传 `true`：多出一条透明度条（棋盘格 + 「透明 → 当前色」渐变），可拖；
  /// 输入框右侧显示百分比；hex 文本变成带 alpha 的写法（`#RRGGBBAA` /
  /// `0xAARRGGBB`），输入八位写法同样能改透明度。
  final bool showOpacity;

  /// hex 的显示格式；输入时两种写法都认。
  ///
  /// 要直接粘进 `Color(...)` 就用 [ColorHexFormat.flutterArgb]
  /// （显示成 `0xFFRRGGBB`）。
  final ColorHexFormat hexFormat;

  /// 饱和度-明度方块与色相条上的鼠标指针；不传不覆盖（保持系统默认）。
  final MouseCursor? mouseCursor;

  /// 禁用整个控件（面板、色相条、输入框都不响应）。
  final bool enabled;

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late HSVColor _hsv = HSVColor.fromColor(widget.value ?? widget.initialColor);
  late final TextEditingController _hex = TextEditingController(
    text: colorToHex(
      _hsv.toColor(),
      format: widget.hexFormat,
      includeAlpha: widget.showOpacity,
    ),
  );
  final FocusNode _hexFocus = FocusNode(debugLabel: 'ColorPicker.hex');

  Color get _color => _hsv.toColor();

  /// 对外回传的整数：`0xAARRGGBB`，和 `Color(0xFF2B7FFF)` 里的数一致。
  int get _argb => _color.toARGB32();

  /// 当前不透明度 0~1（`showOpacity` 关掉时恒为颜色自带的 alpha）。
  double get _alpha => _hsv.alpha;

  @override
  void initState() {
    super.initState();
    _hexFocus.addListener(_handleHexFocusChange);
  }

  @override
  void didUpdateWidget(covariant ColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换了显示格式 / 开关了透明度：把当前色按新写法重写进输入框。
    if (widget.hexFormat != oldWidget.hexFormat ||
        widget.showOpacity != oldWidget.showOpacity) {
      _syncHexText(force: true);
    }
    final Color? value = widget.value;
    if (value == null || value == oldWidget.value) return;
    // 自己刚发出去的色值原样回来：不重算，免得把 hue 弄丢。
    if (value == _color) return;
    _adoptColor(value, notify: false);
  }

  @override
  void dispose() {
    _hexFocus.removeListener(_handleHexFocusChange);
    _hexFocus.dispose();
    _hex.dispose();
    super.dispose();
  }

  // ── 状态 ────────────────────────────────────────────────────────────────

  /// 把外部色值吸收进来。
  ///
  /// 纯灰 / 纯黑时 [HSVColor.fromColor] 会把 hue 归 0，直接用的话色相条会
  /// 突然跳到红色；这里沿用当前 hue，只取它的饱和度与明度。
  void _adoptColor(Color color, {bool notify = true}) {
    final HSVColor next = HSVColor.fromColor(color);
    final HSVColor merged = (next.saturation == 0 || next.value == 0)
        ? next.withHue(_hsv.hue)
        : next;
    setState(() => _hsv = merged);
    _syncHexText();
    if (!notify) return;
    widget.onChanged?.call(_argb);
  }

  /// 只改 HSV 的一个分量（拖动面板 / 色相条），顺带同步输入框与回调。
  void _setHsv(HSVColor next) {
    if (!widget.enabled) return;
    setState(() => _hsv = next);
    _syncHexText();
    widget.onChanged?.call(_argb);
  }

  void _endChange() {
    if (!widget.enabled) return;
    widget.onChangeEnd?.call(_argb);
  }

  // ── 面板手势 ────────────────────────────────────────────────────────────

  void _updateSatVal(Offset local, double height) {
    final double s = (local.dx / widget.width).clamp(0.0, 1.0);
    final double v = (1 - local.dy / height).clamp(0.0, 1.0);
    _setHsv(_hsv.withSaturation(s).withValue(v));
  }

  void _updateHue(Offset local) {
    final double t = (local.dx / widget.width).clamp(0.0, 1.0);
    // 360 与 0 是同一条边，夹到 359.9 免得滑到最右端时圆环绕回红色。
    _setHsv(_hsv.withHue((t * 360).clamp(0.0, 359.9)));
  }

  void _updateAlpha(Offset local) {
    if (!widget.showOpacity) return;
    final double t = (local.dx / widget.width).clamp(0.0, 1.0);
    _setHsv(_hsv.withAlpha(t));
  }

  // ── hex 输入 ────────────────────────────────────────────────────────────

  /// 把当前颜色写回输入框。
  ///
  /// 用户正在输入时不覆盖（`force` 除外）：拖动时按帧回写会把光标顶走，
  /// 打到一半的 `#2B7` 也被改掉。
  void _syncHexText({bool force = false}) {
    if (!force && _hexFocus.hasFocus) return;
    final String text = colorToHex(
      _color,
      format: widget.hexFormat,
      includeAlpha: widget.showOpacity,
    );
    if (_hex.text == text) return;
    _hex.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _handleHexFocusChange() {
    if (_hexFocus.hasFocus) {
      // 聚焦即全选：点进去直接打字就是整段替换。
      _selectAllHex();
      // 点进输入框时，光标 / 选区是在这次点击里**后面**才落位的，会盖掉上面
      // 那次全选；等这一帧画完再选一次，保证「聚焦就选中全部」。之后再点就
      // 是正常摆光标了（那时焦点没变，不会重复全选）。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hexFocus.hasFocus) _selectAllHex();
      });
      return;
    }
    // 失焦即提交；没改过则 _submitHex 内部自己跳过。
    _submitHex(_hex.text);
  }

  void _selectAllHex() {
    if (_hex.text.isEmpty) return;
    _hex.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _hex.text.length,
    );
  }

  void _submitHex(String raw) {
    // showOpacity 关掉时不读 alpha：八位写法里的透明度在这里就被丢掉，等于
    // 连输入框都改不了透明度。
    final Color? parsed = parseHexColor(raw, includeAlpha: widget.showOpacity);
    if (parsed == null) {
      _syncHexText(force: true); // 非法输入：恢复成当前颜色
      return;
    }
    // 颜色没变、只是写法不同（#2b7fff / 0xFF2B7FFF）：只把文本归一，不回调，
    // 免得「点开面板又关掉」也发一次 onChangeEnd。
    if (parsed.toARGB32() == _color.toARGB32()) {
      _syncHexText(force: true);
      return;
    }
    _adoptColor(parsed);
    _syncHexText(force: true);
    widget.onChangeEnd?.call(parsed.toARGB32());
  }

  // ── 构建 ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double panelHeight = widget.width / _kSatValAspect;
    final Widget content = SizedBox(
      width: widget.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _withCursor(_buildSatVal(panelHeight)),
          const SizedBox(height: _kRowGap),
          _withCursor(_buildHueBar()),
          if (widget.showOpacity) ...<Widget>[
            const SizedBox(height: _kRowGap),
            _withCursor(_buildAlphaBar()),
          ],
          if (widget.showHexField) ...<Widget>[
            const SizedBox(height: _kRowGap),
            _buildFooter(scheme),
          ],
        ],
      ),
    );
    if (widget.enabled) return content;
    return Opacity(opacity: 0.5, child: IgnorePointer(child: content));
  }

  /// 给可拖拽区域套上自定义指针（没配就不插 [MouseRegion]，保持原样）。
  Widget _withCursor(Widget child) {
    final MouseCursor? cursor = widget.mouseCursor;
    if (cursor == null) return child;
    return MouseRegion(cursor: cursor, child: child);
  }

  /// 饱和度-明度方块：底色是当前色相的纯色，上面盖「白 → 透明」与
  /// 「透明 → 黑」两层渐变，正好对应 HSV 的 `s`（横轴）与 `v`（纵轴）。
  Widget _buildSatVal(double height) {
    final Color pure = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    // 指针圆心夹在面板内：贴着右上角时圆环不会有一半被裁掉。
    final double cx = (_hsv.saturation * widget.width).clamp(
      _kThumbRadius,
      widget.width - _kThumbRadius,
    );
    final double cy = ((1 - _hsv.value) * height).clamp(
      _kThumbRadius,
      height - _kThumbRadius,
    );

    return _PointerDragArea(
      key: _satValKey,
      enabled: widget.enabled,
      onUpdate: (Offset local) => _updateSatVal(local, height),
      onEnd: _endChange,
      child: SizedBox(
        width: widget.width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_kPanelRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ColoredBox(color: pure),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0x00000000), Color(0xFF000000)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: cx - _kThumbRadius,
              top: cy - _kThumbRadius,
              child: _buildThumb(Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }

  /// 色相条：胶囊渐变 + 一个跟着色相走的圆环滑块。
  Widget _buildHueBar() {
    final double cx = (_hsv.hue / 360 * widget.width).clamp(
      _kThumbRadius,
      widget.width - _kThumbRadius,
    );

    return _PointerDragArea(
      key: _hueKey,
      enabled: widget.enabled,
      onUpdate: _updateHue,
      onEnd: _endChange,
      child: SizedBox(
        width: widget.width,
        height: _kHueRowHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Center(
              child: Container(
                height: _kHueBarHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_kHueBarHeight / 2),
                  gradient: LinearGradient(colors: _hueStops),
                ),
              ),
            ),
            Positioned(
              left: cx - _kThumbRadius,
              top: (_kHueRowHeight - _kThumbRadius * 2) / 2,
              child: _buildThumb(Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }

  /// 透明度条：棋盘格底 + 「全透明 → 当前色」渐变，滑块横坐标就是 alpha。
  ///
  /// 棋盘格不是装饰：同样一串「越来越浓」的渐变铺在白底上，只是看起来变淡；
  /// 压在格子上才有「透出后面的背景」的直觉。
  Widget _buildAlphaBar() {
    final Color opaque = _hsv.withAlpha(1).toColor();
    final double cx = (_alpha * widget.width).clamp(
      _kThumbRadius,
      widget.width - _kThumbRadius,
    );

    return _PointerDragArea(
      key: _alphaKey,
      enabled: widget.enabled,
      onUpdate: _updateAlpha,
      onEnd: _endChange,
      child: SizedBox(
        width: widget.width,
        height: _kHueRowHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_kHueBarHeight / 2),
                child: SizedBox(
                  height: _kHueBarHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      const CheckerPattern(square: 4),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[opaque.withAlpha(0), opaque],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: cx - _kThumbRadius,
              top: (_kHueRowHeight - _kThumbRadius * 2) / 2,
              child: _buildThumb(Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }

  /// 指针 / 滑块：白描边的空心圆。
  ///
  /// 内部留透明而不是填色：压在渐变上时会直接透出下面的颜色，圆环里就是它
  /// 所指向的那个色。
  Widget _buildThumb(Color fill) {
    return Container(
      width: _kThumbRadius * 2,
      height: _kThumbRadius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: Colors.white, width: _kThumbStroke),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }

  /// 底行：左边当前色圆点，中间 hex 输入框，右边透明度读数（开关打开时）。
  Widget _buildFooter(ColorScheme scheme) {
    final Color field = scheme.onSurface.withAlpha(18);
    return SizedBox(
      height: _kFooterHeight,
      child: Row(
        children: <Widget>[
          _buildPreview(scheme),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: _hexKey,
              controller: _hex,
              focusNode: _hexFocus,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
                // 十六进制是大写字母 + 数字，等宽更好对齐。
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
              cursorColor: scheme.primary,
              cursorHeight: 16,
              textAlignVertical: TextAlignVertical.center,
              // 只让十六进制字符进来：`#RRGGBB` 与 `0xAARRGGBB` 都要能打。
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-FxX#]')),
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: field,
                hintText: switch (widget.hexFormat) {
                  ColorHexFormat.hashRgb =>
                    widget.showOpacity ? '#RRGGBBAA' : '#RRGGBB',
                  ColorHexFormat.flutterArgb =>
                    widget.showOpacity ? '0xAARRGGBB' : '0xFFRRGGBB',
                },
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurface.withAlpha(90),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_kFieldRadius),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_kFieldRadius),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_kFieldRadius),
                  borderSide: BorderSide(color: scheme.primary, width: 1.4),
                ),
              ),
              onSubmitted: _submitHex,
              onTapOutside: (PointerDownEvent event) {
                // 点面板 / 色相条时也会走到这里：先提交，再让手势继续。
                _submitHex(_hex.text);
                _hexFocus.unfocus();
              },
            ),
          ),
          if (widget.showOpacity) ...<Widget>[
            const SizedBox(width: 8),
            _buildAlphaLabel(scheme),
          ],
        ],
      ),
    );
  }

  /// 当前色圆点：底下垫一层棋盘格，半透明时才看得出「透了多少」。
  ///
  /// 描边用中性色：白色不透明时圆点和白底分不清，深色时不会脏。
  Widget _buildPreview(ColorScheme scheme) {
    return SizedBox(
      width: _kPreviewSize,
      height: _kPreviewSize,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipOval(child: const CheckerPattern()),
          Container(
            key: _previewKey,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color,
              border: Border.all(color: scheme.onSurface.withAlpha(26)),
            ),
          ),
        ],
      ),
    );
  }

  /// 输入框右边的透明度读数（`100%`）。
  ///
  /// 只读：改透明度用上面的透明度条或 hex 输入，这里只管把数值摊开给人看。
  Widget _buildAlphaLabel(ColorScheme scheme) {
    return SizedBox(
      width: _kAlphaLabelWidth,
      child: Text(
        '${(_alpha * 100).round()}%',
        key: _alphaLabelKey,
        maxLines: 1,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface.withAlpha(160),
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 拖动区域：直接吃 pointer 事件，而不是 `GestureDetector` 的 pan 手势。
///
/// pan 必须先赢下手势竞技场才会给 `onPanUpdate`（垂直方向还可能被外层
/// `Scrollable` 抢走），表现就是：按下不动、拖一段才跟上、松手时才跳到最终
/// 位置。pointer 事件按下即到、拖出 widget 边界也照样继续跟，颜色面板要的
/// 就是这个手感。
///
/// 同一时间只跟一根手指 / 一个鼠标（第二根手指不会抢走当前拖动）。
class _PointerDragArea extends StatefulWidget {
  const _PointerDragArea({
    super.key,
    required this.onUpdate,
    required this.onEnd,
    required this.child,
    this.enabled = true,
  });

  /// 指针位置（本组件局部坐标）；按下和每次移动都会调用。
  final ValueChanged<Offset> onUpdate;

  /// 抬起 / 取消时回调一次。
  final VoidCallback onEnd;

  /// 为 false 时不响应任何指针。
  final bool enabled;

  final Widget child;

  @override
  State<_PointerDragArea> createState() => _PointerDragAreaState();
}

class _PointerDragAreaState extends State<_PointerDragArea> {
  /// 正在跟的那个指针；null = 没在拖。
  int? _pointer;

  void _handleDown(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    // 鼠标只认左键：右键拖动不参与，免得跟上下文菜单打架。
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons & kPrimaryButton == 0) {
      return;
    }
    _pointer = event.pointer;
    widget.onUpdate(event.localPosition);
  }

  void _handleMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    widget.onUpdate(event.localPosition);
  }

  void _handleUp(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handleDown,
      onPointerMove: _handleMove,
      onPointerUp: _handleUp,
      onPointerCancel: _handleUp,
      child: widget.child,
    );
  }
}

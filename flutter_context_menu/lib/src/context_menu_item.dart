part of '../flutter_context_menu.dart';

// ── 单行渲染 ──────────────────────────────────────────────────────────────

/// 一个操作项：图标 / 文案 / 快捷键或子菜单箭头 / 禁用 / 危险色 / hover。
///
/// 外层面板是 [Material]，所以这里用 [InkWell] + [Ink] 而不是
/// `Container(decoration:)` —— 后者会把 Material 上的水波纹盖住。
class _ContextMenuItemView<T extends Object> extends StatefulWidget {
  const _ContextMenuItemView({
    required this.item,
    required this.index,
    required this.level,
    required this.style,
    required this.baseTextStyle,
    required this.palette,
    required this.highlighted,
    required this.reserveIconSpace,
    required this.builder,
    required this.onTap,
    required this.onHover,
  });

  final ContextMenuItem<T> item;
  final int index;
  final int level;
  final ContextMenuStyle style;
  final TextStyle baseTextStyle;
  final _ContextMenuPalette palette;
  final bool highlighted;
  final bool reserveIconSpace;
  final Widget Function(BuildContext, ContextMenuItem<T>)? builder;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  @override
  State<_ContextMenuItemView<T>> createState() =>
      _ContextMenuItemViewState<T>();
}

class _ContextMenuItemViewState<T extends Object>
    extends State<_ContextMenuItemView<T>> {
  bool _hovered = false;

  Color get _foreground {
    if (!widget.item.enabled) return widget.palette.disabled;
    return widget.item.color ??
        (widget.item.danger
            ? widget.palette.danger
            : widget.palette.foreground);
  }

  void _setHover(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    widget.onHover(value);
  }

  TextStyle _textStyle({required Color color}) {
    // 先与主题的 bodyMedium 合并（fontFamily / 字重 / 字距都跟着主题走），
    // 只把字号和前景色落到组件自己的配置上；显式传的 textStyle 字号优先。
    return widget.baseTextStyle
        .merge(widget.style.textStyle)
        .copyWith(
          fontSize: widget.style.textStyle?.fontSize ?? widget.style.fontSize,
          color: color,
        );
  }

  @override
  Widget build(BuildContext context) {
    final ContextMenuStyle style = widget.style;
    final bool selectable = widget.item.isSelectable;
    final bool active = selectable && (widget.highlighted || _hovered);

    return Semantics(
      button: true,
      enabled: selectable,
      child: InkWell(
        onTap: selectable ? widget.onTap : null,
        onHover: selectable ? _setHover : null,
        // 禁用行显式回落默认箭头：直接传 style.mouseCursor 的话，置灰的行
        // 也会顶着手型光标，看起来像能点。
        mouseCursor: selectable ? style.mouseCursor : MouseCursor.defer,
        borderRadius: BorderRadius.circular(style.itemRadius),
        // hover 高亮由下面的 Ink 统一画，避免两层颜色叠加变深。
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: widget.palette.hover,
        child: Ink(
          key: contextMenuItemKey(widget.index, widget.level),
          height: style.itemHeight,
          padding: EdgeInsets.symmetric(horizontal: style.itemPadding),
          decoration: BoxDecoration(
            color: active ? widget.palette.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(style.itemRadius),
          ),
          child:
              widget.builder?.call(context, widget.item) ??
              (widget.item.child ?? _defaultRow()),
        ),
      ),
    );
  }

  Widget _defaultRow() {
    final ContextMenuStyle style = widget.style;
    final ContextMenuItem<T> item = widget.item;

    final Widget leading;
    if (item.prefix != null) {
      leading = Padding(
        padding: EdgeInsets.only(right: style.iconGap),
        // 给自定义内容一份本行的图标主题：塞进去的 Icon 也能跟着禁用变灰、
        // danger / color 换色，尺寸默认与内置图标一致。
        child: IconTheme.merge(
          data: IconThemeData(size: style.iconSize, color: _foreground),
          child: item.prefix!,
        ),
      );
    } else if (item.icon != null) {
      leading = Padding(
        padding: EdgeInsets.only(right: style.iconGap),
        child: Icon(item.icon, size: style.iconSize, color: _foreground),
      );
    } else if (widget.reserveIconSpace) {
      leading = SizedBox(width: style.iconSize + style.iconGap);
    } else {
      leading = const SizedBox.shrink();
    }

    final Widget? trailing;
    if (item.hasChildren) {
      trailing = Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Icon(
          Icons.chevron_right,
          size: style.iconSize,
          color: item.enabled ? widget.palette.muted : widget.palette.disabled,
        ),
      );
    } else if (item.shortcut != null) {
      trailing = Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          item.shortcut!,
          style: widget.baseTextStyle
              .merge(style.shortcutTextStyle)
              .copyWith(
                fontSize:
                    style.shortcutTextStyle?.fontSize ?? style.fontSize - 1,
                color: item.enabled
                    ? widget.palette.muted
                    : widget.palette.disabled,
              ),
        ),
      );
    } else {
      trailing = null;
    }

    return Row(
      children: <Widget>[
        leading,
        Expanded(
          child: Text(
            item.label ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _textStyle(color: _foreground),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

part of '../flutter_context_menu.dart';

// ── 单行渲染 ──────────────────────────────────────────────────────────────

/// 一个操作项：图标 / 文案 / 快捷键或子菜单箭头 / 禁用 / 危险色 / hover。
///
/// 外层面板是 [Material]，所以这里用 [InkWell] + [Ink] 而不是
/// `Container(decoration:)` —— 后者会把 Material 上的水波纹盖住。
///
/// hover 高亮**不自持状态**：指针进出只回调 [onHover]，由
/// [ContextMenuPanelState] 决定哪一行是活动行（它同时管键盘导航）。行内再存
/// 一份 `_hovered` 的话，键盘高亮与指针会各亮一行；而且 items 原地刷新时
/// State 被复用，旧的高亮会留在别的行上。
class _ContextMenuItemView<T extends Object> extends StatelessWidget {
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

  Color get _foreground {
    if (!item.enabled) return palette.disabled;
    return item.color ?? (item.danger ? palette.danger : palette.foreground);
  }

  TextStyle _textStyle({required Color color}) {
    // 先与主题的 bodyMedium 合并（fontFamily / 字重 / 字距都跟着主题走），
    // 只把字号和前景色落到组件自己的配置上；显式传的 textStyle 字号优先。
    return baseTextStyle
        .merge(style.textStyle)
        .copyWith(
          fontSize: style.textStyle?.fontSize ?? style.fontSize,
          color: color,
        );
  }

  @override
  Widget build(BuildContext context) {
    final bool selectable = item.isSelectable;
    final bool active = selectable && highlighted;

    return Semantics(
      button: true,
      enabled: selectable,
      child: InkWell(
        onTap: selectable ? onTap : null,
        onHover: selectable ? onHover : null,
        // 禁用行显式回落默认箭头：直接传 style.mouseCursor 的话，置灰的行
        // 也会顶着手型光标，看起来像能点。
        mouseCursor: selectable ? style.mouseCursor : MouseCursor.defer,
        borderRadius: BorderRadius.circular(style.itemRadius),
        // hover 高亮由下面的 Ink 统一画，避免两层颜色叠加变深。
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: palette.hover,
        child: Ink(
          key: contextMenuItemKey(index, level),
          height: style.itemHeight,
          padding: EdgeInsets.symmetric(horizontal: style.itemPadding),
          decoration: BoxDecoration(
            color: active ? palette.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(style.itemRadius),
          ),
          child: builder?.call(context, item) ?? (item.child ?? _defaultRow()),
        ),
      ),
    );
  }

  Widget _defaultRow() {
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
    } else if (reserveIconSpace) {
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
          color: item.enabled ? palette.muted : palette.disabled,
        ),
      );
    } else if (item.shortcut != null) {
      trailing = Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          item.shortcut!,
          style: baseTextStyle
              .merge(style.shortcutTextStyle)
              .copyWith(
                fontSize:
                    style.shortcutTextStyle?.fontSize ?? style.fontSize - 1,
                color: item.enabled ? palette.muted : palette.disabled,
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

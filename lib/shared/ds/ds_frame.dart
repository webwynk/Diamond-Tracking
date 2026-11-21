import 'package:flutter/material.dart';

import '../../core/design/ds_colors.dart';
import '../../core/design/ds_icons.dart';
import '../../core/design/ds_layout.dart';
import '../../core/design/ds_text.dart';
import 'ds_button.dart';

/// The top of a screen (design v2, section 08): a round back button, a
/// title (24 bold) and a one-line subtitle, below the phone's notch.
class DsScreenHeader extends StatelessWidget {
  const DsScreenHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Shows the back button.
  final VoidCallback? onBack;

  /// Round buttons on the right.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DsSpace.gutter,
        MediaQuery.paddingOf(context).top + DsSpace.md,
        DsSpace.gutter,
        DsSpace.md,
      ),
      child: Row(
        children: <Widget>[
          if (onBack != null) ...<Widget>[
            DsIconButton(icon: DsIcons.back, label: 'Back', onPressed: onBack),
            const SizedBox(width: DsSpace.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DsText.title,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DsText.caption,
                  ),
              ],
            ),
          ),
          for (final Widget action in actions) ...<Widget>[
            const SizedBox(width: DsSpace.sm),
            action,
          ],
        ],
      ),
    );
  }
}

/// Shows a bottom sheet of the new design: radius 24 on top, a 40×4
/// handle, the dimmed page behind. It scrolls when it does not fit, and
/// stays above the keyboard and the phone's bottom bar.
Future<T?> showDsSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The sheet draws its own handle; the app theme's would make two.
    showDragHandle: false,
    backgroundColor: DsColors.white,
    barrierColor: DsColors.scrim,
    shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            DsSpace.xl,
            DsSpace.md,
            DsSpace.xl,
            DsSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: DsColors.line,
                    borderRadius: DsRadius.pill,
                  ),
                ),
              ),
              const SizedBox(height: DsSpace.lg),
              builder(context),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One item of the floating bottom bar.
class DsNavItem {
  const DsNavItem({required this.icon, required this.label, this.dot = false});

  final IconData icon;
  final String label;

  /// A red dot (Requests waiting).
  final bool dot;
}

/// The floating bottom bar (design v2, section 08): an ink pill; the active
/// item is white with its label, the others icon only. Every item keeps a
/// tap area of at least 48 and a spoken name. On a narrow phone, when the
/// active label would squeeze the icons under 48, it shows the white
/// highlight without the label.
class DsNavBar extends StatelessWidget {
  const DsNavBar({
    required this.items,
    required this.current,
    required this.onTap,
    super.key,
  });

  final List<DsNavItem> items;
  final int current;
  final ValueChanged<int> onTap;

  static const double _iconSlot = DsSize.tap;

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DsSpace.lg,
        0,
        DsSpace.lg,
        DsSpace.lg + bottom,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double inner = box.maxWidth - 2 * DsSpace.sm;
          final String label = items[current].label;
          final TextPainter painter = TextPainter(
            text: TextSpan(text: label, style: DsText.button),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          final double activeWidth = 16 + 20 + DsSpace.sm + painter.width + 20;
          painter.dispose();
          final bool showLabel =
              activeWidth + (items.length - 1) * _iconSlot <= inner;
          return Container(
            height: DsSize.navBar,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm),
            decoration: const BoxDecoration(
              color: DsColors.ink,
              borderRadius: DsRadius.pill,
              boxShadow: DsShadow.navBar,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (int i = 0; i < items.length; i++)
                  _item(i, showLabel && i == current),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _item(int i, bool withLabel) {
    final DsNavItem item = items[i];
    final bool on = i == current;
    return Semantics(
      button: true,
      selected: on,
      label: item.dot ? '${item.label}, new' : item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onTap(i),
        customBorder: const StadiumBorder(),
        child: Container(
          height: DsSize.tap,
          constraints: const BoxConstraints(minWidth: DsSize.tap),
          padding: EdgeInsets.only(
            left: withLabel ? 16 : 14,
            right: withLabel ? 20 : 14,
          ),
          decoration: BoxDecoration(
            color: on ? DsColors.white : Colors.transparent,
            borderRadius: DsRadius.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Icon(
                    item.icon,
                    size: 20,
                    color: on ? DsColors.deep : const Color(0xFFA7B4C6),
                  ),
                  if (item.dot)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: DsColors.unreadBadge,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: on ? DsColors.white : DsColors.ink,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (withLabel) ...<Widget>[
                const SizedBox(width: DsSpace.sm),
                Text(
                  item.label,
                  maxLines: 1,
                  style: DsText.button.copyWith(
                    color: DsColors.deep,
                    fontSize: 15,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

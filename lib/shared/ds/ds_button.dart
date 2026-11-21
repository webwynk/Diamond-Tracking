import 'package:flutter/material.dart';

import '../../core/design/ds_colors.dart';
import '../../core/design/ds_icons.dart';
import '../../core/design/ds_layout.dart';
import '../../core/design/ds_text.dart';

/// The kinds of main button (design v2, section 04).
enum DsButtonKind {
  /// The one main action of a screen: Sign in, Send, Save, Approve.
  primary,

  /// A second choice next to a primary: Keep working, Add visit.
  secondary,

  /// A neutral choice: Cancel, Close.
  outline,

  /// Ends something: Duty off, Reject, Delete user.
  danger,

  /// Risky but common: Log out, Cancel request.
  dangerSoft,

  /// White button on a deep card or header: Duty on now.
  onDeep,

  /// White button with red text on a deep card: Duty off.
  dangerOnDeep,
}

/// A main button: 56 tall, pill shaped, 16 bold.
///
/// With [onPressed] null it is disabled, and [label] should then say what is
/// missing ("Add a photo to save"), never just look grey. While [busy] it
/// shows [busyLabel] with a spinner and ignores taps, so a double tap sends
/// nothing twice.
class DsButton extends StatelessWidget {
  const DsButton({
    required this.label,
    required this.onPressed,
    this.kind = DsButtonKind.primary,
    this.arrow = false,
    this.icon,
    this.busy = false,
    this.busyLabel,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final DsButtonKind kind;

  /// The white circle with an arrow at the end, for actions that move
  /// forward (Sign in, Send). Primary buttons only.
  final bool arrow;

  /// An icon before the label.
  final IconData? icon;

  final bool busy;
  final String? busyLabel;

  /// Full width (the default) or as wide as its label.
  final bool expand;

  bool get _enabled => onPressed != null && !busy;

  ({Color bg, Color fg, Color? border, List<BoxShadow> shadow}) _look() {
    if (!_enabled && !busy) {
      return (
        bg: DsColors.disabled,
        fg: DsColors.text2,
        border: null,
        shadow: const <BoxShadow>[],
      );
    }
    return switch (kind) {
      DsButtonKind.primary => (
        bg: DsColors.primary,
        fg: DsColors.white,
        border: null,
        shadow: DsShadow.button,
      ),
      DsButtonKind.secondary => (
        bg: DsColors.primaryTint,
        fg: DsColors.primary,
        border: null,
        shadow: const <BoxShadow>[],
      ),
      DsButtonKind.outline => (
        bg: DsColors.white,
        fg: DsColors.ink,
        border: DsColors.line,
        shadow: const <BoxShadow>[],
      ),
      DsButtonKind.danger => (
        bg: DsColors.dangerText,
        fg: DsColors.white,
        border: null,
        shadow: const <BoxShadow>[],
      ),
      DsButtonKind.dangerSoft => (
        bg: DsColors.dangerTint,
        fg: DsColors.dangerText,
        border: null,
        shadow: const <BoxShadow>[],
      ),
      DsButtonKind.onDeep => (
        bg: DsColors.white,
        fg: DsColors.deep,
        border: null,
        shadow: const <BoxShadow>[],
      ),
      DsButtonKind.dangerOnDeep => (
        bg: DsColors.white,
        fg: DsColors.dangerText,
        border: null,
        shadow: const <BoxShadow>[],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg, Color? border, List<BoxShadow> shadow}) look =
        _look();
    final bool showArrow =
        arrow && kind == DsButtonKind.primary && _enabled && !busy;
    final Widget text = Text(
      busy ? (busyLabel ?? label) : label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: DsText.button.copyWith(color: look.fg),
    );
    final List<Widget> row = <Widget>[
      if (busy) ...<Widget>[
        SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: look.fg),
        ),
        const SizedBox(width: DsSpace.sm),
      ] else if (icon != null) ...<Widget>[
        Icon(icon, size: 20, color: look.fg),
        const SizedBox(width: DsSpace.sm),
      ],
      Flexible(child: text),
      if (showArrow) ...<Widget>[
        const SizedBox(width: DsSpace.md),
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: DsColors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(DsIcons.arrow, size: 20, color: DsColors.primary),
        ),
      ],
    ];
    return Semantics(
      button: true,
      enabled: _enabled,
      child: Container(
        height: DsSize.control,
        width: expand ? double.infinity : null,
        decoration: BoxDecoration(
          borderRadius: DsRadius.pill,
          boxShadow: look.shadow,
        ),
        child: Material(
          color: look.bg,
          shape: StadiumBorder(
            side: look.border == null
                ? BorderSide.none
                : BorderSide(color: look.border!),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _enabled ? onPressed : null,
            child: Padding(
              padding: EdgeInsets.only(
                left: DsSpace.xl,
                right: showArrow ? 6 : DsSpace.xl,
              ),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: showArrow
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.center,
                children: row,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small button inside rows and cards (Allow, Open, Maps). It looks 38
/// tall, but its tap area is 48 (decided 2026-11-21).
class DsSmallButton extends StatelessWidget {
  const DsSmallButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.color = DsColors.primary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Solid [color] instead of the soft tint.
  final bool filled;

  /// The solid colour when [filled]: brand blue, or red on a danger banner.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color bg = !enabled
        ? DsColors.disabled
        : (filled ? color : DsColors.primaryTint);
    final Color fg = !enabled
        ? DsColors.text2
        : (filled ? DsColors.white : DsColors.primary);
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: DsSize.tap,
            minWidth: DsSize.tap,
          ),
          child: Center(
            widthFactor: 1,
            child: Container(
              height: DsSize.smallButton,
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: DsRadius.pill),
              child: Text(
                label,
                maxLines: 1,
                style: DsText.button.copyWith(fontSize: 14, color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A text link for small extras ("Forgot password?", "See all"). 14 bold,
/// primary, with a 48 tap area.
class DsTextLink extends StatelessWidget {
  const DsTextLink({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: InkWell(
        onTap: onPressed,
        borderRadius: DsRadius.medium,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: DsSize.tap),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: onPressed == null
                    ? DsText.link.copyWith(color: DsColors.text3)
                    : DsText.link,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round icon button (design v2): 46 white circle (back, bell), 54 primary
/// circle (add), or a glass circle on a deep header. Always has a spoken
/// [label]. An optional red [badge] shows an unread count.
class DsIconButton extends StatelessWidget {
  const DsIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.kind = DsIconButtonKind.white,
    this.badge = 0,
    super.key,
  });

  final IconData icon;

  /// What it does, read out by screen readers ("Back", "Notifications").
  final String label;
  final VoidCallback? onPressed;
  final DsIconButtonKind kind;

  /// Unread count; 0 shows no badge, over 9 shows "9+".
  final int badge;

  @override
  Widget build(BuildContext context) {
    final double size = kind == DsIconButtonKind.add ? 54 : 46;
    final (Color bg, Color fg) = switch (kind) {
      DsIconButtonKind.white => (DsColors.white, DsColors.ink),
      DsIconButtonKind.add => (DsColors.primary, DsColors.white),
      DsIconButtonKind.glass => (const Color(0x1FFFFFFF), DsColors.white),
    };
    return Semantics(
      button: true,
      label: badge > 0 ? '$label, $badge unread' : label,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: Material(
                color: bg,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: Icon(icon, size: 22, color: fg),
                ),
              ),
            ),
            if (badge > 0)
              Positioned(top: -2, right: -2, child: DsCountBadge(count: badge)),
          ],
        ),
      ),
    );
  }
}

enum DsIconButtonKind { white, add, glass }

/// A small round count: red for unread, amber for "waiting for you".
class DsCountBadge extends StatelessWidget {
  const DsCountBadge({required this.count, this.waiting = false, super.key});

  final int count;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: waiting ? DsColors.warningDot : DsColors.unreadBadge,
        borderRadius: DsRadius.pill,
        border: Border.all(color: DsColors.white, width: 2),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: DsText.micro.copyWith(
          color: waiting ? DsColors.ink : DsColors.white,
          height: 1,
        ),
      ),
    );
  }
}

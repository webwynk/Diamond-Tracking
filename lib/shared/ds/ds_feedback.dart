import 'package:flutter/material.dart';

import '../../core/design/ds_colors.dart';
import '../../core/design/ds_icons.dart';
import '../../core/design/ds_layout.dart';
import '../../core/design/ds_text.dart';
import 'ds_button.dart';

/// The kinds of banner (design v2, section 07).
enum DsBannerKind { warning, danger, info, success, offline }

/// A banner across the screen: a status tint with an icon, a bold title and
/// a line of text, and an optional action button. The offline banner is
/// dark slate with an amber icon.
class DsBanner extends StatelessWidget {
  const DsBanner({
    required this.kind,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final DsBannerKind kind;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color iconColor, IconData icon) = switch (kind) {
      DsBannerKind.warning => (
        DsColors.warningTint,
        DsColors.warningText,
        DsColors.warningText,
        DsIcons.warning,
      ),
      DsBannerKind.danger => (
        DsColors.dangerTint,
        DsColors.dangerText,
        DsColors.dangerText,
        DsIcons.error,
      ),
      DsBannerKind.info => (
        DsColors.primaryTint,
        DsColors.primary,
        DsColors.primary,
        DsIcons.info,
      ),
      DsBannerKind.success => (
        DsColors.successTint,
        DsColors.successText,
        DsColors.successText,
        DsIcons.check,
      ),
      DsBannerKind.offline => (
        DsColors.slate,
        DsColors.white,
        DsColors.warningDot,
        DsIcons.offline,
      ),
    };
    final Color bodyColor = kind == DsBannerKind.offline
        ? DsColors.skyText
        : DsColors.ink;
    return Semantics(
      container: true,
      liveRegion: kind == DsBannerKind.danger,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: DsRadius.medium),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: DsText.body.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontVariations: const <FontVariation>[
                        FontVariation('wght', 700),
                      ],
                    ),
                  ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        message!,
                        style: DsText.caption.copyWith(color: bodyColor),
                      ),
                    ),
                  if (actionLabel != null && onAction != null)
                    Padding(
                      padding: const EdgeInsets.only(top: DsSpace.xs),
                      child: DsSmallButton(
                        label: actionLabel!,
                        onPressed: onAction,
                        filled: true,
                        color: kind == DsBannerKind.danger
                            ? DsColors.dangerDot
                            : DsColors.primary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nothing to show yet ("No requests yet"): a round icon, a title, a line
/// of text and an optional action.
class DsEmptyState extends StatelessWidget {
  const DsEmptyState({
    required this.title,
    this.message,
    this.icon = DsIcons.empty,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpace.xl,
        vertical: DsSpace.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: DsColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: DsColors.primary),
          ),
          const SizedBox(height: DsSpace.lg),
          Text(title, textAlign: TextAlign.center, style: DsText.section),
          if (message != null) ...<Widget>[
            const SizedBox(height: DsSpace.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: DsText.body.copyWith(color: DsColors.text2),
            ),
          ],
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: DsSpace.lg),
            DsButton(
              label: actionLabel!,
              onPressed: onAction,
              kind: DsButtonKind.secondary,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}

/// Something could not load: the message and a Try again button.
class DsErrorState extends StatelessWidget {
  const DsErrorState({
    required this.message,
    required this.onRetry,
    this.title = 'Could not load',
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DsEmptyState(
      title: title,
      message: message,
      icon: DsIcons.error,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import 'app_badge.dart';

/// Colour treatment of an [AppTopBar].
enum AppTopBarStyle {
  /// Solid brand colour. For the main tab screens.
  brand,

  /// White with a 1 px bottom border. For every screen opened from a tab.
  surface,
}

/// The icon shown in the leading slot of an [AppTopBar].
enum AppTopBarLeading {
  /// Nothing. Title starts at the 16 dp gutter.
  none,

  /// Back arrow. Defaults to popping the current route.
  back,

  /// Close cross, for forms and modal flows. Defaults to popping the route.
  close,
}

/// The one top app bar used by every screen.
///
/// Fixed [AppSizes.appBarHeight] below the status bar, one title style
/// ([AppTypography.h3]), one icon size and one spacing, so screens cannot drift
/// apart. Tab screens use [AppTopBarStyle.brand]; screens opened from a tab use
/// [AppTopBarStyle.surface] with a [AppTopBarLeading.back] or
/// [AppTopBarLeading.close] button.
///
/// Icon buttons and text buttons placed in [actions] pick up the foreground
/// colour from the bar style, so callers never pass colours.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    required this.title,
    super.key,
    this.subtitle,
    this.titleTrailing,
    this.style = AppTopBarStyle.surface,
    this.leading = AppTopBarLeading.none,
    this.leadingKey,
    this.onLeadingPressed,
    this.leadingWidget,
    this.actions = const <Widget>[],
  }) : assert(
         leadingWidget == null || leading == AppTopBarLeading.none,
         'Use either a leading button or a leadingWidget, not both.',
       );

  final String title;

  /// Optional second line under the title.
  final String? subtitle;

  /// Optional widget after the title, such as a count pill.
  final Widget? titleTrailing;

  final AppTopBarStyle style;
  final AppTopBarLeading leading;

  /// Key for the leading back or close button.
  final Key? leadingKey;

  /// Overrides the default "pop the route" behaviour of [leading].
  final VoidCallback? onLeadingPressed;

  /// Non-interactive or custom leading content, such as an avatar.
  final Widget? leadingWidget;

  /// Trailing controls: [IconButton], [TextButton], [AppTopBarIconButton] or
  /// [AppTopBarProfileButton].
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final isBrand = style == AppTopBarStyle.brand;
    final titleColor = isBrand ? AppColors.neutral0 : AppColors.textPrimary;
    final subtitleColor = isBrand
        ? AppColors.neutral0.withValues(alpha: 0.8)
        : AppColors.textSecondary;
    final iconColor = isBrand ? AppColors.neutral0 : AppColors.neutral700;
    final accentColor = isBrand ? AppColors.neutral0 : AppColors.primary600;
    final disabledColor = isBrand
        ? AppColors.neutral0.withValues(alpha: 0.5)
        : AppColors.neutral400;

    final hasLeadingButton = leading != AppTopBarLeading.none;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isBrand ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isBrand ? AppColors.primary600 : AppColors.surface,
          border: isBrand
              ? null
              : const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: AppSizes.appBarHeight,
            child: IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: iconColor,
                  disabledForegroundColor: disabledColor,
                ),
              ),
              child: TextButtonTheme(
                data: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    disabledForegroundColor: disabledColor,
                    textStyle: AppTypography.label.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: hasLeadingButton ? AppSpacing.x1 : AppSpacing.x4,
                    ),
                    if (hasLeadingButton)
                      IconButton(
                        key: leadingKey,
                        icon: Icon(
                          leading == AppTopBarLeading.back
                              ? Icons.arrow_back_rounded
                              : Icons.close_rounded,
                        ),
                        tooltip: leading == AppTopBarLeading.back
                            ? 'Back'
                            : 'Close',
                        onPressed:
                            onLeadingPressed ??
                            () => Navigator.of(context).maybePop(),
                      ),
                    if (hasLeadingButton) const SizedBox(width: AppSpacing.x1),
                    if (leadingWidget != null) ...<Widget>[
                      leadingWidget!,
                      const SizedBox(width: AppSpacing.x3),
                    ],
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Flexible(
                            // The bar is a fixed height, so its title and subtitle
                            // grow with the user's text size only up to 120%.
                            child: MediaQuery.withClampedTextScaling(
                              maxScaleFactor: 1.2,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.h3.copyWith(
                                      color: titleColor,
                                    ),
                                  ),
                                  if (subtitle != null)
                                    Text(
                                      subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                        color: subtitleColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (titleTrailing != null) ...<Widget>[
                            const SizedBox(width: AppSpacing.x2),
                            titleTrailing!,
                          ],
                        ],
                      ),
                    ),
                    ...actions,
                    const SizedBox(width: AppSpacing.x1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An [IconButton] for an [AppTopBar] with an optional count badge or dot.
///
/// The icon colour comes from the surrounding bar. Pass [key] to identify the
/// whole control in tests.
class AppTopBarIconButton extends StatelessWidget {
  const AppTopBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
    this.badgeCount = 0,
    this.badgeColor = AppColors.error,
    this.badgeTextColor = AppColors.neutral0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Shows a count badge when greater than zero.
  final int badgeCount;
  final Color badgeColor;
  final Color badgeTextColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: <Widget>[
        IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed),
        if (badgeCount > 0)
          Positioned(
            top: 4,
            right: 2,
            child: IgnorePointer(
              child: AppBadge.count(
                badgeCount,
                backgroundColor: badgeColor,
                textColor: badgeTextColor,
              ),
            ),
          ),
      ],
    );
  }
}

/// Circular profile button for the trailing end of an [AppTopBar].
class AppTopBarProfileButton extends StatelessWidget {
  const AppTopBarProfileButton({
    required this.onPressed,
    super.key,
    this.tooltip = 'My profile',
  });

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 32,
      padding: const EdgeInsets.all(AppSpacing.x2),
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary500,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.person_rounded,
          size: 18,
          color: AppColors.neutral0,
        ),
      ),
    );
  }
}

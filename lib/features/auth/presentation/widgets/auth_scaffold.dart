import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

/// The frame for the signed-out screens: brand band on top, form below.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Shows a back button in the band when set.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              color: AppColors.primary600,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x2,
                    AppSpacing.x2,
                    AppSpacing.x2,
                    AppSpacing.x8,
                  ),
                  child: Column(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          height: AppSizes.minTouchTarget,
                          child: onBack == null
                              ? null
                              : IconButton(
                                  tooltip: 'Back',
                                  color: AppColors.neutral0,
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  onPressed: onBack,
                                ),
                        ),
                      ),
                      Image.asset(
                        'assets/image/white-logo.png',
                        width: 140,
                        semanticLabel: 'Diamond Agritech',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x5,
                    AppSpacing.x6,
                    AppSpacing.x5,
                    AppSpacing.x8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(title, style: AppTypography.h1),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.x1),
                        Text(
                          subtitle!,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.x6),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

/// Pattern 5: Full-Screen / Card Load Failure.
///
/// Prominently communicates network or data loading failures with a clear retry
/// mechanism and secondary navigation fallback.
class LoadFailureCard extends StatefulWidget {
  const LoadFailureCard({
    super.key,
    required this.onRetry,
    this.onGoBack,
    this.title = "Couldn't load this",
    this.message = 'Check your connection and try again.',
  });

  final VoidCallback onRetry;
  final VoidCallback? onGoBack;
  final String title;
  final String message;

  @override
  State<LoadFailureCard> createState() => _LoadFailureCardState();
}

class _LoadFailureCardState extends State<LoadFailureCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _handleRetry() {
    _rotationController.forward(from: 0.0);
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('card-load-failure'),
      constraints: const BoxConstraints(minHeight: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // 64x64 dp Error Badge
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.errorBg,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.cloud_off,
                size: 32,
                color: AppColors.error,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.x4),

          // Title
          Text(
            widget.title,
            style: AppTypography.title.copyWith(
              color: AppColors.neutral900,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 4),

          // Subtitle (max width 220 dp)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              widget.message,
              style: AppTypography.caption.copyWith(
                color: AppColors.neutral500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: AppSpacing.x5),

          // 44 dp Brand Primary "Retry" Button
          SizedBox(
            height: 44,
            child: ElevatedButton(
              key: const Key('btn-load-failure-retry'),
              onPressed: _handleRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary600,
                foregroundColor: AppColors.surface,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  RotationTransition(
                    turns: _rotationController,
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: AppColors.surface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Retry',
                    style: AppTypography.label.copyWith(
                      color: AppColors.surface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (widget.onGoBack != null) ...<Widget>[
            const SizedBox(height: 8),
            TextButton(
              key: const Key('btn-load-failure-back'),
              onPressed: widget.onGoBack,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                'Go back',
                style: AppTypography.label.copyWith(
                  color: AppColors.neutral500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

/// Section 6: Next-Page Loader with scroll anchor architectural callout.
///
/// RULE (Design System 8): Pagination uses a 24 dp spinner, never a skeleton,
/// preserving scroll anchor without layout jump during field data sync.
class PaginationLoaderCard extends StatelessWidget {
  const PaginationLoaderCard({
    super.key,
    this.showCalloutNote = true,
    this.isSpinning = true,
  });

  final bool showCalloutNote;
  final bool isSpinning;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('skeleton-pagination-loader-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 56 dp Next-Page Spinner Card
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: isSpinning
                  ? const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary600),
                    )
                  : const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      value: 0.75,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary600),
                    ),
            ),
          ),
        ),

        // Architectural Note Banner
        if (showCalloutNote) ...<Widget>[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.anchor,
                    size: 16,
                    color: AppColors.neutral500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral600,
                        fontSize: 11,
                        height: 1.4,
                      ),
                      children: const <TextSpan>[
                        TextSpan(
                          text: 'NOTE: ',
                          style: TextStyle(
                            color: AppColors.neutral900,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextSpan(
                          text:
                              'Pagination uses a 24px spinner, never a skeleton, preserving scroll anchor without layout jump during field data sync.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

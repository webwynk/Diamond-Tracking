import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_reports_state.dart';

/// Panel B: Report Ready Download & Share View for Screen 26.
class AdminReportsReadyView extends StatelessWidget {
  const AdminReportsReadyView({
    super.key,
    required this.state,
    required this.onShare,
    required this.onSaveToDevice,
  });

  final AdminReportsState state;
  final VoidCallback onShare;
  final VoidCallback onSaveToDevice;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // 1. Top Progress Strip Banner
        _buildProgressStrip(),

        // 2. Centered Content Viewport
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            child: Column(
              children: <Widget>[
                const SizedBox(height: AppSpacing.x6),

                // 72px Circular #DCFCE7 Badge with Green Check
                _buildSuccessBadge(),
                const SizedBox(height: AppSpacing.x4),

                // H3 20px Report Ready Title
                Text(
                  'Report ready',
                  textAlign: TextAlign.center,
                  style: AppTypography.h3.copyWith(
                    color: AppColors.neutral900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  state.readySubtitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.neutral500,
                  ),
                ),
                const SizedBox(height: AppSpacing.x6),

                // Generated File Card
                _buildFileCard(),
                const SizedBox(height: AppSpacing.x6),

                // Action Buttons Stack
                _buildActionButtons(),
                const SizedBox(height: AppSpacing.x6),

                // Audit Log Notice at Bottom
                Text(
                  'This export has been recorded in the audit log.',
                  key: const Key('text-audit-notice'),
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral400,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressStrip() {
    return Container(
      key: const Key('reports-progress-banner'),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.neutral200, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        10,
        AppSpacing.x4,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 4px Track filled to 100% in Green (#16A34A)
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.neutral200,
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.centerLeft,
            child: Container(
              width: double.infinity,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  'Completed in ${state.generationDurationSeconds}s',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral500,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Text(
                'READY TO EXPORT',
                style: AppTypography.overline.copyWith(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBadge() {
    return Container(
      key: const Key('badge-report-ready-check'),
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.successBg,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.successBg.withValues(alpha: 0.6),
          width: 6,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.check_rounded,
        color: AppColors.success,
        size: 38,
      ),
    );
  }

  Widget _buildFileCard() {
    final isPdf = state.reportFormat == ReportFormat.pdf;

    return Container(
      key: const Key('card-generated-file'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral200, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Row(
        children: <Widget>[
          // Badge Holding PDF / Excel Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isPdf ? AppColors.errorBg : AppColors.successBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(
              isPdf
                  ? Icons.picture_as_pdf_rounded
                  : Icons.table_chart_rounded,
              color: isPdf ? AppColors.error : AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // File Title & Metrics
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  state.generatedFileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    color: AppColors.neutral900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.readyFileMetrics,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Verified Green Badge
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: <Widget>[
        // Primary 48px Button: Share
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('btn-share-report'),
            onPressed: onShare,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: AppColors.neutral0,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: Text(
              'Share',
              style: AppTypography.label.copyWith(
                color: AppColors.neutral0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x3),

        // Secondary 48px Outlined Button: Save to device
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            key: const Key('btn-download-report'),
            onPressed: onSaveToDevice,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary600,
              side: const BorderSide(color: AppColors.primary600, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: Text(
              'Save to device',
              style: AppTypography.label.copyWith(
                color: AppColors.primary600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

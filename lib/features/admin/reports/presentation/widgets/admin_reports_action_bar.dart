import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../controllers/admin_reports_state.dart';

/// The pinned bar under the builder. It is the Generate button, then the
/// progress while the report is built, then the finished report with Share and
/// Print, or what went wrong with a retry.
class AdminReportsActionBar extends StatelessWidget {
  const AdminReportsActionBar({
    super.key,
    required this.state,
    required this.onGenerate,
    required this.onShare,
    required this.onPrint,
  });

  final AdminReportsState state;
  final VoidCallback onGenerate;
  final VoidCallback onShare;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.neutral200)),
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (state.phase == ReportPhase.ready && result != null)
              _ResultCard(result: result, onShare: onShare, onPrint: onPrint)
            else ...[
              if (state.phase == ReportPhase.failed &&
                  state.errorMessage != null)
                _ErrorNote(message: state.errorMessage!),
              if (state.isWorking && state.stage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                  child: Text(
                    state.stage!,
                    key: const Key('text-generate-stage'),
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else if (!state.isWorking && state.blocker != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                  child: Text(
                    state.blocker!,
                    key: const Key('text-generate-blocker'),
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              AppButton(
                key: const Key('btn-generate-report'),
                label: state.phase == ReportPhase.failed
                    ? 'Try again'
                    : 'Generate report',
                loadingLabel: 'Preparing report…',
                isLoading: state.isWorking,
                isFullWidth: true,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                onPressed: state.canGenerate ? onGenerate : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('text-report-error'),
      margin: const EdgeInsets.only(bottom: AppSpacing.x3),
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.errorText),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.onShare,
    required this.onPrint,
  });

  final GeneratedReport result;
  final VoidCallback onShare;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('report-result-card'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (result.truncated)
          Container(
            key: const Key('text-report-truncated'),
            margin: const EdgeInsets.only(bottom: AppSpacing.x3),
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              'Incomplete: this period holds more duty records than one report '
              'can include. Choose a shorter period for the full picture.',
              style: AppTypography.caption.copyWith(
                color: AppColors.warningText,
              ),
            ),
          ),
        Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: AppColors.primary600,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Report ready',
                        style: AppTypography.label.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    result.fileName,
                    key: const Key('text-report-file-name'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'PDF · ${result.sizeLabel}',
                    key: const Key('text-report-size'),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        Row(
          children: <Widget>[
            Expanded(
              child: AppButton(
                key: const Key('btn-share-report'),
                label: 'Share',
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                isFullWidth: true,
                onPressed: onShare,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: AppButton(
                key: const Key('btn-print-report'),
                label: 'Print',
                variant: AppButtonVariant.secondary,
                icon: const Icon(Icons.print_outlined, size: 20),
                isFullWidth: true,
                onPressed: onPrint,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import 'empty_state_card.dart';
import 'empty_state_type.dart';

/// Screen 28 — Empty States Reference Sheet.
///
/// Comprehensive reference matrix of default, filter, and error-adjacent
/// empty view states across agritech field tracking workflows.
class EmptyStatesReferencePage extends StatelessWidget {
  const EmptyStatesReferencePage({
    super.key,
    this.onAddEmployee,
    this.onViewTeam,
    this.onClearFilters,
    this.onPickDate,
    this.onViewSummary,
  });

  final VoidCallback? onAddEmployee;
  final VoidCallback? onViewTeam;
  final VoidCallback? onClearFilters;
  final VoidCallback? onPickDate;
  final VoidCallback? onViewSummary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Empty States Subsystem',
          style: AppTypography.title.copyWith(
            color: AppColors.neutral900,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.neutral200,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x8,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1024),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // 1. Top System Specification Header
                _buildSystemHeader(context),

                const SizedBox(height: AppSpacing.x10),

                // 2. 2x3 Reference Matrix
                _buildMatrixGrid(context),

                const SizedBox(height: AppSpacing.x12),

                // 3. Technical Specification Telemetry Strip
                _buildTelemetryFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemHeader(BuildContext context) {
    return Column(
      children: <Widget>[
        // System Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.neutral200),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                color: AppColors.primary600,
              ),
              const SizedBox(width: 8),
              Text(
                'DIAMOND AGRITECH · UI SYSTEM SPECIFICATION',
                style: AppTypography.overline.copyWith(
                  color: AppColors.neutral600,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.x3),

        // Main Title
        Text(
          'Screen 28 — Empty States Reference Sheet',
          style: AppTypography.h2.copyWith(
            color: AppColors.neutral900,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.x2),

        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Text(
            'Comprehensive reference matrix of default, filter, and error-adjacent empty view states across field tracking workflows.',
            style: AppTypography.body.copyWith(
              color: AppColors.neutral600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: AppSpacing.x4),

        // Telemetry Calibration Badges
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Matrix Mode: Android Telemetry v3.4',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral600,
                  ),
                ),
              ],
            ),
            const Text('/', style: TextStyle(color: AppColors.neutral400)),
            Text(
              'Canvas Scale: 1:1 Reference Target',
              style: AppTypography.caption.copyWith(
                color: AppColors.neutral600,
              ),
            ),
            const Text('/', style: TextStyle(color: AppColors.neutral400)),
            Text(
              '6 Scenarios Calibrated',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMatrixGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = <Widget>[
          EmptyStateCard(
            key: const Key('card-empty-state-noEmployees'),
            type: EmptyStateType.noEmployees,
            onActionPressed: onAddEmployee ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Triggered: Add employee')),
                  );
                },
          ),
          EmptyStateCard(
            key: const Key('card-empty-state-nobodyOnDuty'),
            type: EmptyStateType.nobodyOnDuty,
            onActionPressed: onViewTeam ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Triggered: View team')),
                  );
                },
          ),
          const EmptyStateCard(
            key: Key('card-empty-state-noNotifications'),
            type: EmptyStateType.noNotifications,
          ),
          EmptyStateCard(
            key: const Key('card-empty-state-filteredToNothing'),
            type: EmptyStateType.filteredToNothing,
            onActionPressed: onClearFilters ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Triggered: Clear filters')),
                  );
                },
          ),
          EmptyStateCard(
            key: const Key('card-empty-state-noRoute'),
            type: EmptyStateType.noRoute,
            onActionPressed: onPickDate ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Triggered: Pick another date')),
                  );
                },
          ),
          EmptyStateCard(
            key: const Key('card-empty-state-routeExpired'),
            type: EmptyStateType.routeExpired,
            onActionPressed: onViewSummary ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Triggered: View summary')),
                  );
                },
          ),
        ];

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 32,
          runSpacing: 40,
          children: cards,
        );
      },
    );
  }

  Widget _buildTelemetryFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: AppSpacing.x6),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.neutral200, width: 1),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: <Widget>[
          // Left Title
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                color: AppColors.primary600,
              ),
              const SizedBox(width: 8),
              Text(
                'Field Telemetry Standards · Empty States Subsystem',
                style: AppTypography.overline.copyWith(
                  color: AppColors.neutral900,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  fontSize: 10,
                ),
              ),
            ],
          ),

          // Right Specs
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: <Widget>[
              _buildSpecChip('Corner Radius', '16px'),
              _buildSpecChip('Illustration Size', '56×56px'),
              _buildSpecChip('Button Height', '36px'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$label: ',
          style: AppTypography.caption.copyWith(
            color: AppColors.neutral500,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.neutral200,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            value,
            style: AppTypography.caption.copyWith(
              color: AppColors.neutral900,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

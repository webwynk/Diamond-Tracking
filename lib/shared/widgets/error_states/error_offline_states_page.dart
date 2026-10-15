import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import 'widgets/floating_undo_snackbar.dart';
import 'widgets/gps_blocking_banner.dart';
import 'widgets/inline_field_error.dart';
import 'widgets/load_failure_card.dart';
import 'widgets/offline_info_banner.dart';
import 'widgets/realtime_disconnected_strip.dart';
import 'widgets/sync_pending_banner.dart';

/// Screen 29: Error and Offline States Specification Sheet.
///
/// Complete catalog of telemetry and connectivity exception patterns
/// calibrated for frontline field hardware.
class ErrorOfflineStatesPage extends StatefulWidget {
  const ErrorOfflineStatesPage({
    super.key,
    this.onSyncDetailsPressed,
    this.onGpsSettingsPressed,
    this.onRetryPressed,
    this.onGoBackPressed,
    this.onUndoPressed,
    this.isRealtimeSpinning = true,
  });

  final VoidCallback? onSyncDetailsPressed;
  final VoidCallback? onGpsSettingsPressed;
  final VoidCallback? onRetryPressed;
  final VoidCallback? onGoBackPressed;
  final VoidCallback? onUndoPressed;
  final bool isRealtimeSpinning;

  @override
  State<ErrorOfflineStatesPage> createState() => _ErrorOfflineStatesPageState();
}

class _ErrorOfflineStatesPageState extends State<ErrorOfflineStatesPage> {
  int _activeNavIndex = 1; // 1 = States (active by default per design)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: AppColors.primary600,
          elevation: 1,
          automaticallyImplyLeading: false,
          title: Row(
            children: <Widget>[
              const Icon(
                Icons.token_outlined,
                size: 22,
                color: AppColors.primary100,
              ),
              const SizedBox(width: AppSpacing.x2),
              Text(
                'Error & Offline States',
                style: AppTypography.h3.copyWith(
                  color: AppColors.surface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x4),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primary500,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 18,
                  color: AppColors.surface,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x6,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 1. Specification Sheet Header Section
                _buildSheetHeader(),

                const SizedBox(height: AppSpacing.x6),

                // 2. Pattern 1: OFFLINE BANNER (INFO)
                _buildSectionHeader('OFFLINE BANNER (INFO, NOT AN ERROR)'),
                const OfflineInfoBanner(),

                const SizedBox(height: AppSpacing.x6),

                // 3. Pattern 2: SYNC PENDING
                _buildSectionHeader('SYNC PENDING'),
                SyncPendingBanner(
                  onDetails: widget.onSyncDetailsPressed ??
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Triggered: Sync pending details'),
                          ),
                        );
                      },
                ),

                const SizedBox(height: AppSpacing.x6),

                // 4. Pattern 3: GPS OFF (BLOCKING)
                _buildSectionHeader('GPS OFF (BLOCKING)'),
                GpsBlockingBanner(
                  onOpenSettings: widget.onGpsSettingsPressed ??
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Triggered: Open GPS settings'),
                          ),
                        );
                      },
                ),

                const SizedBox(height: AppSpacing.x6),

                // 5. Pattern 4: INLINE FIELD ERROR
                _buildSectionHeader('INLINE FIELD ERROR'),
                const InlineFieldError(),

                const SizedBox(height: AppSpacing.x6),

                // 6. Pattern 5: FULL-SCREEN LOAD FAILURE
                _buildSectionHeader('FULL-SCREEN LOAD FAILURE'),
                LoadFailureCard(
                  onRetry: widget.onRetryPressed ??
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Triggered: Retry load')),
                        );
                      },
                  onGoBack: widget.onGoBackPressed ??
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Triggered: Go back')),
                        );
                      },
                ),

                const SizedBox(height: AppSpacing.x6),

                // 7. Pattern 6: REALTIME DISCONNECTED
                _buildSectionHeader('REALTIME DISCONNECTED'),
                RealtimeDisconnectedStrip(
                  isSpinning: widget.isRealtimeSpinning,
                ),

                const SizedBox(height: AppSpacing.x6),

                // 8. Pattern 7: SNACKBAR
                _buildSectionHeader('SNACKBAR'),
                FloatingUndoSnackbar(
                  onUndo: widget.onUndoPressed ??
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Triggered: Undo action')),
                        );
                      },
                ),

                const SizedBox(height: AppSpacing.x10),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildSheetHeader() {
    return Container(
      padding: const EdgeInsets.only(bottom: AppSpacing.x6),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.neutral200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'SPECIFICATION SHEET 29',
                style: AppTypography.overline.copyWith(
                  color: AppColors.neutral500,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary600,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'DIAMOND AGRITECH',
                style: AppTypography.overline.copyWith(
                  color: AppColors.info,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Error & Offline States',
            style: AppTypography.h2.copyWith(
              color: AppColors.neutral900,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Telemetry and connectivity exception patterns for frontline field hardware.',
            style: AppTypography.body.copyWith(
              color: AppColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Text(
        title,
        style: AppTypography.overline.copyWith(
          color: AppColors.neutral400,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final navItems = <(IconData, String)>[
      (Icons.description_outlined, 'Specs'),
      (Icons.cloud_off_outlined, 'States'),
      (Icons.sensors_outlined, 'Telemetry'),
      (Icons.terminal_outlined, 'Logs'),
    ];

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.neutral200, width: 1),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: navItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isActive = _activeNavIndex == index;

          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeNavIndex = index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    item.$1,
                    size: 22,
                    color:
                        isActive ? AppColors.primary600 : AppColors.neutral500,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$2.toUpperCase(),
                    style: AppTypography.overline.copyWith(
                      color: isActive
                          ? AppColors.primary600
                          : AppColors.neutral500,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

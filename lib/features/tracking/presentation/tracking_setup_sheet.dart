import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../application/tracker_control.dart';
import '../application/tracker_providers.dart';

/// Shows what the phone must allow before duty on. Returns true when every
/// required item is allowed.
Future<bool> showTrackingSetup(BuildContext context) async {
  final bool? ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => const TrackingSetupSheet(),
  );
  return ok ?? false;
}

class TrackingSetupSheet extends ConsumerStatefulWidget {
  const TrackingSetupSheet({super.key});

  @override
  ConsumerState<TrackingSetupSheet> createState() => _TrackingSetupSheetState();
}

class _TrackingSetupSheetState extends ConsumerState<TrackingSetupSheet> {
  late final AppLifecycleListener _lifecycle;
  List<TrackerRequirement>? _missing;
  bool _asking = false;

  TrackerControl get _tracker => ref.read(trackerControlProvider);

  @override
  void initState() {
    super.initState();
    // Coming back from a settings page: check again.
    _lifecycle = AppLifecycleListener(onResume: _check);
    _check();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final List<TrackerRequirement> missing = await _tracker
        .missingRequirements();
    if (mounted) setState(() => _missing = missing);
  }

  Future<void> _ask(TrackerRequirement r) async {
    setState(() => _asking = true);
    try {
      await _tracker.request(r);
    } finally {
      if (mounted) setState(() => _asking = false);
    }
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final List<TrackerRequirement>? missing = _missing;
    final bool ready =
        missing != null && !missing.any((TrackerRequirement r) => r.required);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            0,
            AppSpacing.x4,
            AppSpacing.x4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Before duty on', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.x1),
              Text(
                'Your route is recorded only while you are on duty. The phone '
                'must allow these:',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              if (missing == null)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.x6),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                for (final TrackerRequirement r in TrackerRequirement.values)
                  _RequirementRow(
                    requirement: r,
                    done: !missing.contains(r),
                    onAllow: _asking ? null : () => _ask(r),
                  ),
              const SizedBox(height: AppSpacing.x4),
              AppButton(
                label: 'Continue',
                isFullWidth: true,
                onPressed: ready ? () => Navigator.pop(context, true) : null,
                disabledReason: 'Allow the items above first',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.requirement,
    required this.done,
    required this.onAllow,
  });

  final TrackerRequirement requirement;
  final bool done;
  final VoidCallback? onAllow;

  @override
  Widget build(BuildContext context) {
    final (String title, String why) = requirementText(requirement);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done ? AppColors.success : AppColors.neutral400,
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  requirement.required ? title : '$title (recommended)',
                  style: AppTypography.title,
                ),
                const SizedBox(height: 2),
                Text(
                  why,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!done) ...<Widget>[
            const SizedBox(width: AppSpacing.x2),
            TextButton(onPressed: onAllow, child: const Text('Allow')),
          ],
        ],
      ),
    );
  }
}

/// Title and reason shown for a requirement.
(String, String) requirementText(TrackerRequirement r) => switch (r) {
  TrackerRequirement.locationService => (
    'Turn on location',
    'GPS must be on to record your route.',
  ),
  TrackerRequirement.locationPermission => (
    'Allow location',
    'Needed to record your route while you are on duty.',
  ),
  TrackerRequirement.backgroundLocation => (
    'Allow location all the time',
    'Choose "Allow all the time", so recording starts again by itself if '
        'the phone restarts.',
  ),
  TrackerRequirement.notifications => (
    'Allow notifications',
    'Shows that you are on duty, and warns you when the battery is low.',
  ),
  TrackerRequirement.batteryOptimization => (
    'Stop battery saver closing the app',
    'Some phones stop apps in the background to save battery.',
  ),
};

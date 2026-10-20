import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Full-width 48 dp outlined button: "Clear device binding", with one line that
/// says whether a phone is registered. The line is left out when that is not
/// known, and the button is off when it is known that no phone is registered.
class AdminEmployeeClearDeviceButton extends StatelessWidget {
  const AdminEmployeeClearDeviceButton({
    super.key,
    required this.deviceRegistered,
    required this.onPressed,
  });

  /// Null when it is not known.
  final bool? deviceRegistered;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = deviceRegistered != false;
    final color = enabled ? AppColors.primary600 : AppColors.neutral400;
    final caption = switch (deviceRegistered) {
      true => 'A phone is registered to this employee.',
      false =>
        'No phone is registered yet. The first phone they sign in on will be '
            'registered.',
      null => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            key: const Key('btn-employee-clear-device'),
            onPressed: enabled ? onPressed : null,
            icon: Icon(Icons.phonelink_erase_rounded, color: color, size: 20),
            label: Text(
              'Clear device binding',
              style: AppTypography.label.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color, width: 1.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
        if (caption != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x1),
          Text(
            caption,
            key: const Key('clear-device-caption'),
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: AppColors.neutral500),
          ),
        ],
      ],
    );
  }
}

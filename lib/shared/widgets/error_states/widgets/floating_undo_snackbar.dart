import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

/// Pattern 7: Dark Floating Snackbar.
///
/// Enterprise snackbar pattern featuring dark neutral container, severity indicator,
/// and contextual undo action.
class FloatingUndoSnackbar extends StatefulWidget {
  const FloatingUndoSnackbar({
    super.key,
    this.message = 'Employee blocked',
    this.actionLabel = 'UNDO',
    this.onUndo,
  });

  final String message;
  final String actionLabel;
  final VoidCallback? onUndo;

  @override
  State<FloatingUndoSnackbar> createState() => _FloatingUndoSnackbarState();
}

class _FloatingUndoSnackbarState extends State<FloatingUndoSnackbar> {
  bool _isRestored = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleUndo() {
    setState(() => _isRestored = true);
    widget.onUndo?.call();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _isRestored = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('widget-undo-snackbar'),
      height: 56,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.neutral800,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Left: Status Dot & Message
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isRestored ? AppColors.success : AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Text(
                _isRestored ? 'Action restored' : widget.message,
                style: AppTypography.body.copyWith(
                  color: AppColors.surface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Right: Action Button
          TextButton(
            key: const Key('btn-snackbar-undo'),
            onPressed: _handleUndo,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
            child: Text(
              _isRestored ? 'RESTORED' : widget.actionLabel,
              style: AppTypography.label.copyWith(
                color: _isRestored ? AppColors.success : AppColors.primary400,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

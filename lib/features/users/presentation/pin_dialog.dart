import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';

/// How long a copied PIN stays on the clipboard (L78).
const Duration pinClipboardTime = Duration(minutes: 1);

/// Copies [text], then clears the clipboard after [pinClipboardTime] unless
/// something else was copied since.
Future<void> copyForAMinute(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  Timer(pinClipboardTime, () async {
    try {
      final ClipboardData? now = await Clipboard.getData(Clipboard.kTextPlain);
      if (now?.text == text) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } on Object {
      // The clipboard could not be read; leave it.
    }
  });
}

/// Shows the user ID and temporary PIN once, for the admin to pass on.
Future<void> showPinDialog(
  BuildContext context, {
  required String title,
  required String userCode,
  required String pin,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Give these to the user. They will choose their own password when '
            'they sign in. The PIN is not shown again.',
          ),
          const SizedBox(height: AppSpacing.x4),
          _Line(label: 'User ID', value: userCode),
          const SizedBox(height: AppSpacing.x2),
          _Line(label: 'Temporary PIN', value: pin),
        ],
      ),
      actions: <Widget>[
        TextButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy'),
          onPressed: () async {
            await copyForAMinute('User ID: $userCode\nTemporary PIN: $pin');
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Copied')));
            }
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: const BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppTypography.caption),
          SelectableText(
            value,
            style: AppTypography.h2.copyWith(letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }
}

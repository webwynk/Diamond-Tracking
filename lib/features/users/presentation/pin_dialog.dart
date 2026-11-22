import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_button.dart';

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

/// "User created" (design v2): shows the user ID and the temporary PIN
/// once, with Copy and Done. It cannot be swiped away, so the PIN is not
/// lost by accident.
Future<void> showPinDialog(
  BuildContext context, {
  required String title,
  required String userCode,
  required String pin,
  String message =
      'Give these to the user. On first sign-in they choose their own '
      'password.',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: DsColors.white,
    barrierColor: DsColors.scrim,
    shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
    builder: (BuildContext context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: _PinSheet(
          title: title,
          message: message,
          userCode: userCode,
          pin: pin,
        ),
      ),
    ),
  );
}

class _PinSheet extends StatelessWidget {
  const _PinSheet({
    required this.title,
    required this.message,
    required this.userCode,
    required this.pin,
  });

  final String title;
  final String message;
  final String userCode;
  final String pin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFCBD5E1),
              borderRadius: DsRadius.pill,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: DsStatus.present.tint,
              shape: BoxShape.circle,
            ),
            child: Icon(DsIcons.check, size: 32, color: DsStatus.present.text),
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(title, textAlign: TextAlign.center, style: DsText.title),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: DsText.body.copyWith(color: DsColors.text2, height: 1.45),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: DsRadius.large,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(DsSpace.lg),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFEEF2F6))),
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      'User ID',
                      style: DsText.body.copyWith(color: DsColors.text2),
                    ),
                    const SizedBox(width: DsSpace.md),
                    Expanded(
                      child: SelectableText(
                        userCode,
                        textAlign: TextAlign.right,
                        style: DsText.section,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DsSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Temporary PIN',
                      style: DsText.body.copyWith(color: DsColors.text2),
                    ),
                    const SizedBox(height: 10),
                    PinBoxes(pin: pin, height: 52, big: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: DsColors.warningTint,
            borderRadius: DsRadius.medium,
          ),
          child: Row(
            children: <Widget>[
              const Icon(DsIcons.lock, size: 18, color: DsColors.warningText),
              const SizedBox(width: DsSpace.sm),
              Expanded(
                child: Text(
                  'This PIN is shown only once. Copy it now.',
                  style: DsText.label.copyWith(
                    color: DsColors.warningText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: DsButton(
                label: 'Copy',
                icon: DsIcons.copy,
                kind: DsButtonKind.outline,
                onPressed: () async {
                  await copyForAMinute(
                    'User ID: $userCode\nTemporary PIN: $pin',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Copied')));
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DsButton(
                label: 'Done',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A 6-digit PIN as six boxes, read out digit by digit.
class PinBoxes extends StatelessWidget {
  const PinBoxes({
    required this.pin,
    this.height = 50,
    this.big = false,
    this.boxColour = DsColors.primaryTint,
    super.key,
  });

  final String pin;
  final double height;
  final bool big;
  final Color boxColour;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Temporary PIN ${pin.split('').join(' ')}',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < pin.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: boxColour,
                  borderRadius: DsRadius.medium,
                ),
                child: Text(
                  pin[i],
                  style: (big ? DsText.title : DsText.section).copyWith(
                    color: DsColors.deep,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

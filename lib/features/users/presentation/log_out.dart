import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_frame.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../../notifications/application/notifications_providers.dart';
import '../../tracking/application/tracker_control.dart';
import '../../tracking/application/tracker_providers.dart';
import '../../visits/application/visits_providers.dart';
import '../../visits/data/visit_outbox.dart';

/// Log out, after the safety checks: duty must be off and its route sent,
/// and visits kept on the phone must reach the server first. Then asks
/// once, stops push to this phone, signs out and clears the phone's files.
Future<void> logOut(BuildContext context, WidgetRef ref) async {
  final TrackerControl tracker = ref.read(trackerControlProvider);
  if (await tracker.hasUnsentWork()) {
    if (!context.mounted) return;
    await _notYet(
      context,
      'Do duty off first. If you already did, your route is still being '
      'sent: connect to the internet and try again in a minute.',
    );
    return;
  }
  final AuthStatus status = ref.read(authStatusProvider);
  final VisitOutbox outbox = ref.read(visitOutboxProvider);
  if (status is SignedIn &&
      (await outbox.pending(userId: status.userId)).isNotEmpty) {
    if (!context.mounted) return;
    await _notYet(
      context,
      'Some visits are still on this phone. Connect to the internet and '
      'open Home to send them, then try again.',
    );
    return;
  }
  if (!context.mounted) return;
  final bool ok = await showDsConfirm(
    context: context,
    title: 'Log out?',
    message:
        'You will need your user ID and password to sign in again. Log out '
        'here before you sign in on another phone.',
    confirm: 'Log out',
    keep: 'Stay signed in',
  );
  if (!ok) return;
  await ref.read(authStatusProvider.notifier).signOutWith(() async {
    // While still signed in: this phone stops getting the account's pushes.
    await ref.read(pushRegistrarProvider).clear();
    await ref.read(authRepositoryProvider).signOut();
    await tracker.clear();
    await outbox.clear();
  });
}

Future<void> _notYet(BuildContext context, String why) => showDsSheet<void>(
  context: context,
  builder: (BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const Text('Not yet', style: DsText.title),
      const SizedBox(height: DsSpace.xs),
      Text(why, style: DsText.body.copyWith(color: DsColors.text2)),
      const SizedBox(height: DsSpace.xl),
      DsButton(label: 'OK', onPressed: () => Navigator.pop(context)),
    ],
  ),
);

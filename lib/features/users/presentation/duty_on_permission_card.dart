import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_log.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../application/users_providers.dart';
import '../domain/profile.dart';

/// Why allowing or taking back duty on failed, in plain words.
String dutyPermitProblem(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is AuthRetryableFetchException) {
    return 'No internet. Try again.';
  }
  final String text = error is PostgrestException
      ? error.message
      : error.toString();
  if (text.contains('day_already_recorded')) {
    return 'This person already has a record for today (duty, leave or '
        'absent), so duty on cannot be allowed again.';
  }
  if (text.contains('too_late')) {
    return 'It is after 9:00 PM. A duty started now would be too short to '
        'count, so duty on can no longer be allowed today.';
  }
  if (text.contains('user_not_found')) {
    return 'Only an active employee can be allowed.';
  }
  return 'Something went wrong. Try again.';
}

/// On an employee's edit screen: let them do duty on today outside the
/// 5:00 to 8:30 AM window, once.
class DutyOnPermissionCard extends ConsumerStatefulWidget {
  const DutyOnPermissionCard({required this.user, super.key});

  final Profile user;

  @override
  ConsumerState<DutyOnPermissionCard> createState() =>
      _DutyOnPermissionCardState();
}

class _DutyOnPermissionCardState extends ConsumerState<DutyOnPermissionCard> {
  bool _busy = false;
  String? _error;

  Future<void> _allow() async {
    final String? note = await showDialog<String>(
      context: context,
      builder: (BuildContext context) =>
          _AllowDialog(name: widget.user.fullName),
    );
    if (note == null) return;
    await _run(
      () => ref
          .read(usersRepositoryProvider)
          .allowDutyOn(widget.user.id, note: note),
      'Duty on allowed. ${widget.user.fullName} was told.',
    );
  }

  Future<void> _revoke() => _run(
    () => ref.read(usersRepositoryProvider).revokeDutyOn(widget.user.id),
    'Permission taken back.',
  );

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(dutyOnAllowedProvider(widget.user.id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(done)));
      }
    } on Object catch (e, s) {
      AppLog.failure('duty on permission', e, s);
      if (mounted) setState(() => _error = dutyPermitProblem(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<bool> allowed = ref.watch(
      dutyOnAllowedProvider(widget.user.id),
    );
    final bool isAllowed = allowed.value ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Duty on today', style: AppTypography.title),
        const SizedBox(height: AppSpacing.x1),
        Text(
          allowed.hasError
              ? 'Could not check. Pull to reload this screen.'
              : isAllowed
              ? 'Allowed for today, until 9:00 PM. Not used yet.'
              : 'Normally only 5:00 to 8:30 AM. You can allow one duty on '
                    'today outside those times, until 9:00 PM.',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        if (_error case final String e) ...<Widget>[
          const SizedBox(height: AppSpacing.x2),
          Text(
            e,
            style: AppTypography.caption.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.x2),
        if (isAllowed)
          AppButton(
            label: 'Take back permission',
            variant: AppButtonVariant.secondary,
            icon: const Icon(Icons.block_rounded, size: 18),
            isFullWidth: true,
            isLoading: _busy,
            onPressed: _revoke,
          )
        else
          AppButton(
            label: 'Allow duty on today',
            variant: AppButtonVariant.secondary,
            icon: const Icon(Icons.verified_user_rounded, size: 18),
            isFullWidth: true,
            isLoading: _busy,
            onPressed: allowed.isLoading ? null : _allow,
          ),
      ],
    );
  }
}

/// Asks for an optional note. Pops with the note, or null on cancel. It owns
/// its text controller so the controller outlives the closing animation.
class _AllowDialog extends StatefulWidget {
  const _AllowDialog({required this.name});

  final String name;

  @override
  State<_AllowDialog> createState() => _AllowDialogState();
}

class _AllowDialogState extends State<_AllowDialog> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Allow duty on for ${widget.name}?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Today only, once, until 9:00 PM. They get a notification and can '
          'then press Duty on at any time until 9:00 PM.',
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: _note,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'Why',
          ),
        ),
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _note.text),
        child: const Text('Allow'),
      ),
    ],
  );
}

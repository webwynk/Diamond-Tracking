import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/logging/app_log.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_field.dart';
import '../../../shared/ds/ds_frame.dart';
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

/// On an employee's profile: let them do duty on today outside the 5:00 to
/// 8:30 AM window, once (design v2, "Allow late duty on"). Greyed out when
/// they already have a record for today ([dayRecorded]).
class DutyOnPermissionRow extends ConsumerStatefulWidget {
  const DutyOnPermissionRow({
    required this.user,
    required this.dayRecorded,
    super.key,
  });

  final Profile user;

  /// Today already has a duty, leave or absent: nothing to allow.
  final bool dayRecorded;

  @override
  ConsumerState<DutyOnPermissionRow> createState() =>
      _DutyOnPermissionRowState();
}

class _DutyOnPermissionRowState extends ConsumerState<DutyOnPermissionRow> {
  bool _busy = false;
  String? _error;

  Future<void> _allow() async {
    final String? note = await showDsSheet<String>(
      context: context,
      builder: (_) => _AllowSheet(name: widget.user.fullName),
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
    final bool off = widget.dayRecorded && !isAllowed;
    final String help = widget.dayRecorded && !isAllowed
        ? 'Not needed, today is already recorded'
        : allowed.hasError
        ? 'Could not check. Pull down to reload.'
        : isAllowed
        ? 'Allowed for today, until 9:00 PM. Not used yet.'
        : 'Today only, until 9:00 PM';
    return Opacity(
      opacity: off ? 0.55 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2F6),
                  borderRadius: DsRadius.medium,
                ),
                child: const Icon(
                  DsIcons.dutyOn,
                  size: 18,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(width: DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Allow late duty on',
                      style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(help, style: DsText.caption),
                  ],
                ),
              ),
              if (!off) ...<Widget>[
                const SizedBox(width: DsSpace.sm),
                SmallOutlineButton(
                  label: isAllowed ? 'Take back' : 'Allow',
                  busy: _busy,
                  onPressed: allowed.isLoading
                      ? null
                      : isAllowed
                      ? _revoke
                      : _allow,
                ),
              ],
            ],
          ),
          if (_error case final String e) ...<Widget>[
            const SizedBox(height: DsSpace.sm),
            Text(e, style: DsText.caption.copyWith(color: DsColors.dangerText)),
          ],
        ],
      ),
    );
  }
}

/// A small white pill with a grey border, for an action on a row
/// ("Release phone", "Allow").
class SmallOutlineButton extends StatelessWidget {
  const SmallOutlineButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null && !busy,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: DsColors.white,
      shape: const StadiumBorder(side: BorderSide(color: Color(0xFFCBD5E1))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onPressed,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  label,
                  maxLines: 1,
                  style: DsText.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: onPressed == null ? DsColors.text3 : DsColors.ink,
                  ),
                ),
        ),
      ),
    ),
  );
}

/// Asks for an optional note. Pops with the note, or null on cancel. It owns
/// its text controller so the controller outlives the closing animation.
class _AllowSheet extends StatefulWidget {
  const _AllowSheet({required this.name});

  final String name;

  @override
  State<_AllowSheet> createState() => _AllowSheetState();
}

class _AllowSheetState extends State<_AllowSheet> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text('Allow duty on for ${widget.name}?', style: DsText.title),
      const SizedBox(height: DsSpace.xs),
      Text(
        'Today only, once, until 9:00 PM. They get a notification and can '
        'then press Duty on at any time until 9:00 PM.',
        style: DsText.body.copyWith(color: DsColors.text2),
      ),
      const SizedBox(height: DsSpace.lg),
      DsTextField(
        label: 'Note',
        optional: true,
        hint: 'Why',
        controller: _note,
        maxLength: 300,
      ),
      const SizedBox(height: DsSpace.lg),
      DsButton(
        label: 'Allow',
        onPressed: () => Navigator.pop(context, _note.text),
      ),
      const SizedBox(height: 6),
      Center(
        child: DsTextLink(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
      ),
    ],
  );
}

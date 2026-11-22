import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_chips.dart';
import '../../../shared/ds/ds_field.dart';
import '../../../shared/ds/ds_frame.dart';
import '../../duty/domain/duty_day.dart';
import '../../requests/application/requests_providers.dart';
import '../../requests/domain/app_request.dart';
import '../../requests/domain/request_failure.dart';
import '../application/route_providers.dart';

/// The statuses an admin can give a day, with the leave type for leave.
enum DayChoice {
  present('Present', DayStatus.present, null),
  halfDay('Half day', DayStatus.halfDay, null),
  absent('Absent', DayStatus.absent, null),
  sick('Sick leave', DayStatus.leave, LeaveType.sick),
  casual('Casual leave', DayStatus.leave, LeaveType.casual);

  const DayChoice(this.label, this.status, this.leave);

  final String label;
  final DayStatus status;
  final LeaveType? leave;

  /// The choice that matches [day] now, if any (not for on duty/waiting).
  static DayChoice? of(DutyDay day) => switch (day.status) {
    DayStatus.present => present,
    DayStatus.halfDay => halfDay,
    DayStatus.absent => absent,
    DayStatus.leave => day.leaveType == LeaveType.sick ? sick : casual,
    DayStatus.onDuty || DayStatus.pending => null,
  };
}

/// Admin: "Change day status" for one person's day. Answers true when the
/// day was changed.
Future<bool> showChangeDayStatus(BuildContext context, DutyDay day) async =>
    await showDsSheet<bool>(
      context: context,
      builder: (_) => _ChangeDayStatus(day: day),
    ) ??
    false;

class _ChangeDayStatus extends ConsumerStatefulWidget {
  const _ChangeDayStatus({required this.day});

  final DutyDay day;

  @override
  ConsumerState<_ChangeDayStatus> createState() => _ChangeDayStatusState();
}

class _ChangeDayStatusState extends ConsumerState<_ChangeDayStatus> {
  final TextEditingController _note = TextEditingController();
  late DayChoice? _choice = DayChoice.of(widget.day);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final DayChoice? c = _choice;
    final String? userId = widget.day.userId;
    if (c == null || userId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(requestsRepositoryProvider)
          .setDayStatus(
            userId,
            widget.day.day,
            c.status,
            leave: c.leave,
            note: _note.text,
          );
      ref
        ..invalidate(dayViewProvider(widget.day.id))
        ..invalidate(historyProvider(userId))
        ..invalidate(todayDaysProvider)
        ..invalidate(adminRequestsProvider);
      if (!mounted) return;
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(SnackBar(content: Text('Saved: ${c.label}.')));
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = mapRequestError(e).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DayChoice? now = DayChoice.of(widget.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: const Text('Change day status', style: DsText.title),
        ),
        const SizedBox(height: DsSpace.xs),
        Text(
          '${IstFormat.weekdayDay(widget.day.day)} · now '
          '${now?.label ?? widget.day.status.label}',
          style: DsText.body.copyWith(color: DsColors.text2),
        ),
        const SizedBox(height: DsSpace.lg),
        Wrap(
          spacing: DsSpace.sm,
          runSpacing: DsSpace.sm,
          children: <Widget>[
            for (final DayChoice c in DayChoice.values)
              DsFilterChip(
                label: c.label,
                selected: c == _choice,
                onTap: () {
                  if (!_busy) setState(() => _choice = c);
                },
              ),
          ],
        ),
        const SizedBox(height: DsSpace.lg),
        DsTextField(
          label: 'Note',
          optional: true,
          controller: _note,
          hint: 'Why it changed, e.g. manager confirmed',
          maxLines: 3,
          maxLength: 300,
        ),
        if (_error case final String e) ...<Widget>[
          const SizedBox(height: DsSpace.sm),
          Text(e, style: DsText.body.copyWith(color: DsColors.dangerText)),
        ],
        const SizedBox(height: DsSpace.lg),
        DsButton(
          label: 'Save',
          busy: _busy,
          busyLabel: 'Saving…',
          onPressed: _choice == null || _choice == now ? null : _save,
        ),
        const SizedBox(height: DsSpace.xs),
        const Text(
          'The change is saved with your name.',
          textAlign: TextAlign.center,
          style: DsText.caption,
        ),
      ],
    );
  }
}

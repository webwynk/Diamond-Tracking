import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/form_message.dart';
import '../application/requests_providers.dart';
import '../data/requests_repository.dart';
import '../domain/app_request.dart';
import '../domain/request_failure.dart';
import 'photo_field.dart';

/// Ask for sick or casual leave on one or more dates, with an optional proof.
class LeaveRequestPage extends ConsumerStatefulWidget {
  const LeaveRequestPage({super.key});

  @override
  ConsumerState<LeaveRequestPage> createState() => _LeaveRequestPageState();
}

class _LeaveRequestPageState extends ConsumerState<LeaveRequestPage> {
  final TextEditingController _message = TextEditingController();
  LeaveType _type = LeaveType.casual;
  final Set<DateTime> _dates = <DateTime>{};
  Uint8List? _proof;

  /// Set once the proof is uploaded, so a retry does not upload it again
  /// (L68). Cleared when the photo changes.
  String? _proofId;
  bool _busy = false;
  String? _error;

  static const int maxDays = 31;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  DateTime get _today => Ist.dateOf(ref.read(serverClockProvider).now());

  Future<void> _addDates() async {
    final DateTime t = _today;
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(t.year, t.month, t.day - 7),
      lastDate: DateTime(t.year, t.month, t.day + 90),
      helpText: 'Leave dates',
      saveText: 'Add',
    );
    if (range == null) return;
    setState(() {
      for (
        DateTime d = DateTime.utc(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        !d.isAfter(
          DateTime.utc(range.end.year, range.end.month, range.end.day),
        );
        d = d.add(const Duration(days: 1))
      ) {
        _dates.add(d);
      }
      _error = _dates.length > maxDays
          ? 'At most $maxDays days in one request.'
          : null;
    });
  }

  Future<void> _submit() async {
    final String? problem = _dates.isEmpty
        ? 'Add the leave dates.'
        : _dates.length > maxDays
        ? 'At most $maxDays days in one request.'
        : _message.text.trim().isEmpty
        ? 'Write a message.'
        : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final RequestsRepository repo = ref.read(requestsRepositoryProvider);
      final String? proofId = _proof == null
          ? null
          : _proofId ??= await repo.uploadPhoto(_proof!);
      await repo.requestLeave(
        type: _type,
        dates: _sorted,
        message: _message.text.trim(),
        proofId: proofId,
      );
      if (!mounted) return;
      refreshRequests(ref);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Leave request sent.')));
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) setState(() => _error = mapRequestError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<DateTime> get _sorted => _dates.toList()..sort();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave request')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: <Widget>[
            SegmentedButton<LeaveType>(
              segments: <ButtonSegment<LeaveType>>[
                for (final LeaveType t in LeaveType.values)
                  ButtonSegment<LeaveType>(value: t, label: Text(t.label)),
              ],
              selected: <LeaveType>{_type},
              onSelectionChanged: _busy
                  ? null
                  : (Set<LeaveType> s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: AppSpacing.x4),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _dates.isEmpty
                        ? 'Dates'
                        : 'Dates (${_dates.length} '
                              '${_dates.length == 1 ? 'day' : 'days'})',
                    style: AppTypography.label,
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _addDates,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add dates'),
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x2,
              children: <Widget>[
                for (final DateTime d in _sorted)
                  InputChip(
                    label: Text(IstFormat.date(d)),
                    onDeleted: _busy
                        ? null
                        : () => setState(() => _dates.remove(d)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x4),
            TextField(
              controller: _message,
              enabled: !_busy,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Reason for the leave',
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            PhotoField(
              label: 'Proof (optional), for example a doctor\'s note',
              photo: _proof,
              enabled: !_busy,
              onChanged: (Uint8List? p) => setState(() {
                _proof = p;
                _proofId = null;
              }),
            ),
            if (_error case final String e) ...<Widget>[
              const SizedBox(height: AppSpacing.x4),
              FormMessage.error(e),
            ],
            const SizedBox(height: AppSpacing.x4),
            AppButton(
              label: 'Send request',
              isFullWidth: true,
              isLoading: _busy,
              loadingLabel: 'Sending…',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

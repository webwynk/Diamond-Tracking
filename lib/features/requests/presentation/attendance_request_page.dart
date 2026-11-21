import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/form_message.dart';
import '../application/requests_providers.dart';
import '../data/requests_repository.dart';
import '../domain/request_failure.dart';
import 'photo_field.dart';

/// Forgot duty on: ask for attendance with the times worked, a message and a
/// photo. Today or up to 7 days back.
class AttendanceRequestPage extends ConsumerStatefulWidget {
  const AttendanceRequestPage({super.key});

  @override
  ConsumerState<AttendanceRequestPage> createState() =>
      _AttendanceRequestPageState();
}

class _AttendanceRequestPageState extends ConsumerState<AttendanceRequestPage> {
  final TextEditingController _message = TextEditingController();
  late DateTime _day; // IST date
  int? _on; // minutes since midnight
  int? _off;
  Uint8List? _photo;

  /// Set once the photo is uploaded, so a retry does not upload it again
  /// (L68). Cleared when the photo changes.
  String? _photoId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _day = Ist.dateOf(ref.read(serverClockProvider).now());
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  DateTime get _today => Ist.dateOf(ref.read(serverClockProvider).now());

  Future<void> _pickDay() async {
    final DateTime t = _today;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_day.year, _day.month, _day.day),
      firstDate: DateTime(t.year, t.month, t.day - 7),
      lastDate: DateTime(t.year, t.month, t.day),
      helpText: 'Day you worked',
    );
    if (picked != null) {
      setState(
        () => _day = DateTime.utc(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _pickTime({required bool on}) async {
    final int? current = on ? _on : _off;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay(hour: on ? 9 : 19, minute: 0)
          : TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: on ? 'Duty on time' : 'Duty off time',
    );
    if (picked == null) return;
    setState(() {
      if (on) {
        _on = picked.hour * 60 + picked.minute;
      } else {
        _off = picked.hour * 60 + picked.minute;
      }
    });
  }

  String? _check() {
    if (_on == null || _off == null) {
      return 'Pick the duty on and duty off times.';
    }
    if (_off! <= _on!) return 'Duty off must be after duty on.';
    final DateTime now = ref.read(serverClockProvider).now();
    if (_day == _today && _off! > Ist.minuteOfDay(now)) {
      return 'Duty off cannot be later than now.';
    }
    if (_message.text.trim().isEmpty) return 'Write a message.';
    if (_photo == null) return 'Add a photo.';
    return null;
  }

  Future<void> _submit() async {
    final String? problem = _check();
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
      final String photoId = _photoId ??= await repo.uploadPhoto(_photo!);
      await repo.requestAttendance(
        day: _day,
        dutyOnMinute: _on!,
        dutyOffMinute: _off!,
        message: _message.text.trim(),
        photoId: photoId,
      );
      if (!mounted) return;
      refreshRequests(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent. The admin will decide.')),
      );
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) setState(() => _error = mapRequestError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _time(int? m) {
    if (m == null) return 'Pick';
    final DateTime t = DateTime.utc(2000, 1, 1, m ~/ 60, m % 60);
    return IstFormat.time(t.subtract(Ist.offset));
  }

  @override
  Widget build(BuildContext context) {
    final Widget form = ListView(
      padding: const EdgeInsets.all(AppSpacing.x4),
      children: <Widget>[
        const Text(
          'Forgot to do duty on? Ask the admin to count the day. You can ask '
          'for today or the last 7 days.',
        ),
        const SizedBox(height: AppSpacing.x4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today_rounded),
          title: const Text('Date'),
          trailing: Text(IstFormat.date(_day)),
          onTap: _busy ? null : _pickDay,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.login_rounded),
          title: const Text('Duty on'),
          trailing: Text(_time(_on)),
          onTap: _busy ? null : () => _pickTime(on: true),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout_rounded),
          title: const Text('Duty off'),
          trailing: Text(_time(_off)),
          onTap: _busy ? null : () => _pickTime(on: false),
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: _message,
          enabled: !_busy,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Message',
            hintText: 'Why there was no duty on, and what you did that day',
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        PhotoField(
          label: 'Photo (required)',
          photo: _photo,
          enabled: !_busy,
          onChanged: (Uint8List? p) => setState(() {
            _photo = p;
            _photoId = null;
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
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Request attendance')),
      body: SafeArea(child: form),
    );
  }
}

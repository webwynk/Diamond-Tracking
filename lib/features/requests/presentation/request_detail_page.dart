import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/time/ist.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/form_message.dart';
import '../../duty/domain/duty_day.dart';
import '../../users/application/users_providers.dart';
import '../../users/domain/profile.dart';
import '../application/requests_providers.dart';
import '../domain/app_request.dart';
import '../domain/request_failure.dart';
import 'request_widgets.dart';

/// One request. The admin decides it here; the employee can cancel it while
/// it waits.
class RequestDetailPage extends ConsumerStatefulWidget {
  const RequestDetailPage({
    required this.requestId,
    required this.admin,
    super.key,
  });

  final int requestId;
  final bool admin;

  @override
  ConsumerState<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends ConsumerState<RequestDetailPage> {
  final TextEditingController _note = TextEditingController();
  DayStatus? _busyWith;
  bool _cancelling = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decide(AppRequest r, DayStatus d) async {
    setState(() {
      _busyWith = d;
      _error = null;
    });
    try {
      await ref.read(requestsRepositoryProvider).decide(r.id, d, _note.text);
      if (!mounted) return;
      refreshRequests(ref, r.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: ${decisionLabel(r.kind, d)}.')),
      );
    } on Object catch (e) {
      if (mounted) setState(() => _error = mapRequestError(e).message);
      refreshRequests(ref, r.id);
    } finally {
      if (mounted) setState(() => _busyWith = null);
    }
  }

  Future<void> _cancel(AppRequest r) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Cancel this request?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    setState(() {
      _cancelling = true;
      _error = null;
    });
    try {
      await ref.read(requestsRepositoryProvider).cancel(r.id);
      if (mounted) refreshRequests(ref, r.id);
    } on Object catch (e) {
      if (mounted) setState(() => _error = mapRequestError(e).message);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppRequest?> req = ref.watch(
      requestProvider(widget.requestId),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Request')),
      body: req.when(
        skipLoadingOnRefresh: true,
        data: (AppRequest? r) => r == null
            ? const Center(child: Text('This request was not found.'))
            : _body(r),
        error: (_, _) => AppErrorView(
          onRetry: () => ref.invalidate(requestProvider(widget.requestId)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _body(AppRequest r) {
    final String? person = widget.admin
        ? ref
              .watch(usersListProvider)
              .value
              ?.where((Profile p) => p.id == r.userId)
              .firstOrNull
              ?.fullName
        : null;
    final bool busy = _busyWith != null || _cancelling;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.x4),
      children: <Widget>[
        if (person != null) Text(person, style: AppTypography.h3),
        Row(
          children: <Widget>[
            Expanded(child: Text(requestTitle(r), style: AppTypography.title)),
            RequestStatusPill(request: r),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        ..._facts(r),
        if (r.kind == RequestKind.shortDuty && r.day != null) _shortDay(r),
        if (r.message case final String m) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          const Text('Message', style: AppTypography.label),
          const SizedBox(height: AppSpacing.x1),
          Text(m, style: AppTypography.bodyLarge),
        ],
        if (r.hasPhoto) ...<Widget>[
          const SizedBox(height: AppSpacing.x4),
          Text(
            r.kind == RequestKind.leave ? 'Proof' : 'Photo',
            style: AppTypography.label,
          ),
          const SizedBox(height: AppSpacing.x2),
          if (r.photoRemoved)
            Text(
              'Photo removed after 90 days.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            RequestPhoto(requestId: r.id),
        ],
        if (!r.isPending) ...<Widget>[
          const SizedBox(height: AppSpacing.x4),
          _fact('Decision', requestOutcome(r)),
          if (r.decidedAt case final DateTime t)
            _fact(
              'Decided',
              '${IstFormat.date(Ist.dateOf(t))}, ${IstFormat.time(t)}',
            ),
          if (r.decisionNote case final String n) _fact('Admin note', n),
        ],
        if (_error case final String e) ...<Widget>[
          const SizedBox(height: AppSpacing.x4),
          FormMessage.error(e),
        ],
        if (widget.admin && r.isPending) ...<Widget>[
          const SizedBox(height: AppSpacing.x4),
          TextField(
            controller: _note,
            enabled: !busy,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Note to the employee (optional)',
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          for (final DayStatus d in r.choices) ...<Widget>[
            AppButton(
              label: decisionLabel(r.kind, d),
              isFullWidth: true,
              variant: d == DayStatus.absent
                  ? AppButtonVariant.destructive
                  : d == r.choices.first
                  ? AppButtonVariant.primary
                  : AppButtonVariant.secondary,
              isLoading: _busyWith == d,
              onPressed: busy ? null : () => _decide(r, d),
            ),
            const SizedBox(height: AppSpacing.x2),
          ],
        ],
        if (!widget.admin && r.cancellable) ...<Widget>[
          const SizedBox(height: AppSpacing.x4),
          AppButton(
            label: 'Cancel request',
            isFullWidth: true,
            variant: AppButtonVariant.secondary,
            isLoading: _cancelling,
            onPressed: busy ? null : () => _cancel(r),
          ),
        ],
      ],
    );
  }

  List<Widget> _facts(AppRequest r) => <Widget>[
    _fact(
      'Sent',
      '${IstFormat.date(Ist.dateOf(r.createdAt))}, ${IstFormat.time(r.createdAt)}',
    ),
    if (r.dutyOnAt case final DateTime on)
      _fact(
        'Worked',
        '${IstFormat.time(on)} to ${IstFormat.time(r.dutyOffAt!)} '
            '(${IstFormat.duration(r.dutyOffAt!.difference(on))})',
      ),
    if (r.kind == RequestKind.leave)
      _fact('Dates', r.dates.map(IstFormat.date).join(', ')),
  ];

  Widget _shortDay(AppRequest r) {
    final DutyDay? d = ref.watch(requestDayProvider((r.userId, r.day!))).value;
    if (d == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (d.dutyOnAt != null && d.dutyOffAt != null)
          _fact(
            'Worked',
            '${IstFormat.time(d.dutyOnAt!)} to ${IstFormat.time(d.dutyOffAt!)} '
                '(${IstFormat.duration(Duration(minutes: d.workedMinutes ?? 0))})',
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.push(
              widget.admin ? Routes.adminDay(d.id) : Routes.userDay(d.id),
            ),
            icon: const Icon(Icons.route_rounded),
            label: const Text('View route'),
          ),
        ),
      ],
    );
  }

  static Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.x2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(child: Text(value, style: AppTypography.body)),
      ],
    ),
  );
}

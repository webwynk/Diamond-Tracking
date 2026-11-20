import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_status_pill.dart';
import '../../duty/domain/duty_day.dart';
import '../../users/presentation/account_button.dart';
import '../application/reports_providers.dart';
import '../data/report_pdf.dart';
import '../domain/report.dart';

enum _Preset { thisMonth, lastMonth, custom }

/// Attendance, duty time, km and visits for a date range, everyone or one
/// person, with a PDF to share.
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  late ReportRange _range;
  _Preset _preset = _Preset.thisMonth;
  String? _person; // null: everyone
  StatusFilter _filter = StatusFilter.all;
  bool _makingPdf = false;

  DateTime get _today => Ist.dateOf(ref.read(serverClockProvider).now());

  @override
  void initState() {
    super.initState();
    _range = ReportRange.month(_today);
  }

  void _setPreset(_Preset p) {
    final DateTime t = _today;
    if (p == _Preset.custom) {
      _pickRange();
      return;
    }
    setState(() {
      _preset = p;
      _range = ReportRange.month(
        p == _Preset.thisMonth ? t : DateTime.utc(t.year, t.month - 1),
      );
    });
  }

  Future<void> _pickRange() async {
    final DateTime t = _today;
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(t.year - 1, t.month, t.day),
      lastDate: DateTime(t.year, t.month, t.day + 90),
      initialDateRange: DateTimeRange(
        start: DateTime(_range.from.year, _range.from.month, _range.from.day),
        end: DateTime(_range.to.year, _range.to.month, _range.to.day),
      ),
      helpText: 'Report dates',
    );
    if (picked == null || !mounted) return;
    final ReportRange r = ReportRange(
      DateTime.utc(picked.start.year, picked.start.month, picked.start.day),
      DateTime.utc(picked.end.year, picked.end.month, picked.end.day),
    );
    if (r.days > maxReportDays) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick up to $maxReportDays days (about 3 months).'),
        ),
      );
      return;
    }
    setState(() {
      _preset = _Preset.custom;
      _range = r;
    });
  }

  List<PersonReport> _shown(List<PersonReport> all) => _person == null
      ? all
      : all.where((PersonReport p) => p.userId == _person).toList();

  Future<void> _pdf(List<PersonReport> people) async {
    final bool? detail = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.table_rows_rounded),
              title: const Text('Summary'),
              subtitle: const Text('One line per person'),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_month_rounded),
              title: const Text('Summary and every day'),
              subtitle: Text(
                'Each person\'s days, with duty times and km '
                '(${_filter.label.toLowerCase()})',
              ),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (detail == null || !mounted) return;
    setState(() => _makingPdf = true);
    try {
      final Uint8List bytes = await buildReportPdf(
        range: _range,
        people: people,
        filter: _filter,
        detail: detail,
        madeAt: ref.read(serverClockProvider).now(),
      );
      await ref.read(pdfSharerProvider).share(bytes, reportFileName(_range));
    } on Object catch (e, s) {
      AppLog.failure('report pdf', e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The PDF could not be made. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _makingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PersonReport>> report = ref.watch(
      reportProvider(_range),
    );
    final List<PersonReport>? data = report.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: <Widget>[
          if (_makingPdf)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.x4),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Download PDF',
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: data == null ? null : () => _pdf(_shown(data)),
            ),
          const AccountButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(reportProvider(_range).future),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.x2,
              children: <Widget>[
                for (final (_Preset p, String label) in <(_Preset, String)>[
                  (_Preset.thisMonth, 'This month'),
                  (_Preset.lastMonth, 'Last month'),
                  (_Preset.custom, 'Pick dates'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _preset == p,
                    onSelected: (_) => _setPreset(p),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              '${IstFormat.date(_range.from)} to ${IstFormat.date(_range.to)}',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            if (data != null)
              DropdownButtonFormField<String?>(
                key: ValueKey<String?>('person-$_person'),
                initialValue: data.any((PersonReport p) => p.userId == _person)
                    ? _person
                    : null,
                decoration: const InputDecoration(labelText: 'Person'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(child: Text('Everyone')),
                  for (final PersonReport p in data)
                    DropdownMenuItem<String?>(
                      value: p.userId,
                      child: Text('${p.name} (${p.userCode})'),
                    ),
                ],
                onChanged: (String? id) => setState(() => _person = id),
              ),
            const SizedBox(height: AppSpacing.x3),
            Wrap(
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x1,
              children: <Widget>[
                for (final StatusFilter f in StatusFilter.values)
                  FilterChip(
                    label: Text(f.label),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x4),
            ...report.when(
              skipLoadingOnRefresh: true,
              data: (List<PersonReport> all) => _results(_shown(all)),
              error: (_, _) => <Widget>[
                AppErrorView(
                  onRetry: () => ref.invalidate(reportProvider(_range)),
                ),
              ],
              loading: () => const <Widget>[
                Padding(
                  padding: EdgeInsets.all(AppSpacing.x8),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _results(List<PersonReport> people) {
    if (people.isEmpty) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.all(AppSpacing.x6),
          child: Center(child: Text('No records in these dates.')),
        ),
      ];
    }
    if (_person == null) {
      return <Widget>[
        for (final PersonReport p in people)
          _PersonCard(
            person: p,
            filter: _filter,
            onTap: () => setState(() => _person = p.userId),
          ),
      ];
    }
    final PersonReport p = people.single;
    final List<ReportDay> days = p.filtered(_filter);
    return <Widget>[
      _PersonCard(person: p, filter: _filter),
      const SizedBox(height: AppSpacing.x3),
      Text('Days (${days.length})', style: AppTypography.title),
      if (days.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.x4),
          child: Text('No days match.'),
        ),
      for (final ReportDay d in days) _DayTile(day: d),
    ];
  }
}

/// A person's totals.
class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, required this.filter, this.onTap});

  final PersonReport person;
  final StatusFilter filter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final PersonReport p = person;
    final TextStyle muted = AppTypography.body.copyWith(
      color: AppColors.textSecondary,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${p.name} (${p.userCode})',
                      style: AppTypography.title,
                    ),
                  ),
                  Text(
                    '${formatDays(p.attendance)} days',
                    style: AppTypography.title.copyWith(
                      color: AppColors.primary600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                'Present ${p.present} · Half day ${p.halfDays} · '
                'Absent ${p.absent} · Sick ${p.sickLeave} · '
                'Casual ${p.casualLeave}'
                '${p.waiting > 0 ? ' · Waiting ${p.waiting}' : ''}',
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                '${p.workedMinutes == 0 ? 'No duty time' : IstFormat.duration(Duration(minutes: p.workedMinutes))}'
                ' · ${(p.distanceM / 1000).toStringAsFixed(1)} km'
                ' · ${p.visits} ${p.visits == 1 ? 'visit' : 'visits'}',
                style: muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day});

  final ReportDay day;

  @override
  Widget build(BuildContext context) {
    final ReportDay d = day;
    final (Color fg, Color bg) = switch (d.status) {
      DayStatus.present => (AppColors.success, AppColors.successBg),
      DayStatus.halfDay => (AppColors.info, AppColors.infoBg),
      DayStatus.absent => (AppColors.error, AppColors.errorBg),
      DayStatus.leave => (AppColors.primary600, AppColors.primary50),
      DayStatus.pending ||
      DayStatus.onDuty => (AppColors.warningText, AppColors.warningBg),
    };
    final List<String> facts = <String>[
      if (d.dutyOnAt != null)
        '${IstFormat.time(d.dutyOnAt!)} to '
            '${d.dutyOffAt == null ? 'now' : IstFormat.time(d.dutyOffAt!)}'
            '${d.autoEnded ? ' (auto)' : ''}',
      if (d.distanceM != null) '${(d.distanceM! / 1000).toStringAsFixed(1)} km',
      if (d.visits > 0) '${d.visits} ${d.visits == 1 ? 'visit' : 'visits'}',
    ];
    final bool hasRoute = d.dutyOnAt != null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(IstFormat.date(d.day)),
      subtitle: facts.isEmpty ? null : Text(facts.join(' · ')),
      trailing: AppStatusPill.custom(
        color: fg,
        backgroundColor: bg,
        label: d.statusLabel,
      ),
      onTap: hasRoute ? () => context.push(Routes.adminDay(d.dayId)) : null,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_field.dart';
import '../../../shared/ds/ds_frame.dart';
import '../../users/domain/profile.dart' show initialsOf;
import '../application/reports_providers.dart';
import '../domain/report.dart';
import 'export_pdf_sheet.dart';
import 'report_parts.dart';

enum _Preset { thisMonth, lastMonth, custom }

enum _Sort { attendance, name }

/// "Reports" (design v2): attendance, duty time, km and visits for a date
/// range, everyone or one person, by person, with a PDF to share.
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  late ReportRange _range;
  _Preset _preset = _Preset.thisMonth;
  String? _person; // null: everyone
  _Sort _sort = _Sort.attendance;

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

  Future<void> _pickPerson(List<PersonReport> all) async {
    final String? picked = await showDsSheet<String>(
      context: context,
      builder: (_) => _PersonPicker(people: all, selected: _person),
    );
    if (picked == null || !mounted) return;
    setState(() => _person = picked.isEmpty ? null : picked);
  }

  List<PersonReport> _shown(List<PersonReport> all) => _person == null
      ? all
      : all.where((PersonReport p) => p.userId == _person).toList();

  void _export(List<PersonReport> all) {
    final List<PersonReport> people = _shown(all);
    showExportPdfSheet(
      context,
      range: _range,
      people: people,
      who: _person == null ? 'Everyone' : people.single.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PersonReport>> report = ref.watch(
      reportProvider(_range),
    );
    final List<PersonReport>? data = report.value;
    final List<PersonReport> shown = data == null
        ? const <PersonReport>[]
        : _shown(data);
    final String who = _person == null || shown.isEmpty
        ? 'Everyone'
        : shown.single.name;

    return Scaffold(
      backgroundColor: DsColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(reportProvider(_range).future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    DsSpace.gutter,
                    DsSpace.md,
                    DsSpace.gutter,
                    DsSpace.xl,
                  ),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: DsSpace.xs),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Semantics(
                                  header: true,
                                  child: const Text(
                                    'Reports',
                                    style: DsText.title,
                                  ),
                                ),
                                const Text(
                                  'Attendance, duty time and visits',
                                  style: DsText.caption,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Semantics(
                          container: true,
                          button: true,
                          label: 'Download PDF',
                          excludeSemantics: true,
                          child: Material(
                            color: DsColors.ink,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: data == null ? null : () => _export(data),
                              child: const SizedBox.square(
                                dimension: 46,
                                child: Icon(
                                  DsIcons.download,
                                  size: 20,
                                  color: DsColors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _Filters(
                      preset: _preset,
                      onPreset: _setPreset,
                      range: _range,
                      onRange: _pickRange,
                      who: who,
                      onWho: data == null ? null : () => _pickPerson(data),
                    ),
                    const SizedBox(height: 14),
                    ...report.when(
                      skipLoadingOnRefresh: true,
                      data: (List<PersonReport> _) => _results(shown),
                      error: (_, _) => <Widget>[
                        DsErrorState(
                          title: "Couldn't load the report",
                          message: 'Check the internet and try again.',
                          onRetry: () => ref.invalidate(reportProvider(_range)),
                        ),
                      ],
                      loading: () => const <Widget>[
                        Padding(
                          padding: EdgeInsets.only(top: DsSpace.xxl),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpace.gutter,
                DsSpace.sm,
                DsSpace.gutter,
                DsSpace.md,
              ),
              child: DsButton(
                label: 'Download PDF',
                icon: DsIcons.download,
                onPressed: data == null || shown.isEmpty
                    ? null
                    : () => _export(data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _results(List<PersonReport> people) {
    if (people.isEmpty) {
      return const <Widget>[
        DsEmptyState(
          title: 'No records in these dates',
          message: 'Pick other dates or another person.',
          icon: DsIcons.reports,
        ),
      ];
    }
    final List<ReportDay> all = <ReportDay>[
      for (final PersonReport p in people) ...p.days,
    ];
    final ({int present, int halfDay, int leave, int absent}) c = statusCounts(
      all.map((ReportDay d) => d.status),
    );
    final int minutes = people.fold(
      0,
      (int s, PersonReport p) => s + p.workedMinutes,
    );
    final int metres = people.fold(
      0,
      (int s, PersonReport p) => s + p.distanceM,
    );
    final int visits = people.fold(0, (int s, PersonReport p) => s + p.visits);
    final int waiting = people.fold(
      0,
      (int s, PersonReport p) => s + p.waiting,
    );
    final List<PersonReport> sorted = List<PersonReport>.of(people)
      ..sort(
        (PersonReport a, PersonReport b) => _sort == _Sort.name
            ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
            : b.attendance.compareTo(a.attendance),
      );
    return <Widget>[
      Container(
        padding: const EdgeInsets.all(DsSpace.lg),
        decoration: const BoxDecoration(
          color: DsColors.white,
          borderRadius: DsRadius.large,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StatusTotals(
              present: c.present,
              halfDay: c.halfDay,
              leave: c.leave,
              absent: c.absent,
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFEEF2F6)),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _Total(
                  value: '${_thousands(minutes ~/ 60)} h',
                  label: 'Duty time',
                ),
                _Total(
                  value: '${_thousands((metres / 1000).round())} km',
                  label: 'Distance',
                ),
                _Total(value: _thousands(visits), label: 'Dealer visits'),
              ],
            ),
          ],
        ),
      ),
      if (waiting > 0) ...<Widget>[
        const SizedBox(height: 14),
        _WaitingCard(
          count: waiting,
          onTap: () => context.go(Routes.adminRequests),
        ),
      ],
      const SizedBox(height: 14),
      Row(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: DsSpace.xs),
              child: Semantics(
                header: true,
                child: const Text('By person', style: DsText.section),
              ),
            ),
          ),
          _SortSwitch(
            sort: _sort,
            onPick: (_Sort s) => setState(() => _sort = s),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: DsColors.white,
          borderRadius: DsRadius.large,
        ),
        child: Column(
          children: <Widget>[
            for (final (int i, PersonReport p) in sorted.indexed)
              _PersonRow(
                person: p,
                index: i,
                onTap: () => context.push(Routes.adminUserDays(p.userId)),
              ),
          ],
        ),
      ),
    ];
  }
}

/// "4,610".
String _thousands(int n) {
  final String s = n.abs().toString();
  final StringBuffer b = StringBuffer(n < 0 ? '-' : '');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.preset,
    required this.onPreset,
    required this.range,
    required this.onRange,
    required this.who,
    required this.onWho,
  });

  final _Preset preset;
  final ValueChanged<_Preset> onPreset;
  final ReportRange range;
  final VoidCallback onRange;
  final String who;
  final VoidCallback? onWho;

  @override
  Widget build(BuildContext context) {
    Widget tab(_Preset p, String label) => Expanded(
      child: Semantics(
        container: true,
        button: true,
        selected: p == preset,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onPreset(p),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p == preset ? DsColors.white : Colors.transparent,
              borderRadius: DsRadius.medium,
              boxShadow: p == preset ? DsShadow.card : null,
            ),
            child: Text(
              label,
              style: DsText.label.copyWith(
                fontWeight: FontWeight.w700,
                color: p == preset ? DsColors.ink : DsColors.text2,
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(DsSpace.sm),
      decoration: const BoxDecoration(
        color: DsColors.white,
        borderRadius: DsRadius.large,
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2F6),
              borderRadius: DsRadius.medium,
            ),
            child: Row(
              children: <Widget>[
                tab(_Preset.thisMonth, 'This month'),
                const SizedBox(width: 4),
                tab(_Preset.lastMonth, 'Last month'),
                const SizedBox(width: 4),
                tab(_Preset.custom, 'Custom'),
              ],
            ),
          ),
          const SizedBox(height: DsSpace.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: _FilterButton(
                  icon: DsIcons.history,
                  label: rangeLabel(range),
                  semantics: 'Dates, ${rangeLabel(range, withYear: true)}',
                  onTap: onRange,
                ),
              ),
              const SizedBox(width: DsSpace.sm),
              Expanded(
                child: _FilterButton(
                  icon: DsIcons.team,
                  label: who,
                  semantics: 'Person, $who',
                  onTap: onWho,
                  dropdown: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.semantics,
    required this.onTap,
    this.dropdown = false,
  });

  final IconData icon;
  final String label;
  final String semantics;
  final VoidCallback? onTap;
  final bool dropdown;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: semantics,
    excludeSemantics: true,
    child: Material(
      color: DsColors.surface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 16, color: DsColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsText.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DsColors.ink,
                  ),
                ),
              ),
              if (dropdown) ...<Widget>[
                const SizedBox(width: 4),
                const Icon(DsIcons.expandMore, size: 14, color: DsColors.text2),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _Total extends StatelessWidget {
  const _Total({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: DsText.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(label, style: DsText.caption),
        ],
      ),
    ),
  );
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label:
        '$count ${count == 1 ? 'day' : 'days'} still waiting. Review requests.',
    excludeSemantics: true,
    child: Material(
      color: DsColors.warningTint,
      borderRadius: DsRadius.large,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: DsColors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  DsIcons.clock,
                  size: 18,
                  color: DsColors.warningText,
                ),
              ),
              const SizedBox(width: DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$count ${count == 1 ? 'day' : 'days'} still waiting',
                      style: DsText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DsColors.warningText,
                      ),
                    ),
                    Text(
                      'Decide them so the report is final',
                      style: DsText.caption.copyWith(
                        color: DsColors.warningText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: DsColors.warningText,
                  borderRadius: DsRadius.pill,
                ),
                child: Text(
                  'Review',
                  style: DsText.label.copyWith(
                    color: DsColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SortSwitch extends StatelessWidget {
  const _SortSwitch({required this.sort, required this.onPick});

  final _Sort sort;
  final ValueChanged<_Sort> onPick;

  @override
  Widget build(BuildContext context) {
    Widget seg(_Sort s, String label) => Semantics(
      container: true,
      button: true,
      selected: s == sort,
      label: 'Sort by $label',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onPick(s),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s == sort ? DsColors.white : Colors.transparent,
            borderRadius: DsRadius.medium,
            boxShadow: s == sort ? DsShadow.card : null,
          ),
          child: Text(
            label,
            style: DsText.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: s == sort ? DsColors.ink : DsColors.text2,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Color(0xFFEEF2F6),
        borderRadius: DsRadius.medium,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          seg(_Sort.attendance, 'Attendance'),
          seg(_Sort.name, 'Name'),
        ],
      ),
    );
  }
}

/// The avatar colours, in turn.
const List<DsStatus> _tints = <DsStatus>[
  DsStatus.onDuty,
  DsStatus.present,
  DsStatus.leave,
  DsStatus.waiting,
];

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.index,
    required this.onTap,
  });

  final PersonReport person;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PersonReport p = person;
    final DsStatus t = _tints[index % _tints.length];
    final int leave = p.sickLeave + p.casualLeave;
    final String line = <String>[
      '${p.workedMinutes ~/ 60} h',
      '${(p.distanceM / 1000).round()} km',
      '${p.visits} ${p.visits == 1 ? 'visit' : 'visits'}',
      if (p.waiting > 0) '${p.waiting} waiting',
    ].join(' · ');
    final int parts = p.present + p.halfDays + leave + p.absent;
    Widget seg(int n, Color c) => n == 0
        ? const SizedBox.shrink()
        : Expanded(
            flex: n,
            child: Container(
              height: 6,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
    return Semantics(
      container: true,
      button: true,
      label:
          '${p.name}, ${p.userCode}, ${formatDays(p.attendance)} days. $line',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.medium,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.tint,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initialsOf(p.name),
                  style: DsText.label.copyWith(
                    color: t.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsText.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          p.userCode,
                          style: DsText.micro.copyWith(color: DsColors.text2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (parts == 0)
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2F6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )
                    else
                      Row(
                        children: <Widget>[
                          seg(p.present, DsColors.primary),
                          seg(p.halfDays, const Color(0xFF7DD3FC)),
                          seg(leave, DsStatus.leave.dot),
                          seg(p.absent, const Color(0xFFF87171)),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsText.micro.copyWith(color: DsColors.text2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DsSpace.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatDays(p.attendance),
                    style: DsText.title.copyWith(fontSize: 20),
                  ),
                  Text(
                    'days',
                    style: DsText.micro.copyWith(color: DsColors.text2),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Everyone or one person, with a search when the list is long. Pops the
/// person's id, or "" for everyone.
class _PersonPicker extends StatefulWidget {
  const _PersonPicker({required this.people, required this.selected});

  final List<PersonReport> people;
  final String? selected;

  @override
  State<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<_PersonPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final String q = _q.trim().toLowerCase();
    final List<PersonReport> shown =
        widget.people
            .where(
              (PersonReport p) =>
                  q.isEmpty ||
                  p.name.toLowerCase().contains(q) ||
                  p.userCode.toLowerCase().contains(q),
            )
            .toList()
          ..sort(
            (PersonReport a, PersonReport b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    Widget option(String id, String title, String? sub) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: DsText.body.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: sub == null ? null : Text(sub, style: DsText.caption),
      trailing: (widget.selected ?? '') == id
          ? const Icon(DsIcons.check, color: DsColors.primary)
          : null,
      onTap: () => Navigator.pop(context, id),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('Person', style: DsText.title),
        const SizedBox(height: DsSpace.md),
        if (widget.people.length > 6) ...<Widget>[
          DsSearchField(
            hint: 'Name or user ID',
            onChanged: (String v) => setState(() => _q = v),
          ),
          const SizedBox(height: DsSpace.sm),
        ],
        if (q.isEmpty) option('', 'Everyone', null),
        for (final PersonReport p in shown)
          option(p.userId, p.name, p.userCode),
        if (shown.isEmpty && q.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.lg),
            child: Text(
              'Nobody matches.',
              textAlign: TextAlign.center,
              style: DsText.body.copyWith(color: DsColors.text2),
            ),
          ),
      ],
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/time/clock_providers.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_frame.dart';
import '../application/reports_providers.dart';
import '../data/report_pdf.dart';
import '../domain/report.dart';
import 'report_parts.dart';

/// Roughly how many pages the PDF takes: about 28 people per summary page,
/// and with [detail] about 35 days per page for each person.
int reportPages(List<PersonReport> people, {required bool detail}) {
  int pages = (people.length / 28).ceil().clamp(1, 1 << 20);
  if (detail) {
    for (final PersonReport p in people) {
      pages += (p.days.length / 35).ceil().clamp(1, 1 << 20);
    }
  }
  return pages;
}

/// "Download report" (design v2, Export PDF): which dates and people, which
/// days for the day list, Summary or Every day, then the share sheet.
Future<void> showExportPdfSheet(
  BuildContext context, {
  required ReportRange range,
  required List<PersonReport> people,
  required String who,
  StatusFilter filter = StatusFilter.all,
}) => showDsSheet<void>(
  context: context,
  builder: (_) =>
      _ExportSheet(range: range, people: people, who: who, filter: filter),
);

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet({
    required this.range,
    required this.people,
    required this.who,
    required this.filter,
  });

  final ReportRange range;
  final List<PersonReport> people;
  final String who;
  final StatusFilter filter;

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  bool _detail = false;
  late StatusFilter _filter = widget.filter;
  bool _busy = false;
  String? _error;

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final Uint8List bytes = await buildReportPdfInBackground(
        range: widget.range,
        people: widget.people,
        filter: _filter,
        detail: _detail,
        madeAt: ref.read(serverClockProvider).now(),
      );
      await ref
          .read(pdfSharerProvider)
          .share(bytes, reportFileName(widget.range));
      // In the admin log (L84); a failure here does not stop the export.
      try {
        await ref
            .read(reportsRepositoryProvider)
            .logExport(
              widget.range,
              detail: _detail,
              people: widget.people.length,
            );
      } on Object catch (e, s) {
        AppLog.failure('report export log', e, s);
      }
      if (mounted) Navigator.pop(context);
    } on Object catch (e, s) {
      AppLog.failure('report pdf', e, s);
      if (mounted) {
        setState(() => _error = 'The PDF could not be made. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFilter() async {
    final StatusFilter? f = await showDsSheet<StatusFilter>(
      context: context,
      builder: (BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Which days', style: DsText.title),
          const SizedBox(height: DsSpace.xs),
          Text(
            'For the "Every day" PDF.',
            style: DsText.body.copyWith(color: DsColors.text2),
          ),
          const SizedBox(height: DsSpace.md),
          for (final StatusFilter s in StatusFilter.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.label, style: DsText.body),
              trailing: s == _filter
                  ? const Icon(DsIcons.check, color: DsColors.primary)
                  : null,
              onTap: () => Navigator.pop(context, s),
            ),
        ],
      ),
    );
    if (f != null && mounted) setState(() => _filter = f);
  }

  @override
  Widget build(BuildContext context) {
    final int pages = reportPages(widget.people, detail: _detail);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: DsColors.primaryTint,
                borderRadius: DsRadius.medium,
              ),
              child: const Icon(
                DsIcons.reports,
                size: 22,
                color: DsColors.primary,
              ),
            ),
            const SizedBox(width: DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: const Text('Download report', style: DsText.title),
                  ),
                  const Text('Attendance PDF', style: DsText.caption),
                ],
              ),
            ),
            DsIconButton(
              icon: DsIcons.close,
              label: 'Close',
              onPressed: _busy ? null : () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: DsSpace.lg),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            ReportChip(
              icon: DsIcons.history,
              label: rangeLabel(widget.range, withYear: true),
            ),
            ReportChip(icon: DsIcons.team, label: widget.who),
            ReportChip(
              icon: DsIcons.requests,
              label: _filter.label,
              onTap: _busy ? null : _pickFilter,
            ),
          ],
        ),
        const SizedBox(height: DsSpace.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _Option(
                label: 'Summary',
                help: 'One line per person',
                detail: false,
                selected: !_detail,
                onTap: _busy ? null : () => setState(() => _detail = false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Option(
                label: 'Every day',
                help: 'Each day with times, hours and km',
                detail: true,
                selected: _detail,
                onTap: _busy ? null : () => setState(() => _detail = true),
              ),
            ),
          ],
        ),
        if (_error case final String e) ...<Widget>[
          const SizedBox(height: DsSpace.md),
          Text(e, style: DsText.body.copyWith(color: DsColors.dangerText)),
        ],
        const SizedBox(height: DsSpace.lg),
        DsButton(
          label: 'Create PDF · about $pages ${pages == 1 ? 'page' : 'pages'}',
          icon: DsIcons.download,
          busy: _busy,
          busyLabel: 'Making the PDF…',
          onPressed: widget.people.isEmpty ? null : _create,
        ),
        const SizedBox(height: DsSpace.md),
        const Text(
          'Then share it: Save · WhatsApp · Print',
          textAlign: TextAlign.center,
          style: DsText.caption,
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.help,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String help;
  final bool detail;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h, Color c) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    Widget row(List<int> flex, double h, Color c) => Row(
      children: <Widget>[
        for (final (int i, int f) in flex.indexed) ...<Widget>[
          if (i > 0) const SizedBox(width: 3),
          Expanded(flex: f, child: bar(double.infinity, h, c)),
        ],
      ],
    );
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '$label. $help',
      excludeSemantics: true,
      child: Material(
        color: selected ? DsColors.primaryTint : DsColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: DsRadius.large,
          side: selected
              ? const BorderSide(color: DsColors.primary, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      height: 96,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: DsColors.white,
                        borderRadius: DsRadius.medium,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          FractionallySizedBox(
                            widthFactor: 0.55,
                            child: bar(double.infinity, 6, DsColors.primary),
                          ),
                          const SizedBox(height: 5),
                          FractionallySizedBox(
                            widthFactor: 0.35,
                            child: bar(
                              double.infinity,
                              4,
                              const Color(0xFFCBD5E1),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!detail) ...<Widget>[
                            row(<int>[2, 1, 1], 5, const Color(0xFF94A3B8)),
                            for (int i = 0; i < 3; i++) ...<Widget>[
                              const SizedBox(height: 5),
                              row(<int>[2, 1, 1], 5, const Color(0xFFE2E8F0)),
                            ],
                          ] else ...<Widget>[
                            row(<int>[2, 1], 5, const Color(0xFF94A3B8)),
                            for (int i = 0; i < 5; i++) ...<Widget>[
                              const SizedBox(height: 4),
                              row(
                                <int>[1, 1, 1, 1],
                                3,
                                const Color(0xFFE2E8F0),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(help, style: DsText.caption.copyWith(height: 1.35)),
                  ],
                ),
                if (selected)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: DsColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: DsColors.white, width: 3),
                      ),
                      child: const Icon(
                        DsIcons.check,
                        size: 12,
                        color: DsColors.white,
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
}

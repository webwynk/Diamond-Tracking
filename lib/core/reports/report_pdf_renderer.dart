import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/admin_duty_session.dart';
import '../../domain/entities/attendance_period.dart';
import '../../domain/entities/report_data.dart';
import '../utils/duty_time_helper.dart';
import 'report_pdf_style.dart';

/// Draws a [ReportData] as a PDF: a brand header, the key figures, then the
/// table (whose header row repeats on every page).
///
/// Every figure is read from the report, which was built from the same session
/// rows as the attendance screen; nothing is calculated here except layout.
/// Times are IST. Reports are English only.
class ReportPdfRenderer {
  ReportPdfRenderer({required this.fonts, this.logo, this.compress = true});

  final ReportFonts fonts;

  /// The white logo mark for the header band. Optional: without it the band
  /// carries the company name in text.
  final Uint8List? logo;

  /// Tests turn this off so the text can be read in the PDF bytes.
  final bool compress;

  static const double _margin = 28;
  static const String _dash = '—';

  /// The file name, e.g. `DiamondAgritech_TeamSummary_2026-10-01_to_2026-10-17.pdf`
  /// (one date for a daily report). Safe on every file system.
  static String fileName(ReportData report) {
    final name = switch (report) {
      DailyDetailReport() => 'DailyDetail_${_iso(report.from)}',
      EmployeeSummaryReport(:final employee) =>
        'EmployeeSummary_${_safe(employee.code.isEmpty ? employee.name : employee.code)}'
            '_${_iso(report.from)}_to_${_iso(report.to)}',
      TeamSummaryReport() =>
        'TeamSummary_${_iso(report.from)}_to_${_iso(report.to)}',
    };
    return 'DiamondAgritech_$name.pdf';
  }

  /// Renders [report]. [generatedBy] is the admin's name, printed in the header.
  Future<Uint8List> render(
    ReportData report, {
    required String generatedBy,
  }) async {
    final doc = pw.Document(
      title: _title(report),
      author: generatedBy,
      creator: 'Diamond Agritech Tracking',
      subject: _period(report),
      compress: compress,
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
    );
    switch (report) {
      case DailyDetailReport():
        _daily(doc, report, generatedBy);
      case EmployeeSummaryReport():
        _employee(doc, report, generatedBy);
      case TeamSummaryReport():
        _team(doc, report, generatedBy);
    }
    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // The three reports
  // ---------------------------------------------------------------------------

  void _daily(pw.Document doc, DailyDetailReport r, String by) {
    final distanceUnknown =
        r.distanceKm == null ||
        r.rows.any((row) => row.session.distanceKm == null);
    doc.addPage(
      _page(
        r,
        landscape: true,
        build: [
          _band(r, by),
          pw.SizedBox(height: 10),
          if (r.truncated) _truncatedBanner(),
          _kpis([
            _Kpi('On duty', '${r.employeesOnDuty}'),
            _Kpi('Total hours', DutyTimeHelper.formatElapsed(r.totalDuration)),
            _Kpi('Distance', _km(r.distanceKm, unit: true)),
            _Kpi('Visits', '${r.visits}'),
            if (r.absentKnown) _Kpi('Absent', '${r.absent.length}'),
            _Kpi('Flagged points', '${r.flaggedPoints}'),
          ]),
          pw.SizedBox(height: 12),
          if (r.rows.isEmpty)
            _empty('No duty recorded on this day')
          else
            _table(
              columns: const [
                _Col('Employee', 3.2),
                _Col('Started', 1.3, right: true),
                _Col('Ended', 1.3, right: true),
                _Col('Duration', 1.2, right: true),
                _Col('Distance (km)', 1.3, right: true),
                _Col('Visits', 0.9, right: true),
                _Col('Flagged', 1, right: true),
                _Col('Status', 2.6),
              ],
              rows: [for (final row in r.rows) _dailyRow(row, r.serverNow)],
            ),
          if (r.absentKnown && r.absent.isNotEmpty) ..._absentList(r.absent),
          if (!r.absentKnown)
            _note('Today is not over, so absences are not listed yet.'),
          pw.SizedBox(height: 10),
          _notes([
            if (r.inProgress > 0)
              'Duties still in progress are counted up to the time this report was generated.',
            if (distanceUnknown)
              '$_dash means the distance could not be measured; a total that includes one is also $_dash.',
            _distanceRule,
          ]),
        ],
      ),
    );
  }

  void _employee(pw.Document doc, EmployeeSummaryReport r, String by) {
    final s = r.period.summary;
    final days = [...r.period.days]..sort((a, b) => a.date.compareTo(b.date));
    final hasOpen = days.any((d) => d.hasOpenSession);
    final distanceUnknown = days.any((d) => d.distanceKm == null);
    final showAbsent = r.employee.isActive;
    doc.addPage(
      _page(
        r,
        landscape: false,
        build: [
          _band(r, by),
          pw.SizedBox(height: 10),
          if (r.truncated) _truncatedBanner(),
          _kpis([
            _Kpi('Days worked', '${s.daysWorked}'),
            _Kpi('Total hours', DutyTimeHelper.formatElapsed(s.totalDuration)),
            _Kpi('Distance', _km(s.distanceKm, unit: true)),
            _Kpi('Visits', '${s.visitsCount}'),
            if (showAbsent) _Kpi('Absent days', '${s.absentDays}'),
          ]),
          pw.SizedBox(height: 12),
          if (days.isEmpty)
            _empty('No duty recorded in this period')
          else
            _table(
              columns: const [
                _Col('Date', 2),
                _Col('Duty times', 3),
                _Col('Duration', 1.4, right: true),
                _Col('Distance (km)', 1.9, right: true),
                _Col('Visits', 1, right: true),
                _Col('Notes', 2.6),
              ],
              rows: [for (final day in days) _employeeRow(day)],
            ),
          pw.SizedBox(height: 10),
          _notes([
            if (s.daysWorked == 0 && days.isNotEmpty)
              'No duty was recorded in this period.',
            if (!showAbsent)
              'This account is blocked: days without duty are not counted as absent.',
            if (hasOpen)
              'A duty still in progress is counted up to the time this report was generated.',
            if (distanceUnknown)
              '$_dash means the distance could not be measured; a total that includes one is also $_dash.',
            if (showAbsent) _absentRule,
            _distanceRule,
          ]),
        ],
      ),
    );
  }

  void _team(pw.Document doc, TeamSummaryReport r, String by) {
    final t = r.totals;
    final distanceUnknown = r.rows.any((row) => row.summary.distanceKm == null);
    doc.addPage(
      _page(
        r,
        landscape: true,
        build: [
          _band(r, by),
          pw.SizedBox(height: 10),
          if (r.truncated) _truncatedBanner(),
          _kpis([
            _Kpi('Employees', '${r.rows.length}'),
            _Kpi('Days worked', '${t.daysWorked}'),
            _Kpi('Total hours', DutyTimeHelper.formatElapsed(t.totalDuration)),
            _Kpi('Distance', _km(t.distanceKm, unit: true)),
            _Kpi('Visits', '${t.visitsCount}'),
            _Kpi('Absent days', '${t.absentDays}'),
          ]),
          pw.SizedBox(height: 12),
          if (r.rows.isEmpty)
            _empty('No employees to report on')
          else ...[
            if (t.daysWorked == 0)
              _note('No duty was recorded in this period.'),
            _table(
              columns: const [
                _Col('Employee', 3.4),
                _Col('Code', 1.3),
                _Col('Days worked', 1.2, right: true),
                _Col('Absent', 1, right: true),
                _Col('Hours', 1.3, right: true),
                _Col('Distance (km)', 1.4, right: true),
                _Col('Visits', 0.9, right: true),
                _Col('Auto-ended', 1.2, right: true),
                _Col('Flagged', 1, right: true),
              ],
              rows: [for (final row in r.rows) _teamRow(row), _teamTotals(t)],
              lastIsTotal: true,
            ),
          ],
          pw.SizedBox(height: 10),
          _notes([
            if (r.rows.any((row) => !row.employee.isActive))
              'Blocked accounts are listed only if they worked in this period; their days without duty are not counted as absent ($_dash).',
            if (distanceUnknown)
              '$_dash means the distance could not be measured; a total that includes one is also $_dash.',
            'Auto-ended: days on which a duty was ended automatically at 11:00 PM IST. Flagged: GPS points the phone marked as a mock location.',
            _absentRule,
            _distanceRule,
          ]),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rows
  // ---------------------------------------------------------------------------

  _Row _dailyRow(DailyDetailRow row, DateTime serverNow) {
    final s = row.session;
    return _Row([
      _Cell.employee(row.employee),
      _Cell(DutyTimeHelper.formatTime(s.startedAt)),
      _Cell(s.endedAt == null ? _dash : DutyTimeHelper.formatTime(s.endedAt!)),
      _Cell(DutyTimeHelper.formatElapsed(s.durationAt(serverNow))),
      _Cell(_km(s.distanceKm)),
      _Cell('${s.visitsCount}'),
      s.mockPointsCount > 0
          ? _Cell('${s.mockPointsCount}', tone: _Tone.error)
          : const _Cell(_dash, muted: true),
      _Cell.status(_statusOf(s)),
    ]);
  }

  _Row _employeeRow(AttendanceDay day) {
    final times = day.sessions
        .map((s) => DutyTimeHelper.formatTimeRange(s.startedAt, s.endedAt))
        .join('\n')
        .replaceAll('–Active', ' – in progress');
    return _Row([
      _Cell(_longDay(day.date)),
      day.isAbsent ? const _Cell(_dash, muted: true) : _Cell(times),
      day.isAbsent
          ? const _Cell(_dash, muted: true)
          : _Cell(DutyTimeHelper.formatElapsed(day.duration)),
      day.isAbsent
          ? const _Cell(_dash, muted: true)
          : _Cell(_km(day.distanceKm)),
      day.isAbsent
          ? const _Cell(_dash, muted: true)
          : _Cell('${day.visitsCount}'),
      _Cell.status([
        if (day.isAbsent) const _Status('Absent', _Tone.error),
        if (day.hasOpenSession) const _Status('In progress', _Tone.info),
        if (day.endedAutomatically)
          const _Status('Duty ended automatically', _Tone.warning),
        if (day.hasFlag)
          _Status('${day.flaggedPoints} flagged points', _Tone.error),
      ]),
    ]);
  }

  _Row _teamRow(TeamSummaryRow row) {
    final s = row.summary;
    final active = row.employee.isActive;
    return _Row([
      _Cell.employee(row.employee, withCode: false),
      _Cell(row.employee.code.isEmpty ? _dash : row.employee.code),
      _Cell('${s.daysWorked}'),
      active ? _Cell('${s.absentDays}') : const _Cell(_dash, muted: true),
      _Cell(DutyTimeHelper.formatElapsed(s.totalDuration)),
      _Cell(_km(s.distanceKm)),
      _Cell('${s.visitsCount}'),
      _Cell('${s.autoEndedDays}'),
      s.flaggedPoints > 0
          ? _Cell('${s.flaggedPoints}', tone: _Tone.error)
          : const _Cell(_dash, muted: true),
    ]);
  }

  _Row _teamTotals(AttendanceSummary t) => _Row([
    const _Cell('Total'),
    const _Cell(''),
    _Cell('${t.daysWorked}'),
    _Cell('${t.absentDays}'),
    _Cell(DutyTimeHelper.formatElapsed(t.totalDuration)),
    _Cell(_km(t.distanceKm)),
    _Cell('${t.visitsCount}'),
    _Cell('${t.autoEndedDays}'),
    _Cell('${t.flaggedPoints}'),
  ]);

  List<_Status> _statusOf(AdminDutySession s) => [
    if (s.isOpen) const _Status('In progress', _Tone.info),
    if (s.endedAutomatically)
      const _Status('Duty ended automatically', _Tone.warning),
    if (s.endedByBlock) const _Status('Ended: account blocked', _Tone.warning),
    if (!s.isOpen && !s.endedAutomatically && !s.endedByBlock)
      const _Status('Completed', _Tone.success),
  ];

  // ---------------------------------------------------------------------------
  // Page furniture
  // ---------------------------------------------------------------------------

  pw.MultiPage _page(
    ReportData report, {
    required bool landscape,
    required List<pw.Widget> build,
  }) {
    return pw.MultiPage(
      pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(
        _margin,
        _margin,
        _margin,
        _margin + 6,
      ),
      header: (context) =>
          context.pageNumber == 1 ? pw.SizedBox() : _runningHeader(report),
      footer: _footer,
      build: (context) => build,
    );
  }

  /// The brand band with the title and period, and below it who made the report
  /// and when (the server's clock).
  pw.Widget _band(ReportData report, String generatedBy) {
    final subject = switch (report) {
      EmployeeSummaryReport(:final employee) =>
        employee.code.isEmpty
            ? employee.name
            : '${employee.name} (${employee.code})',
      _ => null,
    };
    final logoBytes = logo;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: pw.BoxDecoration(
            color: ReportPdfColors.brand,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoBytes != null)
                pw.Image(pw.MemoryImage(logoBytes), height: 32)
              else
                pw.Text(
                  'Diamond Agritech',
                  style: _style(14, bold: true, color: ReportPdfColors.white),
                ),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    _title(report),
                    style: _style(17, bold: true, color: ReportPdfColors.white),
                  ),
                  if (subject != null) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      subject,
                      style: _style(
                        11,
                        bold: true,
                        color: ReportPdfColors.white,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 3),
                  pw.Text(
                    _period(report),
                    style: _style(10, color: ReportPdfColors.brandBorder),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Generated ${DutyTimeHelper.formatDate(report.serverNow)}, '
          '${DutyTimeHelper.formatTime(report.serverNow)} IST by $generatedBy',
          style: _style(8.5, color: ReportPdfColors.textSoft),
        ),
      ],
    );
  }

  pw.Widget _runningHeader(ReportData report) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: ReportPdfColors.line, width: 0.6),
      ),
    ),
    child: pw.Text(
      'Diamond Agritech · ${_title(report)} · ${_period(report)}',
      style: _style(8, color: ReportPdfColors.textMuted),
    ),
  );

  pw.Widget _footer(pw.Context context) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 8),
    padding: const pw.EdgeInsets.only(top: 5),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: ReportPdfColors.line, width: 0.6),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Diamond Agritech · Confidential: contains personal data',
          style: _style(7.5, color: ReportPdfColors.textMuted),
        ),
        pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: _style(7.5, color: ReportPdfColors.textMuted),
        ),
      ],
    ),
  );

  pw.Widget _kpis(List<_Kpi> kpis) => pw.Row(
    children: [
      for (var i = 0; i < kpis.length; i++) ...[
        if (i > 0) pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: ReportPdfColors.brandTint,
              border: pw.Border.all(
                color: ReportPdfColors.brandBorder,
                width: 0.6,
              ),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  kpis[i].value,
                  style: _style(
                    15,
                    bold: true,
                    color: ReportPdfColors.brandDark,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  kpis[i].label.toUpperCase(),
                  style: pw.TextStyle(
                    font: fonts.regular,
                    fontSize: 7,
                    letterSpacing: 0.4,
                    color: ReportPdfColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );

  pw.Widget _table({
    required List<_Col> columns,
    required List<_Row> rows,
    bool lastIsTotal = false,
  }) {
    final header = pw.TableRow(
      repeat: true,
      decoration: pw.BoxDecoration(color: ReportPdfColors.brand),
      children: [
        for (final column in columns)
          _box(
            pw.Text(
              column.title,
              style: _style(8.5, bold: true, color: ReportPdfColors.white),
              textAlign: column.right ? pw.TextAlign.right : pw.TextAlign.left,
            ),
            right: column.right,
          ),
      ],
    );
    final body = <pw.TableRow>[];
    for (var i = 0; i < rows.length; i++) {
      final total = lastIsTotal && i == rows.length - 1;
      body.add(
        pw.TableRow(
          decoration: total
              ? pw.BoxDecoration(
                  color: ReportPdfColors.brandTint,
                  border: pw.Border(
                    top: pw.BorderSide(color: ReportPdfColors.brand, width: 1),
                  ),
                )
              : pw.BoxDecoration(
                  color: i.isOdd
                      ? ReportPdfColors.zebra
                      : ReportPdfColors.white,
                ),
          children: [
            for (var j = 0; j < columns.length; j++)
              _box(
                _cell(rows[i].cells[j], columns[j], bold: total),
                right: columns[j].right,
              ),
          ],
        ),
      );
    }
    return pw.Table(
      columnWidths: {
        for (var i = 0; i < columns.length; i++)
          i: pw.FlexColumnWidth(columns[i].flex),
      },
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(
          color: ReportPdfColors.line,
          width: 0.5,
        ),
        bottom: pw.BorderSide(color: ReportPdfColors.line, width: 0.5),
      ),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [header, ...body],
    );
  }

  pw.Widget _box(pw.Widget child, {required bool right}) => pw.Container(
    alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: child,
  );

  pw.Widget _cell(_Cell cell, _Col column, {required bool bold}) {
    final employee = cell.employee;
    if (employee != null) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            employee.isActive ? employee.name : '${employee.name} (blocked)',
            style: _style(9, bold: true, color: ReportPdfColors.text),
          ),
          if (cell.withCode && employee.code.isNotEmpty)
            pw.Text(
              employee.code,
              style: _style(7.5, color: ReportPdfColors.textMuted),
            ),
        ],
      );
    }
    final statuses = cell.statuses;
    if (statuses != null) {
      if (statuses.isEmpty) {
        return pw.Text(
          _dash,
          style: _style(9, color: ReportPdfColors.textMuted),
        );
      }
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final status in statuses)
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 1),
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
              ),
              decoration: pw.BoxDecoration(
                color: _toneBackground(status.tone),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                status.text,
                style: _style(7.5, bold: true, color: _toneText(status.tone)),
              ),
            ),
        ],
      );
    }
    return pw.Text(
      cell.text,
      textAlign: column.right ? pw.TextAlign.right : pw.TextAlign.left,
      style: _style(
        9,
        bold: bold || cell.tone == _Tone.error,
        color: cell.muted
            ? ReportPdfColors.textMuted
            : cell.tone == _Tone.error
            ? ReportPdfColors.errorText
            : ReportPdfColors.text,
      ),
    );
  }

  pw.Widget _empty(String message) => pw.Container(
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.symmetric(vertical: 28),
    decoration: pw.BoxDecoration(
      color: ReportPdfColors.brandTint,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Text(
      message,
      style: _style(11, bold: true, color: ReportPdfColors.brandDark),
    ),
  );

  pw.Widget _truncatedBanner() => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: ReportPdfColors.errorBg,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Text(
      'This report is incomplete. The period holds more duty records than one '
      'report can include, so only the earliest are shown. Choose a shorter period.',
      style: _style(9, bold: true, color: ReportPdfColors.errorText),
    ),
  );

  pw.Widget _note(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(text, style: _style(9, color: ReportPdfColors.textSoft)),
  );

  pw.Widget _notes(List<String> notes) {
    if (notes.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Notes',
          style: _style(8, bold: true, color: ReportPdfColors.textSoft),
        ),
        pw.SizedBox(height: 2),
        for (final note in notes)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(
              '· $note',
              style: _style(7.5, color: ReportPdfColors.textMuted),
            ),
          ),
      ],
    );
  }

  List<pw.Widget> _absentList(List<ReportEmployee> absent) => [
    pw.SizedBox(height: 14),
    pw.Text(
      'No duty recorded (${absent.length})',
      style: _style(10, bold: true, color: ReportPdfColors.brandDark),
    ),
    pw.SizedBox(height: 4),
    pw.Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final employee in absent)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: pw.BoxDecoration(
              color: ReportPdfColors.zebra,
              border: pw.Border.all(color: ReportPdfColors.line, width: 0.6),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              employee.code.isEmpty
                  ? employee.name
                  : '${employee.name} (${employee.code})',
              style: _style(8.5, color: ReportPdfColors.text),
            ),
          ),
      ],
    ),
  ];

  pw.TextStyle _style(double size, {bool bold = false, PdfColor? color}) =>
      pw.TextStyle(
        font: bold ? fonts.bold : fonts.regular,
        fontSize: size,
        color: color ?? ReportPdfColors.text,
      );

  static PdfColor _toneBackground(_Tone tone) => switch (tone) {
    _Tone.normal => ReportPdfColors.zebra,
    _Tone.info => ReportPdfColors.brandTint,
    _Tone.success => ReportPdfColors.successBg,
    _Tone.warning => ReportPdfColors.warningBg,
    _Tone.error => ReportPdfColors.errorBg,
  };

  static PdfColor _toneText(_Tone tone) => switch (tone) {
    _Tone.normal => ReportPdfColors.textSoft,
    _Tone.info => ReportPdfColors.brandDark,
    _Tone.success => ReportPdfColors.text,
    _Tone.warning => ReportPdfColors.warningText,
    _Tone.error => ReportPdfColors.errorText,
  };

  // ---------------------------------------------------------------------------
  // Words and numbers
  // ---------------------------------------------------------------------------

  static const String _distanceRule =
      'Distance is measured by the server from all GPS points of a duty. Points '
      'flagged as mock locations, readings worse than 100 m and jumps faster than '
      '55 m/s are left out. Totals are added from unrounded figures.';

  static const String _absentRule =
      "Absent: a past day with no duty, from the employee's first day. There is "
      'no holiday or weekly-off calendar, so every such day counts.';

  static String _title(ReportData report) => switch (report) {
    DailyDetailReport() => 'Daily Duty Detail',
    EmployeeSummaryReport() => 'Employee Attendance Summary',
    TeamSummaryReport() => 'Team Attendance Summary',
  };

  static String _period(ReportData report) {
    if (report is DailyDetailReport) return _longDay(report.from);
    final days = _wall(report.to).difference(_wall(report.from)).inDays + 1;
    return '${_longDay(report.from)} – ${_longDay(report.to)} '
        '($days ${days == 1 ? 'day' : 'days'})';
  }

  /// A wall-clock IST date as a UTC instant, so the helpers do not shift it by
  /// the phone's zone.
  static DateTime _wall(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  static String _longDay(DateTime d) {
    final weekday = DutyTimeHelper.formatDayAndDate(_wall(d)).split(',').first;
    return '$weekday, ${DutyTimeHelper.formatDate(_wall(d))}';
  }

  static String _km(double? km, {bool unit = false}) => km == null
      ? _dash
      : '${DutyTimeHelper.formatDistanceKm(km)}${unit ? ' km' : ''}';

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '_');
}

enum _Tone { normal, info, success, warning, error }

class _Kpi {
  const _Kpi(this.label, this.value);

  final String label;
  final String value;
}

class _Col {
  const _Col(this.title, this.flex, {this.right = false});

  final String title;
  final double flex;
  final bool right;
}

class _Status {
  const _Status(this.text, this.tone);

  final String text;
  final _Tone tone;
}

class _Cell {
  const _Cell(this.text, {this.muted = false, this.tone = _Tone.normal})
    : employee = null,
      statuses = null,
      withCode = true;

  const _Cell.employee(ReportEmployee this.employee, {this.withCode = true})
    : text = '',
      muted = false,
      tone = _Tone.normal,
      statuses = null;

  const _Cell.status(List<_Status> this.statuses)
    : text = '',
      muted = false,
      tone = _Tone.normal,
      employee = null,
      withCode = true;

  final String text;
  final bool muted;
  final _Tone tone;
  final ReportEmployee? employee;
  final bool withCode;
  final List<_Status>? statuses;
}

class _Row {
  const _Row(this.cells);

  final List<_Cell> cells;
}

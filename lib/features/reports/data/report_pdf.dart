import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/time/ist.dart';
import '../../../core/time/ist_format.dart';
import '../domain/report.dart';

/// Hands a finished PDF to the phone's share sheet (save, WhatsApp, print).
abstract interface class PdfSharer {
  Future<void> share(Uint8List bytes, String filename);
}

class PrintingPdfSharer implements PdfSharer {
  const PrintingPdfSharer();

  @override
  Future<void> share(Uint8List bytes, String filename) =>
      Printing.sharePdf(bytes: bytes, filename: filename);
}

/// "attendance-2026-11-01-to-2026-11-30.pdf".
String reportFileName(ReportRange range) {
  final DateFormat f = DateFormat('yyyy-MM-dd');
  return 'attendance-${f.format(range.from)}-to-${f.format(range.to)}.pdf';
}

String _km(int metres) => (metres / 1000).toStringAsFixed(1);

String _hours(int minutes) =>
    minutes == 0 ? '-' : IstFormat.duration(Duration(minutes: minutes));

/// The report as a PDF: a summary row per person, then (with [detail]) every
/// person's days, narrowed by [filter]. Plain ASCII text, so the built-in
/// PDF font can write all of it.
Future<Uint8List> buildReportPdf({
  required ReportRange range,
  required List<PersonReport> people,
  required StatusFilter filter,
  required bool detail,
  required DateTime madeAt,
}) {
  final pw.Document doc = pw.Document(
    title: 'Attendance report',
    author: 'Diamond Agritech',
  );
  const pw.TextStyle small = pw.TextStyle(fontSize: 8);
  const pw.TextStyle head = pw.TextStyle(
    fontSize: 8,
    fontWeight: pw.FontWeight.bold,
  );
  const PdfColor shade = PdfColor.fromInt(0xFFEFF3F1);

  pw.Widget table(List<String> headers, List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: head,
        cellStyle: small,
        headerDecoration: const pw.BoxDecoration(color: shade),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        cellAlignment: pw.Alignment.centerLeft,
      );

  final String rangeText =
      '${IstFormat.date(range.from)} to ${IstFormat.date(range.to)}';
  final DateTime madeWall = Ist.wallClock(madeAt);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (pw.Context c) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            pw.Text('Diamond Agritech - Attendance report', style: head),
            pw.Text(rangeText, style: small),
          ],
        ),
      ),
      footer: (pw.Context c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            'Made ${DateFormat('d MMM yyyy, h:mm a').format(madeWall)} (India time)',
            style: small,
          ),
          pw.Text('Page ${c.pageNumber} of ${c.pagesCount}', style: small),
        ],
      ),
      build: (pw.Context c) => <pw.Widget>[
        pw.Text(
          'Attendance report',
          style: const pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '$rangeText  |  ${people.length} '
          '${people.length == 1 ? 'person' : 'people'}  |  '
          'Days shown: ${filter.label}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 10),
        if (people.isEmpty)
          pw.Text('No records in this range.')
        else
          table(
            <String>[
              'Code',
              'Name',
              'Attendance',
              'Present',
              'Half day',
              'Absent',
              'Sick',
              'Casual',
              'Waiting',
              'Duty time',
              'Km',
              'Visits',
            ],
            <List<String>>[
              for (final PersonReport p in people)
                <String>[
                  p.userCode,
                  p.name,
                  formatDays(p.attendance),
                  '${p.present}',
                  '${p.halfDays}',
                  '${p.absent}',
                  '${p.sickLeave}',
                  '${p.casualLeave}',
                  '${p.waiting}',
                  _hours(p.workedMinutes),
                  _km(p.distanceM),
                  '${p.visits}',
                ],
            ],
          ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Attendance counts a present day as 1 and a half day as 0.5.',
          style: small,
        ),
        if (detail)
          for (final PersonReport p in people) ...<pw.Widget>[
            pw.SizedBox(height: 14),
            pw.Text(
              '${p.name} (${p.userCode})',
              style: const pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            if (p.filtered(filter).isEmpty)
              pw.Text('No days match.', style: small)
            else
              table(
                <String>[
                  'Date',
                  'Day',
                  'Status',
                  'Duty on',
                  'Duty off',
                  'Duty time',
                  'Km',
                  'Visits',
                ],
                <List<String>>[
                  for (final ReportDay d in p.filtered(filter))
                    <String>[
                      IstFormat.date(d.day),
                      DateFormat('EEE').format(d.day),
                      d.statusLabel,
                      d.dutyOnAt == null ? '-' : IstFormat.time(d.dutyOnAt!),
                      d.dutyOffAt == null
                          ? '-'
                          : '${IstFormat.time(d.dutyOffAt!)}'
                                '${d.autoEnded ? ' (auto)' : ''}',
                      _hours(d.workedMinutes ?? 0),
                      d.distanceM == null ? '-' : _km(d.distanceM!),
                      d.visits == 0 ? '-' : '${d.visits}',
                    ],
                ],
              ),
          ],
      ],
    ),
  );
  return doc.save();
}

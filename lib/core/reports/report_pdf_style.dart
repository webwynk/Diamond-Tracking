import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../theme/app_colors.dart';

/// The design-system colours as the PDF library wants them, so no hex literal
/// lives outside [AppColors]. Reports are printed, so text is only ever the
/// brand shade or darker, or a neutral dark enough for paper.
abstract final class ReportPdfColors {
  const ReportPdfColors._();

  static PdfColor _from(Color c) => PdfColor.fromInt(c.toARGB32());

  static final PdfColor brand = _from(AppColors.primary600);
  static final PdfColor brandDark = _from(AppColors.primary800);
  static final PdfColor brandTint = _from(AppColors.primary50);
  static final PdfColor brandBorder = _from(AppColors.primary100);
  static final PdfColor white = _from(AppColors.neutral0);
  static final PdfColor zebra = _from(AppColors.neutral50);
  static final PdfColor line = _from(AppColors.neutral200);
  static final PdfColor text = _from(AppColors.neutral900);
  static final PdfColor textSoft = _from(AppColors.neutral600);
  static final PdfColor textMuted = _from(AppColors.neutral500);
  static final PdfColor warningBg = _from(AppColors.warningBg);
  static final PdfColor warningText = _from(AppColors.warningText);
  static final PdfColor errorBg = _from(AppColors.errorBg);
  static final PdfColor errorText = _from(AppColors.errorText);
  static final PdfColor successBg = _from(AppColors.successBg);
}

/// The two faces a report is set in.
class ReportFonts {
  const ReportFonts({required this.regular, required this.bold});

  /// The report's real typeface, DM Sans (a static Regular and Bold cut of the
  /// bundled variable font: the PDF library cannot pick a weight from it).
  /// Names in other scripts than Latin have no glyphs in it and print as boxes;
  /// reports are English only (PRD).
  static Future<ReportFonts> load([AssetBundle? bundle]) async {
    final assets = bundle ?? rootBundle;
    final regular = await assets.load('assets/fonts/DMSans-Regular.ttf');
    final bold = await assets.load('assets/fonts/DMSans-Bold.ttf');
    return ReportFonts(regular: pw.Font.ttf(regular), bold: pw.Font.ttf(bold));
  }

  final pw.Font regular;
  final pw.Font bold;
}

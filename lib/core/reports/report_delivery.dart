import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

/// How a finished report leaves the app: the phone's share sheet (WhatsApp,
/// email, Drive, save to files) or the print dialog (which can also save a PDF).
///
/// A seam so tests never open a system dialog.
abstract class ReportDelivery {
  /// Opens the system share sheet with the PDF attached as [fileName].
  Future<void> share(Uint8List bytes, String fileName);

  /// Opens the system print dialog with a preview of the PDF.
  Future<void> printOrSave(Uint8List bytes, String fileName);
}

/// The real delivery, through the `printing` plugin.
class PrintingReportDelivery implements ReportDelivery {
  const PrintingReportDelivery();

  @override
  Future<void> share(Uint8List bytes, String fileName) =>
      Printing.sharePdf(bytes: bytes, filename: fileName);

  @override
  Future<void> printOrSave(Uint8List bytes, String fileName) async {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: fileName,
      dynamicLayout: false,
    );
  }
}

final reportDeliveryProvider = Provider<ReportDelivery>(
  (ref) => const PrintingReportDelivery(),
);

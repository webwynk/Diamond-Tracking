import 'package:flutter/foundation.dart';

import 'visit_record.dart';

/// One page of an employee's visits, newest first.
@immutable
class VisitPage {
  const VisitPage({required this.visits, required this.hasMore});

  final List<VisitRecord> visits;

  /// More, older visits exist after this page.
  final bool hasMore;
}

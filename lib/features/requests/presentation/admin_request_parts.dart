import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../duty/domain/duty_day.dart';
import '../application/requests_providers.dart';
import '../domain/app_request.dart';
import '../domain/request_failure.dart';

/// The request's kind in words: "Short duty", "Attendance request",
/// "Sick leave".
String adminRequestKind(AppRequest r) => switch (r.kind) {
  RequestKind.shortDuty => 'Short duty',
  RequestKind.attendance => 'Attendance request',
  RequestKind.leave => r.leaveType?.label ?? 'Leave',
};

/// The decision in words: "Approved: Half day".
String requestOutcome(AppRequest r) {
  if (r.status != RequestStatus.approved || r.decision == null) {
    return r.status.label;
  }
  if (r.kind == RequestKind.leave) return r.status.label;
  return '${r.status.label}: ${r.decision!.label}';
}

/// How long ago: "Just now", "12m", "3h", "2d".
String requestAgo(DateTime t, DateTime now) {
  final Duration d = now.difference(t);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}

/// Round initials in the kind's colours, with a small kind badge.
class RequestAvatar extends StatelessWidget {
  const RequestAvatar({
    required this.initials,
    required this.tone,
    required this.icon,
    this.size = 40,
    super.key,
  });

  final String initials;
  final DsStatus tone;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double badge = size * 0.45;
    return SizedBox(
      width: size + 3,
      height: size + 3,
      child: Stack(
        children: <Widget>[
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tone.tint, shape: BoxShape.circle),
            child: Text(
              initials,
              style: DsText.label.copyWith(
                color: tone.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: tone.text,
                shape: BoxShape.circle,
                border: Border.all(color: DsColors.white, width: 2),
              ),
              child: Icon(icon, size: badge * 0.5, color: DsColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sends the admin's decision and refreshes every list. Answers the error
/// in plain words, or null when it worked.
Future<String?> sendDecision(
  WidgetRef ref,
  AppRequest r,
  DayStatus decision, {
  String? note,
}) async {
  try {
    await ref.read(requestsRepositoryProvider).decide(r.id, decision, note);
    refreshRequests(ref, r.id);
    return null;
  } on Object catch (e) {
    refreshRequests(ref, r.id);
    return mapRequestError(e).message;
  }
}

/// The colour of a decision button: red for no, blue for half, the brand
/// (or purple for leave) for yes.
Color decisionColor(RequestKind kind, DayStatus d) => switch (d) {
  DayStatus.absent => DsColors.dangerText,
  DayStatus.halfDay => const Color(0xFF0369A1),
  DayStatus.leave => DsStatus.leave.text,
  _ => DsColors.primary,
};

/// A white card with a little shadow, the list's building block.
class RequestCardBox extends StatelessWidget {
  const RequestCardBox({required this.child, this.onTap, super.key});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: DsColors.white,
      borderRadius: DsRadius.large,
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Color(0x0D0F172A),
          blurRadius: 12,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      borderRadius: DsRadius.large,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/widgets/app_status_pill.dart';
import '../application/requests_providers.dart';
import '../data/requests_repository.dart';
import '../domain/app_request.dart';

/// "Attendance · 18 Nov 2026", "Sick leave · 3 days from 20 Nov 2026".
String requestTitle(AppRequest r) => switch (r.kind) {
  RequestKind.attendance => 'Attendance · ${IstFormat.date(r.day!)}',
  RequestKind.shortDuty => 'Short duty · ${IstFormat.date(r.day!)}',
  RequestKind.leave =>
    '${r.leaveType?.label ?? 'Leave'} · '
        '${r.dates.length == 1 ? IstFormat.date(r.dates.first) : '${r.dates.length} days from ${IstFormat.date(r.dates.first)}'}',
};

/// The decision in words: "Approved: Half day".
String requestOutcome(AppRequest r) {
  if (r.status != RequestStatus.approved || r.decision == null) {
    return r.status.label;
  }
  if (r.kind == RequestKind.leave) return r.status.label;
  return '${r.status.label}: ${r.decision!.label}';
}

class RequestStatusPill extends StatelessWidget {
  const RequestStatusPill({required this.request, super.key});

  final AppRequest request;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (request.status) {
      RequestStatus.pending => (AppColors.warningText, AppColors.warningBg),
      RequestStatus.approved => (AppColors.success, AppColors.successBg),
      RequestStatus.rejected => (AppColors.error, AppColors.errorBg),
      RequestStatus.cancelled => (AppColors.neutral600, AppColors.neutral100),
    };
    return AppStatusPill.custom(
      color: fg,
      backgroundColor: bg,
      label: request.status.label,
    );
  }
}

class RequestTile extends StatelessWidget {
  const RequestTile({
    required this.request,
    required this.onTap,
    super.key,
    this.personName,
  });

  final AppRequest request;
  final String? personName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(switch (request.kind) {
      RequestKind.attendance => Icons.event_available_rounded,
      RequestKind.leave => Icons.beach_access_rounded,
      RequestKind.shortDuty => Icons.timelapse_rounded,
    }, color: AppColors.primary600),
    title: Text(personName ?? requestTitle(request)),
    subtitle: Text(
      personName == null
          ? 'Sent ${IstFormat.time(request.createdAt)}'
                ', ${IstFormat.shortDate(request.createdAt)}'
          : requestTitle(request),
    ),
    trailing: RequestStatusPill(request: request),
    onTap: onTap,
  );
}

/// A request's photo, loaded through the photos function. Tap for full size.
class RequestPhoto extends ConsumerWidget {
  const RequestPhoto({required this.requestId, this.index = 0, super.key});

  final int requestId;

  /// 0 is the first photo, 1 and 2 the extra ones.
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PhotoSource src = ref
        .watch(requestsRepositoryProvider)
        .photo(requestId, index: index);
    Widget image(BoxFit fit) => Image.network(
      src.url,
      headers: src.headers,
      fit: fit,
      errorBuilder: (_, _, _) => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.x4),
          child: Text('The photo could not be loaded.'),
        ),
      ),
      loadingBuilder: (_, Widget child, ImageChunkEvent? p) =>
          p == null ? child : const Center(child: CircularProgressIndicator()),
    );
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Photo')),
            body: InteractiveViewer(
              child: Center(child: image(BoxFit.contain)),
            ),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 220,
          width: double.infinity,
          color: AppColors.neutral100,
          child: image(BoxFit.cover),
        ),
      ),
    );
  }
}

/// "Show more" at the end of a request list (L70).
class ShowMoreButton extends StatelessWidget {
  const ShowMoreButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.x4),
    child: Center(
      child: TextButton(onPressed: onPressed, child: const Text('Show more')),
    ),
  );
}

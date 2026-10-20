import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../domain/entities/visit_record.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_pagination_loader.dart';
import '../../../../shared/widgets/app_skeletons.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import 'admin_visit_details_page.dart';
import 'controllers/admin_visits_controller.dart';
import 'controllers/admin_visits_state.dart';
import 'widgets/admin_visit_tile.dart';

/// Visits of one employee (PRD F10), newest first, a page at a time.
///
/// Opened from the employee profile. Each row shows the photo (or why there is
/// none), the store, when (IST) and the note; a tap opens the visit.
class AdminVisitsPage extends ConsumerStatefulWidget {
  const AdminVisitsPage({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
  });

  final String employeeId;
  final String employeeName;
  final String employeeCode;

  @override
  ConsumerState<AdminVisitsPage> createState() => _AdminVisitsPageState();
}

class _AdminVisitsPageState extends ConsumerState<AdminVisitsPage> {
  /// How close to the end of the list, in pixels, the next page is asked for.
  static const double _loadAhead = 300;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - _loadAhead) {
      ref
          .read(adminVisitsControllerProvider(widget.employeeId).notifier)
          .loadMore();
    }
  }

  void _open(VisitRecord visit) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminVisitDetailsPage(
          visit: visit,
          employeeName: widget.employeeName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminVisitsControllerProvider(widget.employeeId));
    final notifier = ref.read(
      adminVisitsControllerProvider(widget.employeeId).notifier,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        leading: AppTopBarLeading.back,
        leadingKey: const Key('btn-visits-back'),
        title: 'Visits',
        subtitle: '${widget.employeeName} · ${widget.employeeCode}',
      ),
      body: switch (state.load) {
        AdminVisitsLoad.loading => const AppListSkeleton(),
        AdminVisitsLoad.failed => AppErrorView(
          title: "Couldn't load visits",
          onRetry: notifier.refresh,
        ),
        AdminVisitsLoad.loaded when state.visits.isEmpty => const Center(
          child: AppEmptyState(
            icon: Icons.storefront_outlined,
            title: 'No visits yet',
            description:
                'Visits this employee adds while on duty will appear here.',
          ),
        ),
        AdminVisitsLoad.loaded => RefreshIndicator(
          onRefresh: notifier.refresh,
          child: ListView.separated(
            key: const Key('visits-list'),
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.x4),
            itemCount: state.visits.length + 1,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.x2),
            itemBuilder: (context, index) {
              if (index == state.visits.length) {
                return _footer(state, notifier);
              }
              final visit = state.visits[index];
              return AppCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
                child: AdminVisitTile(visit: visit, onTap: () => _open(visit)),
              );
            },
          ),
        ),
      },
    );
  }

  Widget _footer(AdminVisitsState state, AdminVisitsNotifier notifier) {
    if (state.isLoadingMore) return const AppPaginationLoader();
    if (state.loadMoreFailed) {
      return Column(
        children: <Widget>[
          Text(
            "Couldn't load older visits.",
            key: const Key('visits-load-more-failed'),
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          TextButton(
            key: const Key('btn-visits-retry-more'),
            onPressed: notifier.loadMore,
            child: const Text('Try again'),
          ),
        ],
      );
    }
    if (state.hasMore) {
      return TextButton(
        key: const Key('btn-visits-load-more'),
        onPressed: notifier.loadMore,
        child: const Text('Load older visits'),
      );
    }
    return const SizedBox(height: AppSpacing.x4);
  }
}

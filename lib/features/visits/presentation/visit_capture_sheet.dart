import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import 'controllers/visit_capture_controller.dart';

/// Screen 10 — Visit Capture bottom sheet modal.
///
/// Adheres strictly to PRD F10 (as amended 2026-10-18):
/// - Field employees capture manual visits with active GPS position.
/// - Optional store/shop name (max 80 chars).
/// - Optional observation note (max 200 chars).
/// - Optional in-situ photo strictly via camera (gallery unreachable).
/// - No skip penalty or mandatory reason; visits can be saved directly with or without photo.
class VisitCaptureSheet extends ConsumerStatefulWidget {
  const VisitCaptureSheet({
    super.key,
    required this.dutySessionId,
    required this.employeeId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.storeName,
    this.initialNote,
    this.onSaved,
  });

  final String dutySessionId;
  final String employeeId;
  final String? storeName;
  final double latitude;
  final double longitude;

  /// How close the GPS fix is, in metres. Kept with the visit as evidence.
  final double? accuracy;
  final String? initialNote;
  final VoidCallback? onSaved;

  /// Shows the Visit Capture bottom sheet modal over the current screen.
  static Future<bool?> show(
    BuildContext context, {
    required String dutySessionId,
    required String employeeId,
    required double latitude,
    required double longitude,
    double? accuracy,
    String? storeName,
    String? initialNote,
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.neutral900.withValues(alpha: 0.40),
      builder: (context) => VisitCaptureSheet(
        dutySessionId: dutySessionId,
        employeeId: employeeId,
        storeName: storeName,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        initialNote: initialNote,
        onSaved: onSaved,
      ),
    );
  }

  @override
  ConsumerState<VisitCaptureSheet> createState() => _VisitCaptureSheetState();
}

class _VisitCaptureSheetState extends ConsumerState<VisitCaptureSheet> {
  late final TextEditingController _storeNameController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final initialStore = widget.storeName ?? '';
    _storeNameController = TextEditingController(text: initialStore);
    _noteController = TextEditingController();

    // Initialize visit state after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(visitCaptureControllerProvider.notifier)
          .initVisit(
            storeName: initialStore,
            latitude: widget.latitude,
            longitude: widget.longitude,
            accuracy: widget.accuracy,
            initialNote: widget.initialNote,
          );
      final currentNote = ref.read(visitCaptureControllerProvider).note;
      _noteController.text = currentNote;
    });
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Saves the visit without a photo. No reason is asked and no flag is set
  /// (PRD F10, BR-12).
  Future<void> _handleSkip() async {
    ref.read(visitCaptureControllerProvider.notifier).skipPhoto();
    await _handleSave();
  }

  Future<void> _handleSave() async {
    final notifier = ref.read(visitCaptureControllerProvider.notifier);
    final success = await notifier.saveVisit(
      dutySessionId: widget.dutySessionId,
      employeeId: widget.employeeId,
    );

    if (success && mounted) {
      widget.onSaved?.call();
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visitCaptureControllerProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.neutral0,
        borderRadius: AppRadius.xlTop,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x3,
            AppSpacing.x4,
            AppSpacing.x6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neutral300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x3),

              // Header Row: Title & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add visit', style: AppTypography.h3),
                  InkWell(
                    key: const Key('close-visit-sheet-btn'),
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.neutral100,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: AppColors.neutral600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x4),

              // GPS Arrival Strip & Location details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.x3),
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(
                    color: AppColors.primary100.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.location_on,
                        size: 20,
                        color: AppColors.primary600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.storeName.isEmpty
                                ? 'Field location'
                                : state.storeName,
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              fontVariations: const [
                                FontVariation('wght', 600),
                              ],
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Recorded at ${state.arrivalTime}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x4),

              // Store / Shop Name Input (Optional, max 80 chars)
              Text(
                'STORE OR SHOP NAME (OPTIONAL)',
                style: AppTypography.overline.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x3,
                  vertical: AppSpacing.x2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.neutral0,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.neutral300),
                ),
                child: TextField(
                  key: const Key('store-name-input'),
                  controller: _storeNameController,
                  maxLength: 80,
                  style: AppTypography.bodyLarge,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'e.g. Kisan Seva Kendra',
                    hintStyle: TextStyle(
                      color: AppColors.neutral400,
                      fontSize: 15,
                      fontFamily: AppTypography.fontFamily,
                    ),
                    counterText: '',
                  ),
                  onChanged: (text) {
                    ref
                        .read(visitCaptureControllerProvider.notifier)
                        .updateStoreName(text);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.x4),

              // Photo Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PHOTO',
                    style: AppTypography.overline.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  // Only once a real photo exists: until then nothing here
                  // may suggest the visit is verified.
                  if (state.photoPath != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.verified,
                          size: 14,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: AppSpacing.x1),
                        Text(
                          'Verified In-situ',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.info,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),

              // 200px Tall Photo Container with In-Situ Geotag Overlay
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.neutral200),
                  color: AppColors.neutral100,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The photo taken, or a field placeholder until there is one
                    if (state.photoPath != null &&
                        File(state.photoPath!).existsSync())
                      Image.file(
                        File(state.photoPath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                      )
                    else
                      // Daylight Indian Agricultural Crop Field Placeholder
                      const _FarmFieldPlaceholder(),

                    // Retake / Take Camera Button (Top-Right)
                    Positioned(
                      top: AppSpacing.x3,
                      right: AppSpacing.x3,
                      child: InkWell(
                        key: const Key('retake-photo-btn'),
                        onTap: () {
                          ref
                              .read(visitCaptureControllerProvider.notifier)
                              .takePhoto();
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.neutral0,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.neutral900.withValues(
                                alpha: 0.10,
                              ),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.flip_camera_ios,
                            size: 20,
                            color: AppColors.neutral600,
                          ),
                        ),
                      ),
                    ),

                    // Geotag Chip Overlay (Bottom-Left): the real fix and time
                    Positioned(
                      bottom: AppSpacing.x3,
                      left: AppSpacing.x3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.neutral900.withValues(alpha: 0.70),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 13,
                                  color: AppColors.primary300,
                                ),
                                const SizedBox(width: AppSpacing.x1),
                                Text(
                                  state.geotagTimestamp,
                                  style: const TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.satellite_alt,
                                  size: 13,
                                  color: AppColors.successBg,
                                ),
                                const SizedBox(width: AppSpacing.x1),
                                Text(
                                  state.geotagCoordinates,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x4),

              // Note Section
              Text(
                'NOTE (OPTIONAL)',
                style: AppTypography.overline.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),

              Container(
                height: 96,
                padding: const EdgeInsets.all(AppSpacing.x3),
                decoration: BoxDecoration(
                  color: AppColors.neutral0,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.neutral300),
                ),
                child: Stack(
                  children: [
                    TextField(
                      key: const Key('visit-notes-input'),
                      controller: _noteController,
                      maxLines: 2,
                      maxLength: 200,
                      style: AppTypography.bodyLarge,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Add observation details...',
                        hintStyle: TextStyle(
                          color: AppColors.neutral400,
                          fontSize: 16,
                          fontFamily: AppTypography.fontFamily,
                        ),
                        counterText: '',
                      ),
                      onChanged: (text) {
                        ref
                            .read(visitCaptureControllerProvider.notifier)
                            .updateNote(text);
                      },
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Text(
                        '${state.note.length}/200',
                        style: AppTypography.caption.tabular.copyWith(
                          color: AppColors.neutral400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x6),

              // Actions Section
              AppButton(
                key: const Key('save-visit-btn'),
                label: state.isSaved ? 'Saved' : 'Save visit',
                onPressed: state.isSaving ? null : _handleSave,
                isLoading: state.isSaving,
                loadingLabel: 'Syncing...',
                icon: Icon(
                  state.isSaved ? Icons.task_alt : Icons.check_circle_outline,
                  size: 18,
                  color: Colors.white,
                ),
                isFullWidth: true,
              ),
              const SizedBox(height: AppSpacing.x2),

              SizedBox(
                width: double.infinity,
                height: AppSizes.controlHeight,
                child: TextButton(
                  key: const Key('skip-photo-btn'),
                  onPressed: state.isSaving ? null : _handleSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                  ),
                  child: Text(
                    'Skip photo',
                    style: AppTypography.label.withColor(
                      AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter rendering a scenic Indian agricultural crop field under daylight
/// for reliable in-situ previews before physical camera snaps.
class _FarmFieldPlaceholder extends StatelessWidget {
  const _FarmFieldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FarmFieldPainter(),
      size: const Size(double.infinity, 200),
    );
  }
}

class _FarmFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Sky gradient (daylight sunny sky)
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF87CEEB), // Soft daylight sky blue
          Color(0xFFE0F2FE),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.4));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.4),
      skyPaint,
    );

    // Distant tree line
    final distantTreesPaint = Paint()..color = const Color(0xFF2E6F40);
    final treePath = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.36,
        size.width * 0.5,
        size.height * 0.39,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.35,
        size.width,
        size.height * 0.38,
      )
      ..lineTo(size.width, size.height * 0.45)
      ..lineTo(0, size.height * 0.45)
      ..close();
    canvas.drawPath(treePath, distantTreesPaint);

    // Lush green agricultural crop rows
    final fieldPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF388E3C), // Vibrant green crop rows
              Color(0xFF1B5E20), // Rich deep foliage
            ],
          ).createShader(
            Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.6),
          );

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.6),
      fieldPaint,
    );

    // Linear furrow lines representing organized field cultivation rows
    final furrowPaint = Paint()
      ..color = const Color(0xFF2E4C20).withValues(alpha: 0.5)
      ..strokeWidth = 2;

    for (int i = 0; i < 9; i++) {
      final startX = size.width * (0.2 + (i * 0.08));
      final endX = size.width * (0.05 + (i * 0.12));
      canvas.drawLine(
        Offset(startX, size.height * 0.42),
        Offset(endX, size.height),
        furrowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

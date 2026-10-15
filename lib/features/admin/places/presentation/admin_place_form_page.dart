import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import 'controllers/admin_place_form_controller.dart';
import 'controllers/admin_places_state.dart';
import 'widgets/admin_place_form_sheet.dart';
import 'widgets/admin_place_form_top_bar.dart';
import 'widgets/admin_place_geofence_map.dart';

/// Screen 25 — Create / Edit Place (Admin).
///
/// Comprehensive geofence designer and boundary editor:
/// - Floating inset app bar with Close, Title ("New place" / "Edit place"), and Save
/// - Upper 55% dynamic geofence map viewport with scale bar, center teardrop pin,
///   radius envelope, and adjacent overlapping geofence ("Patel Agro Dealer — 320 m away")
/// - Lower 45% scrollable configuration sheet with name input, type chips,
///   interactive radius slider (50m to 2000m), photo prompt info strip,
///   read-only coordinates with copy button, and active toggle switch.
class AdminPlaceFormPage extends ConsumerStatefulWidget {
  const AdminPlaceFormPage({
    super.key,
    this.place,
    this.onClose,
    this.onSaved,
  });

  final AdminPlaceItem? place;
  final VoidCallback? onClose;
  final VoidCallback? onSaved;

  @override
  ConsumerState<AdminPlaceFormPage> createState() => _AdminPlaceFormPageState();
}

class _AdminPlaceFormPageState extends ConsumerState<AdminPlaceFormPage> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final initialName = widget.place?.name ?? 'Shivpuri Farm';
    _nameController = TextEditingController(text: initialName);
    _nameController.addListener(() {
      ref
          .read(adminPlaceFormControllerProvider.notifier)
          .setName(_nameController.text);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(adminPlaceFormControllerProvider.notifier)
          .initializeForPlace(widget.place);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final notifier = ref.read(adminPlaceFormControllerProvider.notifier);
    notifier.setName(_nameController.text);
    final isValid = notifier.validateAndSave();

    if (isValid) {
      final state = ref.read(adminPlaceFormControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Geofence perimeter for ${state.name} saved successfully.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.of(context).maybePop();
      }
    }
  }

  void _handleCopyCoordinates(String coords) {
    Clipboard.setData(ClipboardData(text: coords));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coordinates copied to clipboard.'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminPlaceFormControllerProvider);
    final notifier = ref.read(adminPlaceFormControllerProvider.notifier);
    final title = state.isEditMode ? 'Edit place' : 'New place';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          // Main Body: Upper 55% Map + Lower 45% Sheet
          Column(
            children: <Widget>[
              // Upper 55% Geofence Map Viewport
              Expanded(
                flex: 55,
                child: AdminPlaceGeofenceMap(
                  radiusMeters: state.radiusMeters,
                  adjacentPlaceName: state.adjacentPlaceName,
                  adjacentDistanceMeters: state.adjacentDistanceMeters,
                  isSatellite: state.isSatellite,
                  onToggleLayers: notifier.toggleSatellite,
                ),
              ),

              // Lower 45% Configuration Bottom Sheet
              Expanded(
                flex: 45,
                child: AdminPlaceFormSheet(
                  nameController: _nameController,
                  selectedType: state.type,
                  radiusMeters: state.radiusMeters,
                  coordinatesText: state.coordinatesText,
                  isActive: state.isActive,
                  errorMessage: state.errorMessage,
                  onTypeChanged: notifier.setType,
                  onRadiusChanged: notifier.setRadius,
                  onActiveChanged: notifier.setIsActive,
                  onCopyCoordinates: () =>
                      _handleCopyCoordinates(state.coordinatesText),
                ),
              ),
            ],
          ),

          // Floating Top App Bar (Inset in SafeArea)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AdminPlaceFormTopBar(
                title: title,
                onClose: widget.onClose ?? () => Navigator.of(context).maybePop(),
                onSave: _handleSave,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

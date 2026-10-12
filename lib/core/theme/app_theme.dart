import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';

/// The single application theme.
///
/// Source of truth: docs/03-DESIGN-SYSTEM.md.
///
/// **Light mode only.** There is deliberately no `dark` counterpart: the app is
/// used outdoors in bright sunlight, a map would have to be styled and tested
/// twice, and every status colour would need its contrast re-verified against a
/// dark surface. [MaterialApp.themeMode] is pinned to [ThemeMode.light] so the
/// system setting is ignored.
///
/// If dark mode is ever wanted, it is a deliberate project with its own
/// contrast verification pass. It is not a switch to flip.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary600,
          brightness: Brightness.light,
        ).copyWith(
          // Pin the roles the design system defines, rather than accepting what
          // fromSeed derives. The seed only gets us close.
          primary: AppColors.primary600,
          onPrimary: AppColors.neutral0,
          primaryContainer: AppColors.primary50,
          onPrimaryContainer: AppColors.primary800,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          error: AppColors.error,
          onError: AppColors.neutral0,
          errorContainer: AppColors.errorBg,
          outline: AppColors.neutral300,
          outlineVariant: AppColors.border,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,

      textTheme: const TextTheme(
        displayLarge: AppTypography.display,
        displayMedium: AppTypography.display,
        displaySmall: AppTypography.h1,
        headlineLarge: AppTypography.h1,
        headlineMedium: AppTypography.h2,
        headlineSmall: AppTypography.h3,
        titleLarge: AppTypography.h3,
        titleMedium: AppTypography.title,
        titleSmall: AppTypography.label,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.body,
        bodySmall: AppTypography.caption,
        labelLarge: AppTypography.label,
        labelMedium: AppTypography.label,
        labelSmall: AppTypography.overline,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary600,
        foregroundColor: AppColors.neutral0,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 20,
          height: 28 / 20,
          fontWeight: FontWeight.w600,
          fontVariations: <FontVariation>[FontVariation('wght', 600)],
          color: AppColors.neutral0,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: AppColors.border),
        ),
      ),

      // 48 dp tall, 12 radius, brand fill. See design system section 11.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary600,
          foregroundColor: AppColors.neutral0,
          disabledBackgroundColor: AppColors.primary300,
          disabledForegroundColor: AppColors.neutral400,
          minimumSize: const Size.fromHeight(AppSizes.controlHeight),
          elevation: 0,
          textStyle: AppTypography.label,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary600,
          disabledForegroundColor: AppColors.neutral400,
          minimumSize: const Size.fromHeight(AppSizes.controlHeight),
          side: const BorderSide(color: AppColors.primary600),
          textStyle: AppTypography.label,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary600,
          disabledForegroundColor: AppColors.neutral400,
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          textStyle: AppTypography.label,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),

      // Every icon button is a full 48 dp target, even when the glyph is 24.
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.neutral600,
          minimumSize: const Size.square(AppSizes.minTouchTarget),
        ),
      ),

      iconTheme: const IconThemeData(
        color: AppColors.neutral600,
        size: AppSizes.icon,
      ),

      // Labels sit ABOVE fields, never as a placeholder only, so build the
      // label outside the field. floatingLabelBehavior is never used.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x3,
        ),
        hintStyle: AppTypography.bodyLarge.copyWith(
          color: AppColors.textDisabled,
        ),
        helperStyle: AppTypography.caption,
        errorStyle: AppTypography.caption.copyWith(color: AppColors.error),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.neutral300),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.neutral300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.primary600, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary600,
        side: const BorderSide(color: AppColors.neutral300),
        labelStyle: AppTypography.label,
        secondaryLabelStyle: AppTypography.label.copyWith(
          color: AppColors.neutral0,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.fullAll),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlTop),
        showDragHandle: true,
        dragHandleColor: AppColors.neutral300,
        dragHandleSize: Size(32, 4),
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
        ),
        titleTextStyle: AppTypography.title,
        contentTextStyle: AppTypography.body,
      ),

      // The one dark surface in a light-only app. See AppColors.snackbarSurface.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.snackbarSurface,
        contentTextStyle: AppTypography.body.copyWith(
          color: AppColors.neutral0,
        ),
        actionTextColor: AppColors.snackbarAction,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary600,
        unselectedItemColor: AppColors.neutral400,
        selectedLabelStyle: AppTypography.caption,
        unselectedLabelStyle: AppTypography.caption,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary600,
        linearTrackColor: AppColors.border,
        circularTrackColor: AppColors.border,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return AppColors.neutral0;
        }),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary600;
          }
          return AppColors.neutral300;
        }),
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        titleTextStyle: AppTypography.title,
        subtitleTextStyle: AppTypography.caption,
        iconColor: AppColors.neutral400,
      ),
    );
  }
}

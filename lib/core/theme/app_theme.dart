import 'package:flutter/material.dart';

/// The single application theme.
///
/// The base Material theme under the design v2 parts (lib/shared/ds):
/// dialogs, date pickers, snack bars, switches and list tiles use it.
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
          seedColor: _C.primary600,
          brightness: Brightness.light,
        ).copyWith(
          // Pin the roles the design system defines, rather than accepting what
          // fromSeed derives. The seed only gets us close.
          primary: _C.primary600,
          onPrimary: _C.neutral0,
          primaryContainer: _C.primary50,
          onPrimaryContainer: _C.primary800,
          surface: _C.surface,
          onSurface: _C.textPrimary,
          error: _C.error,
          onError: _C.neutral0,
          errorContainer: _C.errorBg,
          outline: _C.neutral300,
          outlineVariant: _C.border,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _T.fontFamily,
      scaffoldBackgroundColor: _C.background,
      splashFactory: InkRipple.splashFactory,

      textTheme: const TextTheme(
        displayLarge: _T.display,
        displayMedium: _T.display,
        displaySmall: _T.h1,
        headlineLarge: _T.h1,
        headlineMedium: _T.h2,
        headlineSmall: _T.h3,
        titleLarge: _T.h3,
        titleMedium: _T.title,
        titleSmall: _T.label,
        bodyLarge: _T.bodyLarge,
        bodyMedium: _T.body,
        bodySmall: _T.caption,
        labelLarge: _T.label,
        labelMedium: _T.label,
        labelSmall: _T.overline,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: _C.primary600,
        foregroundColor: _C.neutral0,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _T.fontFamily,
          fontSize: 20,
          height: 28 / 20,
          fontWeight: FontWeight.w600,
          fontVariations: <FontVariation>[FontVariation('wght', 600)],
          color: _C.neutral0,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: _C.border,
        thickness: 1,
        space: 1,
      ),

      cardTheme: const CardThemeData(
        color: _C.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: _D.mdAll,
          side: BorderSide(color: _C.border),
        ),
      ),

      // 48 dp tall, 12 radius, brand fill. See design system section 11.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _C.primary600,
          foregroundColor: _C.neutral0,
          disabledBackgroundColor: _C.primary300,
          disabledForegroundColor: _C.neutral400,
          minimumSize: const Size.fromHeight(_D.controlHeight),
          elevation: 0,
          textStyle: _T.label,
          shape: const RoundedRectangleBorder(borderRadius: _D.mdAll),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _C.primary600,
          disabledForegroundColor: _C.neutral400,
          minimumSize: const Size.fromHeight(_D.controlHeight),
          side: const BorderSide(color: _C.primary600),
          textStyle: _T.label,
          shape: const RoundedRectangleBorder(borderRadius: _D.mdAll),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _C.primary600,
          disabledForegroundColor: _C.neutral400,
          minimumSize: const Size(_D.minTouchTarget, _D.minTouchTarget),
          textStyle: _T.label,
          shape: const RoundedRectangleBorder(borderRadius: _D.mdAll),
        ),
      ),

      // Every icon button is a full 48 dp target, even when the glyph is 24.
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: _C.neutral600,
          minimumSize: const Size.square(_D.minTouchTarget),
        ),
      ),

      iconTheme: const IconThemeData(color: _C.neutral600, size: _D.icon),

      // Labels sit ABOVE fields, never as a placeholder only, so build the
      // label outside the field. floatingLabelBehavior is never used.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _C.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: _D.x3,
          vertical: _D.x3,
        ),
        hintStyle: _T.bodyLarge.copyWith(color: _C.textDisabled),
        helperStyle: _T.caption,
        errorStyle: _T.caption.copyWith(color: _C.error),
        border: const OutlineInputBorder(
          borderRadius: _D.mdAll,
          borderSide: BorderSide(color: _C.neutral300),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: _D.mdAll,
          borderSide: BorderSide(color: _C.neutral300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: _D.mdAll,
          borderSide: BorderSide(color: _C.primary600, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: _D.mdAll,
          borderSide: BorderSide(color: _C.error, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: _D.mdAll,
          borderSide: BorderSide(color: _C.error, width: 2),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: _C.surface,
        selectedColor: _C.primary600,
        side: const BorderSide(color: _C.neutral300),
        labelStyle: _T.label,
        secondaryLabelStyle: _T.label.copyWith(color: _C.neutral0),
        shape: const RoundedRectangleBorder(borderRadius: _D.fullAll),
        padding: const EdgeInsets.symmetric(horizontal: _D.x3),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _C.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: _D.xlTop),
        showDragHandle: true,
        dragHandleColor: _C.neutral300,
        dragHandleSize: Size(32, 4),
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: _C.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_D.xl)),
        ),
        titleTextStyle: _T.title,
        contentTextStyle: _T.body,
      ),

      // The one dark surface in a light-only app. See _C.snackbarSurface.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _C.snackbarSurface,
        contentTextStyle: _T.body.copyWith(color: _C.neutral0),
        actionTextColor: _C.snackbarAction,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: _D.mdAll),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _C.surface,
        selectedItemColor: _C.primary600,
        unselectedItemColor: _C.neutral400,
        selectedLabelStyle: _T.caption,
        unselectedLabelStyle: _T.caption,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _C.primary600,
        linearTrackColor: _C.border,
        circularTrackColor: _C.border,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return _C.neutral0;
        }),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return _C.primary600;
          }
          return _C.neutral300;
        }),
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: _D.x4),
        titleTextStyle: _T.title,
        subtitleTextStyle: _T.caption,
        iconColor: _C.neutral400,
      ),
    );
  }
}

/// The colours the base theme uses.
abstract final class _C {
  static const Color primary50 = Color(0xFFE8F3F8);
  static const Color primary300 = Color(0xFF76B9D2);
  static const Color primary600 = Color(0xFF016893);
  static const Color primary800 = Color(0xFF01425A);
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral300 = Color(0xFFCBD5E1);
  static const Color neutral400 = Color(0xFF94A3B8);
  static const Color neutral600 = Color(0xFF475569);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = neutral0;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textDisabled = neutral400;
  static const Color snackbarSurface = Color(0xFF1E293B);
  static const Color snackbarAction = Color(0xFF4AA5C6);
}

/// Sizes the base theme uses.
abstract final class _D {
  static const double x3 = 12;
  static const double x4 = 16;
  static const double xl = 24;
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(12));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(999));
  static const BorderRadius xlTop = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const double minTouchTarget = 48;
  static const double controlHeight = 48;
  static const double icon = 24;
}

/// Text styles the base theme uses (DM Sans).
abstract final class _T {
  static const String fontFamily = 'DMSans';

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    fontVariations: <FontVariation>[FontVariation('wght', 700)],
    color: _C.textPrimary,
  );
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
    fontVariations: <FontVariation>[FontVariation('wght', 700)],
    color: _C.textPrimary,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    color: _C.textPrimary,
  );
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    color: _C.textPrimary,
  );
  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    color: _C.textPrimary,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    fontVariations: <FontVariation>[FontVariation('wght', 400)],
    color: _C.textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    fontVariations: <FontVariation>[FontVariation('wght', 400)],
    color: _C.textPrimary,
  );
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    fontVariations: <FontVariation>[FontVariation('wght', 500)],
    color: _C.textPrimary,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    fontVariations: <FontVariation>[FontVariation('wght', 400)],
    color: _C.textSecondary,
  );
  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    color: _C.textSecondary,
    letterSpacing: 0.5,
  );
}

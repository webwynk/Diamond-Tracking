import 'dart:math' as math;

import 'package:diamond_tracking/core/theme/app_colors.dart';
import 'package:diamond_tracking/core/theme/app_dimens.dart';
import 'package:diamond_tracking/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.x contrast ratio between two colours. 1.0 to 21.0.
double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double lighter = math.max(la, lb);
  final double darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Brand tokens match docs/03-DESIGN-SYSTEM.md', () {
    test('the brand colour is exactly #016893', () {
      expect(AppColors.primary600, const Color(0xFF016893));
    });

    test('page background, surface and primary text are correct', () {
      expect(AppColors.background, const Color(0xFFF8FAFC));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.textPrimary, const Color(0xFF0F172A));
    });

    test('semantic colours are correct', () {
      expect(AppColors.success, const Color(0xFF16A34A));
      expect(AppColors.warning, const Color(0xFFF59E0B));
      expect(AppColors.error, const Color(0xFFDC2626));
      expect(AppColors.info, const Color(0xFF0284C7));
    });
  });

  group('Accessibility — contrast is verified, not assumed', () {
    test('white text on the brand colour passes WCAG AA (>= 4.5:1)', () {
      final double ratio = _contrast(AppColors.neutral0, AppColors.primary600);
      expect(ratio, greaterThanOrEqualTo(4.5));
      // The design system documents 6.17:1. Allow for rounding.
      expect(ratio, closeTo(6.17, 0.1));
    });

    test('brand text on white passes WCAG AA', () {
      expect(
        _contrast(AppColors.primary600, AppColors.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('primary text on the page background passes AA', () {
      expect(
        _contrast(AppColors.textPrimary, AppColors.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('secondary text on the page background passes AA', () {
      expect(
        _contrast(AppColors.textSecondary, AppColors.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('the snackbar action colour passes AA on the snackbar surface', () {
      // The one deliberately dark surface in a light-only app.
      expect(
        _contrast(AppColors.snackbarAction, AppColors.snackbarSurface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('primary500 and lighter are NOT safe for text on white', () {
      // Documents why the design system restricts text to primary600 and
      // darker. If this ever starts passing, the ramp has drifted.
      expect(_contrast(AppColors.primary500, AppColors.surface), lessThan(4.5));
      expect(_contrast(AppColors.primary400, AppColors.surface), lessThan(4.5));
    });
  });

  group('Status is colour PLUS a label, never colour alone', () {
    test('every status colour has a matching label and background', () {
      for (final String key in AppStatusColors.colours.keys) {
        expect(
          AppStatusColors.labels[key],
          isNotNull,
          reason: 'status "$key" has a colour but no label',
        );
        expect(
          AppStatusColors.labels[key],
          isNotEmpty,
          reason: 'status "$key" has an empty label',
        );
        expect(
          AppStatusColors.backgrounds[key],
          isNotNull,
          reason: 'status "$key" has no pill background',
        );
      }
    });

    test('all five PRD statuses are present', () {
      expect(
        AppStatusColors.colours.keys,
        containsAll(<String>['active', 'stale', 'suspect', 'off', 'blocked']),
      );
    });
  });

  group('Type scale', () {
    test('sizes and line heights match the design system', () {
      expect(AppTypography.display.fontSize, 32);
      expect(AppTypography.h1.fontSize, 28);
      expect(AppTypography.h2.fontSize, 24);
      expect(AppTypography.h3.fontSize, 20);
      expect(AppTypography.title.fontSize, 18);
      expect(AppTypography.bodyLarge.fontSize, 16);
      expect(AppTypography.body.fontSize, 14);
      expect(AppTypography.label.fontSize, 13);
      expect(AppTypography.caption.fontSize, 12);
      expect(AppTypography.overline.fontSize, 11);
    });

    test('every style uses the bundled DM Sans family', () {
      for (final TextStyle s in <TextStyle>[
        AppTypography.display,
        AppTypography.h1,
        AppTypography.h2,
        AppTypography.h3,
        AppTypography.title,
        AppTypography.bodyLarge,
        AppTypography.body,
        AppTypography.label,
        AppTypography.caption,
        AppTypography.overline,
      ]) {
        expect(s.fontFamily, 'DMSans');
        expect(
          s.fontVariations,
          isNotEmpty,
          reason: 'variable font weight must be set via fontVariations',
        );
      }
    });

    test('only the four approved weights are used', () {
      final Set<double> allowed = <double>{400, 500, 600, 700};
      for (final TextStyle s in <TextStyle>[
        AppTypography.display,
        AppTypography.h1,
        AppTypography.h2,
        AppTypography.h3,
        AppTypography.title,
        AppTypography.bodyLarge,
        AppTypography.body,
        AppTypography.label,
        AppTypography.caption,
        AppTypography.overline,
      ]) {
        expect(allowed, contains(s.fontVariations!.first.value));
      }
    });

    test('nothing is smaller than 11, and body is at least 14', () {
      expect(AppTypography.caption.fontSize, greaterThanOrEqualTo(12));
      expect(AppTypography.body.fontSize, greaterThanOrEqualTo(14));
      expect(AppTypography.overline.fontSize, greaterThanOrEqualTo(11));
    });

    test('tabular applies fixed-width figures', () {
      final TextStyle s = AppTypography.display.tabular;
      expect(s.fontFeatures, isNotNull);
      expect(
        s.fontFeatures!.any((FontFeature f) => f.feature == 'tnum'),
        isTrue,
      );
      // Everything else must be preserved.
      expect(s.fontSize, AppTypography.display.fontSize);
    });
  });

  group('Dimensions', () {
    test('spacing follows the 4 dp base', () {
      for (final double v in <double>[
        AppSpacing.x1,
        AppSpacing.x2,
        AppSpacing.x3,
        AppSpacing.x4,
        AppSpacing.x5,
        AppSpacing.x6,
        AppSpacing.x8,
        AppSpacing.x12,
      ]) {
        expect(v % 4, 0, reason: '$v is not a multiple of 4');
      }
    });

    test('screen padding is 16 on both sides', () {
      expect(AppSpacing.screen.left, 16);
      expect(AppSpacing.screen.right, 16);
    });

    test('minimum touch target is 48', () {
      expect(AppSizes.minTouchTarget, 48);
      expect(AppSizes.controlHeight, 48);
    });

    test('list rows are at least 72', () {
      expect(AppSizes.listRowMinHeight, greaterThanOrEqualTo(72));
    });
  });
}

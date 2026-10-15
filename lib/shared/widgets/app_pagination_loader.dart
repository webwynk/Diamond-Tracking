import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Inline spinner for paginated list footers.
///
/// Matches Screen 30 (item 6) and docs/03-DESIGN-SYSTEM.md section 8:
/// A 56 dp tall row containing a 24 dp [AppColors.primary600] spinner.
/// Pagination deliberately uses a small spinner rather than a skeleton so
/// the list never jumps.
class AppPaginationLoader extends StatelessWidget {
  const AppPaginationLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 56,
      child: Center(
        child: SizedBox(
          width: AppSizes.icon,
          height: AppSizes.icon,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary600),
          ),
        ),
      ),
    );
  }
}

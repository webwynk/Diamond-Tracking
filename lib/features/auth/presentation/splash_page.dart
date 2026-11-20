import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Shown only while the stored session is read at startup.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary600,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset('assets/image/white-logo.png', width: 160),
            const SizedBox(height: 32),
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                color: AppColors.neutral0,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

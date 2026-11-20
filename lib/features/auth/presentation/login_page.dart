import 'package:flutter/material.dart';

import '../../../shared/widgets/coming_soon_page.dart';

/// User ID + password sign-in. Built in Phase 3.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonPage(
    title: 'Sign in',
    phase: 'phase 3 (login and users)',
    icon: Icons.login_rounded,
  );
}

/// First-login password change after a temporary PIN. Built in Phase 3.
class SetPasswordPage extends StatelessWidget {
  const SetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonPage(
    title: 'Set your password',
    phase: 'phase 3 (login and users)',
    icon: Icons.password_rounded,
  );
}

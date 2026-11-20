import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';

/// The admin's way to their own account (password, log out) from the top
/// bar, since the admin app has no Profile tab.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'My account',
      icon: const Icon(Icons.account_circle_rounded),
      onPressed: () => context.push(Routes.adminAccount),
    );
  }
}

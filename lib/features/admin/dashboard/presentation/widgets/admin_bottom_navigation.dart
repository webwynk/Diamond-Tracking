import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// 5-item persistent admin navigation bar adhering strictly to Screen 14 specifications.
class AdminBottomNavigationBar extends StatelessWidget {
  const AdminBottomNavigationBar({
    super.key,
    this.currentIndex = 0,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.neutral200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(index: 0, label: 'Home', icon: Icons.home_rounded),
          _buildNavItem(index: 1, label: 'Map', icon: Icons.map_outlined),
          _buildNavItem(index: 2, label: 'Team', icon: Icons.group_outlined),
          _buildNavItem(index: 3, label: 'Places', icon: Icons.domain_outlined),
          _buildNavItem(index: 4, label: 'Reports', icon: Icons.bar_chart_outlined),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = index == currentIndex;
    final color = isSelected ? AppColors.primary600 : AppColors.textDisabled;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('admin-nav-${label.toLowerCase()}'),
          onTap: () => onTap(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: color,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

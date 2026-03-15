import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class SeniorNavBar extends StatelessWidget {
  final int currentIndex;

  const SeniorNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: AppColors.brandPrimary,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        switch (index) {
          case 0:
            context.go('/senior/home');
          case 1:
            context.go('/senior/medications');
          case 2:
            // Family tab — placeholder
            break;
          case 3:
            // Settings — placeholder
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.medication), label: 'Meds'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Family'),
        BottomNavigationBarItem(
            icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }
}

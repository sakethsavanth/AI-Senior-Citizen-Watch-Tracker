import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/scenario_picker.dart';

class FamilyNavBar extends StatelessWidget {
  final int currentIndex;

  const FamilyNavBar({super.key, required this.currentIndex});

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
            context.go('/family/home');
          case 1:
            context.go('/family/reports');
          case 2:
            context.go('/family/alerts');
          case 3:
            ScenarioPicker.show(context);
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.medication_liquid), label: 'Reports'),
        BottomNavigationBarItem(
            icon: Icon(Icons.notifications), label: 'Alerts'),
        BottomNavigationBarItem(
            icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }
}

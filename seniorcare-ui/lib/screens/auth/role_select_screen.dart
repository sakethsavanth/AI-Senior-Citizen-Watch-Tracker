import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'SC',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'SeniorCare AI',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Keeping your loved ones safe',
                style: AppTextStyles.label.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 32),

              // Parent role button
              _RoleButton(
                label: 'I am a Parent (Senior)',
                subtitle: 'Senior citizen monitoring',
                bgColor: AppColors.parentRoleBg,
                textColor: AppColors.parentRoleText,
                borderColor: AppColors.parentRoleBorder,
                subtitleColor: const Color(0xFF534AB7),
                onTap: () => context.go('/auth/parent-login'),
              ),
              const SizedBox(height: 12),

              // Family role button
              _RoleButton(
                label: 'I am Family / Caregiver',
                subtitle: 'Monitor my parent remotely',
                bgColor: AppColors.childRoleBg,
                textColor: AppColors.childRoleText,
                borderColor: AppColors.childRoleBorder,
                subtitleColor: AppColors.okText,
                onTap: () => context.go('/auth/family-login'),
              ),
              const SizedBox(height: 24),

              TextButton(
                onPressed: () {},
                child: Text(
                  'Already have an account? Sign in',
                  style: TextStyle(fontSize: 11, color: AppColors.brandPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;
  final Color subtitleColor;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.subtitle,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
    required this.subtitleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(color: subtitleColor, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

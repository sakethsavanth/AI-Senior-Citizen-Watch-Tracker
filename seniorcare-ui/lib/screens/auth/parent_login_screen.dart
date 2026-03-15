import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class ParentLoginScreen extends ConsumerStatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  ConsumerState<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends ConsumerState<ParentLoginScreen> {
  final List<int> _pin = [];

  void _onKeyTap(String key) {
    if (key == 'del') {
      if (_pin.isNotEmpty) setState(() => _pin.removeLast());
    } else if (key.isNotEmpty && _pin.length < 4) {
      setState(() => _pin.add(int.parse(key)));
      if (_pin.length == 4) _submitPin();
    }
  }

  void _submitPin() {
    final entered = _pin.join();
    if (entered == '1234') {
      ref.read(authProvider).loginAsParent();
      context.go('/senior/home');
    } else {
      setState(() => _pin.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid PIN. Try 1234.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/auth/role-select'),
              ),
              const SizedBox(height: 16),
              const Text('Welcome back', style: AppTextStyles.seniorTitle),
              const Text('Senior login', style: AppTextStyles.seniorLabel),
              const SizedBox(height: 16),

              // Phone number pill
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.parentRoleBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.parentRoleBorder),
                  ),
                  child: Text(
                    '+91 98765 43210',
                    style: TextStyle(
                      color: AppColors.parentRoleText,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // PIN label
              Center(
                child: Text('Enter your PIN', style: AppTextStyles.seniorLabel),
              ),
              const SizedBox(height: 12),

              // PIN circles
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    4,
                    (i) => Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length
                            ? AppColors.parentRoleText
                            : Colors.transparent,
                        border: Border.all(
                          color: AppColors.parentRoleBorder,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Numpad
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 240,
                    child: GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      childAspectRatio: 1.3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        for (final key in [
                          '1', '2', '3',
                          '4', '5', '6',
                          '7', '8', '9',
                          '', '0', 'del',
                        ])
                          _NumKey(
                            label: key,
                            onTap: () => _onKeyTap(key),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Face ID link
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    'Use Face ID instead',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NumKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: label == 'del' ? Colors.transparent : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: label == 'del'
              ? const Icon(Icons.backspace_outlined, size: 20)
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}

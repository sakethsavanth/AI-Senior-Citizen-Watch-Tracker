import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/scenario_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/scenario_picker.dart';

class FamilyContactsScreen extends ConsumerWidget {
  const FamilyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(currentPersonaDataProvider);
    final contacts = persona['family_contacts'] as List? ?? [];
    final emergencyPhone = persona['emergency_contact'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Family Contacts')),
      floatingActionButton: const ScenarioPickerFab(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Emergency contact card
          Card(
            color: AppColors.criticalBg,
            child: ListTile(
              leading: const Icon(Icons.emergency, color: AppColors.criticalText),
              title: Text('Emergency Contact', style: AppTextStyles.seniorTitle.copyWith(color: AppColors.criticalText)),
              subtitle: Text(emergencyPhone, style: AppTextStyles.seniorBody),
              trailing: IconButton(
                icon: const Icon(Icons.phone, color: AppColors.criticalText),
                onPressed: () {},
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Family Members', style: AppTextStyles.seniorTitle),
          const SizedBox(height: 8),
          ...contacts.map((c) {
            final contact = c as Map<String, dynamic>;
            final name = contact['name'] as String? ?? '';
            final phone = contact['phone'] as String? ?? '';
            final lastContact = contact['last_contact_iso'] as String? ?? '';
            final daysAgo = lastContact.isNotEmpty
                ? DateTime.now().difference(DateTime.tryParse(lastContact) ?? DateTime.now()).inDays
                : 0;

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.aiActionBg,
                  child: Text(name.isNotEmpty ? name[0] : '?',
                      style: TextStyle(color: AppColors.aiActionText, fontWeight: FontWeight.w600)),
                ),
                title: Text(name, style: AppTextStyles.seniorTitle),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(phone, style: AppTextStyles.seniorBody),
                    Text('Last contact: ${daysAgo}d ago', style: AppTextStyles.seniorLabel),
                  ],
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.phone, color: AppColors.brandPrimary), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.message, color: AppColors.brandPrimary), onPressed: () {}),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

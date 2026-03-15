import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/agent_simulator.dart';
import '../../data/scenario_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/senior_nav_bar.dart';

class FamilyContactsScreen extends ConsumerWidget {
  const FamilyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(scenarioHealthDataProvider);
    final contacts = (h['family_contacts'] as List?)
        ?.map((c) => Map<String, dynamic>.from(c as Map))
        .toList() ?? [];
    final picked = AgentSimulator.pickFamilyContact(contacts);

    return Scaffold(
      appBar: AppBar(title: const Text('Family Contacts')),
      bottomNavigationBar: const SeniorNavBar(currentIndex: 2),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final c = contacts[index];
          final isPicked = c['phone'] == picked['phone'];
          final lastIso = c['last_contact_iso'] as String? ?? '';
          final ago = _formatAgo(lastIso);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPicked ? AppColors.aiActionBg : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isPicked ? AppColors.aiActionBorder : const Color(0xFFE2E8F0),
                width: isPicked ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isPicked ? AppColors.brandPrimary : Colors.grey[300],
                  child: Text(
                    (c['name'] as String? ?? '?')[0],
                    style: TextStyle(color: isPicked ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(c['name'] as String? ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          if (isPicked) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brandPrimary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Next to call', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                      Text('Last contacted: $ago', style: AppTextStyles.seniorLabel),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.phone, color: AppColors.brandPrimary),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Calling ${c['name']} — simulated'), backgroundColor: AppColors.okText),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatAgo(String iso) {
    if (iso.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return 'Recently';
    } catch (_) {
      return 'Unknown';
    }
  }
}

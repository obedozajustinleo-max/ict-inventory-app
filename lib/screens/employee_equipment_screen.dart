import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/employee_roster.dart';
import '../models/equipment_item.dart';
import 'equipment_detail_screen.dart';

class EmployeeEquipmentScreen extends StatefulWidget {
  final User user;
  final String? employeeFullName;

  const EmployeeEquipmentScreen({
    super.key,
    required this.user,
    this.employeeFullName,
  });

  @override
  State<EmployeeEquipmentScreen> createState() =>
      _EmployeeEquipmentScreenState();
}

class _EmployeeEquipmentScreenState extends State<EmployeeEquipmentScreen> {
  final Set<String> _expandedIds = <String>{};

  Future<void> _reportDiscrepancy(
    BuildContext context,
    String displayName,
    String email,
  ) async {
    final noteCtrl = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report MR Discrepancy to ICTU'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Missing an issued device, or seeing equipment already transferred to another staff? Describe it below:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., Missing Epson L3210 printer in HIMS...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final notes = noteCtrl.text.trim();
              if (notes.isEmpty) return;
              await FirebaseFirestore.instance.collection('ictu_requests').add({
                'type': 'mr_discrepancy',
                'fullName': displayName,
                'email': email,
                'notes': notes,
                'status': 'pending',
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Submit to ICTU'),
          ),
        ],
      ),
    );

    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discrepancy note sent to ICTU for verification.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = (widget.user.email ?? '').trim().toLowerCase();
    final fullName = (widget.employeeFullName ?? widget.user.displayName ?? '')
        .trim();

    final stream = FirebaseFirestore.instance
        .collection(AppConstants.equipmentCollection)
        .where('isArchived', isEqualTo: false)
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) => EquipmentItem.fromFirestore(doc)).where(
            (item) {
              final emailMatch =
                  email.isNotEmpty &&
                  (item.assignedUserEmail ?? '').trim().toLowerCase() == email;
              final nameMatch =
                  fullName.isNotEmpty &&
                  EmployeeRoster.matchesResponsiblePersonnel(
                    rosterName: fullName,
                    responsiblePersonnel: item.responsiblePersonnel,
                  );
              return emailMatch || nameMatch;
            },
          ).toList();
        });

    return Scaffold(
      appBar: AppBar(
        title: const Text('My MR Equipment'),
        actions: [
          IconButton(
            tooltip: 'Report Missing / Wrong Item',
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => _reportDiscrepancy(
              context,
              fullName.isEmpty ? email : fullName,
              email,
            ),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isNotEmpty ? fullName : 'Employee Account',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(email, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EquipmentItem>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No MR\'ed ICT equipment matched "${fullName.isEmpty ? email : fullName}" yet.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _reportDiscrepancy(
                              context,
                              fullName.isEmpty ? email : fullName,
                              email,
                            ),
                            icon: const Icon(Icons.support_agent),
                            label: const Text('Notify ICTU to Link My MR'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isExpanded = _expandedIds.contains(item.id);
                    return Card(
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              '${item.equipmentType}${item.year.isNotEmpty ? " (${item.year})" : ""} • ${item.brandModel}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Prop #: ${item.propertyNumber.isEmpty ? "—" : item.propertyNumber}\n'
                              'SN: ${item.serialNumber.isEmpty ? "—" : item.serialNumber} • '
                              '${item.location} • ${item.condition}',
                            ),
                            isThreeLine: true,
                            trailing: item.isDesktopSet
                                ? IconButton(
                                    icon: Icon(
                                      isExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedIds.remove(item.id);
                                        } else {
                                          _expandedIds.add(item.id);
                                        }
                                      });
                                    },
                                  )
                                : null,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EquipmentDetailScreen(itemId: item.id),
                                ),
                              );
                            },
                          ),
                          if (item.isDesktopSet && isExpanded) ...[
                            const Divider(height: 1),
                            ...item.components.map(
                              (comp) => ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.subdirectory_arrow_right,
                                  size: 18,
                                ),
                                title: Text(
                                  '${comp.componentType}: ${comp.brandModel.isEmpty ? "—" : comp.brandModel}',
                                ),
                                subtitle: Text(
                                  'SN: ${comp.serialNumber.isEmpty ? "—" : comp.serialNumber} • Prop #: ${comp.propertyNumber.isEmpty ? "—" : comp.propertyNumber}',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

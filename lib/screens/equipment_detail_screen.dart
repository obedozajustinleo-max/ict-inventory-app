import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/date_formatter.dart';
import '../models/equipment_history.dart';
import '../models/equipment_item.dart';
import '../services/inventory_service.dart';
import 'equipment_form_screen.dart';

class EquipmentDetailScreen extends StatelessWidget {
  final String itemId;

  const EquipmentDetailScreen({super.key, required this.itemId});

  Color _conditionColor(String condition) {
    return switch (condition) {
      'Working' => Colors.green,
      'For Repair' => Colors.orange,
      'Defective' => Colors.red,
      _ => Colors.blueGrey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final service = InventoryService();
    final docStream = FirebaseFirestore.instance
        .collection(AppConstants.equipmentCollection)
        .doc(itemId)
        .snapshots()
        .map((snap) => EquipmentItem.fromFirestore(snap));

    return StreamBuilder<EquipmentItem>(
      stream: docStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final item = snapshot.data!;
        final titleProp = item.propertyNumber.isEmpty
            ? item.equipmentType
            : item.propertyNumber;

        return Scaffold(
          appBar: AppBar(
            title: Text(titleProp),
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EquipmentFormScreen(existingItem: item),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Archive Record',
                icon: const Icon(Icons.archive_outlined),
                onPressed: () async {
                  await service.archiveEquipment(item);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${item.equipmentType}${item.year.isNotEmpty ? " (${item.year})" : ""} — ${item.brandModel}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Division: ${item.division}'),
              if (item.year.isNotEmpty) Text('Year: ${item.year}'),
              Text(
                'Serial Number: ${item.serialNumber.isEmpty ? "—" : item.serialNumber}',
              ),
              Text(
                'Property Number: ${item.propertyNumber.isEmpty ? "—" : item.propertyNumber}',
              ),
              Text(
                'Date Acquired: ${DateFormatter.formatShort(item.dateAcquired)}',
              ),
              Text(
                'Warranty Until: ${DateFormatter.formatShort(item.warrantyEndDate)}',
              ),
              Text('Location / Section: ${item.location}'),
              Text('Responsible Personnel: ${item.responsiblePersonnel}'),
              if (item.assignedUserEmail != null &&
                  item.assignedUserEmail!.trim().isNotEmpty)
                Text('Assigned Account: ${item.assignedUserEmail}'),
              Text('Condition: ${item.condition}'),
              Text('Remarks: ${item.remarks.isEmpty ? "—" : item.remarks}'),

              if (item.components.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Tied Peripherals & Components (${item.components.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...item.components.map((comp) {
                  final color = _conditionColor(comp.condition);
                  final details = <String>[
                    if (comp.brandModel.isNotEmpty) 'Model: ${comp.brandModel}',
                    if (comp.year.isNotEmpty) 'Year: ${comp.year}',
                    if (comp.serialNumber.isNotEmpty)
                      'SN: ${comp.serialNumber}',
                    if (comp.propertyNumber.isNotEmpty)
                      'Prop #: ${comp.propertyNumber}',
                    if (comp.dateAcquired.isNotEmpty)
                      'Acquired: ${comp.dateAcquired}',
                    if (comp.warrantyPeriod.isNotEmpty)
                      'Warranty: ${comp.warrantyPeriod}',
                    if (comp.remarks.isNotEmpty) 'Remarks: ${comp.remarks}',
                  ];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.memory),
                      title: Text(
                        comp.componentType.isEmpty
                            ? 'Peripheral'
                            : comp.componentType,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        details.isEmpty
                            ? 'No extra details'
                            : details.join('\n'),
                      ),
                      trailing: Text(
                        comp.condition,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 16),

              if (item.serialPhotoUrl != null ||
                  item.propertyTagPhotoUrl != null)
                Row(
                  children: [
                    if (item.serialPhotoUrl != null)
                      Expanded(
                        child: Column(
                          children: [
                            Image.network(
                              item.serialPhotoUrl!,
                              height: 140,
                              fit: BoxFit.cover,
                            ),
                            const SizedBox(height: 4),
                            const Text('Serial Photo'),
                          ],
                        ),
                      ),
                    if (item.serialPhotoUrl != null &&
                        item.propertyTagPhotoUrl != null)
                      const SizedBox(width: 12),
                    if (item.propertyTagPhotoUrl != null)
                      Expanded(
                        child: Column(
                          children: [
                            Image.network(
                              item.propertyTagPhotoUrl!,
                              height: 140,
                              fit: BoxFit.cover,
                            ),
                            const SizedBox(height: 4),
                            const Text('Property Tag'),
                          ],
                        ),
                      ),
                  ],
                ),

              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    QrImageView(
                      data: item.id,
                      version: QrVersions.auto,
                      size: 150,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'QR Tag ID: ${item.id}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'Custody & Condition History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<EquipmentHistory>>(
                stream: service.watchItemHistory(item.id),
                builder: (context, histSnap) {
                  final logs = histSnap.data ?? [];
                  if (logs.isEmpty) {
                    return const Text(
                      'No status or custody changes logged yet.',
                    );
                  }
                  return Column(
                    children: logs
                        .map(
                          (log) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.history),
                            title: Text(
                              '${log.fieldChanged}: "${log.oldValue}" → "${log.newValue}"',
                            ),
                            subtitle: Text(
                              'By ${log.changedBy} • ${DateFormatter.formatShort(log.changedAt)}',
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

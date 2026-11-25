import 'package:flutter/material.dart';
import '../models/equipment_item.dart';
import '../services/inventory_service.dart';
import 'equipment_detail_screen.dart';

class ArchivedEquipmentScreen extends StatelessWidget {
  const ArchivedEquipmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = InventoryService();

    return Scaffold(
      appBar: AppBar(title: const Text('Archived Equipment')),
      body: StreamBuilder<List<EquipmentItem>>(
        stream: service.watchArchivedEquipment(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No archived equipment.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  title: Text('${item.equipmentType} • ${item.brandModel}'),
                  subtitle: Text(
                    'Prop #: ${item.propertyNumber.isEmpty ? "—" : item.propertyNumber} • ${item.location}',
                  ),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.unarchive_outlined, size: 18),
                    label: const Text('Restore'),
                    onPressed: () async {
                      await service.restoreEquipment(item);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Equipment restored.')),
                        );
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EquipmentDetailScreen(itemId: item.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

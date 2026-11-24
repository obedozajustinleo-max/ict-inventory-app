import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/utils/date_formatter.dart';
import '../models/equipment_item.dart';
import '../providers/inventory_provider.dart';
import 'equipment_detail_screen.dart';
import 'equipment_form_screen.dart';
import 'qr_scanner_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _handleSync(
    BuildContext context,
    InventoryProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final msg = await provider.syncToGoogleSheet();
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Sync error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final items = provider.filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ICT Equipment Inventory'),
        actions: [
          IconButton(
            tooltip: 'Scan QR Code',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QrScannerScreen(allItems: provider.allItems),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EquipmentFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Device'),
      ),
      body: Column(
        children: [
          // Google Sheets Sync Bar
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Last Sheet Sync: ${DateFormatter.formatShort(provider.lastSyncedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: provider.isSyncingSheet
                      ? null
                      : () => _handleSync(context, provider),
                  icon: provider.isSyncingSheet
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.table_chart, size: 18),
                  label: Text(
                    provider.isSyncingSheet ? 'Syncing...' : 'Update Sheet',
                  ),
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              onChanged: provider.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search property #, serial #, model, or person...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _FilterChipItem(
                  label: 'All (${provider.totalCount})',
                  selected: provider.activeFilter == InventoryFilter.all,
                  onTap: () => provider.setFilter(InventoryFilter.all),
                ),
                _FilterChipItem(
                  label: 'Working (${provider.workingCount})',
                  selected: provider.activeFilter == InventoryFilter.working,
                  onTap: () => provider.setFilter(InventoryFilter.working),
                ),
                _FilterChipItem(
                  label: 'For Repair (${provider.forRepairCount})',
                  selected: provider.activeFilter == InventoryFilter.forRepair,
                  onTap: () => provider.setFilter(InventoryFilter.forRepair),
                ),
                _FilterChipItem(
                  label: 'Defective (${provider.defectiveCount})',
                  selected: provider.activeFilter == InventoryFilter.defective,
                  onTap: () => provider.setFilter(InventoryFilter.defective),
                ),
                _FilterChipItem(
                  label: 'Expiring Soon (${provider.expiringWarrantyCount})',
                  selected:
                      provider.activeFilter == InventoryFilter.expiringWarranty,
                  onTap: () =>
                      provider.setFilter(InventoryFilter.expiringWarranty),
                ),
              ],
            ),
          ),

          // Equipment List
          Expanded(
            child: provider.errorMessage != null
                ? Center(child: Text(provider.errorMessage!))
                : items.isEmpty
                ? const Center(child: Text('No matching equipment found.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 84),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _EquipmentCard(item: item);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  final EquipmentItem item;

  const _EquipmentCard({required this.item});

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
    final badgeColor = _conditionColor(item.condition);

    return Card(
      child: ListTile(
        title: Text(
          '${item.equipmentType} • ${item.brandModel}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Prop #: ${item.propertyNumber}\n'
          'SN: ${item.serialNumber} • ${item.location} (${item.responsiblePersonnel})',
        ),
        isThreeLine: true,
        trailing: Chip(
          label: Text(
            item.condition,
            style: TextStyle(color: badgeColor, fontWeight: FontWeight.w600),
          ),
          side: BorderSide(color: badgeColor.withValues(alpha: 0.5)),
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
  }
}

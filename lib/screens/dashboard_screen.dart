import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_constants.dart';
import '../models/equipment_item.dart';
import '../providers/inventory_provider.dart';
import 'archived_equipment_screen.dart';
import 'equipment_detail_screen.dart';
import 'equipment_form_screen.dart';
import 'qr_scanner_screen.dart';
import 'sync_management_screen.dart';
import 'ictu_requests_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Set<String> _expandedIds = <String>{};

  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  void _openFilterSortSheet(BuildContext context, InventoryProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return ChangeNotifierProvider.value(
          value: provider,
          child: const _FilterSortSheet(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final items = provider.filteredItems;
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'ICTU Staff';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ICT Inventory'),
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
          PopupMenuButton<InventoryViewMode>(
            tooltip: 'View Mode',
            icon: Icon(switch (provider.viewMode) {
              InventoryViewMode.detailed => Icons.view_agenda_outlined,
              InventoryViewMode.compact => Icons.view_list_outlined,
              InventoryViewMode.groupedByOffice => Icons.folder_shared_outlined,
            }),
            onSelected: provider.setViewMode,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: InventoryViewMode.detailed,
                child: ListTile(
                  leading: Icon(Icons.view_agenda_outlined),
                  title: Text('Detailed Cards'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: InventoryViewMode.compact,
                child: ListTile(
                  leading: Icon(Icons.view_list_outlined),
                  title: Text('Compact List'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: InventoryViewMode.groupedByOffice,
                child: ListTile(
                  leading: Icon(Icons.folder_shared_outlined),
                  title: Text('Group by Office/Section'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text('DOH - DATRC ICTU'),
              accountEmail: Text(userEmail),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.computer),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Active Inventory'),
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Data & Google Sheets Sync'),
              subtitle: const Text('Fetch, Update Sheet, Wipe DB'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: provider,
                      child: const SyncManagementScreen(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archived Equipment'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ArchivedEquipmentScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Employee Requests & Help'),
              subtitle: const Text('Unlisted names, password & MR notes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IctuRequestsScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out'),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
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
          // Search + Filter/Sort Trigger Row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: provider.setSearchQuery,
                    decoration: InputDecoration(
                      hintText:
                          'Search prop #, SN, model, office, or person...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: provider.activeFilterCount > 0,
                  label: Text('${provider.activeFilterCount}'),
                  child: FilledButton.tonalIcon(
                    onPressed: () => _openFilterSortSheet(context, provider),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Filter'),
                  ),
                ),
              ],
            ),
          ),

          // Quick Condition Summary Strip
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
                  label: 'Expiring (${provider.expiringWarrantyCount})',
                  selected:
                      provider.activeFilter == InventoryFilter.expiringWarranty,
                  onTap: () =>
                      provider.setFilter(InventoryFilter.expiringWarranty),
                ),
              ],
            ),
          ),

          // Active Division / Office Indicator Bar
          if (provider.activeFilterCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Showing ${items.length} of ${provider.totalCount} items',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: provider.clearAllFilters,
                    child: const Text('Reset Filters'),
                  ),
                ],
              ),
            ),

          // Equipment Content Area
          Expanded(
            child: provider.errorMessage != null
                ? Center(child: Text(provider.errorMessage!))
                : items.isEmpty
                ? const Center(child: Text('No matching equipment found.'))
                : switch (provider.viewMode) {
                    InventoryViewMode.detailed => ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 84),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _EquipmentCard(
                          item: item,
                          isExpanded: _expandedIds.contains(item.id),
                          onToggleExpand: item.isDesktopSet
                              ? () => _toggleExpanded(item.id)
                              : null,
                        );
                      },
                    ),
                    InventoryViewMode.compact => ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 84),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _CompactEquipmentTile(item: item);
                      },
                    ),
                    InventoryViewMode.groupedByOffice => _GroupedByOfficeView(
                      items: items,
                      expandedIds: _expandedIds,
                      onToggleExpand: _toggleExpanded,
                    ),
                  },
          ),
        ],
      ),
    );
  }
}

class _FilterSortSheet extends StatelessWidget {
  const _FilterSortSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter & Sort Inventory',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: provider.clearAllFilters,
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sort Dropdown
            DropdownButtonFormField<InventorySortOption>(
              initialValue: provider.sortOption,
              decoration: const InputDecoration(
                labelText: 'Sort By',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: InventorySortOption.recentUpdated,
                  child: Text('Recently Updated'),
                ),
                DropdownMenuItem(
                  value: InventorySortOption.officeAsc,
                  child: Text('Office / Section (A–Z)'),
                ),
                DropdownMenuItem(
                  value: InventorySortOption.brandModelAsc,
                  child: Text('Brand / Model (A–Z)'),
                ),
                DropdownMenuItem(
                  value: InventorySortOption.yearDesc,
                  child: Text('Year (Newest First)'),
                ),
                DropdownMenuItem(
                  value: InventorySortOption.yearAsc,
                  child: Text('Year (Oldest First)'),
                ),
                DropdownMenuItem(
                  value: InventorySortOption.propertyNumberAsc,
                  child: Text('Property Number (A–Z)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) provider.setSortOption(val);
              },
            ),
            const SizedBox(height: 12),

            // Division Filter (4 Official Divisions)
            DropdownButtonFormField<String?>(
              initialValue: provider.selectedDivision,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Division',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Divisions'),
                ),
                ...AppConstants.divisions.map(
                  (d) => DropdownMenuItem<String?>(
                    value: d,
                    child: Text(d, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: provider.setDivisionFilter,
            ),
            const SizedBox(height: 12),

            // Office / Section Filter
            DropdownButtonFormField<String?>(
              initialValue: provider.selectedLocation,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Office / Section / Unit',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Offices / Sections'),
                ),
                ...provider.availableLocations.map(
                  (loc) => DropdownMenuItem<String?>(
                    value: loc,
                    child: Text(loc, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: provider.setLocationFilter,
            ),
            const SizedBox(height: 12),

            // Equipment Type Filter
            DropdownButtonFormField<String?>(
              initialValue: provider.selectedEquipmentType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Equipment Type',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Equipment Types'),
                ),
                ...provider.availableEquipmentTypes.map(
                  (t) => DropdownMenuItem<String?>(
                    value: t,
                    child: Text(t, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: provider.setEquipmentTypeFilter,
            ),
            const SizedBox(height: 12),

            // Year Filter
            DropdownButtonFormField<String?>(
              initialValue: provider.selectedYear,
              decoration: const InputDecoration(
                labelText: 'Year',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Years'),
                ),
                ...provider.availableYears.map(
                  (y) => DropdownMenuItem<String?>(value: y, child: Text(y)),
                ),
              ],
              onChanged: provider.setYearFilter,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupedByOfficeView extends StatelessWidget {
  final List<EquipmentItem> items;
  final Set<String> expandedIds;
  final void Function(String) onToggleExpand;

  const _GroupedByOfficeView({
    required this.items,
    required this.expandedIds,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<EquipmentItem>>{};
    for (final item in items) {
      final key = item.location.trim().isEmpty
          ? 'Unassigned Office'
          : item.location.trim();
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final offices = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 84),
      itemCount: offices.length,
      itemBuilder: (context, idx) {
        final office = offices[idx];
        final officeItems = grouped[office]!;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            initiallyExpanded: offices.length <= 3,
            title: Text(
              office,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${officeItems.length} equipment item(s)'),
            children: officeItems.map((item) {
              return _CompactEquipmentTile(item: item);
            }).toList(),
          ),
        );
      },
    );
  }
}

class _CompactEquipmentTile extends StatelessWidget {
  final EquipmentItem item;

  const _CompactEquipmentTile({required this.item});

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
    return ListTile(
      dense: true,
      title: Text(
        '${item.equipmentType}${item.year.isNotEmpty ? " (${item.year})" : ""} • ${item.brandModel}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${item.location} • ${item.responsiblePersonnel}'
        '${item.propertyNumber.isNotEmpty ? " • Prop #: ${item.propertyNumber}" : ""}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          item.condition,
          style: TextStyle(
            color: badgeColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EquipmentDetailScreen(itemId: item.id),
          ),
        );
      },
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
  final bool isExpanded;
  final VoidCallback? onToggleExpand;

  const _EquipmentCard({
    required this.item,
    required this.isExpanded,
    this.onToggleExpand,
  });

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
    final yearSuffix = item.year.isNotEmpty ? ' (${item.year})' : '';

    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(
              '${item.equipmentType}$yearSuffix • ${item.brandModel}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Prop #: ${item.propertyNumber.isEmpty ? "—" : item.propertyNumber}\n'
              'SN: ${item.serialNumber.isEmpty ? "—" : item.serialNumber} • ${item.location} (${item.responsiblePersonnel})',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(
                    item.condition,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  side: BorderSide(color: badgeColor.withValues(alpha: 0.5)),
                ),
                if (onToggleExpand != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: isExpanded
                        ? 'Hide Peripherals'
                        : 'Show Peripherals',
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: onToggleExpand,
                  ),
                ],
              ],
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
          if (item.isDesktopSet) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: InkWell(
                onTap: onToggleExpand,
                child: Row(
                  children: [
                    Icon(
                      Icons.devices_other,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isExpanded
                          ? 'Hide ${item.components.length} tied peripherals'
                          : 'View ${item.components.length} tied peripherals',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: item.components.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16),
                itemBuilder: (context, idx) {
                  final comp = item.components[idx];
                  final compColor = _conditionColor(comp.condition);
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 2,
                    ),
                    leading: const Icon(
                      Icons.subdirectory_arrow_right,
                      size: 18,
                    ),
                    title: Text(
                      '${comp.componentType}${comp.year.isNotEmpty ? " (${comp.year})" : ""}: ${comp.brandModel.isEmpty ? "—" : comp.brandModel}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'SN: ${comp.serialNumber.isEmpty ? "—" : comp.serialNumber} • '
                      'Prop #: ${comp.propertyNumber.isEmpty ? "—" : comp.propertyNumber}',
                    ),
                    trailing: Text(
                      comp.condition,
                      style: TextStyle(
                        color: compColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}

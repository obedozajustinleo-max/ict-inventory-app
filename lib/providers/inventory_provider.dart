import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/utils/date_formatter.dart';
import '../models/equipment_item.dart';
import '../services/inventory_service.dart';
import '../services/sheets_sync_service.dart';

enum InventoryFilter { all, working, forRepair, defective, expiringWarranty }

class InventoryProvider extends ChangeNotifier {
  final InventoryService _inventoryService;
  final SheetsSyncService _sheetsSyncService;

  StreamSubscription<List<EquipmentItem>>? _itemsSub;
  StreamSubscription<DateTime?>? _syncSub;

  List<EquipmentItem> _allItems = [];
  DateTime? _lastSyncedAt;
  InventoryFilter _activeFilter = InventoryFilter.all;
  String _searchQuery = '';
  bool _isSyncingSheet = false;
  String? _errorMessage;

  InventoryProvider({
    InventoryService? inventoryService,
    SheetsSyncService? sheetsSyncService,
  }) : _inventoryService = inventoryService ?? InventoryService(),
       _sheetsSyncService = sheetsSyncService ?? SheetsSyncService() {
    _listen();
  }

  List<EquipmentItem> get allItems => _allItems;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  InventoryFilter get activeFilter => _activeFilter;
  String get searchQuery => _searchQuery;
  bool get isSyncingSheet => _isSyncingSheet;
  String? get errorMessage => _errorMessage;

  int get totalCount => _allItems.length;
  int get workingCount =>
      _allItems.where((e) => e.condition == 'Working').length;
  int get forRepairCount =>
      _allItems.where((e) => e.condition == 'For Repair').length;
  int get defectiveCount =>
      _allItems.where((e) => e.condition == 'Defective').length;
  int get expiringWarrantyCount => _allItems.where((e) {
    final status = DateFormatter.getWarrantyStatus(e.warrantyEndDate);
    return status == WarrantyStatus.expiringSoon;
  }).length;

  List<EquipmentItem> get filteredItems {
    return _allItems.where((item) {
      final matchesFilter = switch (_activeFilter) {
        InventoryFilter.all => true,
        InventoryFilter.working => item.condition == 'Working',
        InventoryFilter.forRepair => item.condition == 'For Repair',
        InventoryFilter.defective => item.condition == 'Defective',
        InventoryFilter.expiringWarranty =>
          DateFormatter.getWarrantyStatus(item.warrantyEndDate) ==
              WarrantyStatus.expiringSoon,
      };

      if (!matchesFilter) return false;

      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      return item.equipmentType.toLowerCase().contains(q) ||
          item.brandModel.toLowerCase().contains(q) ||
          item.serialNumber.toLowerCase().contains(q) ||
          item.propertyNumber.toLowerCase().contains(q) ||
          item.location.toLowerCase().contains(q) ||
          item.responsiblePersonnel.toLowerCase().contains(q);
    }).toList();
  }

  void _listen() {
    _itemsSub = _inventoryService.watchActiveEquipment().listen(
      (items) {
        _allItems = items;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object err) {
        _errorMessage = err.toString();
        notifyListeners();
      },
    );

    _syncSub = _inventoryService.watchLastSyncedAt().listen((timestamp) {
      _lastSyncedAt = timestamp;
      notifyListeners();
    });
  }

  void setFilter(InventoryFilter filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<String> syncToGoogleSheet() async {
    _isSyncingSheet = true;
    notifyListeners();
    try {
      final count = await _sheetsSyncService.syncEquipmentToSheet(_allItems);
      return 'Synced $count equipment records to Google Sheets.';
    } finally {
      _isSyncingSheet = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _itemsSub?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }
}

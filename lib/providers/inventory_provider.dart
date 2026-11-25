import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/date_formatter.dart';
import '../models/equipment_item.dart';
import '../services/inventory_service.dart';
import '../services/sheets_sync_service.dart';

enum InventoryFilter { all, working, forRepair, defective, expiringWarranty }

enum InventorySortOption {
  recentUpdated,
  brandModelAsc,
  officeAsc,
  yearDesc,
  yearAsc,
  propertyNumberAsc,
}

enum InventoryViewMode { detailed, compact, groupedByOffice }

class InventoryProvider extends ChangeNotifier {
  final InventoryService _inventoryService;
  final SheetsSyncService _sheetsSyncService;

  StreamSubscription<List<EquipmentItem>>? _itemsSub;
  StreamSubscription<DateTime?>? _syncSub;

  List<EquipmentItem> _allItems = [];
  DateTime? _lastSyncedAt;

  InventoryFilter _activeFilter = InventoryFilter.all;
  String? _selectedDivision;
  String? _selectedLocation;
  String? _selectedEquipmentType;
  String? _selectedYear;
  InventorySortOption _sortOption = InventorySortOption.recentUpdated;
  InventoryViewMode _viewMode = InventoryViewMode.detailed;

  String _searchQuery = '';
  bool _isSyncingSheet = false;
  bool _isWipingDatabase = false;
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
  String? get selectedDivision => _selectedDivision;
  String? get selectedLocation => _selectedLocation;
  String? get selectedEquipmentType => _selectedEquipmentType;
  String? get selectedYear => _selectedYear;
  InventorySortOption get sortOption => _sortOption;
  InventoryViewMode get viewMode => _viewMode;
  String get searchQuery => _searchQuery;
  bool get isSyncingSheet => _isSyncingSheet;
  bool get isWipingDatabase => _isWipingDatabase;
  String? get errorMessage => _errorMessage;

  int get activeFilterCount {
    int count = 0;
    if (_activeFilter != InventoryFilter.all) count++;
    if (_selectedDivision != null) count++;
    if (_selectedLocation != null) count++;
    if (_selectedEquipmentType != null) count++;
    if (_selectedYear != null) count++;
    return count;
  }

  List<String> get availableLocations {
    final set = <String>{...AppConstants.defaultLocations};
    for (final item in _allItems) {
      if (item.location.trim().isNotEmpty) set.add(item.location.trim());
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get availableEquipmentTypes {
    final set = <String>{...AppConstants.equipmentTypes};
    for (final item in _allItems) {
      if (item.equipmentType.trim().isNotEmpty) {
        set.add(item.equipmentType.trim());
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get availableYears {
    final set = <String>{};
    for (final item in _allItems) {
      if (item.year.trim().isNotEmpty) set.add(item.year.trim());
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

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
    final q = _searchQuery.toLowerCase().trim();

    final list = _allItems.where((item) {
      final matchesCondition = switch (_activeFilter) {
        InventoryFilter.all => true,
        InventoryFilter.working => item.condition == 'Working',
        InventoryFilter.forRepair => item.condition == 'For Repair',
        InventoryFilter.defective => item.condition == 'Defective',
        InventoryFilter.expiringWarranty =>
          DateFormatter.getWarrantyStatus(item.warrantyEndDate) ==
              WarrantyStatus.expiringSoon,
      };
      if (!matchesCondition) return false;

      if (_selectedDivision != null &&
          AppConstants.normalizeDivision(item.division) != _selectedDivision) {
        return false;
      }

      if (_selectedLocation != null &&
          item.location.trim().toLowerCase() !=
              _selectedLocation!.trim().toLowerCase()) {
        return false;
      }

      if (_selectedEquipmentType != null &&
          item.equipmentType.trim().toLowerCase() !=
              _selectedEquipmentType!.trim().toLowerCase()) {
        return false;
      }

      if (_selectedYear != null && item.year.trim() != _selectedYear!.trim()) {
        return false;
      }

      if (q.isEmpty) return true;

      final baseMatch =
          item.equipmentType.toLowerCase().contains(q) ||
          item.year.toLowerCase().contains(q) ||
          item.division.toLowerCase().contains(q) ||
          item.brandModel.toLowerCase().contains(q) ||
          item.serialNumber.toLowerCase().contains(q) ||
          item.propertyNumber.toLowerCase().contains(q) ||
          item.location.toLowerCase().contains(q) ||
          item.responsiblePersonnel.toLowerCase().contains(q);

      if (baseMatch) return true;

      for (final comp in item.components) {
        if (comp.componentType.toLowerCase().contains(q) ||
            comp.brandModel.toLowerCase().contains(q) ||
            comp.serialNumber.toLowerCase().contains(q) ||
            comp.propertyNumber.toLowerCase().contains(q) ||
            comp.year.toLowerCase().contains(q)) {
          return true;
        }
      }
      return false;
    }).toList();

    switch (_sortOption) {
      case InventorySortOption.recentUpdated:
        break;
      case InventorySortOption.brandModelAsc:
        list.sort(
          (a, b) =>
              a.brandModel.toLowerCase().compareTo(b.brandModel.toLowerCase()),
        );
        break;
      case InventorySortOption.officeAsc:
        list.sort((a, b) {
          final locCmp = a.location.toLowerCase().compareTo(
            b.location.toLowerCase(),
          );
          if (locCmp != 0) return locCmp;
          return a.brandModel.toLowerCase().compareTo(
            b.brandModel.toLowerCase(),
          );
        });
        break;
      case InventorySortOption.yearDesc:
        list.sort((a, b) => b.year.compareTo(a.year));
        break;
      case InventorySortOption.yearAsc:
        list.sort((a, b) => a.year.compareTo(b.year));
        break;
      case InventorySortOption.propertyNumberAsc:
        list.sort(
          (a, b) => a.propertyNumber.toLowerCase().compareTo(
            b.propertyNumber.toLowerCase(),
          ),
        );
        break;
    }

    return list;
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

  void setDivisionFilter(String? division) {
    _selectedDivision = division;
    notifyListeners();
  }

  void setLocationFilter(String? location) {
    _selectedLocation = location;
    notifyListeners();
  }

  void setEquipmentTypeFilter(String? type) {
    _selectedEquipmentType = type;
    notifyListeners();
  }

  void setYearFilter(String? year) {
    _selectedYear = year;
    notifyListeners();
  }

  void setSortOption(InventorySortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void setViewMode(InventoryViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  void clearAllFilters() {
    _activeFilter = InventoryFilter.all;
    _selectedDivision = null;
    _selectedLocation = null;
    _selectedEquipmentType = null;
    _selectedYear = null;
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

  Future<String> importFromGoogleSheet() async {
    _isSyncingSheet = true;
    notifyListeners();
    try {
      final count = await _sheetsSyncService.importEquipmentFromSheet();
      return count == 0
          ? 'No equipment rows found in Google Sheets.'
          : 'Imported $count equipment records from Google Sheets.';
    } finally {
      _isSyncingSheet = false;
      notifyListeners();
    }
  }

  Future<String> wipeDatabase() async {
    _isWipingDatabase = true;
    notifyListeners();
    try {
      final deletedCount = await _inventoryService.wipeAllEquipment();
      return 'Cleared $deletedCount equipment records from Firestore.';
    } finally {
      _isWipingDatabase = false;
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

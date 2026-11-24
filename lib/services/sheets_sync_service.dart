import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/equipment_item.dart';
import 'inventory_service.dart';

class SheetsSyncService {
  // Replace with your deployed Google Apps Script Web App URL
  static const String webhookUrl =
      'https://script.google.com/macros/s/AKfycby_4cPLmTT4o20NbVp_lBt6cQYFF7A093c_caJiV1mEjdtgd1p4zw5J8KLLDDJoy6HToQ/exec';
  static const String apiToken = 'ict_sync_9xK4mP2vR8zL6wQ1';

  final InventoryService _inventoryService;

  SheetsSyncService({InventoryService? inventoryService})
    : _inventoryService = inventoryService ?? InventoryService();

  Future<int> syncEquipmentToSheet(List<EquipmentItem> items) async {
    final uri = Uri.parse(webhookUrl);
    final body = jsonEncode({
      'token': apiToken,
      'syncedAt': DateTime.now().toIso8601String(),
      'items': items.map((e) => e.toSheetRowJson()).toList(),
    });

    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        'Google Sheet sync failed (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['ok'] == false) {
      throw Exception(decoded['error'] ?? 'Apps Script rejected sync request.');
    }

    await _inventoryService.recordSheetSync();
    return items.length;
  }
}

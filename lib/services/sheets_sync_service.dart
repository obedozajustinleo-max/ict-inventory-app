import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/equipment_item.dart';
import 'inventory_service.dart';

class SheetsSyncService {
  static const String webhookUrl = String.fromEnvironment(
    'SHEETS_WEBHOOK_URL',
    defaultValue:
        'https://script.google.com/macros/s/AKfycby_4cPLmTT4o20NbVp_lBt6cQYFF7A093c_caJiV1mEjdtgd1p4zw5J8KLLDDJoy6HToQ/exec',
  );
  static const String apiToken = String.fromEnvironment(
    'SHEETS_API_TOKEN',
    defaultValue: 'ict_sync_9xK4mP2vR8zL6wQ1',
  );

  final InventoryService _inventoryService;
  final http.Client _client;

  SheetsSyncService({InventoryService? inventoryService, http.Client? client})
    : _inventoryService = inventoryService ?? InventoryService(),
      _client = client ?? http.Client();

  Future<int> syncEquipmentToSheet(List<EquipmentItem> items) async {
    if (items.isEmpty) {
      throw Exception('No equipment records available to sync.');
    }

    final uri = Uri.parse(webhookUrl);
    final payload = jsonEncode({
      'token': apiToken,
      'syncedAt': DateTime.now().toIso8601String(),
      'items': items.map((e) => e.toSheetRowJson()).toList(),
    });

    try {
      var response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'text/plain; charset=utf-8'},
            body: payload,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl == null || redirectUrl.isEmpty) {
          throw Exception('Apps Script redirect missing Location header.');
        }
        response = await _client
            .get(Uri.parse(redirectUrl))
            .timeout(const Duration(seconds: 30));
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Google Sheet sync failed (HTTP ${response.statusCode}).',
        );
      }

      final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw Exception(
          'Invalid response from Apps Script. Check Web App access permissions ("Anyone").',
        );
      }

      if (decoded is Map && decoded['ok'] == false) {
        throw Exception(
          decoded['error'] ?? 'Apps Script rejected sync request.',
        );
      }

      await _inventoryService.recordSheetSync();
      return items.length;
    } on TimeoutException {
      throw Exception(
        'Google Sheet sync timed out. Check your internet connection and try again.',
      );
    } on SocketException {
      throw Exception('No internet connection. Unable to reach Google Sheets.');
    }
  }

  Future<int> importEquipmentFromSheet() async {
    final uri = Uri.parse(
      webhookUrl,
    ).replace(queryParameters: {'token': apiToken});

    try {
      var response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl == null || redirectUrl.isEmpty) {
          throw Exception('Apps Script redirect missing Location header.');
        }
        response = await _client
            .get(Uri.parse(redirectUrl))
            .timeout(const Duration(seconds: 30));
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch Google Sheet (HTTP ${response.statusCode}).',
        );
      }

      final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw Exception(
          'Invalid response from Apps Script. Ensure Web App access is set to "Anyone".',
        );
      }

      if (decoded is! Map || decoded['ok'] == false) {
        throw Exception(
          (decoded is Map ? decoded['error'] : null) ??
              'Apps Script rejected fetch request.',
        );
      }

      final rawItems = decoded['items'];
      if (rawItems is! List || rawItems.isEmpty) {
        return 0;
      }

      final importedCount = await _inventoryService
          .importEquipmentFromSheetRows(rawItems);
      await _inventoryService.recordSheetSync();
      return importedCount;
    } on TimeoutException {
      throw Exception(
        'Fetching Google Sheet timed out. Check your internet connection and try again.',
      );
    } on SocketException {
      throw Exception('No internet connection. Unable to reach Google Sheets.');
    }
  }
}

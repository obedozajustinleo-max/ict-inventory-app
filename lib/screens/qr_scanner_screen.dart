import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/equipment_item.dart';
import 'equipment_detail_screen.dart';

class QrScannerScreen extends StatefulWidget {
  final List<EquipmentItem> allItems;

  const QrScannerScreen({super.key, required this.allItems});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;

    EquipmentItem? match;
    for (final item in widget.allItems) {
      if (item.id == raw ||
          item.propertyNumber.toLowerCase() == raw.toLowerCase() ||
          item.serialNumber.toLowerCase() == raw.toLowerCase()) {
        match = item;
        break;
      }
    }

    _handled = true;
    if (match != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EquipmentDetailScreen(itemId: match!.id),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No equipment found for code "$raw".')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Equipment QR / Tag')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}

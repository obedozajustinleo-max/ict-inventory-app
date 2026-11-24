import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/date_formatter.dart';
import '../models/equipment_item.dart';
import '../services/inventory_service.dart';
import '../services/storage_service.dart';

class EquipmentFormScreen extends StatefulWidget {
  final EquipmentItem? existingItem;

  const EquipmentFormScreen({super.key, this.existingItem});

  @override
  State<EquipmentFormScreen> createState() => _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends State<EquipmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inventoryService = InventoryService();
  final _storageService = StorageService();
  final _picker = ImagePicker();

  late List<String> _divisionOptions;
  late List<String> _locationOptions;
  late String _division;
  late String _equipmentType;
  late String _condition;
  late String _location;
  late DateTime _dateAcquired;
  DateTime? _warrantyEndDate;

  late final TextEditingController _brandModelCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _propertyCtrl;
  late final TextEditingController _personnelCtrl;
  late final TextEditingController _remarksCtrl;

  File? _newSerialPhoto;
  File? _newPropertyPhoto;
  bool _saving = false;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;

    _divisionOptions = List<String>.from(AppConstants.divisions);
    if (item != null &&
        item.division.trim().isNotEmpty &&
        !_divisionOptions.contains(item.division)) {
      _divisionOptions.insert(0, item.division);
    }

    _locationOptions = List<String>.from(AppConstants.defaultLocations);
    if (item != null &&
        item.location.trim().isNotEmpty &&
        !_locationOptions.contains(item.location)) {
      _locationOptions.insert(0, item.location);
    }

    _division = item?.division ?? _divisionOptions.first;
    _equipmentType = item?.equipmentType ?? AppConstants.equipmentTypes.first;
    _condition = item?.condition ?? AppConstants.conditions.first;
    _location = item?.location ?? _locationOptions.first;
    _dateAcquired = item?.dateAcquired ?? DateTime.now();
    _warrantyEndDate = item?.warrantyEndDate;

    _brandModelCtrl = TextEditingController(text: item?.brandModel ?? '');
    _serialCtrl = TextEditingController(text: item?.serialNumber ?? '');
    _propertyCtrl = TextEditingController(text: item?.propertyNumber ?? '');
    _personnelCtrl = TextEditingController(
      text: item?.responsiblePersonnel ?? '',
    );
    _remarksCtrl = TextEditingController(text: item?.remarks ?? '');
  }

  @override
  void dispose() {
    _brandModelCtrl.dispose();
    _serialCtrl.dispose();
    _propertyCtrl.dispose();
    _personnelCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto({required bool isSerial}) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (picked == null) return;
      setState(() {
        if (isSerial) {
          _newSerialPhoto = File(picked.path);
        } else {
          _newPropertyPhoto = File(picked.path);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
    }
  }

  Future<void> _pickDate({required bool isWarranty}) async {
    final initial = isWarranty
        ? (_warrantyEndDate ?? _dateAcquired.add(const Duration(days: 365)))
        : _dateAcquired;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2005),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    setState(() {
      if (isWarranty) {
        _warrantyEndDate = picked;
      } else {
        _dateAcquired = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final itemId =
          widget.existingItem?.id ?? _inventoryService.generateNewItemId();

      final duplicateError = await _inventoryService
          .checkDuplicateIdentifiers(
            propertyNumber: _propertyCtrl.text,
            serialNumber: _serialCtrl.text,
            excludeItemId: _isEditing ? itemId : null,
          )
          .timeout(const Duration(seconds: 10));
      if (duplicateError != null) {
        messenger.showSnackBar(SnackBar(content: Text(duplicateError)));
        return;
      }

      String? serialUrl = widget.existingItem?.serialPhotoUrl;
      String? propertyUrl = widget.existingItem?.propertyTagPhotoUrl;

      if (_newSerialPhoto != null) {
        serialUrl = await _storageService
            .uploadEquipmentPhoto(
              itemId: itemId,
              tagType: 'serial_number',
              imageFile: _newSerialPhoto!,
            )
            .timeout(const Duration(seconds: 30));
      }
      if (_newPropertyPhoto != null) {
        propertyUrl = await _storageService
            .uploadEquipmentPhoto(
              itemId: itemId,
              tagType: 'property_tag',
              imageFile: _newPropertyPhoto!,
            )
            .timeout(const Duration(seconds: 30));
      }

      final draft = EquipmentItem(
        id: itemId,
        division: _division,
        equipmentType: _equipmentType,
        brandModel: _brandModelCtrl.text,
        serialNumber: _serialCtrl.text,
        propertyNumber: _propertyCtrl.text,
        dateAcquired: _dateAcquired,
        warrantyEndDate: _warrantyEndDate,
        location: _location,
        responsiblePersonnel: _personnelCtrl.text,
        condition: _condition,
        remarks: _remarksCtrl.text,
        serialPhotoUrl: serialUrl,
        propertyTagPhotoUrl: propertyUrl,
        isArchived: widget.existingItem?.isArchived ?? false,
        createdBy: widget.existingItem?.createdBy ?? '',
        updatedBy: '',
      );

      if (_isEditing) {
        await _inventoryService
            .updateEquipment(previous: widget.existingItem!, updated: draft)
            .timeout(const Duration(seconds: 12));
      } else {
        await _inventoryService
            .createEquipment(draft)
            .timeout(const Duration(seconds: 12));
      }

      if (mounted) Navigator.pop(context);
    } on TimeoutException {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Saved offline; will sync when connection returns.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Equipment' : 'Add Equipment'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _division,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Division (Sheet Section)',
                border: OutlineInputBorder(),
              ),
              items: _divisionOptions
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text(d, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _division = val ?? _division),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _equipmentType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Equipment Type',
                border: OutlineInputBorder(),
              ),
              items: AppConstants.equipmentTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) =>
                  setState(() => _equipmentType = val ?? _equipmentType),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brandModelCtrl,
              decoration: const InputDecoration(
                labelText: 'Brand / Model',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _serialCtrl,
              decoration: const InputDecoration(
                labelText: 'Serial Number',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _propertyCtrl,
              decoration: const InputDecoration(
                labelText: 'Property Number',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isWarranty: false),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      'Acquired: ${DateFormatter.formatShort(_dateAcquired)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isWarranty: true),
                    icon: const Icon(Icons.verified_user, size: 18),
                    label: Text(
                      'Warranty: ${DateFormatter.formatShort(_warrantyEndDate)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _location,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
              items: _locationOptions
                  .map(
                    (loc) => DropdownMenuItem(
                      value: loc,
                      child: Text(loc, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _location = val ?? _location),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _personnelCtrl,
              decoration: const InputDecoration(
                labelText: 'Responsible Personnel',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _condition,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Condition',
                border: OutlineInputBorder(),
              ),
              items: AppConstants.conditions
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) =>
                  setState(() => _condition = val ?? _condition),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _remarksCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Remarks',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TagCaptureBox(
                    title: 'Serial Photo',
                    localFile: _newSerialPhoto,
                    remoteUrl: widget.existingItem?.serialPhotoUrl,
                    onCapture: () => _capturePhoto(isSerial: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TagCaptureBox(
                    title: 'Property Tag Photo',
                    localFile: _newPropertyPhoto,
                    remoteUrl: widget.existingItem?.propertyTagPhotoUrl,
                    onCapture: () => _capturePhoto(isSerial: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save Equipment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagCaptureBox extends StatelessWidget {
  final String title;
  final File? localFile;
  final String? remoteUrl;
  final VoidCallback onCapture;

  const _TagCaptureBox({
    required this.title,
    required this.localFile,
    required this.remoteUrl,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (localFile != null) {
      preview = Image.file(localFile!, fit: BoxFit.cover);
    } else if (remoteUrl != null && remoteUrl!.isNotEmpty) {
      preview = Image.network(remoteUrl!, fit: BoxFit.cover);
    } else {
      preview = const Center(child: Icon(Icons.camera_alt, size: 32));
    }

    return Column(
      children: [
        InkWell(
          onTap: onCapture,
          child: Container(
            height: 120,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(10),
            ),
            child: preview,
          ),
        ),
        const SizedBox(height: 6),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

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
  late List<String> _equipmentTypeOptions;
  late String _division;
  late String _equipmentType;
  late String _condition;
  late String _location;
  DateTime? _dateAcquired;
  DateTime? _warrantyEndDate;

  late final TextEditingController _yearCtrl;
  late final TextEditingController _brandModelCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _propertyCtrl;
  late final TextEditingController _personnelCtrl;
  late final TextEditingController _assignedEmailCtrl;
  late final TextEditingController _remarksCtrl;

  late List<EquipmentComponent> _components;

  File? _newSerialPhoto;
  File? _newPropertyPhoto;
  bool _saving = false;

  bool get _isEditing => widget.existingItem != null;
  bool get _supportsComponents =>
      _equipmentType.toLowerCase().contains('desktop');

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

    _equipmentTypeOptions = List<String>.from(AppConstants.equipmentTypes);
    if (!_equipmentTypeOptions.any(
      (t) => t.toLowerCase().contains('desktop'),
    )) {
      _equipmentTypeOptions.insert(0, 'Desktop Set');
    }
    if (item != null &&
        item.equipmentType.trim().isNotEmpty &&
        !_equipmentTypeOptions.contains(item.equipmentType)) {
      _equipmentTypeOptions.insert(0, item.equipmentType);
    }

    _division = item?.division ?? _divisionOptions.first;
    _equipmentType = item?.equipmentType ?? _equipmentTypeOptions.first;
    _condition = item?.condition ?? AppConstants.conditions.first;
    _location = item?.location ?? _locationOptions.first;
    _dateAcquired = item?.dateAcquired;
    _warrantyEndDate = item?.warrantyEndDate;

    final initialYear = (item?.year.trim().isNotEmpty == true)
        ? item!.year.trim()
        : (_dateAcquired != null ? _dateAcquired!.year.toString() : '');

    _yearCtrl = TextEditingController(text: initialYear);
    _brandModelCtrl = TextEditingController(text: item?.brandModel ?? '');
    _serialCtrl = TextEditingController(text: item?.serialNumber ?? '');
    _propertyCtrl = TextEditingController(text: item?.propertyNumber ?? '');
    _personnelCtrl = TextEditingController(
      text: item?.responsiblePersonnel ?? '',
    );
    _assignedEmailCtrl = TextEditingController(
      text: item?.assignedUserEmail ?? '',
    );
    _remarksCtrl = TextEditingController(text: item?.remarks ?? '');

    _components = item?.components.map((c) => c.copyWith()).toList() ?? [];
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _brandModelCtrl.dispose();
    _serialCtrl.dispose();
    _propertyCtrl.dispose();
    _personnelCtrl.dispose();
    _assignedEmailCtrl.dispose();
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
    final baseDate = _dateAcquired ?? DateTime.now();
    final initial = isWarranty
        ? (_warrantyEndDate ?? baseDate.add(const Duration(days: 365)))
        : baseDate;
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
        if (_yearCtrl.text.trim().isEmpty) {
          _yearCtrl.text = picked.year.toString();
        }
      }
    });
  }

  Future<void> _openComponentDialog({
    EquipmentComponent? existing,
    int? index,
  }) async {
    final result = await showDialog<EquipmentComponent>(
      context: context,
      builder: (_) => _PeripheralDialog(
        existing: existing,
        defaultYear: _yearCtrl.text.trim(),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      if (index != null && index >= 0 && index < _components.length) {
        _components[index] = result;
      } else {
        _components.add(result);
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

      final finalComponents = List<EquipmentComponent>.from(_components);
      if (_supportsComponents && finalComponents.isNotEmpty) {
        final hasSystemUnit = finalComponents.any(
          (c) => c.componentType.toLowerCase().contains('system unit'),
        );
        if (!hasSystemUnit && _brandModelCtrl.text.trim().isNotEmpty) {
          finalComponents.insert(
            0,
            EquipmentComponent(
              componentType: 'System Unit',
              year: _yearCtrl.text.trim(),
              brandModel: _brandModelCtrl.text.trim(),
              serialNumber: _serialCtrl.text.trim(),
              propertyNumber: _propertyCtrl.text.trim(),
              dateAcquired: _dateAcquired != null
                  ? _dateAcquired!.toIso8601String().split('T').first
                  : '',
              warrantyPeriod: _warrantyEndDate != null
                  ? _warrantyEndDate!.toIso8601String().split('T').first
                  : '',
              condition: _condition,
              remarks: _remarksCtrl.text.trim(),
            ),
          );
        }
      }

      final resolvedYear = _yearCtrl.text.trim().isNotEmpty
          ? _yearCtrl.text.trim()
          : (_dateAcquired != null ? _dateAcquired!.year.toString() : '');

      final draft = EquipmentItem(
        id: itemId,
        division: _division,
        equipmentType: _equipmentType,
        year: resolvedYear,
        brandModel: _brandModelCtrl.text,
        serialNumber: _serialCtrl.text,
        propertyNumber: _propertyCtrl.text,
        dateAcquired: _dateAcquired,
        warrantyEndDate: _warrantyEndDate,
        location: _location,
        responsiblePersonnel: _personnelCtrl.text,
        assignedUserEmail: _assignedEmailCtrl.text.trim().isEmpty
            ? null
            : _assignedEmailCtrl.text.trim(),
        condition: _condition,
        remarks: _remarksCtrl.text,
        serialPhotoUrl: serialUrl,
        propertyTagPhotoUrl: propertyUrl,
        components: _supportsComponents ? finalComponents : const [],
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
              items: _equipmentTypeOptions
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
              controller: _yearCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Year (Release / Acquisition)',
                border: OutlineInputBorder(),
              ),
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
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _propertyCtrl,
              decoration: const InputDecoration(
                labelText: 'Property Number',
                border: OutlineInputBorder(),
              ),
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
                labelText: 'Location / Section',
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
            TextFormField(
              controller: _assignedEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Assigned Employee Email (Optional, for MR Portal)',
                border: OutlineInputBorder(),
              ),
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

            if (_supportsComponents) ...[
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Desktop Set Peripherals (${_components.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openComponentDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Peripheral'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_components.isEmpty)
                const Text(
                  'No peripherals added yet. Tap "Add Peripheral" for System Unit, Monitor, UPS, Mouse, or Keyboard.',
                )
              else
                ...List.generate(_components.length, (idx) {
                  final comp = _components[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        '${comp.componentType}${comp.year.isNotEmpty ? " (${comp.year})" : ""} — ${comp.brandModel.isEmpty ? "—" : comp.brandModel}',
                      ),
                      subtitle: Text(
                        'SN: ${comp.serialNumber.isEmpty ? "—" : comp.serialNumber} • '
                        'Prop #: ${comp.propertyNumber.isEmpty ? "—" : comp.propertyNumber} • '
                        '${comp.condition}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit Peripheral',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openComponentDialog(
                              existing: comp,
                              index: idx,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove Peripheral',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                setState(() => _components.removeAt(idx)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],

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

class _PeripheralDialog extends StatefulWidget {
  final EquipmentComponent? existing;
  final String defaultYear;

  const _PeripheralDialog({this.existing, required this.defaultYear});

  @override
  State<_PeripheralDialog> createState() => _PeripheralDialogState();
}

class _PeripheralDialogState extends State<_PeripheralDialog> {
  late final TextEditingController _typeCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _propCtrl;
  late final TextEditingController _remarksCtrl;
  late String _compCondition;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _typeCtrl = TextEditingController(
      text: existing?.componentType ?? 'System Unit',
    );
    _yearCtrl = TextEditingController(
      text: existing?.year.isNotEmpty == true
          ? existing!.year
          : widget.defaultYear,
    );
    _modelCtrl = TextEditingController(text: existing?.brandModel ?? '');
    _serialCtrl = TextEditingController(text: existing?.serialNumber ?? '');
    _propCtrl = TextEditingController(text: existing?.propertyNumber ?? '');
    _remarksCtrl = TextEditingController(text: existing?.remarks ?? '');
    _compCondition = existing?.condition ?? 'Working';
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _yearCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _propCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add Peripheral' : 'Edit Peripheral',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _typeCtrl,
              decoration: const InputDecoration(
                labelText: 'Component (e.g., System Unit, Monitor, UPS)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _yearCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Year'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _modelCtrl,
              decoration: const InputDecoration(labelText: 'Brand / Model'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _serialCtrl,
              decoration: const InputDecoration(labelText: 'Serial Number'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _propCtrl,
              decoration: const InputDecoration(labelText: 'Property Number'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: AppConstants.conditions.contains(_compCondition)
                  ? _compCondition
                  : AppConstants.conditions.first,
              decoration: const InputDecoration(labelText: 'Condition'),
              items: AppConstants.conditions
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _compCondition = v ?? 'Working'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _remarksCtrl,
              decoration: const InputDecoration(labelText: 'Remarks'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final compType = _typeCtrl.text.trim();
            if (compType.isEmpty) return;
            Navigator.pop(
              context,
              EquipmentComponent(
                componentType: compType,
                year: _yearCtrl.text.trim(),
                brandModel: _modelCtrl.text.trim(),
                serialNumber: _serialCtrl.text.trim(),
                propertyNumber: _propCtrl.text.trim(),
                condition: _compCondition,
                remarks: _remarksCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
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

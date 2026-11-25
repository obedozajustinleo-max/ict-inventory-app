import 'package:cloud_firestore/cloud_firestore.dart';

class EquipmentComponent {
  final String componentType;
  final String year;
  final String brandModel;
  final String serialNumber;
  final String propertyNumber;
  final String dateAcquired;
  final String warrantyPeriod;
  final String condition;
  final String remarks;

  const EquipmentComponent({
    required this.componentType,
    this.year = '',
    this.brandModel = '',
    this.serialNumber = '',
    this.propertyNumber = '',
    this.dateAcquired = '',
    this.warrantyPeriod = '',
    this.condition = 'Working',
    this.remarks = '',
  });

  EquipmentComponent copyWith({
    String? componentType,
    String? year,
    String? brandModel,
    String? serialNumber,
    String? propertyNumber,
    String? dateAcquired,
    String? warrantyPeriod,
    String? condition,
    String? remarks,
  }) {
    return EquipmentComponent(
      componentType: componentType ?? this.componentType,
      year: year ?? this.year,
      brandModel: brandModel ?? this.brandModel,
      serialNumber: serialNumber ?? this.serialNumber,
      propertyNumber: propertyNumber ?? this.propertyNumber,
      dateAcquired: dateAcquired ?? this.dateAcquired,
      warrantyPeriod: warrantyPeriod ?? this.warrantyPeriod,
      condition: condition ?? this.condition,
      remarks: remarks ?? this.remarks,
    );
  }

  factory EquipmentComponent.fromMap(Map<String, dynamic> map) {
    return EquipmentComponent(
      componentType: (map['componentType'] ?? map['Component'] ?? '')
          .toString()
          .trim(),
      year: (map['year'] ?? map['Year'] ?? '').toString().trim(),
      brandModel: (map['brandModel'] ?? map['Brand/Model'] ?? '')
          .toString()
          .trim(),
      serialNumber: (map['serialNumber'] ?? map['Serial Number'] ?? '')
          .toString()
          .trim(),
      propertyNumber: (map['propertyNumber'] ?? map['Property Number'] ?? '')
          .toString()
          .trim(),
      dateAcquired: (map['dateAcquired'] ?? map['Date Acquired'] ?? '')
          .toString()
          .trim(),
      warrantyPeriod:
          (map['warrantyPeriod'] ??
                  map['Warranty Period'] ??
                  map['warrantyEndDate'] ??
                  '')
              .toString()
              .trim(),
      condition: (map['condition'] ?? map['Condition'] ?? 'Working')
          .toString()
          .trim(),
      remarks: (map['remarks'] ?? map['Remarks'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'componentType': componentType.trim(),
      'year': year.trim(),
      'brandModel': brandModel.trim(),
      'serialNumber': serialNumber.trim(),
      'propertyNumber': propertyNumber.trim(),
      'dateAcquired': dateAcquired.trim(),
      'warrantyPeriod': warrantyPeriod.trim(),
      'condition': condition.trim(),
      'remarks': remarks.trim(),
    };
  }
}

class EquipmentItem {
  final String id;
  final String division;
  final String equipmentType;
  final String year;
  final String brandModel;
  final String serialNumber;
  final String propertyNumber;
  final DateTime? dateAcquired;
  final DateTime? warrantyEndDate;
  final String location;
  final String responsiblePersonnel;
  final String? assignedUserEmail;
  final String condition;
  final String remarks;
  final String? serialPhotoUrl;
  final String? propertyTagPhotoUrl;
  final List<EquipmentComponent> components;
  final bool isArchived;
  final String createdBy;
  final String updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EquipmentItem({
    required this.id,
    required this.division,
    required this.equipmentType,
    this.year = '',
    required this.brandModel,
    required this.serialNumber,
    required this.propertyNumber,
    this.dateAcquired,
    this.warrantyEndDate,
    required this.location,
    required this.responsiblePersonnel,
    this.assignedUserEmail,
    required this.condition,
    required this.remarks,
    this.serialPhotoUrl,
    this.propertyTagPhotoUrl,
    this.components = const [],
    this.isArchived = false,
    required this.createdBy,
    required this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDesktopSet =>
      equipmentType.toLowerCase().contains('desktop') && components.isNotEmpty;

  EquipmentItem copyWith({
    String? id,
    String? division,
    String? equipmentType,
    String? year,
    String? brandModel,
    String? serialNumber,
    String? propertyNumber,
    DateTime? dateAcquired,
    bool clearDateAcquired = false,
    DateTime? warrantyEndDate,
    bool clearWarrantyEndDate = false,
    String? location,
    String? responsiblePersonnel,
    String? assignedUserEmail,
    String? condition,
    String? remarks,
    String? serialPhotoUrl,
    String? propertyTagPhotoUrl,
    List<EquipmentComponent>? components,
    bool? isArchived,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EquipmentItem(
      id: id ?? this.id,
      division: division ?? this.division,
      equipmentType: equipmentType ?? this.equipmentType,
      year: year ?? this.year,
      brandModel: brandModel ?? this.brandModel,
      serialNumber: serialNumber ?? this.serialNumber,
      propertyNumber: propertyNumber ?? this.propertyNumber,
      dateAcquired: clearDateAcquired
          ? null
          : (dateAcquired ?? this.dateAcquired),
      warrantyEndDate: clearWarrantyEndDate
          ? null
          : (warrantyEndDate ?? this.warrantyEndDate),
      location: location ?? this.location,
      responsiblePersonnel: responsiblePersonnel ?? this.responsiblePersonnel,
      assignedUserEmail: assignedUserEmail ?? this.assignedUserEmail,
      condition: condition ?? this.condition,
      remarks: remarks ?? this.remarks,
      serialPhotoUrl: serialPhotoUrl ?? this.serialPhotoUrl,
      propertyTagPhotoUrl: propertyTagPhotoUrl ?? this.propertyTagPhotoUrl,
      components: components ?? this.components,
      isArchived: isArchived ?? this.isArchived,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory EquipmentItem.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawComponents = (data['components'] as List<dynamic>?) ?? const [];
    final parsedComponents = rawComponents
        .whereType()
        .map((c) => EquipmentComponent.fromMap(Map<String, dynamic>.from(c)))
        .toList();

    final acquiredDate = (data['dateAcquired'] as Timestamp?)?.toDate();
    final rawYear = (data['year'] ?? '').toString().trim();

    return EquipmentItem(
      id: doc.id,
      division: (data['division'] ?? 'OFFICE OF THE TRC CHIEF').toString(),
      equipmentType: (data['equipmentType'] ?? '').toString(),
      year: rawYear.isNotEmpty
          ? rawYear
          : (acquiredDate != null ? acquiredDate.year.toString() : ''),
      brandModel: (data['brandModel'] ?? '').toString(),
      serialNumber: (data['serialNumber'] ?? '').toString(),
      propertyNumber: (data['propertyNumber'] ?? '').toString(),
      dateAcquired: acquiredDate,
      warrantyEndDate: (data['warrantyEndDate'] as Timestamp?)?.toDate(),
      location: (data['location'] ?? '').toString(),
      responsiblePersonnel: (data['responsiblePersonnel'] ?? '').toString(),
      assignedUserEmail: data['assignedUserEmail'] as String?,
      condition: (data['condition'] ?? 'Working').toString(),
      remarks: (data['remarks'] ?? '').toString(),
      serialPhotoUrl: data['serialPhotoUrl'] as String?,
      propertyTagPhotoUrl: data['propertyTagPhotoUrl'] as String?,
      components: parsedComponents,
      isArchived: (data['isArchived'] as bool?) ?? false,
      createdBy: (data['createdBy'] ?? '').toString(),
      updatedBy: (data['updatedBy'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory EquipmentItem.fromSheetRow(
    Map<String, dynamic> row, {
    required String resolvedId,
    required String currentUser,
  }) {
    String pick(List<String> keys, [String fallback = '']) {
      for (final k in keys) {
        final v = row[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return fallback;
    }

    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      final str = raw.toString().trim();
      if (str.isEmpty) return null;
      return DateTime.tryParse(str);
    }

    bool parseBool(dynamic raw) {
      if (raw is bool) return raw;
      final str = (raw ?? '').toString().trim().toLowerCase();
      return str == 'true' || str == '1' || str == 'yes';
    }

    final rawComponents = (row['components'] as List<dynamic>?) ?? const [];
    final parsedComponents = rawComponents
        .whereType()
        .map((c) => EquipmentComponent.fromMap(Map<String, dynamic>.from(c)))
        .toList();

    final serialPhoto = pick(['serialPhotoUrl', 'Serial Photo URL']);
    final propPhoto = pick(['propertyTagPhotoUrl', 'Property Tag Photo URL']);
    final assignedEmail = pick(['assignedUserEmail', 'Assigned Email']);
    final acquired = parseDate(row['dateAcquired'] ?? row['Date Acquired']);
    final yearStr = pick([
      'year',
      'Year',
    ], acquired != null ? acquired.year.toString() : '');

    return EquipmentItem(
      id: resolvedId,
      division: pick(['division', 'Division'], 'OFFICE OF THE TRC CHIEF'),
      equipmentType: pick(['equipmentType', 'Equipment Type']),
      year: yearStr,
      brandModel: pick(['brandModel', 'Brand/Model', 'Brand Model']),
      serialNumber: pick(['serialNumber', 'Serial Number']),
      propertyNumber: pick(['propertyNumber', 'Property Number']),
      dateAcquired: acquired,
      warrantyEndDate: parseDate(
        row['warrantyEndDate'] ??
            row['warrantyPeriod'] ??
            row['Warranty Period'] ??
            row['Warranty End Date'],
      ),
      location: pick(['location', 'Location', 'Section/Unit']),
      responsiblePersonnel: pick([
        'responsiblePersonnel',
        'Responsible Personnel',
      ]),
      assignedUserEmail: assignedEmail.isEmpty ? null : assignedEmail,
      condition: pick([
        'condition',
        'Condition (Working/For Repair/Defective)',
        'Condition',
      ], 'Working'),
      remarks: pick(['remarks', 'Remarks']),
      serialPhotoUrl: serialPhoto.isEmpty ? null : serialPhoto,
      propertyTagPhotoUrl: propPhoto.isEmpty ? null : propPhoto,
      components: parsedComponents,
      isArchived: parseBool(row['isArchived'] ?? row['Is Archived']),
      createdBy: currentUser,
      updatedBy: currentUser,
    );
  }

  Map<String, dynamic> toFirestore({required bool isNew}) {
    final resolvedYear = year.trim().isNotEmpty
        ? year.trim()
        : (dateAcquired != null ? dateAcquired!.year.toString() : '');

    return {
      'division': division.trim(),
      'equipmentType': equipmentType.trim(),
      'year': resolvedYear,
      'brandModel': brandModel.trim(),
      'serialNumber': serialNumber.trim(),
      'propertyNumber': propertyNumber.trim(),
      'dateAcquired': dateAcquired != null
          ? Timestamp.fromDate(dateAcquired!)
          : null,
      'warrantyEndDate': warrantyEndDate != null
          ? Timestamp.fromDate(warrantyEndDate!)
          : null,
      'location': location.trim(),
      'responsiblePersonnel': responsiblePersonnel.trim(),
      'assignedUserEmail': assignedUserEmail?.trim().isEmpty == true
          ? null
          : assignedUserEmail?.trim(),
      'condition': condition.trim(),
      'remarks': remarks.trim(),
      'serialPhotoUrl': serialPhotoUrl,
      'propertyTagPhotoUrl': propertyTagPhotoUrl,
      'components': components.map((c) => c.toMap()).toList(),
      'isArchived': isArchived,
      if (isNew) ...{
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      },
      'updatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toSheetRowJson() {
    final resolvedYear = year.trim().isNotEmpty
        ? year.trim()
        : (dateAcquired != null ? dateAcquired!.year.toString() : '');

    return {
      'id': id,
      'division': division,
      'equipmentType': equipmentType,
      'year': resolvedYear,
      'brandModel': brandModel,
      'serialNumber': serialNumber,
      'propertyNumber': propertyNumber,
      'dateAcquired': dateAcquired?.toIso8601String().split('T').first ?? '',
      'warrantyPeriod':
          warrantyEndDate?.toIso8601String().split('T').first ?? '',
      'warrantyEndDate':
          warrantyEndDate?.toIso8601String().split('T').first ?? '',
      'location': location,
      'responsiblePersonnel': responsiblePersonnel,
      'assignedUserEmail': assignedUserEmail ?? '',
      'condition': condition,
      'remarks': remarks,
      'serialPhotoUrl': serialPhotoUrl ?? '',
      'propertyTagPhotoUrl': propertyTagPhotoUrl ?? '',
      'components': components.map((c) => c.toMap()).toList(),
      'isArchived': isArchived,
      'updatedBy': updatedBy,
      'updatedAt': updatedAt?.toIso8601String() ?? '',
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class EquipmentItem {
  final String id;
  final String division;
  final String equipmentType;
  final String brandModel;
  final String serialNumber;
  final String propertyNumber;
  final DateTime dateAcquired;
  final DateTime? warrantyEndDate;
  final String location;
  final String responsiblePersonnel;
  final String condition;
  final String remarks;
  final String? serialPhotoUrl;
  final String? propertyTagPhotoUrl;
  final bool isArchived;
  final String createdBy;
  final String updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EquipmentItem({
    required this.id,
    required this.division,
    required this.equipmentType,
    required this.brandModel,
    required this.serialNumber,
    required this.propertyNumber,
    required this.dateAcquired,
    this.warrantyEndDate,
    required this.location,
    required this.responsiblePersonnel,
    required this.condition,
    required this.remarks,
    this.serialPhotoUrl,
    this.propertyTagPhotoUrl,
    this.isArchived = false,
    required this.createdBy,
    required this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  EquipmentItem copyWith({
    String? id,
    String? division,
    String? equipmentType,
    String? brandModel,
    String? serialNumber,
    String? propertyNumber,
    DateTime? dateAcquired,
    DateTime? warrantyEndDate,
    bool clearWarrantyEndDate = false,
    String? location,
    String? responsiblePersonnel,
    String? condition,
    String? remarks,
    String? serialPhotoUrl,
    String? propertyTagPhotoUrl,
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
      brandModel: brandModel ?? this.brandModel,
      serialNumber: serialNumber ?? this.serialNumber,
      propertyNumber: propertyNumber ?? this.propertyNumber,
      dateAcquired: dateAcquired ?? this.dateAcquired,
      warrantyEndDate: clearWarrantyEndDate
          ? null
          : (warrantyEndDate ?? this.warrantyEndDate),
      location: location ?? this.location,
      responsiblePersonnel: responsiblePersonnel ?? this.responsiblePersonnel,
      condition: condition ?? this.condition,
      remarks: remarks ?? this.remarks,
      serialPhotoUrl: serialPhotoUrl ?? this.serialPhotoUrl,
      propertyTagPhotoUrl: propertyTagPhotoUrl ?? this.propertyTagPhotoUrl,
      isArchived: isArchived ?? this.isArchived,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory EquipmentItem.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return EquipmentItem(
      id: doc.id,
      division: (data['division'] ?? 'OFFICE OF THE TRC CHIEF').toString(),
      equipmentType: (data['equipmentType'] ?? '').toString(),
      brandModel: (data['brandModel'] ?? '').toString(),
      serialNumber: (data['serialNumber'] ?? '').toString(),
      propertyNumber: (data['propertyNumber'] ?? '').toString(),
      dateAcquired:
          (data['dateAcquired'] as Timestamp?)?.toDate() ?? DateTime.now(),
      warrantyEndDate: (data['warrantyEndDate'] as Timestamp?)?.toDate(),
      location: (data['location'] ?? '').toString(),
      responsiblePersonnel: (data['responsiblePersonnel'] ?? '').toString(),
      condition: (data['condition'] ?? 'Working').toString(),
      remarks: (data['remarks'] ?? '').toString(),
      serialPhotoUrl: data['serialPhotoUrl'] as String?,
      propertyTagPhotoUrl: data['propertyTagPhotoUrl'] as String?,
      isArchived: (data['isArchived'] as bool?) ?? false,
      createdBy: (data['createdBy'] ?? '').toString(),
      updatedBy: (data['updatedBy'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore({required bool isNew}) {
    return {
      'division': division.trim(),
      'equipmentType': equipmentType.trim(),
      'brandModel': brandModel.trim(),
      'serialNumber': serialNumber.trim(),
      'propertyNumber': propertyNumber.trim(),
      'dateAcquired': Timestamp.fromDate(dateAcquired),
      'warrantyEndDate': warrantyEndDate != null
          ? Timestamp.fromDate(warrantyEndDate!)
          : null,
      'location': location.trim(),
      'responsiblePersonnel': responsiblePersonnel.trim(),
      'condition': condition.trim(),
      'remarks': remarks.trim(),
      'serialPhotoUrl': serialPhotoUrl,
      'propertyTagPhotoUrl': propertyTagPhotoUrl,
      'isArchived': isArchived,
      if (isNew) ...{
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      },
      'updatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Payload formatted for the division-aware Google Apps Script webhook
  Map<String, dynamic> toSheetRowJson() {
    return {
      'id': id,
      'division': division,
      'equipmentType': equipmentType,
      'brandModel': brandModel,
      'serialNumber': serialNumber,
      'propertyNumber': propertyNumber,
      'dateAcquired': dateAcquired.toIso8601String().split('T').first,
      'warrantyEndDate':
          warrantyEndDate?.toIso8601String().split('T').first ?? '',
      'location': location,
      'responsiblePersonnel': responsiblePersonnel,
      'condition': condition,
      'remarks': remarks,
      'serialPhotoUrl': serialPhotoUrl ?? '',
      'propertyTagPhotoUrl': propertyTagPhotoUrl ?? '',
      'isArchived': isArchived,
      'updatedBy': updatedBy,
      'updatedAt': updatedAt?.toIso8601String() ?? '',
    };
  }
}

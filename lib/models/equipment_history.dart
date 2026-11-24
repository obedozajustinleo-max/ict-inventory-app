import 'package:cloud_firestore/cloud_firestore.dart';

class EquipmentHistory {
  final String id;
  final String fieldChanged;
  final String oldValue;
  final String newValue;
  final String changedBy;
  final DateTime? changedAt;

  const EquipmentHistory({
    required this.id,
    required this.fieldChanged,
    required this.oldValue,
    required this.newValue,
    required this.changedBy,
    this.changedAt,
  });

  factory EquipmentHistory.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return EquipmentHistory(
      id: doc.id,
      fieldChanged: (data['fieldChanged'] ?? '').toString(),
      oldValue: (data['oldValue'] ?? '').toString(),
      newValue: (data['newValue'] ?? '').toString(),
      changedBy: (data['changedBy'] ?? '').toString(),
      changedAt: (data['changedAt'] as Timestamp?)?.toDate(),
    );
  }
}

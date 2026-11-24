import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/app_constants.dart';
import '../models/equipment_history.dart';
import '../models/equipment_item.dart';

class InventoryService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  InventoryService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  CollectionReference get _itemsRef =>
      _db.collection(AppConstants.equipmentCollection);

  DocumentReference get _sheetSyncRef => _db
      .collection(AppConstants.metadataCollection)
      .doc(AppConstants.sheetSyncDocId);

  String get currentUserLabel =>
      _auth.currentUser?.email ?? _auth.currentUser?.uid ?? 'ict_staff';

  String generateNewItemId() => _itemsRef.doc().id;

  Stream<List<EquipmentItem>> watchActiveEquipment() {
    return _itemsRef
        .where('isArchived', isEqualTo: false)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EquipmentItem.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<EquipmentHistory>> watchItemHistory(String itemId) {
    return _itemsRef
        .doc(itemId)
        .collection(AppConstants.historySubcollection)
        .orderBy('changedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EquipmentHistory.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<DateTime?> watchLastSyncedAt() {
    return _sheetSyncRef.snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return (data?['lastSyncedAt'] as Timestamp?)?.toDate();
    });
  }

  Future<String?> checkDuplicateIdentifiers({
    required String propertyNumber,
    required String serialNumber,
    String? excludeItemId,
  }) async {
    final cleanProp = propertyNumber.trim();
    final cleanSerial = serialNumber.trim();

    if (cleanProp.isNotEmpty) {
      final propSnap = await _itemsRef
          .where('propertyNumber', isEqualTo: cleanProp)
          .limit(5)
          .get();
      final conflict = propSnap.docs
          .where((d) => d.id != excludeItemId)
          .toList();
      if (conflict.isNotEmpty) {
        return 'Property Number "$cleanProp" is already assigned to another item.';
      }
    }

    if (cleanSerial.isNotEmpty) {
      final serialSnap = await _itemsRef
          .where('serialNumber', isEqualTo: cleanSerial)
          .limit(5)
          .get();
      final conflict = serialSnap.docs
          .where((d) => d.id != excludeItemId)
          .toList();
      if (conflict.isNotEmpty) {
        return 'Serial Number "$cleanSerial" is already registered.';
      }
    }

    return null;
  }

  Future<void> createEquipment(EquipmentItem item) async {
    final user = currentUserLabel;
    final payload = item
        .copyWith(createdBy: user, updatedBy: user, isArchived: false)
        .toFirestore(isNew: true);

    await _itemsRef.doc(item.id).set(payload);
  }

  Future<void> updateEquipment({
    required EquipmentItem previous,
    required EquipmentItem updated,
  }) async {
    final user = currentUserLabel;
    final docRef = _itemsRef.doc(updated.id);

    final batch = _db.batch();
    batch.update(
      docRef,
      updated.copyWith(updatedBy: user).toFirestore(isNew: false),
    );

    final trackedChanges = [];
    if (previous.location.trim() != updated.location.trim()) {
      trackedChanges.add({
        'field': 'Location',
        'old': previous.location,
        'new': updated.location,
      });
    }
    if (previous.responsiblePersonnel.trim() !=
        updated.responsiblePersonnel.trim()) {
      trackedChanges.add({
        'field': 'Responsible Personnel',
        'old': previous.responsiblePersonnel,
        'new': updated.responsiblePersonnel,
      });
    }
    if (previous.condition.trim() != updated.condition.trim()) {
      trackedChanges.add({
        'field': 'Condition',
        'old': previous.condition,
        'new': updated.condition,
      });
    }

    for (final change in trackedChanges) {
      final histRef = docRef
          .collection(AppConstants.historySubcollection)
          .doc();
      batch.set(histRef, {
        'fieldChanged': change['field'],
        'oldValue': change['old'],
        'newValue': change['new'],
        'changedBy': user,
        'changedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> archiveEquipment(EquipmentItem item) async {
    final updated = item.copyWith(isArchived: true);
    await updateEquipment(previous: item, updated: updated);
  }

  Future<void> recordSheetSync() async {
    await _sheetSyncRef.set({
      'lastSyncedAt': FieldValue.serverTimestamp(),
      'lastSyncedBy': currentUserLabel,
    }, SetOptions(merge: true));
  }
}

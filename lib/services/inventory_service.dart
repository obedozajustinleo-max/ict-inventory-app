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

  Stream<List<EquipmentItem>> watchArchivedEquipment() {
    return _itemsRef
        .where('isArchived', isEqualTo: true)
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
        .copyWith(
          division: AppConstants.normalizeDivision(item.division),
          createdBy: user,
          updatedBy: user,
          isArchived: false,
        )
        .toFirestore(isNew: true);

    await _itemsRef.doc(item.id).set(payload);
  }

  Future<void> updateEquipment({
    required EquipmentItem previous,
    required EquipmentItem updated,
  }) async {
    final user = currentUserLabel;
    final docRef = _itemsRef.doc(updated.id);
    final normalizedUpdated = updated.copyWith(
      division: AppConstants.normalizeDivision(updated.division),
      updatedBy: user,
    );

    final batch = _db.batch();
    batch.update(docRef, normalizedUpdated.toFirestore(isNew: false));

    final trackedChanges = [];
    if (previous.location.trim() != normalizedUpdated.location.trim()) {
      trackedChanges.add({
        'field': 'Location',
        'old': previous.location,
        'new': normalizedUpdated.location,
      });
    }
    if (previous.responsiblePersonnel.trim() !=
        normalizedUpdated.responsiblePersonnel.trim()) {
      trackedChanges.add({
        'field': 'Responsible Personnel',
        'old': previous.responsiblePersonnel,
        'new': normalizedUpdated.responsiblePersonnel,
      });
    }
    if (previous.condition.trim() != normalizedUpdated.condition.trim()) {
      trackedChanges.add({
        'field': 'Condition',
        'old': previous.condition,
        'new': normalizedUpdated.condition,
      });
    }
    if (previous.isArchived != normalizedUpdated.isArchived) {
      trackedChanges.add({
        'field': 'Archive Status',
        'old': previous.isArchived ? 'Archived' : 'Active',
        'new': normalizedUpdated.isArchived ? 'Archived' : 'Active',
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

  Future<void> restoreEquipment(EquipmentItem item) async {
    final updated = item.copyWith(isArchived: false);
    await updateEquipment(previous: item, updated: updated);
  }

  Future<int> wipeAllEquipment() async {
    final snap = await _itemsRef.get();
    if (snap.docs.isEmpty) return 0;

    final refsToDelete = <DocumentReference>[];
    for (final doc in snap.docs) {
      final histSnap = await doc.reference
          .collection(AppConstants.historySubcollection)
          .get();
      for (final histDoc in histSnap.docs) {
        refsToDelete.add(histDoc.reference);
      }
      refsToDelete.add(doc.reference);
    }

    const chunkSize = 400;
    for (var i = 0; i < refsToDelete.length; i += chunkSize) {
      final chunk = refsToDelete.sublist(
        i,
        i + chunkSize > refsToDelete.length
            ? refsToDelete.length
            : i + chunkSize,
      );
      final batch = _db.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }

    return snap.docs.length;
  }

  Future<void> recordSheetSync() async {
    await _sheetSyncRef.set({
      'lastSyncedAt': FieldValue.serverTimestamp(),
      'lastSyncedBy': currentUserLabel,
    }, SetOptions(merge: true));
  }

  Future<int> importEquipmentFromSheetRows(List<dynamic> rows) async {
    final user = currentUserLabel;

    final existingSnap = await _itemsRef.get();
    final byId = <String, EquipmentItem>{};
    final byProperty = <String, EquipmentItem>{};
    final bySerial = <String, EquipmentItem>{};

    for (final doc in existingSnap.docs) {
      final item = EquipmentItem.fromFirestore(doc);
      byId[item.id] = item;
      if (item.propertyNumber.trim().isNotEmpty) {
        byProperty[item.propertyNumber.trim().toLowerCase()] = item;
      }
      if (item.serialNumber.trim().isNotEmpty) {
        bySerial[item.serialNumber.trim().toLowerCase()] = item;
      }
      for (final comp in item.components) {
        if (comp.propertyNumber.trim().isNotEmpty) {
          byProperty.putIfAbsent(
            comp.propertyNumber.trim().toLowerCase(),
            () => item,
          );
        }
        if (comp.serialNumber.trim().isNotEmpty) {
          bySerial.putIfAbsent(
            comp.serialNumber.trim().toLowerCase(),
            () => item,
          );
        }
      }
    }

    const chunkSize = 200;
    int importedCount = 0;

    for (var i = 0; i < rows.length; i += chunkSize) {
      final chunk = rows.sublist(
        i,
        i + chunkSize > rows.length ? rows.length : i + chunkSize,
      );
      final batch = _db.batch();

      for (final raw in chunk) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);

        final rawId = (row['id'] ?? row['ID'] ?? '').toString().trim();
        final prop = (row['propertyNumber'] ?? row['Property Number'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final serial = (row['serialNumber'] ?? row['Serial Number'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final existing =
            byId[rawId] ??
            (prop.isNotEmpty ? byProperty[prop] : null) ??
            (serial.isNotEmpty ? bySerial[serial] : null);

        final docRef = existing != null
            ? _itemsRef.doc(existing.id)
            : (rawId.isNotEmpty ? _itemsRef.doc(rawId) : _itemsRef.doc());

        final parsed = EquipmentItem.fromSheetRow(
          row,
          resolvedId: docRef.id,
          currentUser: user,
        );

        final normalizedParsed = parsed.copyWith(
          division: AppConstants.normalizeDivision(parsed.division),
        );

        final mergedItem = existing == null
            ? normalizedParsed
            : normalizedParsed.copyWith(
                serialPhotoUrl:
                    normalizedParsed.serialPhotoUrl ?? existing.serialPhotoUrl,
                propertyTagPhotoUrl:
                    normalizedParsed.propertyTagPhotoUrl ??
                    existing.propertyTagPhotoUrl,
                assignedUserEmail:
                    normalizedParsed.assignedUserEmail ??
                    existing.assignedUserEmail,
                components: normalizedParsed.components.isNotEmpty
                    ? normalizedParsed.components
                    : existing.components,
                createdBy: existing.createdBy,
                createdAt: existing.createdAt,
              );

        batch.set(
          docRef,
          mergedItem.toFirestore(isNew: existing == null),
          SetOptions(merge: true),
        );

        if (existing != null) {
          final trackedChanges = [];
          if (existing.location.trim() != mergedItem.location.trim()) {
            trackedChanges.add({
              'field': 'Location',
              'old': existing.location,
              'new': mergedItem.location,
            });
          }
          if (existing.responsiblePersonnel.trim() !=
              mergedItem.responsiblePersonnel.trim()) {
            trackedChanges.add({
              'field': 'Responsible Personnel',
              'old': existing.responsiblePersonnel,
              'new': mergedItem.responsiblePersonnel,
            });
          }
          if (existing.condition.trim() != mergedItem.condition.trim()) {
            trackedChanges.add({
              'field': 'Condition',
              'old': existing.condition,
              'new': mergedItem.condition,
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
        }

        importedCount++;
      }

      await batch.commit();
    }

    return importedCount;
  }
}

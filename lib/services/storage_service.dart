import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  Future<File> _compressImage(File file, String targetName) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/$targetName';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 75,
      minWidth: 1280,
      minHeight: 1280,
    );

    return compressed != null ? File(compressed.path) : file;
  }

  /// [tagType] should be 'serial_number' or 'property_tag'
  Future<String> uploadEquipmentPhoto({
    required String itemId,
    required String tagType,
    required File imageFile,
  }) async {
    final fileName = '${tagType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final compressedFile = await _compressImage(imageFile, fileName);

    final ref = _storage
        .ref()
        .child('inventory_photos')
        .child(itemId)
        .child('$tagType.jpg');

    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putFile(compressedFile, metadata);
    return ref.getDownloadURL();
  }
}

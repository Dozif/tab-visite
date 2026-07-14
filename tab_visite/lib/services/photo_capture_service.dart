import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../data/models/photo.dart';
import '../data/repositories/photo_repository.dart';
import 'file_storage.dart';

class PhotoCaptureService {
  final PhotoRepository photoRepo;
  final FileStorage storage;
  final ImagePicker picker;
  final Uuid _uuid = const Uuid();
  PhotoCaptureService(this.photoRepo, this.storage, {ImagePicker? picker})
      : picker = picker ?? ImagePicker();

  /// Ouvre l'appareil photo, enregistre la photo et l'associe à [zoneId]
  /// (et à la visite [visiteId] si la prise se fait dans le cadre d'une visite).
  /// Renvoie null si l'utilisateur annule.
  Future<Photo?> capture(String zoneId, int nowMs, {String? visiteId}) async {
    final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x == null) return null;
    final rel = await storage.importImage(File(x.path), 'photos', 'jpg');
    final photo = Photo(
      id: _uuid.v4(),
      zoneId: zoneId,
      cheminFichier: rel,
      datePrise: nowMs,
      dateCreation: nowMs,
      visiteId: visiteId,
    );
    await photoRepo.insert(photo);
    return photo;
  }
}

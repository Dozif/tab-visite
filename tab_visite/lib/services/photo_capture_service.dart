import 'dart:typed_data';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../data/models/photo.dart';
import '../data/repositories/photo_repository.dart';
import '../data/repositories/zone_repository.dart';
import '../data/repositories/visite_repository.dart';
import 'pending_capture_store.dart';
import 'photo_store.dart';

class PhotoCaptureService {
  final PhotoRepository photoRepo;
  final PhotoStore storage;
  final ZoneRepository zones;
  final VisiteRepository visites;
  final PendingCaptureStore pending;
  final ImagePicker picker;
  final Uuid _uuid = const Uuid();
  PhotoCaptureService(
      this.photoRepo, this.storage, this.zones, this.visites, this.pending,
      {ImagePicker? picker})
      : picker = picker ?? ImagePicker();

  /// Ouvre l'appareil photo, enregistre la photo et l'associe à [zoneId]
  /// (et à la visite [visiteId] si la prise se fait dans le cadre d'une visite).
  /// Renvoie null si l'utilisateur annule.
  ///
  /// Le contexte (zone/visite) est persisté **avant** de lancer la caméra : si
  /// Android tue l'app pendant la prise de vue, [recoverLostPhoto] pourra
  /// rattacher la photo à la bonne zone au redémarrage. En cas d'échec I/O, le
  /// pending est conservé (non effacé) et l'exception est relancée pour que
  /// l'UI puisse en informer l'utilisateur.
  Future<Photo?> capture(String zoneId, int nowMs, {String? visiteId}) async {
    await pending.set(zoneId, visiteId, nowMs);
    // Borne le côté le plus long à 2048 px (ratio préservé) : réduit le pic
    // mémoire au ré-encodage (source d'échecs à la validation) et allège les
    // fichiers, tout en restant net pour documenter la corrosion.
    final x = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048);
    if (x == null) {
      await pending.clear(); // annulation : rien à récupérer
      return null;
    }
    final photo = await enregistrer(await x.readAsBytes(), zoneId, nowMs,
        visiteId: visiteId);
    await pending.clear();
    return photo;
  }

  /// Enregistre une photo déjà prise ([bytes] JPEG) et l'associe à [zoneId]
  /// (et à [visiteId]). Utilisé tel quel par la caméra intégrée du web, qui ne
  /// passe pas par l'appli Appareil photo d'Android (donc pas de pending).
  Future<Photo> enregistrer(Uint8List bytes, String zoneId, int nowMs,
      {String? visiteId}) async {
    final rel = await storage.importBytes(bytes, 'photos', 'jpg');
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

  /// Récupère une photo dont l'app a été tuée par Android pendant la prise de
  /// vue (`ImagePicker.retrieveLostData`). Renvoie `true` si une photo a été
  /// récupérée et enregistrée. Android uniquement (no-op ailleurs).
  Future<bool> recoverLostPhoto(int nowMs) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;

    final resp = await picker.retrieveLostData();
    final file = resp.file;
    if (resp.isEmpty || file == null) return false;

    final ctx = await pending.get();
    if (ctx == null || !await zones.exists(ctx.zoneId)) {
      await pending.clear(); // rien à quoi rattacher
      return false;
    }
    // Si la visite a été effacée entre-temps, on garde quand même la photo
    // sur sa zone (sans rattachement de visite) plutôt que de la perdre.
    var visiteId = ctx.visiteId;
    if (visiteId != null && !await visites.exists(visiteId)) {
      visiteId = null;
    }

    final rel =
        await storage.importBytes(await file.readAsBytes(), 'photos', 'jpg');
    await photoRepo.insert(Photo(
      id: _uuid.v4(),
      zoneId: ctx.zoneId,
      cheminFichier: rel,
      datePrise: nowMs,
      dateCreation: nowMs,
      visiteId: visiteId,
    ));
    await pending.clear();
    return true;
  }
}

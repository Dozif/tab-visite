import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/models/plan.dart';
import 'package:tab_visite/data/models/zone.dart';
import 'package:tab_visite/data/repositories/plan_repository.dart';
import 'package:tab_visite/data/repositories/zone_repository.dart';
import 'package:tab_visite/data/repositories/photo_repository.dart';
import 'package:tab_visite/data/repositories/visite_repository.dart';
import 'package:tab_visite/services/pending_capture_store.dart';
import 'package:tab_visite/services/photo_capture_service.dart';
import 'package:tab_visite/services/photo_store.dart';

/// Faux stockage en mémoire.
class _MemStore implements PhotoStore {
  final Map<String, Uint8List> files = {};
  int _n = 0;
  @override
  Future<void> ensureReady() async {}
  @override
  Future<String> importBytes(Uint8List bytes, String subdir, String ext) async {
    final key = '$subdir/${_n++}.$ext';
    files[key] = bytes;
    return key;
  }
  @override
  Future<Uint8List?> readBytes(String key) async => files[key];
  @override
  Future<void> delete(String key) async => files.remove(key);
}

/// Faux ImagePicker : contrôle la valeur de retour de pickImage et
/// retrieveLostData depuis le test.
class _FakePicker extends ImagePicker {
  XFile? pickResult;
  bool pickThrows = false;
  LostDataResponse lostData = LostDataResponse.empty();

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (pickThrows) throw Exception('échec caméra simulée');
    return pickResult;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async => lostData;
}

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  Future<(PhotoCaptureService, _FakePicker, PhotoRepository, PendingCaptureStore)>
      build() async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    addTearDown(db.close); // isole la base :memory: entre les tests
    await PlanRepository(db).insert(
        const Plan(id: 'p1', nom: 'P', cheminImage: 'a', ordre: 0, dateCreation: 0));
    await ZoneRepository(db).insert(const Zone(
        id: 'z1', planId: 'p1', nom: 'M', x: 0, y: 0,
        largeur: .1, hauteur: .1, dateCreation: 0));
    final photos = PhotoRepository(db);
    final pending = PendingCaptureStore(db);
    final picker = _FakePicker();
    final service = PhotoCaptureService(photos, _MemStore(),
        ZoneRepository(db), VisiteRepository(db), pending, picker: picker);
    return (service, picker, photos, pending);
  }

  test('capture écrit le pending avant la prise et le vide après enregistrement',
      () async {
    final (service, picker, photos, pending) = await build();
    picker.pickResult = XFile.fromData(Uint8List.fromList([1, 2, 3]));

    final photo = await service.capture('z1', 1000, visiteId: null);

    expect(photo, isNotNull);
    expect(photo!.zoneId, 'z1');
    expect((await photos.forZone('z1')).length, 1);
    // Pending vidé après succès.
    expect(await pending.get(), isNull);
  });

  test('enregistrer (caméra intégrée web) : stocke les octets et rattache zone/visite',
      () async {
    final (service, picker, photos, pending) = await build();

    final photo = await service.enregistrer(
        Uint8List.fromList([7, 8, 9]), 'z1', 2000, visiteId: null);

    expect(photo.zoneId, 'z1');
    expect(photo.datePrise, 2000);
    final enBase = await photos.forZone('z1');
    expect(enBase.single.id, photo.id);
    expect(await service.storage.readBytes(photo.cheminFichier),
        Uint8List.fromList([7, 8, 9]));
    // N'utilise pas le pending (pas d'appli caméra externe).
    expect(await pending.get(), isNull);
  });

  test('annulation (pickImage null) vide le pending et renvoie null', () async {
    final (service, picker, photos, pending) = await build();
    picker.pickResult = null; // utilisateur annule

    final photo = await service.capture('z1', 1000);

    expect(photo, isNull);
    expect((await photos.forZone('z1')).length, 0);
    expect(await pending.get(), isNull);
  });

  test('échec I/O : exception relancée, pending conservé pour récupération',
      () async {
    final (service, picker, photos, pending) = await build();
    picker.pickThrows = true;

    await expectLater(service.capture('z1', 1000), throwsA(isA<Exception>()));
    expect((await photos.forZone('z1')).length, 0);
    // Le contexte reste pour une éventuelle récupération.
    final ctx = await pending.get();
    expect(ctx!.zoneId, 'z1');
  });

  test('recoverLostPhoto : photo perdue + pending présent -> insérée et rattachée',
      () async {
    final (service, picker, photos, pending) = await build();
    await pending.set('z1', null, 900);
    picker.lostData =
        LostDataResponse(file: XFile.fromData(Uint8List.fromList([9, 9])));

    final ok = await service.recoverLostPhoto(2000);

    expect(ok, isTrue);
    final list = await photos.forZone('z1');
    expect(list.length, 1);
    expect(list.first.zoneId, 'z1');
    expect(await pending.get(), isNull); // pending vidé après récupération
  });

  test('recoverLostPhoto : aucune donnée perdue -> false, rien inséré',
      () async {
    final (service, picker, photos, pending) = await build();
    await pending.set('z1', null, 900);
    picker.lostData = LostDataResponse.empty();

    final ok = await service.recoverLostPhoto(2000);

    expect(ok, isFalse);
    expect((await photos.forZone('z1')).length, 0);
  });

  test('recoverLostPhoto : photo perdue mais aucun pending -> false + clear',
      () async {
    final (service, picker, photos, pending) = await build();
    // Pas de pending.
    picker.lostData =
        LostDataResponse(file: XFile.fromData(Uint8List.fromList([9])));

    final ok = await service.recoverLostPhoto(2000);

    expect(ok, isFalse);
    expect((await photos.forZone('z1')).length, 0);
    expect(await pending.get(), isNull);
  });
}

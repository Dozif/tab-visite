import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'photo_store.dart';

/// Implémentation mobile/desktop (et VM de test) : les images sont des
/// fichiers sous [rootDir]. La clé est le chemin relatif à [rootDir].
class PhotoStoreIo implements PhotoStore {
  final Directory rootDir;
  final Uuid _uuid = const Uuid();
  PhotoStoreIo(this.rootDir);

  File _file(String key) => File(p.join(rootDir.path, key));

  @override
  Future<void> ensureReady() async {
    await Directory(p.join(rootDir.path, 'plans')).create(recursive: true);
    await Directory(p.join(rootDir.path, 'photos')).create(recursive: true);
  }

  @override
  Future<String> importBytes(Uint8List bytes, String subdir, String ext) async {
    final key = '$subdir/${_uuid.v4()}.$ext';
    final dest = _file(key);
    await dest.parent.create(recursive: true);
    await dest.writeAsBytes(bytes);
    return key;
  }

  @override
  Future<Uint8List?> readBytes(String key) async {
    final f = _file(key);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  @override
  Future<void> delete(String key) async {
    final f = _file(key);
    if (await f.exists()) await f.delete();
  }
}

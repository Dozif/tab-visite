import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class FileStorage {
  final Directory rootDir;
  final Uuid _uuid = const Uuid();
  FileStorage(this.rootDir);

  Future<void> ensureDirs() async {
    await Directory(p.join(rootDir.path, 'plans')).create(recursive: true);
    await Directory(p.join(rootDir.path, 'photos')).create(recursive: true);
  }

  File resolve(String relative) => File(p.join(rootDir.path, relative));

  Future<String> importImage(File src, String subdir, String ext) async {
    final rel = '$subdir/${_uuid.v4()}.$ext';
    final dest = File(p.join(rootDir.path, rel));
    await dest.parent.create(recursive: true);
    await src.copy(dest.path);
    return rel;
  }

  Future<void> deleteRelative(String relative) async {
    final f = resolve(relative);
    if (await f.exists()) await f.delete();
  }
}

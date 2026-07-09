import 'package:sqflite/sqflite.dart';
import '../models/photo.dart';

class PhotoRepository {
  final Database db;
  PhotoRepository(this.db);

  Future<void> insert(Photo p) => db.insert('photos', p.toMap());

  Future<List<Photo>> forZone(String zoneId) async {
    final rows = await db.query('photos',
        where: 'zone_id = ?', whereArgs: [zoneId], orderBy: 'date_prise DESC');
    return rows.map(Photo.fromMap).toList();
  }

  Future<void> delete(String id) =>
      db.delete('photos', where: 'id = ?', whereArgs: [id]);

  Future<int> countForZone(String zoneId) async {
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM photos WHERE zone_id = ?', [zoneId]);
    return r.first['n'] as int;
  }

  Future<Map<String, int>> countsForPlanZones(String planId) async {
    final rows = await db.rawQuery('''
      SELECT p.zone_id AS zid, COUNT(*) AS n
      FROM photos p JOIN zones z ON z.id = p.zone_id
      WHERE z.plan_id = ? GROUP BY p.zone_id''', [planId]);
    return { for (final r in rows) r['zid'] as String : r['n'] as int };
  }
}

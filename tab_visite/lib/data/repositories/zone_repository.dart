import 'package:sqflite/sqflite.dart';
import '../models/zone.dart';

class ZoneRepository {
  final Database db;
  ZoneRepository(this.db);

  Future<void> insert(Zone z) => db.insert('zones', z.toMap());

  Future<List<Zone>> forPlan(String planId) async {
    final rows = await db.query('zones',
        where: 'plan_id = ?', whereArgs: [planId], orderBy: 'nom ASC');
    return rows.map(Zone.fromMap).toList();
  }

  Future<void> update(Zone z) =>
      db.update('zones', z.toMap(), where: 'id = ?', whereArgs: [z.id]);

  Future<void> delete(String id) =>
      db.delete('zones', where: 'id = ?', whereArgs: [id]);

  /// La zone existe-t-elle encore ? (utile avant de rattacher une photo récupérée)
  Future<bool> exists(String id) async {
    final rows =
        await db.query('zones', columns: ['id'], where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty;
  }

  Future<List<Zone>> searchByName(String q) async {
    final rows = await db.query('zones',
        where: 'nom LIKE ?', whereArgs: ['%$q%'], orderBy: 'nom ASC');
    return rows.map(Zone.fromMap).toList();
  }
}

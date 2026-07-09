import 'package:sqflite/sqflite.dart';
import '../models/plan.dart';

class PlanRepository {
  final Database db;
  PlanRepository(this.db);

  Future<void> insert(Plan p) => db.insert('plans', p.toMap());

  Future<List<Plan>> all() async {
    final rows = await db.query('plans', orderBy: 'ordre ASC');
    return rows.map(Plan.fromMap).toList();
  }

  Future<void> update(Plan p) =>
      db.update('plans', p.toMap(), where: 'id = ?', whereArgs: [p.id]);

  Future<void> delete(String id) =>
      db.delete('plans', where: 'id = ?', whereArgs: [id]);

  Future<int> nextOrdre() async {
    final r = await db.rawQuery('SELECT COALESCE(MAX(ordre), -1) + 1 AS n FROM plans');
    return (r.first['n'] as int);
  }
}

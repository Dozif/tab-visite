import 'package:sqflite/sqflite.dart';
import '../models/plan.dart';
import '../models/visite.dart';

class PlanRepository {
  final Database db;
  PlanRepository(this.db);

  Future<void> insert(Plan p) => db.insert('plans', p.toMap());

  Future<List<Plan>> all() async {
    final rows = await db.query('plans', orderBy: 'ordre ASC');
    return rows.map(Plan.fromMap).toList();
  }

  /// Plans à inspecter pour un type de visite :
  /// MKBAM → les motrices ; MKBDR → les remorques série 2N ;
  /// MKBAR → les remorques d'une autre série (aucune tant que non fournies).
  Future<List<Plan>> forTypeVisite(String typeVisite) async {
    final (where, args) = switch (typeVisite) {
      TypeVisite.mkbam => ("categorie = 'motrice'", <Object?>[]),
      TypeVisite.mkbdr => ("categorie = 'remorque' AND serie = '2N'", <Object?>[]),
      TypeVisite.mkbar => ("categorie = 'remorque' AND serie <> '2N'", <Object?>[]),
      _ => ('', <Object?>[]),
    };
    final rows = await db.query('plans',
        where: where.isEmpty ? null : where,
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'ordre ASC');
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

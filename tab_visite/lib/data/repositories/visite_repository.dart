import 'package:sqflite/sqflite.dart';
import '../models/visite.dart';

class VisiteRepository {
  final Database db;
  VisiteRepository(this.db);

  Future<void> insert(Visite v) => db.insert('visites', v.toMap());

  /// Toutes les visites, plus récentes d'abord.
  Future<List<Visite>> all() async {
    final rows = await db.query('visites', orderBy: 'date_visite DESC');
    return rows.map(Visite.fromMap).toList();
  }

  /// Historique d'une rame donnée (toutes ses visites), plus récentes d'abord.
  Future<List<Visite>> forRame(int numeroRame) async {
    final rows = await db.query('visites',
        where: 'numero_rame = ?',
        whereArgs: [numeroRame],
        orderBy: 'date_visite DESC');
    return rows.map(Visite.fromMap).toList();
  }

  Future<void> delete(String id) =>
      db.delete('visites', where: 'id = ?', whereArgs: [id]);
}

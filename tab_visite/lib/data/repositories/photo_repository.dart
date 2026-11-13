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

  /// Photos d'une visite, jointes à leur zone et leur plan, prêtes pour l'export
  /// (colonnes : id, date_prise, traitee, chemin_fichier, zone_nom, plan_nom).
  Future<List<Map<String, Object?>>> joinedForVisite(String visiteId) {
    return db.rawQuery('''
      SELECT ph.id, ph.date_prise, ph.traitee, ph.chemin_fichier,
             z.nom AS zone_nom, pl.nom AS plan_nom, pl.ordre AS plan_ordre,
             pl.id AS plan_id, pl.chemin_image, z.x, z.y, z.largeur, z.hauteur
      FROM photos ph
      JOIN zones z ON z.id = ph.zone_id
      JOIN plans pl ON pl.id = z.plan_id
      WHERE ph.visite_id = ?
      ORDER BY pl.ordre, z.nom, ph.date_prise''', [visiteId]);
  }

  /// Toutes les photos rattachées à une visite, avec les infos de la visite
  /// (rame, type, niveau, date) — pour l'export global. Les photos sans visite
  /// sont exclues (jointure interne sur visites).
  Future<List<Map<String, Object?>>> joinedAllByVisite() {
    return db.rawQuery('''
      SELECT ph.id, ph.date_prise, ph.traitee, ph.chemin_fichier,
             z.nom AS zone_nom, pl.nom AS plan_nom, pl.ordre AS plan_ordre,
             pl.id AS plan_id, pl.chemin_image, z.x, z.y, z.largeur, z.hauteur,
             vi.id AS visite_id, vi.numero_rame, vi.type_visite, vi.niveau, vi.date_visite
      FROM photos ph
      JOIN zones z ON z.id = ph.zone_id
      JOIN plans pl ON pl.id = z.plan_id
      JOIN visites vi ON vi.id = ph.visite_id
      ORDER BY vi.date_visite DESC, pl.ordre, z.nom, ph.date_prise''');
  }
}

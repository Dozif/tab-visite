import 'package:sqflite/sqflite.dart';

/// Destinataires proposés par défaut pour le mail d'export.
const destinatairesParDefaut = [
  'franck.dozieres@sncf.fr',
  'denis.martel@sncf.fr',
];

/// Découpe une saisie libre d'adresses (virgules, points-virgules, espaces,
/// retours à la ligne) ; ignore les vides et les doublons.
List<String> parseAdresses(String texte) {
  final vues = <String>{};
  return texte
      .split(RegExp(r'[,;\s]+'))
      .map((a) => a.trim())
      .where((a) => a.isNotEmpty && vues.add(a))
      .toList();
}

/// Réglages de l'app stockés dans la table `reglages` (clé/valeur).
class ReglagesRepository {
  static const _cleDestinataires = 'mail_destinataires';
  final Database db;
  ReglagesRepository(this.db);

  Future<String?> _get(String cle) async {
    final rows =
        await db.query('reglages', where: 'cle = ?', whereArgs: [cle]);
    return rows.isEmpty ? null : rows.first['valeur'] as String;
  }

  Future<void> _set(String cle, String valeur) => db.insert(
      'reglages', {'cle': cle, 'valeur': valeur},
      conflictAlgorithm: ConflictAlgorithm.replace);

  /// Destinataires du mail d'export (valeurs par défaut tant que jamais
  /// modifiés ; une liste vide enregistrée reste vide).
  Future<List<String>> destinataires() async {
    final v = await _get(_cleDestinataires);
    return v == null ? List.of(destinatairesParDefaut) : parseAdresses(v);
  }

  Future<void> setDestinataires(List<String> adresses) =>
      _set(_cleDestinataires, adresses.join(','));
}

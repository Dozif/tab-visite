import 'dart:typed_data';

/// Stockage des images (plans + photos) indépendant de la plateforme.
///
/// Le contrat est orienté **octets** pour fonctionner aussi bien sur mobile
/// (fichiers, [PhotoStoreIo]) que sur le web (blobs en base, `PhotoStoreWeb`).
/// La « clé » renvoyée par [importBytes] est stockée telle quelle en base
/// (colonnes `chemin_image` / `chemin_fichier`) : c'est un chemin relatif sur
/// mobile, un identifiant de ligne sur le web.
abstract class PhotoStore {
  /// Prépare le stockage (crée les dossiers sur mobile ; no-op sur web).
  Future<void> ensureReady();

  /// Enregistre [bytes] sous `<subdir>/<uuid>.<ext>` et renvoie la clé.
  Future<String> importBytes(Uint8List bytes, String subdir, String ext);

  /// Renvoie les octets associés à [key], ou `null` si absent.
  Future<Uint8List?> readBytes(String key);

  /// Supprime l'entrée [key] si elle existe.
  Future<void> delete(String key);
}

import 'dart:typed_data';

/// Stockage clé -> octets utilisé par `PhotoStoreWeb`.
///
/// Sur le web : IndexedDB dédié (`IdbBlobBackend`). Abstrait pour tester la
/// logique (dont le transfert depuis l'ancienne table `medias`) sur la VM.
abstract class BlobBackend {
  /// Écrit [bytes] sous [key]. Ne se termine qu'une fois l'écriture
  /// réellement enregistrée.
  Future<void> put(String key, Uint8List bytes);

  /// Octets de [key], ou `null` si absent.
  Future<Uint8List?> get(String key);

  /// Supprime [key] s'il existe.
  Future<void> delete(String key);
}

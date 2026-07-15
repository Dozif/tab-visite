import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/photo_store.dart';

/// Affiche une image stockée dans un [PhotoStore] à partir de sa clé.
///
/// Charge les octets de façon asynchrone (fichier sur mobile, blob IndexedDB
/// sur web) puis les rend via `Image.memory`. Un petit cache mémoire partagé
/// évite de relire la même image à chaque reconstruction (grilles, listes).
class PhotoImage extends StatefulWidget {
  final PhotoStore store;
  final String storageKey;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final WidgetBuilder? errorBuilder;

  const PhotoImage({
    super.key,
    required this.store,
    required this.storageKey,
    this.fit,
    this.width,
    this.height,
    this.errorBuilder,
  });

  /// Retire une clé du cache mémoire (à appeler après suppression).
  static void evict(String key) => _cache.remove(key);

  static final Map<String, Uint8List> _cache = {};

  @override
  State<PhotoImage> createState() => _PhotoImageState();
}

class _PhotoImageState extends State<PhotoImage> {
  Uint8List? _bytes;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PhotoImage old) {
    super.didUpdateWidget(old);
    if (old.storageKey != widget.storageKey) {
      _bytes = null;
      _error = false;
      _load();
    }
  }

  Future<void> _load() async {
    final cached = PhotoImage._cache[widget.storageKey];
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }
    try {
      final b = await widget.store.readBytes(widget.storageKey);
      if (!mounted) return;
      if (b == null) {
        setState(() => _error = true);
        return;
      }
      PhotoImage._cache[widget.storageKey] = b;
      setState(() => _bytes = b);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Widget _errorWidget() =>
      widget.errorBuilder?.call(context) ??
      const Icon(Icons.broken_image, color: Colors.grey);

  @override
  Widget build(BuildContext context) {
    if (_error) return _errorWidget();
    final b = _bytes;
    if (b == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    return Image.memory(
      b,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      errorBuilder: (_, __, ___) => _errorWidget(),
    );
  }
}

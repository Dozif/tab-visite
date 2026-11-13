import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Résultat de [CameraCaptureScreen].
class CameraCaptureResult {
  /// Octets JPEG de la photo validée (null si [utiliserCameraSysteme]).
  final Uint8List? bytes;

  /// La caméra intégrée est indisponible : l'appelant doit se rabattre sur
  /// l'appareil photo du système.
  final bool utiliserCameraSysteme;

  const CameraCaptureResult.photo(Uint8List this.bytes)
      : utiliserCameraSysteme = false;
  const CameraCaptureResult.cameraSysteme()
      : bytes = null,
        utiliserCameraSysteme = true;
}

/// Caméra intégrée à la page (web) : aperçu en direct, prise, puis
/// « Reprendre » / « Enregistrer ».
///
/// Évite de passer par l'appli Appareil photo d'Android : pendant que cette
/// appli est ouverte, Android peut tuer l'onglet de l'app web, et la photo ne
/// peut alors plus être rendue (validation bloquée, app à relancer).
///
/// Renvoie un [CameraCaptureResult], ou null si l'utilisateur ferme l'écran.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  String? _erreur;
  Uint8List? _prise; // photo prise, en attente de validation
  bool _occupe = false;
  bool _lampe = false;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('none', 'Aucune caméra');
      final arriere = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first);
      // ~1920 px : net pour documenter la corrosion sans alourdir la base.
      final c = CameraController(arriere, ResolutionPreset.veryHigh,
          enableAudio: false);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
    } catch (e) {
      debugPrint('Caméra intégrée indisponible : $e');
      if (mounted) {
        setState(() => _erreur =
            'Impossible d\'ouvrir la caméra intégrée.\n'
            'Vérifiez que l\'autorisation « Caméra » est accordée à l\'app.');
      }
    }
  }

  @override
  void dispose() {
    // Libère la caméra (arrête le flux vidéo).
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _prendre() async {
    final c = _controller;
    if (c == null || _occupe) return;
    setState(() => _occupe = true);
    try {
      final x = await c.takePicture();
      final bytes = await x.readAsBytes();
      if (mounted) setState(() => _prise = bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('La photo n\'a pas pu être prise. Réessayez.')));
      }
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _basculerLampe() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.setFlashMode(_lampe ? FlashMode.off : FlashMode.torch);
      setState(() => _lampe = !_lampe);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Lampe non disponible sur cet appareil.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_prise == null ? 'Prendre une photo' : 'Valider la photo'),
        actions: [
          if (_controller != null && _prise == null)
            IconButton(
              tooltip: 'Lampe',
              icon: Icon(_lampe ? Icons.flashlight_on : Icons.flashlight_off),
              onPressed: _basculerLampe,
            ),
        ],
      ),
      body: SafeArea(child: _corps()),
    );
  }

  Widget _corps() {
    if (_erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_erreur!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.photo_camera),
              label: const Text('Utiliser l\'appareil photo du système'),
              onPressed: () => Navigator.pop(
                  context, const CameraCaptureResult.cameraSysteme()),
            ),
          ]),
        ),
      );
    }
    final c = _controller;
    if (c == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final prise = _prise;
    if (prise != null) {
      return Column(children: [
        Expanded(child: Center(child: Image.memory(prise, fit: BoxFit.contain))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
              icon: const Icon(Icons.refresh),
              label: const Text('Reprendre'),
              onPressed: () => setState(() => _prise = null),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
              icon: const Icon(Icons.check),
              label: const Text('Enregistrer'),
              onPressed: () =>
                  Navigator.pop(context, CameraCaptureResult.photo(prise)),
            ),
          ]),
        ),
      ]);
    }
    return Column(children: [
      Expanded(child: Center(child: CameraPreview(c))),
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 76,
          height: 76,
          child: FloatingActionButton(
            heroTag: null,
            backgroundColor: Colors.white,
            shape: const CircleBorder(),
            onPressed: _occupe ? null : _prendre,
            child: _occupe
                ? const CircularProgressIndicator()
                : const Icon(Icons.camera_alt, color: Colors.black, size: 36),
          ),
        ),
      ),
    ]);
  }
}

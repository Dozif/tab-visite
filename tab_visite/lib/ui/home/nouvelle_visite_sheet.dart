import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/visite.dart';
import '../../services/app_context.dart';

/// Affiche le formulaire de création de visite(s) : un ou plusieurs types
/// cochés, un niveau, un numéro de rame. Crée une visite par type en base et
/// renvoie la liste (vide si annulé).
Future<List<Visite>> showNouvelleVisite(BuildContext context, AppContext ctx) async {
  final res = await showModalBottomSheet<List<Visite>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _NouvelleVisiteForm(ctx: ctx),
    ),
  );
  return res ?? const [];
}

/// Construit une visite par type coché, dans l'ordre canonique
/// [TypeVisite.tous] (indépendant de l'ordre de sélection), toutes pour la même
/// rame et le même niveau. Fonction pure (aucune I/O) pour rester testable.
List<Visite> construireVisitesGroupees(
    Set<String> types, String niveau, int rame, int nowMs,
    {required String Function() nouvelId}) {
  return [
    for (final t in TypeVisite.tous)
      if (types.contains(t))
        Visite(
          id: nouvelId(),
          numeroRame: rame,
          typeVisite: t,
          niveau: niveau,
          dateVisite: nowMs,
          dateCreation: nowMs,
        ),
  ];
}

class _NouvelleVisiteForm extends StatefulWidget {
  final AppContext ctx;
  const _NouvelleVisiteForm({required this.ctx});
  @override
  State<_NouvelleVisiteForm> createState() => _NouvelleVisiteFormState();
}

class _NouvelleVisiteFormState extends State<_NouvelleVisiteForm> {
  final Set<String> _types = {};
  String _niveau = Niveau.deux;
  final _rameCtrl = TextEditingController();

  bool get _valide =>
      _types.isNotEmpty && int.tryParse(_rameCtrl.text.trim()) != null;

  Future<void> _creer() async {
    final rame = int.parse(_rameCtrl.text.trim());
    final now = DateTime.now().millisecondsSinceEpoch;
    const uuid = Uuid();
    final visites = construireVisitesGroupees(_types, _niveau, rame, now,
        nouvelId: uuid.v4);
    for (final v in visites) {
      await widget.ctx.visites.insert(v);
    }
    if (mounted) Navigator.pop(context, visites);
  }

  @override
  void dispose() {
    _rameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nouvelle visite',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Text('Types de visite (un ou plusieurs)'),
            const SizedBox(height: 8),
            ...TypeVisite.tous.map((t) => CheckboxListTile(
                  value: _types.contains(t),
                  onChanged: (coche) => setState(() {
                    if (coche == true) {
                      _types.add(t);
                    } else {
                      _types.remove(t);
                    }
                  }),
                  title: Text(TypeVisite.libelle(t)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                )),
            const SizedBox(height: 12),
            const Text('Niveau de la rame'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: Niveau.tous
                  .map((n) => ButtonSegment<String>(
                      value: n, label: Text(Niveau.libelle(n))))
                  .toList(),
              selected: {_niveau},
              onSelectionChanged: (s) => setState(() => _niveau = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rameCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Numéro de rame',
                prefixIcon: Icon(Icons.train),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _valide ? _creer : null,
                  icon: const Icon(Icons.check),
                  label: Text(_types.length > 1
                      ? 'Créer les ${_types.length} visites'
                      : 'Créer la visite'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

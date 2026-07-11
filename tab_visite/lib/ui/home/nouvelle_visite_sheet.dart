import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/visite.dart';
import '../../services/app_context.dart';

/// Affiche le formulaire de création d'une visite (type + numéro de rame).
/// Crée la visite en base et la renvoie, ou null si annulé.
Future<Visite?> showNouvelleVisite(BuildContext context, AppContext ctx) {
  return showModalBottomSheet<Visite>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _NouvelleVisiteForm(ctx: ctx),
    ),
  );
}

class _NouvelleVisiteForm extends StatefulWidget {
  final AppContext ctx;
  const _NouvelleVisiteForm({required this.ctx});
  @override
  State<_NouvelleVisiteForm> createState() => _NouvelleVisiteFormState();
}

class _NouvelleVisiteFormState extends State<_NouvelleVisiteForm> {
  String? _type;
  final _rameCtrl = TextEditingController();

  bool get _valide =>
      _type != null && int.tryParse(_rameCtrl.text.trim()) != null;

  Future<void> _creer() async {
    final rame = int.parse(_rameCtrl.text.trim());
    final now = DateTime.now().millisecondsSinceEpoch;
    final visite = Visite(
      id: const Uuid().v4(),
      numeroRame: rame,
      typeVisite: _type!,
      dateVisite: now,
      dateCreation: now,
    );
    await widget.ctx.visites.insert(visite);
    if (mounted) Navigator.pop(context, visite);
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
            const Text('Type de visite'),
            const SizedBox(height: 8),
            ...TypeVisite.tous.map((t) => RadioListTile<String>(
                  value: t,
                  groupValue: _type,
                  onChanged: (v) => setState(() => _type = v),
                  title: Text(TypeVisite.libelle(t)),
                  contentPadding: EdgeInsets.zero,
                )),
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
                  label: const Text('Créer la visite'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

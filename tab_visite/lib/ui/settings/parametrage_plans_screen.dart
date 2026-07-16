import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/plan.dart';
import '../../services/app_context.dart';
import '../plan/plan_view_screen.dart';
import '../widgets/photo_image.dart';

/// Paramétrage des points : édite les zones (points) de **tous** les plans,
/// hors visite. Les positions réglées ici servent de base commune à toutes les
/// visites (elles ne sont liées à aucune rame).
class ParametragePlansScreen extends StatefulWidget {
  const ParametragePlansScreen({super.key});
  @override
  State<ParametragePlansScreen> createState() => _ParametragePlansScreenState();
}

class _ParametragePlansScreenState extends State<ParametragePlansScreen> {
  late final AppContext ctx = context.read<AppContext>();
  List<Plan> _plans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plans = await ctx.plans.all();
    if (mounted) setState(() => _plans = plans);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramétrage des points')),
      body: _plans.isEmpty
          ? const Center(child: Text('Aucun plan'))
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                      'Déplace, ajoute ou supprime les points de chaque image, '
                      'puis appuie sur 💾. Les réglages sont mémorisés pour '
                      'toutes les visites (pas seulement une rame).',
                      style: TextStyle(color: Colors.grey)),
                ),
                ..._sections(),
              ],
            ),
    );
  }

  List<Widget> _sections() {
    final widgets = <Widget>[];
    // Regroupe par niveau (1N puis 2N), puis les éventuels autres plans.
    for (final serie in const ['1N', '2N']) {
      final duNiveau = _plans.where((p) => p.serie == serie).toList();
      if (duNiveau.isEmpty) continue;
      widgets.add(_titreSection('Niveau $serie'));
      widgets.addAll(duNiveau.map(_tuile));
    }
    final autres =
        _plans.where((p) => p.serie != '1N' && p.serie != '2N').toList();
    if (autres.isNotEmpty) {
      widgets.add(_titreSection('Autres plans'));
      widgets.addAll(autres.map(_tuile));
    }
    return widgets;
  }

  Widget _titreSection(String titre) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(titre,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );

  Widget _tuile(Plan plan) => ListTile(
        leading: SizedBox(
          width: 56,
          child: PhotoImage(
            store: ctx.storage,
            storageKey: plan.cheminImage,
            fit: BoxFit.cover,
            errorBuilder: (_) =>
                const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
        title: Text(plan.nom),
        trailing: const Icon(Icons.edit_location_alt),
        onTap: () async {
          // Ouvre le plan hors visite : le mode édition y règle les points ;
          // les flèches ◀ ▶ permettent de parcourir tous les plans.
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => PlanViewScreen(plan: plan)));
          _load();
        },
      );
}

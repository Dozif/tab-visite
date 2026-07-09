import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/models/plan.dart';
import '../../services/app_context.dart';
import '../../services/plan_import_service.dart';
import '../plan/plan_view_screen.dart';
import '../search/search_screen.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  late final AppContext ctx = context.read<AppContext>();
  List<Plan> _plans = [];
  Map<String, int> _zoneCounts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plans = await ctx.plans.all();
    final counts = <String, int>{};
    for (final p in plans) {
      counts[p.id] = (await ctx.zones.forPlan(p.id)).length;
    }
    if (mounted) setState(() { _plans = plans; _zoneCounts = counts; });
  }

  Future<void> _ajouterPlan() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final nom = await _demanderNom();
    if (nom == null) return;
    await PlanImportService(ctx.plans, ctx.storage)
        .importFromFile(File(x.path), nom, DateTime.now().millisecondsSinceEpoch);
    await _load();
  }

  Future<String?> _demanderNom() async {
    final c = TextEditingController(text: 'Nouveau plan');
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nom du plan'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plans de visite'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Rechercher une zone',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouterPlan,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Ajouter un plan'),
      ),
      body: _plans.isEmpty
          ? const Center(child: Text('Aucun plan'))
          : ListView.separated(
              itemCount: _plans.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final plan = _plans[i];
                return ListTile(
                  leading: SizedBox(
                    width: 64,
                    child: Image.file(ctx.storage.resolve(plan.cheminImage), fit: BoxFit.cover),
                  ),
                  title: Text(plan.nom),
                  subtitle: Text('${_zoneCounts[plan.id] ?? 0} zone(s)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => PlanViewScreen(plan: plan)));
                    _load();
                  },
                );
              },
            ),
    );
  }
}

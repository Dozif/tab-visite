import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/models/plan.dart';
import '../../data/models/visite.dart';
import '../../services/app_context.dart';
import '../../services/plan_import_service.dart';
import '../plan/plan_view_screen.dart';
import '../search/search_screen.dart';
import '../widgets/photo_image.dart';

class PlansScreen extends StatefulWidget {
  /// Visite en cours (dossier de rame). Null = accès direct sans visite.
  final Visite? visite;
  /// Si fourni (« M1 »/« M2 » ou « R1 »..« R8 »), n'affiche que les images
  /// de ce véhicule (ses 2 côtés).
  final String? numeroVehicule;
  const PlansScreen({super.key, this.visite, this.numeroVehicule});
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
    var plans = widget.visite == null
        ? await ctx.plans.all()
        : await ctx.plans
            .forTypeVisite(widget.visite!.typeVisite, widget.visite!.niveau);
    // Restreint à un véhicule précis si demandé (les 2 côtés de M1/M2 ou Rn).
    if (widget.numeroVehicule != null) {
      plans = plans
          .where((p) => p.numeroVehicule == widget.numeroVehicule)
          .toList();
    }
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
    final ext = x.name.contains('.') ? x.name.split('.').last.toLowerCase() : 'png';
    await PlanImportService(ctx.plans, ctx.storage).importFromBytes(
        await x.readAsBytes(), ext, nom, DateTime.now().millisecondsSinceEpoch);
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
        title: Text(widget.visite == null
            ? 'Plans de visite'
            : 'Rame ${widget.visite!.numeroRame} — ${widget.visite!.typeVisite}'
                '${widget.numeroVehicule != null ? ' • ${widget.numeroVehicule}' : ''}'),
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
                    child: PhotoImage(
                      store: ctx.storage,
                      storageKey: plan.cheminImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_) =>
                          const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  title: Text(plan.nom),
                  subtitle: Text('${_zoneCounts[plan.id] ?? 0} zone(s)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PlanViewScreen(
                                plan: plan, visiteId: widget.visite?.id)));
                    _load();
                  },
                  onLongPress: () async {
                    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                      title: Text('Supprimer « ${plan.nom} » ?'),
                      content: const Text('Le plan et toutes ses photos seront supprimés.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
                      ],
                    ));
                    if (ok != true) return;
                    for (final z in await ctx.zones.forPlan(plan.id)) {
                      for (final ph in await ctx.photos.forZone(z.id)) {
                        await ctx.storage.delete(ph.cheminFichier);
                        PhotoImage.evict(ph.cheminFichier);
                      }
                    }
                    await ctx.storage.delete(plan.cheminImage);
                    PhotoImage.evict(plan.cheminImage);
                    await ctx.plans.delete(plan.id);
                    _load();
                  },
                );
              },
            ),
    );
  }
}

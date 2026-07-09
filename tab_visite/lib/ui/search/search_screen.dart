import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/plan.dart';
import '../../data/models/zone.dart';
import '../../services/app_context.dart';
import '../plan/plan_view_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final AppContext ctx = context.read<AppContext>();
  List<Zone> _results = [];
  Map<String, Plan> _plansById = {};

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() => _results = []); return; }
    final zones = await ctx.zones.searchByName(q.trim());
    final plans = await ctx.plans.all();
    setState(() {
      _results = zones;
      _plansById = { for (final p in plans) p.id : p };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Rechercher une zone (ex. M)…', border: InputBorder.none),
          onChanged: _search,
        ),
      ),
      body: ListView.builder(
        itemCount: _results.length,
        itemBuilder: (_, i) {
          final z = _results[i];
          final plan = _plansById[z.planId];
          return ListTile(
            leading: const Icon(Icons.place),
            title: Text('Zone ${z.nom}'),
            subtitle: Text(plan?.nom ?? ''),
            onTap: plan == null ? null : () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => PlanViewScreen(plan: plan)),
            ),
          );
        },
      ),
    );
  }
}

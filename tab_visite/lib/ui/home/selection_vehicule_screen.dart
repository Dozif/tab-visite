import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/visite.dart';
import '../../services/app_context.dart';
import 'plans_screen.dart';

/// Étape de choix du véhicule avant de voir ses images (les 2 côtés) :
/// motrices M1/M2 (MKBAM) ou remorques R1..R8 (MKBDR/MKBAR).
class SelectionVehiculeScreen extends StatefulWidget {
  final Visite visite;
  const SelectionVehiculeScreen({super.key, required this.visite});
  @override
  State<SelectionVehiculeScreen> createState() =>
      _SelectionVehiculeScreenState();
}

class _SelectionVehiculeScreenState extends State<SelectionVehiculeScreen> {
  late final AppContext ctx = context.read<AppContext>();
  List<String> _numeros = [];

  bool get _estMotrice => widget.visite.typeVisite == TypeVisite.mkbam;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plans = await ctx.plans.forTypeVisite(widget.visite.typeVisite);
    // Numéros distincts, triés numériquement (M1, M2 / R1..R8).
    final set = <String>{};
    for (final p in plans) {
      final n = p.numeroVehicule;
      if (n != null) set.add(n);
    }
    final list = set.toList()
      ..sort((a, b) =>
          int.parse(a.substring(1)).compareTo(int.parse(b.substring(1))));
    if (mounted) setState(() => _numeros = list);
  }

  void _ouvrir(String numero) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                PlansScreen(visite: widget.visite, numeroVehicule: numero)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Rame ${widget.visite.numeroRame} — ${widget.visite.typeVisite}'),
      ),
      body: _numeros.isEmpty
          ? const Center(
              child: Text('Aucun véhicule pour ce type.',
                  style: TextStyle(color: Colors.grey)))
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(_estMotrice ? 'Choisir une motrice' : 'Choisir une remorque',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: _numeros.map(_carre).toList(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _carre(String numero) {
    final couleur = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 96,
      height: 96,
      child: Material(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _ouvrir(numero),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: couleur, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(numero,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: couleur)),
          ),
        ),
      ),
    );
  }
}

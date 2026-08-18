// lib/presentation/thix_reservation/delivery/pages/admin/delivery_admin_routes_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_admin_provider.dart';
import '../../data/delivery_models.dart';

class DeliveryAdminRoutesPage extends StatefulWidget {
  const DeliveryAdminRoutesPage({super.key});

  @override
  State<DeliveryAdminRoutesPage> createState() => _DeliveryAdminRoutesPageState();
}

class _DeliveryAdminRoutesPageState extends State<DeliveryAdminRoutesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryAdminProvider>().loadRoutes(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D28D9),
        foregroundColor: Colors.white,
        title: const Text("Prix par trajet", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 18), onPressed: () => context.pop()),
      ),
      body: Consumer<DeliveryAdminProvider>(
        builder: (context, prov, _) {
          if (prov.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9)));
          }
          if (prov.routes.isEmpty) {
            return const Center(child: Text("Aucun trajet - Cliquez + pour créer", style: TextStyle(fontSize: 11, color: Color(0xFF8B8BA3))));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: prov.routes.length,
            itemBuilder: (_, i) {
              final r = prov.routes[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  title: Text("${r.fromCity} → ${r.toCity}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  subtitle: Text("Base ${r.basePrice} | Express ${r.expressPrice} | ${r.distanceKm}km", style: const TextStyle(fontSize: 9)),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 16), onPressed: () => prov.deleteRoute(r.id)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6D28D9),
        onPressed: () => _openCreateDialog(context),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  void _openCreateDialog(BuildContext context) {
    final adminProv = context.read<DeliveryAdminProvider>();
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    final baseCtrl = TextEditingController(text: "3000");
    final expressCtrl = TextEditingController(text: "5000");
    final supCtrl = TextEditingController(text: "500");
    final distCtrl = TextEditingController(text: "230");
    bool isInter = false;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final canCreate = fromCtrl.text.trim().isNotEmpty && toCtrl.text.trim().isNotEmpty;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Nouveau trajet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: fromCtrl, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: "De (ex: Abidjan)"), style: const TextStyle(fontSize: 13)),
                    TextField(controller: toCtrl, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: "Vers (ex: Yamoussoukro)"), style: const TextStyle(fontSize: 13)),
                    TextField(controller: baseCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Prix base 0-5kg (FCFA)"), style: const TextStyle(fontSize: 13)),
                    TextField(controller: expressCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Prix express 0-5kg"), style: const TextStyle(fontSize: 13)),
                    TextField(controller: supCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Supplément /kg au delà 5kg"), style: const TextStyle(fontSize: 13)),
                    TextField(controller: distCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Distance km"), style: const TextStyle(fontSize: 13)),
                    Row(children: [const Text("International", style: TextStyle(fontSize: 12)), const Spacer(), Checkbox(value: isInter, onChanged: (v) => setState(() => isInter = v?? false))]),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: canCreate? const Color(0xFF6D28D9) : Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed:!canCreate || isLoading? null : () async {
                    setState(() => isLoading = true);
                    try {
                      await adminProv.createRoute(
                        fromCity: fromCtrl.text.trim().toUpperCase(),
                        toCity: toCtrl.text.trim().toUpperCase(),
                        basePrice: int.tryParse(baseCtrl.text)?? 3000,
                        expressPrice: int.tryParse(expressCtrl.text)?? 5000,
                        pricePerKg: int.tryParse(supCtrl.text)?? 500,
                        distanceKm: int.tryParse(distCtrl.text)?? 0,
                        isInternational: isInter,
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trajet créé ✅")));
                      }
                    } catch (e) {
                      setState(() => isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
                    }
                  },
                  child: isLoading? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Créer", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

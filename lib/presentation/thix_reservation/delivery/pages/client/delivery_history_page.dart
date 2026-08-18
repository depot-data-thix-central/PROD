// ================================================================
// CHEMIN: lib/presentation/thix_reservation/delivery/pages/client/delivery_history_page.dart
// ROLE: HISTORIQUE avec pagination scalable 1M
// ================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_client_provider.dart';

class DeliveryHistoryPage extends StatefulWidget {
  const DeliveryHistoryPage({super.key});
  @override
  State<DeliveryHistoryPage> createState() => _DeliveryHistoryPageState();
}

class _DeliveryHistoryPageState extends State<DeliveryHistoryPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryClientProvider>().loadMyShipments(refresh: true);
    });
    // Pagination infinite scroll
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        context.read<DeliveryClientProvider>().loadMyShipments();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DeliveryClientProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text("Mes envois")),
      body: prov.myShipments.isEmpty &&!prov.isLoadingHistory
         ? const Center(child: Text("Aucun envoi"))
          : ListView.builder(
              controller: _scroll,
              itemCount: prov.myShipments.length + (prov.hasMoreHistory? 1 : 0),
              itemBuilder: (context, i) {
                if (i == prov.myShipments.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                final s = prov.myShipments[i];
                return ListTile(
                  title: Text("${s.fromCity} → ${s.toCity}"),
                  subtitle: Text(s.trackingCode),
                  trailing: Text("${s.finalPrice}F\n${s.status.name}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
    );
  }
}

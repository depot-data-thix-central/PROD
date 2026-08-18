// ================================================================
// CHEMIN: lib/presentation/thix_reservation/delivery/pages/admin/delivery_admin_shipments_page.dart
// ROLE: Liste de TOUS les colis de tous les clients (1M users)
// Filtrable par statut
// ================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_admin_provider.dart';
import '../../data/delivery_models.dart';

class DeliveryAdminShipmentsPage extends StatefulWidget {
  const DeliveryAdminShipmentsPage({super.key});
  @override
  State<DeliveryAdminShipmentsPage> createState() => _DeliveryAdminShipmentsPageState();
}

class _DeliveryAdminShipmentsPageState extends State<DeliveryAdminShipmentsPage> {
  ShipmentStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DeliveryAdminProvider>();
    final list = _filter == null? prov.allShipments : prov.allShipments.where((e) => e.status == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Tous les colis")),
      body: Column(children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [const SizedBox(width: 8), ChoiceChip(label: const Text("Tous"), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),...ShipmentStatus.values.map((s) => Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChip(label: Text(s.name), selected: _filter == s, onSelected: (_) => setState(() => _filter = s))))])),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) {
          final s = list[i];
          return ListTile(title: Text("${s.fromCity} → ${s.toCity}"), subtitle: Text("${s.trackingCode} - ${s.receiverName}"), trailing: DropdownButton<ShipmentStatus>(value: s.status, items: ShipmentStatus.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: const TextStyle(fontSize: 11)))).toList(), onChanged: (v) { if (v!= null) prov.updateShipmentStatus(s.id, v, s.toCity); }));
        }))
      ]),
    );
  }
}

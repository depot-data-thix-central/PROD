// ================================================================
// CHEMIN: lib/presentation/thix_reservation/delivery/pages/client/delivery_tracking_page.dart
// ROLE: TRACKING par code THX-XXXXXX + Timeline
// ================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_client_provider.dart';

class DeliveryTrackingPage extends StatefulWidget {
  const DeliveryTrackingPage({super.key});
  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  final _codeCtrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DeliveryClientProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text("Suivre un colis")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _codeCtrl, decoration: InputDecoration(labelText: "Code THX-XXXX", suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () async {
            try { await prov.trackByCode(_codeCtrl.text); } catch(e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"))); }
          }))),
          const SizedBox(height: 20),
          if (prov.isTracking) const CircularProgressIndicator(),
          if (prov.trackedShipment!= null)...[
            Text("${prov.trackedShipment!.fromCity} → ${prov.trackedShipment!.toCity}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
           ...prov.trackingEvents.map((e) => ListTile(leading: const Icon(Icons.circle, size: 12, color: Color(0xFF6D28D9)), title: Text(e.status), subtitle: Text("${e.location} - ${e.description}"), trailing: Text(e.date.toString().substring(0,16)))),
          ]
        ]),
      ),
    );
  }
}

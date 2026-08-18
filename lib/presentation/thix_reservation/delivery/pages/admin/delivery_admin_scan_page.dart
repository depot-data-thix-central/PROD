// ================================================================
// CHEMIN: lib/presentation/thix_reservation/delivery/pages/admin/delivery_admin_scan_page.dart
// ROLE: SCAN QR - Pour changer statut colis rapidement
// Le livreur scan le code THX-XXXXXX et passe en delivered
// ================================================================

import 'package:flutter/material.dart';

class DeliveryAdminScanPage extends StatelessWidget {
  const DeliveryAdminScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final codeCtrl = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text("Scanner QR")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Icon(Icons.qr_code_scanner, size: 120, color: Color(0xFF6D28D9)),
          const SizedBox(height: 20),
          const Text("Place le QR du colis devant la caméra", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: "Ou saisis code THX-XXXX manuellement", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9)), onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Scan ${codeCtrl.text} - à brancher avec mobile_scanner package")));
          }, child: const Text("Valider scan", style: TextStyle(color: Colors.white)))),
          const SizedBox(height: 10),
          const Text("Package à ajouter: mobile_scanner: ^5.2.0", style: TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ),
    );
  }
}

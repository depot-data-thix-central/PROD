// ================================================================
// CHEMIN: lib/presentation/thix_reservation/delivery/pages/client/delivery_checkout_page.dart
// ROLE: FLOW CHECKOUT - 4 étapes fusionnées en 1 page à steps
// Destinataire + Adresse + Paiement + Success
// C'est après "Calculer le prix" sur Home
// ================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_client_provider.dart';
import '../../data/delivery_models.dart';

class DeliveryCheckoutPage extends StatefulWidget {
  const DeliveryCheckoutPage({super.key});

  @override
  State<DeliveryCheckoutPage> createState() => _DeliveryCheckoutPageState();
}

class _DeliveryCheckoutPageState extends State<DeliveryCheckoutPage> {
  int _step = 0; // 0=receiver, 1=payment, 2=success
  
  // Contrôleurs Expéditeur
  final _senderNameCtrl = TextEditingController();
  final _senderPhoneCtrl = TextEditingController(); // 🟢 NOUVEAU: Champ pour le téléphone de l'expéditeur
  final _senderAddrCtrl = TextEditingController();
  
  // Contrôleurs Destinataire
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  
  ParcelType _type = ParcelType.other;
  bool _isCreating = false;
  String? _trackingCode;

  @override
  void dispose() {
    _senderNameCtrl.dispose();
    _senderPhoneCtrl.dispose();
    _senderAddrCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DeliveryClientProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("Envoyer un colis"), backgroundColor: Colors.white),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () async {
          if (_step == 0) {
            // Validation simple
            if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty || _senderNameCtrl.text.isEmpty || _senderPhoneCtrl.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Remplis tous les champs obligatoires (*)")));
              return;
            }
            setState(() => _step = 1);
          } else if (_step == 1) {
            // Création colis Supabase
            setState(() => _isCreating = true);
            try {
              final code = await prov.createShipment(
                senderName: _senderNameCtrl.text, 
                senderPhone: _senderPhoneCtrl.text, // 🟢 AJOUTÉ ICI pour corriger l'erreur
                receiverName: _nameCtrl.text,
                receiverPhone: _phoneCtrl.text,
                receiverAddress: _addressCtrl.text,
                senderAddress: _senderAddrCtrl.text,
              );
              setState(() {
                _trackingCode = code;
                _step = 2;
                _isCreating = false;
              });
            } catch (e) {
              setState(() => _isCreating = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
            }
          } else if (_step == 2) {
             // Fin, retour à l'accueil
             Navigator.popUntil(context, (r) => r.isFirst);
          }
        },
        onStepCancel: () => setState(() => _step = _step > 0 ? _step - 1 : 0),
        steps: [
          // --- STEP 0: Infos expéditeur & destinataire ---
          Step(
            title: const Text("Informations"),
            isActive: _step >= 0,
            content: Column(children: [
              const Text("Expéditeur", style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.left),
              TextField(controller: _senderNameCtrl, decoration: const InputDecoration(labelText: "Ton nom (Expéditeur) *")),
              TextField(controller: _senderPhoneCtrl, decoration: const InputDecoration(labelText: "Ton téléphone (Expéditeur) *"), keyboardType: TextInputType.phone), // 🟢 Ajout du champ dans l'UI
              TextField(controller: _senderAddrCtrl, decoration: const InputDecoration(labelText: "Ton adresse")),
              const Divider(height: 30),
              
              const Text("Destinataire", style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.left),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Nom destinataire *")),
              TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: "Téléphone *"), keyboardType: TextInputType.phone),
              TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: "Adresse complète dest.")),
              const SizedBox(height: 10),
              
              DropdownButtonFormField<ParcelType>(
                value: _type, 
                decoration: const InputDecoration(labelText: "Type de colis"),
                items: ParcelType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(), 
                onChanged: (v) => setState(() => _type = v!)
              ),
            ]),
          ),
          // --- STEP 1: Paiement ---
          Step(
            title: const Text("Paiement"),
            isActive: _step >= 1,
            content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("${prov.fromCity} → ${prov.toCity}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("${prov.calculatedPrice} FCFA", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ]),
              ),
              const SizedBox(height: 10),
              const Text("Mode de paiement (M-Pesa / Airtel Money / Carte) - à intégrer"),
              if (_isCreating) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
            ]),
          ),
          // --- STEP 2: Success ---
          Step(
            title: const Text("Succès"),
            isActive: _step >= 2,
            state: StepState.complete,
            content: Column(children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 10),
              const Text("Colis créé avec succès!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                child: SelectableText("Tracking ID: $_trackingCode", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ],
      ),
    );
  }
}

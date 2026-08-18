// lib/presentation/thix_reservation/bus/pages/agency/agency_onboarding_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgencyOnboardingPage extends StatefulWidget {
  const AgencyOnboardingPage({super.key});
  @override State<AgencyOnboardingPage> createState() => _AgencyOnboardingPageState();
}

class _AgencyOnboardingPageState extends State<AgencyOnboardingPage> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String _country = 'RDC';
  bool _loading = false;

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom requis')));
      return;
    }
    setState(() => _loading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      
      // TEST MODE : approved direct, pas d'attente
      final data = {
        'owner_id': uid,
        'name': _name.text.trim(),
        'country': _country,
        'description': _desc.text.trim(),
        'status': 'approved', // <--- PLUS DE PENDING
      };

      await Supabase.instance.client.from('bus_agencies').insert(data);
      if (!mounted) return;
      context.go('/agency/dashboard');
    } catch (e) {
      // Fallback si colonne = user_id
      try {
        final uid = Supabase.instance.client.auth.currentUser!.id;
        await Supabase.instance.client.from('bus_agencies').insert({
          'user_id': uid,
          'name': _name.text.trim(),
          'country': _country,
          'description': _desc.text.trim(),
          'status': 'approved',
        });
        if (!mounted) return;
        context.go('/agency/dashboard');
      } catch (e2) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e2'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override Widget build(BuildContext context) {
    const kPrimary = Color(0xFF0B4FE3);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Devenir Agence Partenaire', style: TextStyle(fontWeight: FontWeight.w800)), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: ()=> context.pop())),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.directions_bus_rounded, size: 72, color: kPrimary),
        const SizedBox(height: 16),
        const Text('Creez votre agence', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 20),
        TextField(controller: _name, decoration: InputDecoration(labelText: "Nom agence *", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 14),
        DropdownButtonFormField(value: _country, decoration: InputDecoration(labelText: 'Pays', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: const [DropdownMenuItem(value: 'RDC', child: Text('RDC')), DropdownMenuItem(value: 'CIV', child: Text('CIV'))], onChanged: (v)=> setState(()=> _country = v!)),
        const SizedBox(height: 14),
        TextField(controller: _desc, maxLines: 3, decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 24),
        SizedBox(height: 52, child: ElevatedButton(onPressed: _loading? null : _create, style: ElevatedButton.styleFrom(backgroundColor: kPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _loading? const CircularProgressIndicator(color: Colors.white) : const Text('Creer mon agence', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))),
        const SizedBox(height: 10),
        const Center(child: Text('MODE TEST : Validation automatique active', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

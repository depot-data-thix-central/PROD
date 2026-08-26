// lib/presentation/thix_reservation/bus/pages/agency/agency_onboarding_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/agency_dashboard_provider.dart';

class AgencyOnboardingPage extends ConsumerStatefulWidget {
  const AgencyOnboardingPage({super.key});

  @override
  ConsumerState<AgencyOnboardingPage> createState() => _AgencyOnboardingPageState();
}

class _AgencyOnboardingPageState extends ConsumerState<AgencyOnboardingPage> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String _country = 'CD';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(agencyDashboardProvider.notifier).init();
      final state = ref.read(agencyDashboardProvider);
      if (!mounted) return;
      if (state.hasAgency) {
        context.go('/agency/dashboard');
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  String _mapCountry(String value) {
    switch (value) {
      case 'RDC':
        return 'CD';
      case 'CIV':
        return 'CI';
      default:
        return value;
    }
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom requis')),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour créer une agence'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final ok = await ref.read(agencyDashboardProvider.notifier).createMyAgency(
            name: _name.text.trim(),
            countryCode: _mapCountry(_country),
            description: _desc.text.trim(),
          );
      if (!mounted) return;
      if (ok) {
        context.go('/agency/dashboard');
      } else {
        final err = ref.read(agencyDashboardProvider).error ?? 'Création impossible';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFF0B4FE3);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Devenir Agence Partenaire',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.directions_bus_rounded, size: 72, color: kPrimary),
          const SizedBox(height: 16),
          const Text(
            'Creez votre agence',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: 'Nom agence *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _country,
            decoration: InputDecoration(
              labelText: 'Pays',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'CD', child: Text('RDC')),
              DropdownMenuItem(value: 'CI', child: Text('CIV')),
            ],
            onChanged: (v) => setState(() => _country = v ?? 'CD'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Creer mon agence',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'MODE TEST : Validation automatique active',
              style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

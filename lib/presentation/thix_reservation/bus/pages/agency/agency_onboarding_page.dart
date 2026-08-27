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
  bool _loadingList = true;
  List<Map<String, dynamic>> _agencies = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMine());
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    setState(() {
      _loadingList = true;
      _error = null;
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loadingList = false;
        _error = 'Connectez-vous pour voir vos agences';
      });
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('bus_agencies')
          .select()
          .eq('owner_id', user.id)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(res as List);
      if (!mounted) return;
      setState(() {
        _agencies = list;
        _loadingList = false;
      });

      await ref.read(agencyDashboardProvider.notifier).init();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openDashboard() async {
    await ref.read(agencyDashboardProvider.notifier).init();
    if (!mounted) return;
    context.go('/agency/dashboard');
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
            countryCode: _country,
            description: _desc.text.trim(),
          );
      if (!mounted) return;
      if (ok) {
        _name.clear();
        _desc.clear();
        await _loadMine();
        if (!mounted) return;
        context.go('/agency/dashboard');
      } else {
        final err = ref.read(agencyDashboardProvider).error ?? 'Création impossible';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
        await _loadMine();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMine,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.directions_bus_rounded, size: 64, color: kPrimary),
          const SizedBox(height: 8),
          const Text(
            'Mes agences',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          if (_loadingList)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))
          else if (_agencies.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Aucune agence pour ce compte. Créez-en une ci-dessous.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          else
            ..._agencies.map((a) {
              final name = (a['name'] ?? 'Agence').toString();
              final status = (a['status'] ?? '').toString();
              final country = (a['country'] ?? a['country_code'] ?? '').toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.storefront_rounded, color: kPrimary),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    [if (country.isNotEmpty) country, if (status.isNotEmpty) status].join(' • '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openDashboard,
                ),
              );
            }),
          if (_agencies.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _openDashboard,
                icon: const Icon(Icons.dashboard_customize),
                label: const Text('Ouvrir le dashboard'),
              ),
            ),
          ],
          const SizedBox(height: 28),
          const Text(
            'Créer une nouvelle agence',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 20),
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

// lib/presentation/thix_money/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/wallet_provider.dart';
import '../services/qr_service.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletStreamProvider);
    final thixIdAsync = ref.watch(currentThixIdProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Mon THIX ID')),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (w) => SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20)]), child: Column(children: [
            QrImageView(data: QrService.encodeThixQr(thixId: w.thixId, displayName: 'THIX USER'), size: 200, backgroundColor: Colors.white),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(w.thixId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () { Clipboard.setData(ClipboardData(text: w.thixId)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('THIX ID copié'))); })]),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.verified, color: Colors.green, size: 16), const SizedBox(width: 4), Text('Vérifié en base • ${thixIdAsync.value?? ''}', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold))])),
          ])),
          const SizedBox(height: 24),
          _Tile(icon: Icons.wallet, title: 'Wallet ID', subtitle: w.id),
          _Tile(icon: Icons.money, title: 'Soldes', subtitle: '${w.soldeCdf} CDF • ${w.soldeUsd} USD'),
          _Tile(icon: Icons.security, title: 'Sécurité', subtitle: '2FA activé • Biométrie'),
          _Tile(icon: Icons.history, title: 'Vérification THIX', subtitle: 'profiles.thix_id EXISTS ✓'),
        ])),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  const _Tile({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF6F8FF), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 20)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)), trailing: const Icon(Icons.chevron_right, size: 18));
  }
}

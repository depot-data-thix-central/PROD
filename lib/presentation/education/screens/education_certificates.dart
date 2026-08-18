import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ✅ CORRIGÉ : L'import relatif cache le conflit de certificatesProvider
import '../providers/education_provider.dart' hide certificatesProvider; 
import '../providers/certificate_provider.dart'; 

import '../models/certificate.dart';
import '../widgets/common/education_empty_state.dart';
import '../widgets/common/education_loading_shimmer.dart';

class EducationCertificates extends ConsumerWidget {
  const EducationCertificates({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ CORRECTION ICI : Ajout de ".value" pour extraire l'ID du StreamProvider
    final userId = ref.watch(currentUserIdProvider).value;
    
    if (userId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7FAFF),
        appBar: AppBar(
          title: const Text('Mes Certificats', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))), 
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)), onPressed: () => context.pop()),
        ),
        body: const Center(child: Text('Veuillez vous connecter pour voir vos certificats.', style: TextStyle(color: Color(0xFF7386A8)))),
      );
    }

    final certsAsync = ref.watch(certificatesProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        title: const Text('Mes Certificats', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)), onPressed: () => context.pop()),
      ),
      body: certsAsync.when(
        loading: () => const EducationLoadingShimmer(),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (certificates) {
          if (certificates.isEmpty) {
            return EducationEmptyState(
              title: 'Aucun certificat',
              subtitle: 'Terminez une formation certifiante pour obtenir votre certificat',
              icon: Icons.workspace_premium_rounded,
              buttonText: 'Voir les formations',
              onButtonPressed: () => context.push('/education'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(certificatesProvider(userId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: certificates.length,
              itemBuilder: (context, index) => _CertificateCard(certificate: certificates[index]),
            ),
          );
        },
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  final Certificate certificate;
  const _CertificateCard({required this.certificate});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/education/certificate/${certificate.id}', extra: certificate),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7EEFC)),
          boxShadow: [BoxShadow(color: const Color(0xFF0A1F44).withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2D6CDF), Color(0xFF123B7A)]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.verified_rounded, color: Colors.white, size: 28)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Certificat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 4),
            Text('Délivré le ${_formatDate(certificate.issuedAt)}', style: const TextStyle(fontSize: 12, color: Color(0xFF7386A8))),
            Text('ID: ${certificate.verificationHash.substring(0, 8)}...', style: const TextStyle(fontSize: 11, color: Color(0xFF7386A8))),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF7386A8)),
        ]),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin', 'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// lib/presentation/mon_pays/pages/provinces/widgets/province_authorities_widgets.dart
//
// 🏛️ AUTORITÉS PROVINCIALES (gouverneur, vice-gouverneur, ministres)
//    + 🚨 CONTACTS D'URGENCE — style de l'ancien fichier (cartes exécutives).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../../models/province.dart';
import 'province_shortcut_bar.dart';

// ════════════════════════════════════════════════════════════════════════
// 🏛️ AUTORITÉS PROVINCIALES
// ════════════════════════════════════════════════════════════════════════
class ProvinceAuthoritiesSection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const ProvinceAuthoritiesSection({super.key, required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    final executives = <Map<String, String?>>[];
    if ((province.governor ?? '').isNotEmpty) {
      executives.add({'role': 'Gouverneur', 'name': province.governor, 'photo': province.governorPhotoUrl});
    }
    if ((province.viceGovernor ?? '').isNotEmpty) {
      executives.add({'role': 'Vice-Gouverneur', 'name': province.viceGovernor, 'photo': province.viceGovernorPhotoUrl});
    }
    final ministers = province.ministers;

    if (executives.isEmpty && ministers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.account_balance_rounded,
          color: ThixPolicy.primary,
          title: ProvinceTranslations.t('authorities', lang),
          count: executives.length + ministers.length,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (executives.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85,
                    ),
                    itemCount: executives.length,
                    itemBuilder: (_, i) => _ExecutiveCard(
                      role: executives[i]['role']!,
                      name: executives[i]['name']!,
                      photoUrl: executives[i]['photo'],
                    ),
                  ),
                if (ministers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Ministres provinciaux',
                      style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.78,
                    ),
                    itemCount: ministers.length,
                    itemBuilder: (_, i) {
                      final m = ministers[i];
                      final name = m['name']?.toString() ?? '—';
                      final role = m['role']?.toString() ?? 'Ministre';
                      final photo = (m['photoUrl'] ?? m['photo_url'] ?? '').toString();
                      return _MinisterCard(name: name, role: role, photoUrl: photo);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _ExecutiveCard extends StatelessWidget {
  final String role, name;
  final String? photoUrl;
  const _ExecutiveCard({required this.role, required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final isGov = role.toLowerCase().contains('gouverneur') && !role.toLowerCase().contains('vice');
    final color = isGov ? ThixPolicy.gold : ThixPolicy.primary;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        showGlassSheet(
          context,
          title: name,
          subtitle: role,
          imageUrl: hasPhoto ? photoUrl : null,
          icon: Icons.person_rounded,
          color: color,
          children: [
            sheetRow(Icons.workspace_premium_rounded, 'Fonction', role, color: color),
            sheetRow(Icons.account_balance_rounded, 'Institution', 'Gouvernement provincial'),
          ],
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: ThixPolicy.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThixPolicy.border),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2.5)),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: ThixPolicy.card,
                backgroundImage: hasPhoto ? CachedNetworkImageProvider(photoUrl!) : null,
                child: hasPhoto ? null : Icon(Icons.person_rounded, size: 30, color: ThixPolicy.textMuted),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(role.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isGov ? const Color(0xFF8A6B00) : ThixPolicy.primary)),
            ),
            const SizedBox(height: 6),
            Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _MinisterCard extends StatelessWidget {
  final String name, role;
  final String photoUrl;
  const _MinisterCard({required this.name, required this.role, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.isNotEmpty;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        showGlassSheet(
          context,
          title: name,
          subtitle: role,
          imageUrl: hasPhoto ? photoUrl : null,
          icon: Icons.person_rounded,
          children: [sheetRow(Icons.work_rounded, 'Portefeuille', role)],
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: ThixPolicy.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ThixPolicy.border),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: ThixPolicy.card,
              backgroundImage: hasPhoto ? CachedNetworkImageProvider(photoUrl) : null,
              child: hasPhoto ? null : const Icon(Icons.person_rounded, size: 20, color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 6),
            Text(role, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontWeight: FontWeight.w700)),
            Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 🚨 URGENCES
// ════════════════════════════════════════════════════════════════════════
class ProvinceEmergencySection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const ProvinceEmergencySection({super.key, required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (province.emergencyContacts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.emergency_rounded,
          color: ThixPolicy.danger,
          title: ProvinceTranslations.t('emergency', lang),
          count: province.emergencyContacts.length,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: province.emergencyContacts.map((c) {
                final dyn = c as dynamic;
                final service = dyn.service?.toString() ?? 'Service';
                final phone = dyn.phone?.toString() ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ThixPolicy.danger.withOpacity(0.25)),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.phone_in_talk_rounded, color: ThixPolicy.danger, size: 18),
                    ),
                    title: Text(service, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                    subtitle: Text(phone, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w600)),
                    trailing: phone.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.call_rounded, color: Color(0xFF2E7D32), size: 20),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              launchUrl(Uri.parse('tel:$phone'));
                            },
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

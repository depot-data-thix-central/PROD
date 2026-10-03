// lib/presentation/thix_media/widgets/media_cert_badge.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/presentation/thix_media/providers/media_certification_provider.dart';
import 'package:thix_id/services/certification_service.dart';

/// Sceau de certification à placer à côté d'un nom dans THIX Media.
/// - `userId` : récupère automatiquement le niveau de l'utilisateur
/// - `official: true` : force le sceau Officiel (ex: compte TDIA)
class MediaCertBadge extends ConsumerWidget {
  final String? userId;
  final bool official;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  const MediaCertBadge({
    super.key,
    this.userId,
    this.official = false,
    this.iconSize = 15,
    this.padding = const EdgeInsets.only(left: 4),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (official) {
      return CertificationNameBadge(
        tier: CertificationTier.official,
        status: CertificationStatus.approved,
        iconSize: iconSize,
        padding: padding,
      );
    }

    final id = userId?.trim() ?? '';
    if (id.isEmpty) return const SizedBox.shrink();

    final async = ref.watch(mediaUserCertTierProvider(id));
    return async.maybeWhen(
      data: (tier) => tier == null
          ? const SizedBox.shrink()
          : CertificationNameBadge(
              tier: tier,
              status: CertificationStatus.approved,
              iconSize: iconSize,
              padding: padding,
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

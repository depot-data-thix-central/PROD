/// THIX SOS — Bannière statut sécurité (production)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sos_models.dart';

enum SecurityBannerState {
  safe,
  sosActive,
  networkLost,
  warning,
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    this.incident,
    this.locationLabel,
    this.onLocationTap,
  });

  /// Si non null et actif → mode SOS
  final SosIncident? incident;
  final String? locationLabel;
  final VoidCallback? onLocationTap;

  SecurityBannerState get _state {
    if (incident == null || !incident!.isActive) {
      return SecurityBannerState.safe;
    }
    if (incident!.status == SosStatus.networkLost) {
      return SecurityBannerState.networkLost;
    }
    return SecurityBannerState.sosActive;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    final Color bg;
    final Color border;
    final Color iconColor;
    final Color titleColor;
    final IconData icon;
    final String title;
    final String subtitle;

    switch (state) {
      case SecurityBannerState.safe:
        bg = const Color(0xFF064E3B).withOpacity(0.45);
        border = const Color(0xFF10B981).withOpacity(0.35);
        iconColor = const Color(0xFF34D399);
        titleColor = const Color(0xFF34D399);
        icon = Icons.verified_user_rounded;
        title = 'VOUS ÊTES EN SÉCURITÉ';
        subtitle = 'Votre protection THIX est active';
        break;
      case SecurityBannerState.sosActive:
        bg = const Color(0xFF7F1D1D).withOpacity(0.55);
        border = const Color(0xFFEF4444).withOpacity(0.5);
        iconColor = const Color(0xFFF87171);
        titleColor = const Color(0xFFFECACA);
        icon = Icons.warning_amber_rounded;
        title = 'SOS EN COURS';
        subtitle = incident!.publicId;
        break;
      case SecurityBannerState.networkLost:
        bg = const Color(0xFF78350F).withOpacity(0.5);
        border = const Color(0xFFF59E0B).withOpacity(0.45);
        iconColor = const Color(0xFFFBBF24);
        titleColor = const Color(0xFFFDE68A);
        icon = Icons.wifi_off_rounded;
        title = 'CONNEXION PERDUE';
        subtitle = 'Dernière position conservée localement';
        break;
      case SecurityBannerState.warning:
        bg = const Color(0xFF78350F).withOpacity(0.45);
        border = const Color(0xFFF59E0B).withOpacity(0.4);
        iconColor = const Color(0xFFFBBF24);
        titleColor = const Color(0xFFFDE68A);
        icon = Icons.info_outline_rounded;
        title = 'ATTENTION';
        subtitle = 'Vérifiez vos paramètres de secours';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          if (locationLabel != null && locationLabel!.isNotEmpty) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onLocationTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Color(0xFF60A5FA)),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: Text(
                        locationLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (state == SecurityBannerState.safe)
            const Icon(Icons.check_circle, color: Color(0xFF34D399), size: 20),
        ],
      ),
    );
  }
}

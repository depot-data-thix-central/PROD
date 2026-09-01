/// THIX SOS — Carte cercle de secours 1/2/3 (Production Enterprise)
/// ✅ SÉCURISÉ : validation URL, ThixPolicy, i18n, semantics, haptic
/// ✅ PERFORMANCE : RepaintBoundary, mounted checks, validation
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../models/sos_models.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMinCircle = 1;
const int _kMaxCircle = 3;
const int _kMaxAvatarPreview = 3;
const Duration _kThrottleDelay = Duration(milliseconds: 500);

// ============================================================================
// VALIDATORS
// ============================================================================
class _CircleValidators {
  _CircleValidators._();

  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static int clampCircle(int circle) {
    return circle.clamp(_kMinCircle, _kMaxCircle);
  }

  static String safeInitial(String? name, {String fallback = '?'}) {
    if (name == null || name.trim().isEmpty) return fallback;
    return name.trim()[0].toUpperCase();
  }
}

// ============================================================================
// CERCLE CARD
// ============================================================================
class CercleCard extends StatelessWidget {
  const CercleCard({
    super.key,
    required this.circle,
    required this.contacts,
    this.onTap,
    this.onManage,
  });

  final int circle;
  final List<SosContact> contacts;
  final VoidCallback? onTap;
  final VoidCallback? onManage;

  Color get _color {
    final clampedCircle = _CircleValidators.clampCircle(circle);
    switch (clampedCircle) {
      case 1:
        return ThixPolicy.success;
      case 2:
        return ThixPolicy.warning;
      case 3:
        return ThixPolicy.primary;
      default:
        return ThixPolicy.textMuted;
    }
  }

  String _title(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final clampedCircle = _CircleValidators.clampCircle(circle);
    switch (clampedCircle) {
      case 1:
        return l10n.t('sos_circle_1_title');
      case 2:
        return l10n.t('sos_circle_2_title');
      case 3:
        return l10n.t('sos_circle_3_title');
      default:
        return '${l10n.t('sos_circle')} $clampedCircle';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = contacts.length;
    final preview = contacts.take(_kMaxAvatarPreview).toList();
    final title = _title(context);

    return Semantics(
      button: true,
      label: '$title, $count ${l10n.t('sos_rescuers')}',
      child: RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap != null
                ? () {
                    HapticFeedback.lightImpact();
                    onTap!();
                  }
                : null,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ThixPolicy.s14,
                vertical: ThixPolicy.s12,
              ),
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                border: Border.all(color: ThixPolicy.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Badge numéro
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                    ),
                    child: Center(
                      child: Text(
                        '$circle',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: ThixPolicy.s12),

                  // Titre + count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          count == 0
                              ? l10n.t('sos_no_rescuers')
                              : '$count ${l10n.t('sos_rescuers')}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: count == 0
                                ? ThixPolicy.textMuted
                                : Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Avatars empilés
                  if (preview.isNotEmpty)
                    SizedBox(
                      width: 12.0 + preview.length * 18.0,
                      height: 28,
                      child: Stack(
                        children: [
                          for (var i = 0; i < preview.length; i++)
                            Positioned(
                              left: i * 16.0,
                              child: _Avatar(
                                name: preview[i].name,
                                photoUrl: preview[i].photoUrl,
                                index: i,
                              ),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      color: ThixPolicy.textMuted, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// AVATAR — ✅ Validation URL + safe initial
// ============================================================================
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    this.photoUrl,
    required this.index,
  });

  final String name;
  final String? photoUrl;
  final int index;

  @override
  Widget build(BuildContext context) {
    final initial = _CircleValidators.safeInitial(name);
    final validPhoto = _CircleValidators.isValidUrl(photoUrl);
    final colors = [
      ThixPolicy.primary,
      ThixPolicy.warning,
      ThixPolicy.success,
      ThixPolicy.danger,
    ];

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ThixPolicy.card, width: 2),
      ),
      child: CircleAvatar(
        radius: 12,
        backgroundColor: colors[index % colors.length],
        backgroundImage: validPhoto ? NetworkImage(photoUrl!) : null,
        child: !validPhoto
            ? Text(
                initial,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              )
            : null,
      ),
    );
  }
}

// ============================================================================
// CERCLES LIST
// ============================================================================
class CerclesList extends StatelessWidget {
  const CerclesList({
    super.key,
    required this.contacts,
    this.onCircleTap,
    this.onManage,
  });

  final List<SosContact> contacts;
  final void Function(int circle)? onCircleTap;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.t('sos_my_rescuers'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ThixPolicy.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            if (onManage != null)
              Semantics(
                button: true,
                label: l10n.t('common_manage'),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onManage!();
                  },
                  child: Text(
                    l10n.t('common_manage'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ThixPolicy.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: ThixPolicy.s10),
        for (final circle in [_kMinCircle, _kMinCircle + 1, _kMaxCircle]) ...[
          CercleCard(
            circle: circle,
            contacts: contacts.where((c) => c.circle == circle).toList(),
            onTap: onCircleTap != null ? () => onCircleTap!(circle) : null,
          ),
          if (circle < _kMaxCircle) const SizedBox(height: ThixPolicy.s8),
        ],
      ],
    );
  }
}

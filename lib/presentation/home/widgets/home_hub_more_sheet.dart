// lib/presentation/home/widgets/home_hub_more_sheet.dart
//
// Panneau « More… » : tous les services qui ne sont pas sur la grille
// (SOS, Coffre-fort, Scan QR, THIX WED, Learning, Opportunités, Info,
//  Booking, Pays, Money, Health) + carte Certification.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';

import 'home_hub_settings.dart';
import 'home_premium_card.dart';
import 'home_services_constellation.dart' show ThixWedLogo;
import 'home_theme.dart';

const double _kIcon = 22.0; // taille d'icône du code existant
const double _kCircle = 46.0;

class HubMoreSheet {
  HubMoreSheet._();

  static Future<void> show(
    BuildContext context, {
    required SectionBadgeCounts counts,
    required Color primary,
    required ValueChanged<String> onAction,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MoreBody(
        counts: counts,
        primary: primary,
        onAction: (key) {
          Navigator.of(ctx).pop();
          onAction(key);
        },
      ),
    );
  }
}

class _MoreItem {
  final String key;
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  final bool customLogo;
  final bool suspended;
  const _MoreItem(
    this.key,
    this.icon,
    this.label,
    this.color, {
    this.badge = 0,
    this.customLogo = false,
    this.suspended = false,
  });
}

class _MoreBody extends StatelessWidget {
  final SectionBadgeCounts counts;
  final Color primary;
  final ValueChanged<String> onAction;

  const _MoreBody({
    required this.counts,
    required this.primary,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final h = MediaQuery.sizeOf(context).height;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final items = <_MoreItem>[
      _MoreItem('sos', Icons.emergency_rounded, 'Thix SOS', ThixPolicy.danger),
      _MoreItem('vault', Icons.folder_shared_rounded, 'Thix Doc', primary),
      _MoreItem('scanQr', Icons.qr_code_scanner_rounded,
          hubTr(l10n, 'home_scan_qr', 'Scan QR'), primary),
      const _MoreItem('thixWed', Icons.favorite_rounded, 'THIX WED',
          Color(0xFFD9667A),
          customLogo: true),
      _MoreItem('formations', Icons.school_rounded,
          'Thix ${l10n.t('svc_learning')}', ThixPolicy.domainLearning,
          badge: counts.formations),
      _MoreItem('opportunites', Icons.lightbulb_rounded,
          'Thix ${l10n.t('svc_opps')}', ThixPolicy.gold,
          badge: counts.opportunities),
      _MoreItem('thixInfo', Icons.newspaper_rounded,
          'Thix ${l10n.t('svc_news')}', primary,
          badge: counts.info),
      _MoreItem('reservation', Icons.confirmation_number_rounded,
          'Thix ${l10n.t('svc_booking')}', primary,
          badge: counts.reservation),
      _MoreItem('monPays', Icons.flag_rounded,
          'Thix ${l10n.t('svc_country')}', ThixPolicy.primaryDeep,
          badge: counts.monPays),
      _MoreItem('thixMoney', Icons.account_balance_wallet_rounded,
          'Thix ${l10n.t('svc_money')}', ThixPolicy.gold,
          badge: counts.money, suspended: true),
      _MoreItem('thixSante', Icons.local_hospital_rounded,
          'Thix ${l10n.t('svc_health')}', ThixPolicy.danger,
          badge: counts.health, suspended: true),
    ];

    return Container(
      constraints: BoxConstraints(maxHeight: h * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: HomeTheme.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                hubTr(l10n, 'home_all_services', 'Tous les services'),
                style: const TextStyle(
                  color: HomeTheme.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      const gap = 12.0;
                      final w = (c.maxWidth - gap * 2) / 3;
                      return Wrap(
                        spacing: gap,
                        runSpacing: 16,
                        children: [
                          for (final it in items)
                            SizedBox(
                              width: w,
                              child: _MoreTile(
                                item: it,
                                onTap: () => onAction(it.key),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const HomePremiumCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final _MoreItem item;
  final VoidCallback onTap;
  const _MoreTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = item.color;
    final badgeText = item.badge > 99 ? '99+' : '${item.badge}';

    return Semantics(
      button: true,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: item.suspended ? 0.55 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: _kCircle,
                    height: _kCircle,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.withOpacity(0.10),
                      border: Border.all(color: c.withOpacity(0.25), width: 1.2),
                    ),
                    alignment: Alignment.center,
                    child: item.customLogo
                        ? ThixWedLogo(color: c, size: 28, stroke: 6)
                        : Icon(item.icon, size: _kIcon, color: c),
                  ),
                  if (item.badge > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1.5),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        decoration: BoxDecoration(
                          color: HomeTheme.alert,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.4),
                        ),
                        child: Text(
                          badgeText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomeTheme.ink,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

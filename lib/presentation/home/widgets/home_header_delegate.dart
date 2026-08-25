// lib/presentation/home/widgets/home_header_delegate.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/nav.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/widgets/language_sheet.dart';
import 'package:thix_id/l10n/locale_controller.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double safeTop;
  final String displayName;
  final String? photoUrl;
  final bool isAuthenticated;
  final Stream<SectionBadgeCounts> badgeCountsStream;
  final VoidCallback onProfileTap;
  final VoidCallback onAccountRequest;

  HomeHeaderDelegate({
    required this.safeTop,
    required this.displayName,
    required this.photoUrl,
    required this.isAuthenticated,
    required this.badgeCountsStream,
    required this.onProfileTap,
    required this.onAccountRequest,
  });

  double _headerExtent() => safeTop + 58; // Réduit (était 72)

  @override
  double get maxExtent => _headerExtent();

  @override
  double get minExtent => _headerExtent();

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // 🌟 EN-TÊTE CLEAN ENTERPRISE
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: overlapsContent ? 15 : 0, sigmaY: overlapsContent ? 15 : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            // Fond blanc ultra clair au scroll, totalement transparent sinon
            color: overlapsContent ? Colors.white.withOpacity(0.9) : Colors.transparent,
            border: overlapsContent ? const Border(bottom: BorderSide(color: ThixPolicy.border, width: 1.0)) : null,
            boxShadow: overlapsContent ? ThixPolicy.shadowSoft() : null,
          ),
          child: _PremiumHeader(
            safeTop: safeTop,
            displayName: displayName,
            isAuthenticated: isAuthenticated,
            badgeCountsStream: badgeCountsStream,
            onProfileTap: onProfileTap,
            onAccountRequest: onAccountRequest,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant HomeHeaderDelegate oldDelegate) {
    return safeTop != oldDelegate.safeTop ||
        displayName != oldDelegate.displayName ||
        photoUrl != oldDelegate.photoUrl ||
        isAuthenticated != oldDelegate.isAuthenticated;
  }
}

class _PremiumHeader extends StatelessWidget {
  final double safeTop;
  final String displayName;
  final bool isAuthenticated;
  final Stream<SectionBadgeCounts> badgeCountsStream;
  final VoidCallback onProfileTap;
  final VoidCallback onAccountRequest;

  const _PremiumHeader({
    required this.safeTop,
    required this.displayName,
    required this.isAuthenticated,
    required this.badgeCountsStream,
    required this.onProfileTap,
    required this.onAccountRequest,
  });

  @override
  Widget build(BuildContext context) {
    final localeCode = context.select<LocaleController, String>((c) => c.locale.languageCode);

    return Padding(
      padding: EdgeInsets.fromLTRB(ThixPolicy.s16, safeTop + 8, ThixPolicy.s16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _RotatingGreeting(),
                const SizedBox(height: 1), // Léger espace pour respirer
                // ── Nom + badge certification ──
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: ThixPolicy.textMain, // Slate 900
                          fontSize: 15.5, // Réduit (était 18)
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Badge visible seulement si connecté
                    if (isAuthenticated)
                      const CertificationNameBadge(
                        iconSize: 14,
                        padding: EdgeInsets.only(left: 5),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              // 🌟 BOUTON LANGUE (Design Clean & Lumineux)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const LanguageSheet(),
                  );
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white, // Blanc pur
                    shape: BoxShape.circle,
                    border: Border.all(color: ThixPolicy.border, width: 1.0),
                    boxShadow: ThixPolicy.shadowSoft(), // Ombre douce
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.language_rounded, size: 16, color: ThixPolicy.textMain), // Slate 900
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: ThixPolicy.primaryDeep,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.white, width: 1.2),
                            boxShadow: [BoxShadow(color: ThixPolicy.primaryDeep.withOpacity(0.3), blurRadius: 2, offset: const Offset(0, 1))],
                          ),
                          child: Text(
                            localeCode.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 🌟 BOUTON NOTIFICATIONS (Design Clean & Lumineux)
              StreamBuilder<SectionBadgeCounts>(
                stream: badgeCountsStream,
                builder: (context, snap) {
                  final c = snap.data ?? SectionBadgeCounts.zero;
                  final total = c.messages + c.opportunities + c.jobs + c.events + c.formations +
                      c.info + c.market + c.media + c.network + c.health + c.money + c.monPays + c.reservation;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (isAuthenticated) {
                        NotificationsSheet.show(context);
                      } else {
                        context.push(AppRoutes.login);
                      }
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white, // Blanc pur
                        shape: BoxShape.circle,
                        border: Border.all(color: ThixPolicy.border, width: 1.0),
                        boxShadow: ThixPolicy.shadowSoft(), // Ombre douce
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_none_rounded, size: 18, color: ThixPolicy.textMain), // Slate 900
                          if (total > 0)
                            Positioned(
                              right: -3,
                              top: -3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                                decoration: BoxDecoration(
                                  color: ThixPolicy.danger,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                  boxShadow: [BoxShadow(color: ThixPolicy.danger.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                                ),
                                child: Text(
                                  total > 9 ? '9+' : '$total',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RotatingGreeting extends StatefulWidget {
  const _RotatingGreeting();
  @override
  State<_RotatingGreeting> createState() => _RotatingGreetingState();
}

class _RotatingGreetingState extends State<_RotatingGreeting> {
  static const List<Map<String, String>> _greetings = [
    {'lang': 'Lingala', 'text': 'Mbote'},
    {'lang': 'Kiswahili', 'text': 'Jambo'},
    {'lang': 'Tshiluba', 'text': 'Moyo'},
    {'lang': 'Kikongo', 'text': 'Mbote'},
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _greetings.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = _greetings[_index];
    return SizedBox(
      height: 17,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: Row(
          key: ValueKey(g['lang']),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              g['text']!,
              style: const TextStyle(
                color: ThixPolicy.textSecondary, // Slate 500
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: ThixPolicy.tint, // Bleu très léger (Blue 50)
                border: Border.all(color: ThixPolicy.primary.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                g['lang']!,
                style: const TextStyle(
                  color: ThixPolicy.primary, // Blue 600
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

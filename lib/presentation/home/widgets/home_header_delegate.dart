// lib/presentation/home/widgets/home_header_delegate.dart
import 'dart:async';
import 'dart:ui'; // ✅ NÉCESSAIRE POUR LE GLASSMORPHISM
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

  double _headerExtent() => safeTop + 72; // Hauteur ajustée pour plus d'élégance

  @override
  double get maxExtent => _headerExtent();

  @override
  double get minExtent => _headerExtent();

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // 🌟 EFFET GLASSMORPHISM SUR LE HEADER AU SCROLL
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: overlapsContent ? 20 : 0, sigmaY: overlapsContent ? 20 : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: overlapsContent ? Colors.white.withValues(alpha: 0.7) : Colors.transparent,
            border: overlapsContent ? Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1.2)) : null,
            boxShadow: overlapsContent
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
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
      padding: EdgeInsets.fromLTRB(ThixPolicy.s20, safeTop + 12, ThixPolicy.s20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _RotatingGreeting(),
                // ── Nom + badge certification ──
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: ThixPolicy.textMain,
                          fontSize: 16, // Légèrement plus grand
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Badge visible seulement si connecté
                    if (isAuthenticated)
                      const CertificationNameBadge(
                        iconSize: 14,
                        padding: EdgeInsets.only(left: 6),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              // 🌟 BOUTON LANGUE (Glassmorphism)
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.65), // Verre dépoli
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.language_rounded, size: 20, color: ThixPolicy.primaryDeep),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: ThixPolicy.primaryDeep,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white, width: 1.2),
                            boxShadow: [BoxShadow(color: ThixPolicy.primaryDeep.withValues(alpha: 0.3), blurRadius: 2, offset: const Offset(0, 1))],
                          ),
                          child: Text(
                            localeCode.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 🌟 BOUTON NOTIFICATIONS (Glassmorphism)
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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65), // Verre dépoli
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_none_rounded, size: 22, color: ThixPolicy.primaryDeep),
                          if (total > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ThixPolicy.danger,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                  boxShadow: [BoxShadow(color: ThixPolicy.danger.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
                                ),
                                child: Text(
                                  total > 9 ? '9+' : '$total',
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
      height: 18,
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
              style: TextStyle(
                color: ThixPolicy.textSecondary.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                g['lang']!,
                style: const TextStyle(
                  color: ThixPolicy.primaryDeep,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

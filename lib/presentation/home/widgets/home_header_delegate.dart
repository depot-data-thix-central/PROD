// lib/presentation/home/widgets/home_header_delegate.dart
import 'dart:async';
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

  double _headerExtent() => safeTop + 92;

  @override
  double get maxExtent => _headerExtent();

  @override
  double get minExtent => _headerExtent();

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.surface,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: ThixPolicy.inkDeep.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                )
              ]
            : null,
      ),
      child: _PremiumHeader(
        safeTop: safeTop,
        displayName: displayName,
        photoUrl: photoUrl,
        isAuthenticated: isAuthenticated,
        badgeCountsStream: badgeCountsStream,
        onProfileTap: onProfileTap,
        onAccountRequest: onAccountRequest,
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
  final String? photoUrl;
  final bool isAuthenticated;
  final Stream<SectionBadgeCounts> badgeCountsStream;
  final VoidCallback onProfileTap;
  final VoidCallback onAccountRequest;

  const _PremiumHeader({
    required this.safeTop,
    required this.displayName,
    required this.photoUrl,
    required this.isAuthenticated,
    required this.badgeCountsStream,
    required this.onProfileTap,
    required this.onAccountRequest,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedPhoto = (photoUrl ?? '').trim();
    final localeCode =
        context.select<LocaleController, String>((c) => c.locale.languageCode);

    return Padding(
      padding:
          EdgeInsets.fromLTRB(ThixPolicy.s20, safeTop + 10, ThixPolicy.s20, 10),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Badge visible seulement si connecté
                    if (isAuthenticated)
                      const CertificationNameBadge(
                        iconSize: 12,
                        padding: EdgeInsets.only(left: 6),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              // LANGUE
              Material(
                color: ThixPolicy.card,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ThixPolicy.card,
                      border: Border.all(color: ThixPolicy.border),
                      boxShadow: ThixPolicy.shadowSoft(),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.language_rounded,
                            size: 20, color: ThixPolicy.primaryDeep),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: ThixPolicy.primaryDeep,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Text(
                              localeCode.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // NOTIFICATIONS
              StreamBuilder<SectionBadgeCounts>(
                stream: badgeCountsStream,
                builder: (context, snap) {
                  final c = snap.data ?? SectionBadgeCounts.zero;
                  final total = c.messages +
                      c.opportunities +
                      c.jobs +
                      c.events +
                      c.formations +
                      c.info +
                      c.market +
                      c.media +
                      c.network +
                      c.health +
                      c.money +
                      c.monPays +
                      c.reservation;

                  return Material(
                    color: ThixPolicy.card,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (isAuthenticated) {
                          NotificationsSheet.show(context);
                        } else {
                          context.push(AppRoutes.login);
                        }
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ThixPolicy.card,
                          border: Border.all(color: ThixPolicy.border),
                          boxShadow: ThixPolicy.shadowSoft(),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_none_rounded,
                                size: 20, color: ThixPolicy.primaryDeep),
                            if (total > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ThixPolicy.danger,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.white, width: 1.2),
                                  ),
                                  child: Text(
                                    total > 9 ? '9+' : '$total',
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
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),

              // AVATAR
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ThixPolicy.card,
                    border: Border.all(color: ThixPolicy.primary, width: 2),
                    boxShadow: ThixPolicy.shadowSoft(),
                  ),
                  child: ClipOval(
                    child: trimmedPhoto.isNotEmpty
                        ? Image.network(
                            trimmedPhoto,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: ThixPolicy.surface,
                              child: const Icon(Icons.person_rounded),
                            ),
                          )
                        : Container(
                            color: ThixPolicy.tint,
                            child: const Icon(Icons.person_rounded,
                                color: ThixPolicy.primary),
                          ),
                  ),
                ),
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
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
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
      height: 15,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
                .animate(anim),
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
                color: ThixPolicy.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: ThixPolicy.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                g['lang']!,
                style: const TextStyle(
                  color: ThixPolicy.primaryDeep,
                  fontSize: 8,
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

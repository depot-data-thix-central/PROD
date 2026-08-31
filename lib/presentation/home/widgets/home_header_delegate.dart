// lib/presentation/home/widgets/home_header_delegate.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/nav.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/widgets/language_sheet.dart';
import 'package:thix_id/l10n/locale_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kHeaderHeight = 58.0;
const int _kMaxDisplayNameLength = 30;
const int _kMaxBadgeDisplay = 9;
const int _kGreetingRotationSeconds = 4;

// ============================================================================
// VALIDATORS
// ============================================================================
class _HeaderValidators {
  _HeaderValidators._();

  static String sanitizeDisplayName(String? input) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > _kMaxDisplayNameLength
        ? s.substring(0, _kMaxDisplayNameLength)
        : s;
  }

  static String formatBadgeCount(int total) {
    if (total <= 0) return '';
    return total > _kMaxBadgeDisplay ? '$_kMaxBadgeDisplay+' : '$total';
  }
}

// ============================================================================
// HELPERS
// ============================================================================
int _calculateTotalNotifications(SectionBadgeCounts c) {
  return c.messages +
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
}

// ============================================================================
// MAIN DELEGATE
// ============================================================================
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

  double _headerExtent() => safeTop + _kHeaderHeight;

  @override
  double get maxExtent => _headerExtent();

  @override
  double get minExtent => _headerExtent();

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    debugPrint('[HomeHeader] 🔧 Build (overlaps=$overlapsContent)');

    // Container solide (pas de BackdropFilter = 10x plus rapide)
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: overlapsContent ? ThixPolicy.card.withOpacity(0.95) : Colors.transparent,
          border: overlapsContent
              ? Border(bottom: BorderSide(color: ThixPolicy.border, width: 1.0))
              : null,
          boxShadow: overlapsContent ? ThixPolicy.shadowSoft() : null,
        ),
        child: _PremiumHeader(
          safeTop: safeTop,
          displayName: _HeaderValidators.sanitizeDisplayName(displayName),
          isAuthenticated: isAuthenticated,
          badgeCountsStream: badgeCountsStream,
          onProfileTap: onProfileTap,
          onAccountRequest: onAccountRequest,
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

// ============================================================================
// PREMIUM HEADER
// ============================================================================
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
          // Section gauche : Salutation + Nom
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _RotatingGreeting(),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName.isEmpty ? '—' : displayName,
                        style: ThixPolicy.labelStyle.copyWith(
                          color: ThixPolicy.textMain,
                          fontSize: 13,
                          fontWeight: ThixPolicy.bold,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAuthenticated)
                      const CertificationNameBadge(
                        iconSize: 12,
                        padding: EdgeInsets.only(left: 4),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Section droite : Boutons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LanguageButton(
                localeCode: localeCode,
                onTap: () => _openLanguageSheet(context),
              ),
              const SizedBox(width: 8),
              _NotificationsButton(
                badgeCountsStream: badgeCountsStream,
                isAuthenticated: isAuthenticated,
                onTap: () => _handleNotificationsTap(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openLanguageSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    debugPrint('[HomeHeader] 🌐 Language sheet opened');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LanguageSheet(),
    );
  }

  void _handleNotificationsTap(BuildContext context) {
    HapticFeedback.lightImpact();
    if (isAuthenticated) {
      debugPrint('[HomeHeader] 🔔 Notifications opened');
      NotificationsSheet.show(context);
    } else {
      debugPrint('[HomeHeader] 🔓 Redirect to login');
      context.push(AppRoutes.login);
    }
  }
}

// ============================================================================
// LANGUAGE BUTTON
// ============================================================================
class _LanguageButton extends StatelessWidget {
  final String localeCode;
  final VoidCallback onTap;

  const _LanguageButton({
    required this.localeCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: '${l10n.t('header_language_button')}: ${localeCode.toUpperCase()}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            shape: BoxShape.circle,
            border: Border.all(color: ThixPolicy.border, width: 1.0),
            boxShadow: ThixPolicy.shadowSoft(),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.language_rounded, size: 16, color: ThixPolicy.textMain),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: ThixPolicy.primaryDeep,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: ThixPolicy.primaryDeep.withOpacity(0.3),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    localeCode.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 6.5,
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
  }
}

// ============================================================================
// NOTIFICATIONS BUTTON
// ============================================================================
class _NotificationsButton extends StatelessWidget {
  final Stream<SectionBadgeCounts> badgeCountsStream;
  final bool isAuthenticated;
  final VoidCallback onTap;

  const _NotificationsButton({
    required this.badgeCountsStream,
    required this.isAuthenticated,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<SectionBadgeCounts>(
      stream: badgeCountsStream,
      builder: (context, snap) {
        final counts = snap.data ?? SectionBadgeCounts.zero;
        final total = _calculateTotalNotifications(counts);
        final badgeText = _HeaderValidators.formatBadgeCount(total);

        return Semantics(
          button: true,
          label: total > 0
              ? '${l10n.t('header_notifications_button')}, $total ${l10n.t('header_notifications_unread')}'
              : l10n.t('header_notifications_button'),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.border, width: 1.0),
                boxShadow: ThixPolicy.shadowSoft(),
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    size: 18,
                    color: ThixPolicy.textMain,
                  ),
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
                          boxShadow: [
                            BoxShadow(
                              color: ThixPolicy.danger.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// ROTATING GREETING
// ============================================================================
class _RotatingGreeting extends StatefulWidget {
  const _RotatingGreeting();

  @override
  State<_RotatingGreeting> createState() => _RotatingGreetingState();
}

class _RotatingGreetingState extends State<_RotatingGreeting>
    with WidgetsBindingObserver {
  static const List<Map<String, String>> _greetings = [
    {'lang': 'Lingala', 'text': 'Mbote'},
    {'lang': 'Kiswahili', 'text': 'Jambo'},
    {'lang': 'Tshiluba', 'text': 'Moyo'},
    {'lang': 'Kikongo', 'text': 'Mbote'},
  ];

  int _index = 0;
  Timer? _timer;
  bool _isAppVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppVisible = state == AppLifecycleState.resumed;
    if (_isAppVisible) {
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: _kGreetingRotationSeconds),
      (_) {
        if (!mounted || !_isAppVisible) return;
        setState(() => _index = (_index + 1) % _greetings.length);
      },
    );
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
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: Row(
          key: ValueKey(g['lang']),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              g['text']!,
              style: ThixPolicy.captionStyle.copyWith(
                color: ThixPolicy.textSecondary,
                fontSize: 11,
                fontWeight: ThixPolicy.bold,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: ThixPolicy.tint,
                border: Border.all(color: ThixPolicy.primary.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                g['lang']!,
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.primary,
                  fontSize: 8,
                  fontWeight: ThixPolicy.bold,
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

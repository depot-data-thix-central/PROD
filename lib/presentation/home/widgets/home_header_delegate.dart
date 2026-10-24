// lib/presentation/home/widgets/home_header_delegate.dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/widgets/language_sheet.dart';
import 'package:thix_id/l10n/locale_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'home_theme.dart';

const double _kHeaderHeight = 58.0;
const int _kMaxDisplayNameLength = 30;
const int _kMaxBadgeDisplay = 9;
const int _kGreetingRotationSeconds = 4;

class _HeaderValidators {
  _HeaderValidators._();

  static String sanitizeDisplayName(String? input) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    return s.length > _kMaxDisplayNameLength ? s.substring(0, _kMaxDisplayNameLength) : s;
  }

  static String formatBadgeCount(int total) {
    if (total <= 0) return '';
    return total > _kMaxBadgeDisplay ? '$_kMaxBadgeDisplay+' : '$total';
  }
}

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
    final content = _PremiumHeader(
      safeTop: safeTop,
      displayName: _HeaderValidators.sanitizeDisplayName(displayName),
      isAuthenticated: isAuthenticated,
      badgeCountsStream: badgeCountsStream,
      onProfileTap: onProfileTap,
      onAccountRequest: onAccountRequest,
    );

    // Transparent au repos ; verre dépoli seulement quand il recouvre le contenu.
    if (!overlapsContent) return RepaintBoundary(child: content);

    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              border: Border(bottom: BorderSide(color: HomeTheme.line.withOpacity(0.9))),
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant HomeHeaderDelegate old) {
    return safeTop != old.safeTop ||
        displayName != old.displayName ||
        photoUrl != old.photoUrl ||
        isAuthenticated != old.isAuthenticated;
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
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName.isEmpty ? '—' : displayName,
                        style: ThixPolicy.labelStyle.copyWith(
                          color: HomeTheme.ink,
                          fontSize: 14,
                          fontWeight: ThixPolicy.bold,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAuthenticated)
                      const CertificationNameBadge(iconSize: 12, padding: EdgeInsets.only(left: 4)),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LanguageButton(localeCode: localeCode, onTap: () => _openLanguageSheet(context)),
              const SizedBox(width: 10),
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
      NotificationsSheet.show(context);
    } else {
      context.push(AppRoutes.login);
    }
  }
}

BoxDecoration _circleDeco() => BoxDecoration(
      color: Colors.white.withOpacity(0.85),
      shape: BoxShape.circle,
      border: Border.all(color: HomeTheme.line, width: 1.0),
      boxShadow: HomeTheme.softShadow(0.07),
    );

class _LanguageButton extends StatelessWidget {
  final String localeCode;
  final VoidCallback onTap;
  const _LanguageButton({required this.localeCode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: '${l10n.t('header_language_button')}: ${localeCode.toUpperCase()}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: _circleDeco(),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.language_rounded, size: 17, color: HomeTheme.ink),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: HomeTheme.skyDeep,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white, width: 1.2),
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
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  final Stream<SectionBadgeCounts> badgeCountsStream;
  final bool isAuthenticated;
  final VoidCallback onTap;
  const _NotificationsButton({required this.badgeCountsStream, required this.isAuthenticated, required this.onTap});

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
              width: 36,
              height: 36,
              decoration: _circleDeco(),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 19, color: HomeTheme.ink),
                  if (total > 0)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        decoration: BoxDecoration(
                          color: HomeTheme.alert,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badgeText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
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

class _RotatingGreeting extends StatefulWidget {
  const _RotatingGreeting();
  @override
  State<_RotatingGreeting> createState() => _RotatingGreetingState();
}

class _RotatingGreetingState extends State<_RotatingGreeting> with WidgetsBindingObserver {
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
    _timer = Timer.periodic(const Duration(seconds: _kGreetingRotationSeconds), (_) {
      if (!mounted || !_isAppVisible) return;
      setState(() => _index = (_index + 1) % _greetings.length);
    });
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
              style: ThixPolicy.captionStyle.copyWith(color: HomeTheme.inkSoft, fontSize: 11, fontWeight: ThixPolicy.bold),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: HomeTheme.skySoft,
                border: Border.all(color: HomeTheme.sky.withOpacity(0.25)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                g['lang']!,
                style: ThixPolicy.microStyle.copyWith(
                  color: HomeTheme.skyDeep,
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

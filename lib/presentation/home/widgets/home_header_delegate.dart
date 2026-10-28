// lib/presentation/home/widgets/home_header_delegate.dart
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
import 'package:thix_id/services/app_update_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'app_update_sheet.dart';
import 'home_theme.dart';

const double _kHeaderHeight = 58.0;
const int _kMaxDisplayNameLength = 30;
const int _kMaxBadgeDisplay = 9;
const int _kMaxSearchLength = 100;

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

// ============================================================================
// DELEGATE
// ============================================================================
class HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double safeTop;
  final String displayName;
  final String? photoUrl;
  final bool isAuthenticated;
  final Stream<SectionBadgeCounts> badgeCountsStream;
  final VoidCallback onProfileTap;
  final VoidCallback onAccountRequest;

  // Recherche rétractable dans le header
  final TextEditingController? searchController;
  final bool isSearching;
  final VoidCallback? onVerify;

  HomeHeaderDelegate({
    required this.safeTop,
    required this.displayName,
    required this.photoUrl,
    required this.isAuthenticated,
    required this.badgeCountsStream,
    required this.onProfileTap,
    required this.onAccountRequest,
    this.searchController,
    this.isSearching = false,
    this.onVerify,
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
      searchController: searchController,
      isSearching: isSearching,
      onVerify: onVerify,
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
        isAuthenticated != old.isAuthenticated ||
        searchController != old.searchController ||
        isSearching != old.isSearching ||
        onVerify != old.onVerify;
  }
}

// ============================================================================
// HEADER PREMIUM (recherche rétractable + indicateur de mise à jour)
// ============================================================================
class _PremiumHeader extends StatefulWidget {
  final double safeTop;
  final String displayName;
  final bool isAuthenticated;
  final Stream<SectionBadgeCounts> badgeCountsStream;
  final VoidCallback onProfileTap;
  final VoidCallback onAccountRequest;
  final TextEditingController? searchController;
  final bool isSearching;
  final VoidCallback? onVerify;

  const _PremiumHeader({
    required this.safeTop,
    required this.displayName,
    required this.isAuthenticated,
    required this.badgeCountsStream,
    required this.onProfileTap,
    required this.onAccountRequest,
    this.searchController,
    this.isSearching = false,
    this.onVerify,
  });

  @override
  State<_PremiumHeader> createState() => _PremiumHeaderState();
}

class _PremiumHeaderState extends State<_PremiumHeader> {
  final FocusNode _searchFocus = FocusNode();
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initUpdateCheck());
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  // ── MISE À JOUR : détection + panneau (max 1 fois / 24 h) ──
  Future<void> _initUpdateCheck() async {
    final svc = AppUpdateService.instance;
    await svc.checkForUpdate();
    if (!mounted || !svc.updateAvailable.value) return;
    if (!await svc.shouldPromptNow()) return;
    if (!mounted) return;
    await AppUpdateSheet.show(context);
  }

  void _openUpdateSheet() {
    HapticFeedback.selectionClick();
    AppUpdateSheet.show(context);
  }

  void _openSearch() {
    HapticFeedback.selectionClick();
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    HapticFeedback.selectionClick();
    _searchFocus.unfocus();
    if (mounted) setState(() => _searchOpen = false);
  }

  void _submit(String value) {
    if (!mounted || widget.isSearching || value.trim().isEmpty) return;
    widget.onVerify?.call();
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = context.select<LocaleController, String>((c) => c.locale.languageCode);
    final canSearch = widget.searchController != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(ThixPolicy.s16, widget.safeTop + 8, ThixPolicy.s16, 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: (_searchOpen && canSearch) ? _buildSearchRow() : _buildIdleRow(localeCode, canSearch),
      ),
    );
  }

  // ── ÉTAT REPLIÉ : [Update · Mettre à jour] + nom + [🔍] [🌐] [🔔] ──────
  Widget _buildIdleRow(String localeCode, bool canSearch) {
    return Row(
      key: const ValueKey('header_idle'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _UpdateHint(onTap: _openUpdateSheet),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.displayName.isEmpty ? '—' : widget.displayName,
                      style: ThixPolicy.labelStyle.copyWith(
                        color: HomeTheme.ink,
                        fontSize: 14,
                        fontWeight: ThixPolicy.bold,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isAuthenticated)
                    const CertificationNameBadge(iconSize: 12, padding: EdgeInsets.only(left: 4)),
                ],
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canSearch) ...[
              _HeaderIconButton(
                icon: Icons.search_rounded,
                semantics: 'Rechercher',
                onTap: _openSearch,
              ),
              const SizedBox(width: 8),
            ],
            _LanguageButton(localeCode: localeCode, onTap: () => _openLanguageSheet(context)),
            const SizedBox(width: 8),
            _NotificationsButton(
              badgeCountsStream: widget.badgeCountsStream,
              isAuthenticated: widget.isAuthenticated,
              onTap: () => _handleNotificationsTap(context),
            ),
          ],
        ),
      ],
    );
  }

  // ── ÉTAT DÉPLOYÉ : [←] [ champ ] [✔] ─────────────────────────────────────
  Widget _buildSearchRow() {
    final l10n = AppLocalizations.of(context);
    return Row(
      key: const ValueKey('header_search'),
      children: [
        _HeaderIconButton(
          icon: Icons.arrow_back_rounded,
          semantics: l10n.t('common_close'),
          onTap: _closeSearch,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.94),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: HomeTheme.sky.withOpacity(0.55), width: 1.2),
              boxShadow: HomeTheme.softShadow(0.10),
            ),
            child: TextField(
              controller: widget.searchController,
              focusNode: _searchFocus,
              enabled: !widget.isSearching,
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              maxLength: _kMaxSearchLength,
              style: ThixPolicy.labelStyle.copyWith(
                color: HomeTheme.ink,
                fontSize: 13,
                fontWeight: ThixPolicy.semiBold,
                letterSpacing: 0.3,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                counterText: '',
                hintText: l10n.t('home_search_hint'),
                hintStyle: ThixPolicy.captionStyle.copyWith(
                  color: HomeTheme.inkSoft.withOpacity(0.8),
                  fontSize: 12,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _HeaderVerifyButton(
          semanticsLabel: l10n.t('home_verify_id'),
          isLoading: widget.isSearching,
          onTap: () {
            if (!widget.isSearching) widget.onVerify?.call();
          },
        ),
      ],
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
    if (widget.isAuthenticated) {
      NotificationsSheet.show(context);
    } else {
      context.push(AppRoutes.login);
    }
  }
}

// ============================================================================
// INDICATEUR "UPDATE · METTRE À JOUR" (remplace les salutations)
// ============================================================================
class _UpdateHint extends StatelessWidget {
  final VoidCallback onTap;
  const _UpdateHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppUpdateService.instance.updateAvailable,
      builder: (context, available, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SizeTransition(sizeFactor: anim, axisAlignment: -1, child: child),
          ),
          child: available
              ? Semantics(
                  key: const ValueKey('update_hint'),
                  button: true,
                  label: 'Mettre à jour',
                  child: GestureDetector(
                    onTap: onTap,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: 17,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: HomeTheme.skySoft,
                              border: Border.all(color: HomeTheme.sky.withOpacity(0.25)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Update',
                              style: ThixPolicy.microStyle.copyWith(
                                color: HomeTheme.skyDeep,
                                fontSize: 8,
                                fontWeight: ThixPolicy.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Mettre à jour',
                            style: ThixPolicy.captionStyle.copyWith(
                              color: HomeTheme.skyDeep,
                              fontSize: 11,
                              fontWeight: ThixPolicy.bold,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right_rounded, size: 14, color: HomeTheme.skyDeep),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('no_update')),
        );
      },
    );
  }
}

// ============================================================================
// BOUTONS RONDS DU HEADER
// ============================================================================
BoxDecoration _circleDeco() => BoxDecoration(
      color: Colors.white.withOpacity(0.85),
      shape: BoxShape.circle,
      border: Border.all(color: HomeTheme.line, width: 1.0),
      boxShadow: HomeTheme.softShadow(0.07),
    );

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String semantics;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.semantics, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: _circleDeco(),
          child: Icon(icon, size: 18, color: HomeTheme.ink),
        ),
      ),
    );
  }
}

class _HeaderVerifyButton extends StatelessWidget {
  final String semanticsLabel;
  final bool isLoading;
  final VoidCallback onTap;
  const _HeaderVerifyButton({required this.semanticsLabel, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      enabled: !isLoading,
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [HomeTheme.sky, HomeTheme.skyDeep],
            ),
            boxShadow: [BoxShadow(color: HomeTheme.skyDeep.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.person_search_rounded, color: Colors.white, size: 17),
        ),
      ),
    );
  }
}

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
      initialData: SectionBadgeCounts.zero,
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

/// THIX SOS — Mes secours / 3 cercles (Production Enterprise)
/// ✅ SÉCURISÉ : validation URL, mounted checks, throttling, i18n, semantics
/// ✅ DESIGN : ThixPolicy, animations, skeleton, empty state premium
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../models/sos_models.dart';
import '../providers/sos_providers.dart';
import 'ajouter_secours_page.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kOperationThrottle = Duration(seconds: 2);

// ============================================================================
// VALIDATORS
// ============================================================================
class _SecoursValidators {
  _SecoursValidators._();

  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static String safeInitial(String? name, {String fallback = '?'}) {
    if (name == null || name.trim().isEmpty) return fallback;
    return name.trim()[0].toUpperCase();
  }
}

// ============================================================================
// PAGE
// ============================================================================
class MesSecoursPage extends ConsumerStatefulWidget {
  const MesSecoursPage({super.key});

  @override
  ConsumerState<MesSecoursPage> createState() => _MesSecoursPageState();
}

class _MesSecoursPageState extends ConsumerState<MesSecoursPage> {
  DateTime? _lastOperation;
  final Set<String> _pendingDeletes = {};

  Future<bool> _throttleOperation() async {
    if (!mounted) return false;
    final now = DateTime.now();
    if (_lastOperation != null &&
        now.difference(_lastOperation!) < _kOperationThrottle) {
      debugPrint('[MesSecours] ⚠️ Operation throttled');
      return false;
    }
    _lastOperation = now;
    return true;
  }

  Future<void> _refresh() async {
    if (!await _throttleOperation()) return;
    HapticFeedback.lightImpact();
    debugPrint('[MesSecours] 🔄 Refreshing contacts');
    ref.invalidate(sosContactsProvider);
  }

  Future<void> _navigateToAdd(BuildContext context, {int? circle}) async {
    if (!await _throttleOperation()) return;
    HapticFeedback.mediumImpact();
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AjouterSecoursPage(initialCircle: circle),
      ),
    );
    if (ok == true && mounted) {
      ref.invalidate(sosContactsProvider);
    }
  }

  Future<void> _confirmDelete(BuildContext context, SosContact contact) async {
    if (!await _throttleOperation()) return;
    if (_pendingDeletes.contains(contact.id)) return;

    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          side: BorderSide(color: ThixPolicy.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(ThixPolicy.rXs),
              ),
              child: const Icon(Icons.delete_outline,
                  color: ThixPolicy.danger, size: 20),
            ),
            const SizedBox(width: ThixPolicy.s12),
            Expanded(
              child: Text(
                l10n.t('sos_delete_rescuer'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.t('sos_delete_rescuer_confirm'),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: ThixPolicy.textMuted,
            height: 1.4,
          ),
        ),
        actions: [
          Semantics(
            button: true,
            label: l10n.t('common_cancel'),
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                l10n.t('common_cancel'),
                style: GoogleFonts.inter(color: ThixPolicy.textMuted),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: l10n.t('common_delete'),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                l10n.t('common_delete'),
                style: GoogleFonts.inter(
                  color: ThixPolicy.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _pendingDeletes.add(contact.id));
      try {
        await ref.read(sosContactActionsProvider).delete(contact.id);
        if (mounted) {
          ref.invalidate(sosContactsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.t('sos_rescuer_deleted')),
              backgroundColor: ThixPolicy.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('[MesSecours] ❌ Delete error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.t('sos_delete_error')),
              backgroundColor: ThixPolicy.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _pendingDeletes.remove(contact.id));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final contactsAsync = ref.watch(sosContactsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      appBar: AppBar(
        backgroundColor: ThixPolicy.inkDeep,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 20, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          l10n.t('sos_my_rescuers'),
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          Semantics(
            button: true,
            label: l10n.t('common_refresh'),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54),
              onPressed: _refresh,
            ),
          ),
        ],
      ),
      floatingActionButton: Semantics(
        button: true,
        label: l10n.t('sos_add_rescuer'),
        child: FloatingActionButton.extended(
          backgroundColor: ThixPolicy.danger,
          onPressed: () => _navigateToAdd(context),
          icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
          label: Text(
            l10n.t('common_add'),
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
      body: contactsAsync.when(
        loading: () => const _SkeletonLoader(),
        error: (e, stack) {
          debugPrint('[MesSecours] ❌ Load error: $e');
          debugPrint('[MesSecours] Stack: $stack');
          return _ErrorState(
            message: l10n.t('sos_load_error'),
            onRetry: _refresh,
          );
        },
        data: (contacts) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              ThixPolicy.s16,
              ThixPolicy.s8,
              ThixPolicy.s16,
              100,
            ),
            children: [
              _InfoBanner(l10n: l10n),
              const SizedBox(height: ThixPolicy.s20),
              for (final circle in [1, 2, 3]) ...[
                _CircleSection(
                  circle: circle,
                  contacts:
                      contacts.where((c) => c.circle == circle).toList(),
                  onAdd: () => _navigateToAdd(context, circle: circle),
                  onDelete: (contact) => _confirmDelete(context, contact),
                  pendingDeletes: _pendingDeletes,
                ),
                const SizedBox(height: ThixPolicy.s24),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// INFO BANNER
// ============================================================================
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThixPolicy.primary.withValues(alpha: 0.25),
            ThixPolicy.primary.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(
            color: ThixPolicy.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ThixPolicy.primary.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ThixPolicy.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info_outline,
                color: ThixPolicy.primary, size: 18),
          ),
          const SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('sos_circle_priority_title'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.t('sos_circle_priority_info'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: ThixPolicy.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CIRCLE SECTION
// ============================================================================
class _CircleSection extends StatelessWidget {
  const _CircleSection({
    required this.circle,
    required this.contacts,
    required this.onAdd,
    required this.onDelete,
    required this.pendingDeletes,
  });

  final int circle;
  final List<SosContact> contacts;
  final VoidCallback onAdd;
  final Future<void> Function(SosContact contact) onDelete;
  final Set<String> pendingDeletes;

  Color get _color {
    switch (circle) {
      case 1:
        return ThixPolicy.success;
      case 2:
        return ThixPolicy.warning;
      default:
        return ThixPolicy.primary;
    }
  }

  String _title(AppLocalizations l10n) {
    switch (circle) {
      case 1:
        return l10n.t('sos_circle_1');
      case 2:
        return l10n.t('sos_circle_2');
      default:
        return l10n.t('sos_circle_3');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _color.withValues(alpha: 0.3),
                    _color.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                border: Border.all(color: _color.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Text(
                  '$circle',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: ThixPolicy.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(l10n),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${contacts.length} ${l10n.t('sos_rescuers')}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: ThixPolicy.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: '${l10n.t('common_add')} ${_title(l10n)}',
              child: TextButton.icon(
                onPressed: onAdd,
                icon: Icon(Icons.add_circle_outline, size: 18, color: _color),
                label: Text(
                  l10n.t('common_add'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _color,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: ThixPolicy.s12),
        if (contacts.isEmpty)
          _EmptyCircle(color: _color, l10n: l10n)
        else
          ...contacts.map(
            (c) => _ContactTile(
              contact: c,
              accent: _color,
              onDelete: () => onDelete(c),
              isDeleting: pendingDeletes.contains(c.id),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// CONTACT TILE — ✅ Validation URL + safe initial + semantics
// ============================================================================
class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.accent,
    required this.onDelete,
    required this.isDeleting,
  });

  final SosContact contact;
  final Color accent;
  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final validPhoto = _SecoursValidators.isValidUrl(contact.photoUrl);
    final safeName = contact.name.isNotEmpty ? contact.name : l10n.t('sos_unknown');

    return AnimatedOpacity(
      opacity: isDeleting ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.only(bottom: ThixPolicy.s10),
        child: Semantics(
          button: true,
          label: '${l10n.t('sos_rescuer')} $safeName',
          child: Material(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            child: InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              child: Container(
                padding: const EdgeInsets.all(ThixPolicy.s14),
                decoration: BoxDecoration(
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
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: accent.withValues(alpha: 0.2),
                      backgroundImage:
                          validPhoto ? NetworkImage(contact.photoUrl!) : null,
                      child: !validPhoto
                          ? Text(
                              _SecoursValidators.safeInitial(safeName),
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: ThixPolicy.s14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  safeName,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (contact.verified)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        ThixPolicy.success.withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(ThixPolicy.rXs),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified,
                                          size: 14, color: ThixPolicy.success),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n.t('sos_verified'),
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: ThixPolicy.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (contact.relation != null &&
                              contact.relation!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              contact.relation!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: ThixPolicy.textMuted,
                              ),
                            ),
                          ],
                          if (contact.phone != null &&
                              contact.phone!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.phone,
                                    size: 12, color: ThixPolicy.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  contact.phone!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: ThixPolicy.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: '${l10n.t('common_delete')} $safeName',
                      child: IconButton(
                        icon: isDeleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ThixPolicy.danger,
                                ),
                              )
                            : const Icon(Icons.delete_outline,
                                color: ThixPolicy.textMuted, size: 22),
                        onPressed: isDeleting ? null : onDelete,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY CIRCLE
// ============================================================================
class _EmptyCircle extends StatelessWidget {
  const _EmptyCircle({required this.color, required this.l10n});
  final Color color;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: ThixPolicy.s24, horizontal: ThixPolicy.s16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_add_outlined,
                color: color.withValues(alpha: 0.6), size: 32),
          ),
          const SizedBox(height: ThixPolicy.s12),
          Text(
            l10n.t('sos_no_rescuers_circle'),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.t('sos_add_first_rescuer'),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: ThixPolicy.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SKELETON LOADER
// ============================================================================
class _SkeletonLoader extends StatefulWidget {
  const _SkeletonLoader();

  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double h, [double w = double.infinity]) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.35 + 0.3 * _ctrl.value,
        child: Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: ThixPolicy.border,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          ),
        ),
      ),
    );
  }

  Widget _tile() {
    return Padding(
      padding: const EdgeInsets.only(bottom: ThixPolicy.s10),
      child: Container(
        padding: const EdgeInsets.all(ThixPolicy.s14),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Row(
          children: [
            _box(48, 48),
            const SizedBox(width: ThixPolicy.s14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(16, 120),
                  const SizedBox(height: 8),
                  _box(12, 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(64),
          const SizedBox(height: ThixPolicy.s20),
          _box(20, 140),
          const SizedBox(height: ThixPolicy.s12),
          _tile(),
          _tile(),
          const SizedBox(height: ThixPolicy.s24),
          _box(20, 140),
          const SizedBox(height: ThixPolicy.s12),
          _tile(),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR STATE
// ============================================================================
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThixPolicy.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  color: ThixPolicy.danger, size: 48),
            ),
            const SizedBox(height: ThixPolicy.s16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: ThixPolicy.s20),
            Semantics(
              button: true,
              label: l10n.t('common_retry'),
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onRetry();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.t('common_retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

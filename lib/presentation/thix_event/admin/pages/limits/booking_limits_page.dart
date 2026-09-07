// lib/presentation/thix_event/admin/pages/bookings/booking_limits_page.dart
//
// BookingLimitsPage — Production Enterprise (i18n + Design System + A11y)
//
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── IMPORTS ABSOLUS SÉCURISÉS ──
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_event/admin/providers/admin_event_provider.dart';
import 'package:thix_id/presentation/thix_event/admin/services/admin_event_service.dart';

// ============================================================================
// EVENT THEME (Aligné sur ThixPolicy)
// ============================================================================
class EventTheme {
  static const Color bg = ThixPolicy.inkDeep;
  static const Color surface = Color(0xFF101B30);
  static const Color surfaceAlt = Color(0xFF14213A);
  static const Color border = Color(0xFF243451);
  static const Color primary = ThixPolicy.domainEvents;
  static const Color textMain = ThixPolicy.textOnDark;
  static const Color textSecondary = Color(0xFFA8B6CC);
  static const Color textMuted = Color(0xFF64748B);
  static const Color success = ThixPolicy.success;
  static const Color danger = ThixPolicy.danger;
}

// ============================================================================
// PAGE
// ============================================================================
class BookingLimitsPage extends ConsumerStatefulWidget {
  const BookingLimitsPage({super.key});

  @override
  ConsumerState<BookingLimitsPage> createState() => _BookingLimitsPageState();
}

class _BookingLimitsPageState extends ConsumerState<BookingLimitsPage> {
  String? _eventId;
  final _maxPerson = TextEditingController(text: '4');
  final _maxTrans = TextEditingController(text: '2');
  bool _requireId = false;
  bool _saving = false;

  @override
  void dispose() {
    _maxPerson.dispose();
    _maxTrans.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);

    if (_eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('admin_seat_select_event') ?? 'Sélectionne un événement'),
          backgroundColor: EventTheme.danger,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    
    try {
      final svc = ref.read(adminEventServiceProvider);
      await svc.upsertBookingLimit(
        _eventId!, 
        {
          'max_per_person': int.tryParse(_maxPerson.text) ?? 4, 
          'max_per_transaction': int.tryParse(_maxTrans.text) ?? 2, 
          'require_id_verification': _requireId
        }
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('admin_event_success') ?? 'Limites enregistrées avec succès'), 
            backgroundColor: EventTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'), 
            backgroundColor: EventTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final events = ref.watch(adminEventProvider).eventsState.items;
    final mediaQuery = MediaQuery.of(context);
    final reduceMotion = mediaQuery.accessibleNavigation || mediaQuery.disableAnimations;

    return Scaffold(
      backgroundColor: EventTheme.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: reduceMotion ? 0 : 20, 
              sigmaY: reduceMotion ? 0 : 20,
            ),
            child: AppBar(
              backgroundColor: EventTheme.bg.withOpacity(0.85), 
              elevation: 0, 
              leading: Semantics(
                button: true,
                label: l10n.t('common_back') ?? 'Retour',
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18), 
                  onPressed: () => Navigator.pop(context),
                ),
              ), 
              title: Text(
                l10n.t('admin_action_limits') ?? 'Anti-Fraude & Limites', 
                style: ThixPolicy.labelStyle.copyWith(
                  color: Colors.white, 
                  fontSize: 13, 
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: ThixPolicy.s16, 
          right: ThixPolicy.s16, 
          bottom: ThixPolicy.s16 + mediaQuery.padding.bottom, 
          top: ThixPolicy.s12,
        ),
        decoration: const BoxDecoration(
          color: EventTheme.surface, 
          border: Border(top: BorderSide(color: EventTheme.border)),
        ),
        child: Semantics(
          button: true,
          enabled: !_saving,
          label: _saving ? (l10n.t('common_loading') ?? 'Enregistrement...') : (l10n.t('common_save') ?? 'Enregistrer'),
          child: SizedBox(
            height: 48, 
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save, 
              icon: _saving 
                ? const SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  ) 
                : const Icon(Icons.security_rounded, size: 16), 
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, 
                foregroundColor: Colors.black, 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.r2Xl),
                ),
              ), 
              label: Text(
                _saving ? (l10n.t('common_loading') ?? 'ENREGISTREMENT...') : (l10n.t('common_save') ?? 'ENREGISTRER').toUpperCase(), 
                style: ThixPolicy.labelStyle.copyWith(
                  fontWeight: FontWeight.w900, 
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(ThixPolicy.s16), 
        children: [
          Text(
            l10n.t('admin_seat_target_event') ?? 'Événement cible', 
            style: ThixPolicy.labelStyle.copyWith(
              color: Colors.white, 
              fontWeight: FontWeight.w800, 
              fontSize: 11,
            ),
          ),
          SizedBox(height: ThixPolicy.s8),
          Semantics(
            label: l10n.t('admin_seat_target_event') ?? 'Événement cible',
            child: DropdownButtonFormField<String>(
              value: _eventId, 
              dropdownColor: EventTheme.surface, 
              style: TextStyle(
                color: Colors.white, 
                fontSize: 12,
                fontFamily: ThixPolicy.fontFamily,
              ),
              decoration: _deco(l10n.t('admin_seat_select_event') ?? 'Sélectionner un événement', Icons.event_rounded),
              items: events.map((e) => DropdownMenuItem(
                value: e.id, 
                child: Text(e.title, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) => setState(() => _eventId = v),
            ),
          ),
          SizedBox(height: ThixPolicy.s20),
          Container(
            padding: EdgeInsets.all(ThixPolicy.s16),
            decoration: BoxDecoration(
              color: EventTheme.surface, 
              borderRadius: BorderRadius.circular(18), 
              border: Border.all(color: EventTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Row(
                  children: [
                    const Icon(Icons.rule_rounded, color: Colors.white, size: 16), 
                    SizedBox(width: ThixPolicy.s8), 
                    Text(
                      l10n.t('admin_limits_purchase_rules') ?? 'Règles d\'achat', 
                      style: ThixPolicy.labelStyle.copyWith(
                        color: Colors.white, 
                        fontWeight: FontWeight.w800, 
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ThixPolicy.s16),
                Semantics(
                  textField: true,
                  label: l10n.t('admin_limits_max_person') ?? 'Max / personne (global)',
                  child: TextFormField(
                    controller: _maxPerson, 
                    keyboardType: TextInputType.number, 
                    style: TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.w700, 
                      fontSize: 12,
                      fontFamily: ThixPolicy.fontFamily,
                    ), 
                    decoration: _deco(l10n.t('admin_limits_max_person') ?? 'Max / personne (global)', Icons.person_outline_rounded),
                  ),
                ),
                SizedBox(height: ThixPolicy.s12),
                Semantics(
                  textField: true,
                  label: l10n.t('admin_limits_max_transaction') ?? 'Max / transaction (panier)',
                  child: TextFormField(
                    controller: _maxTrans, 
                    keyboardType: TextInputType.number, 
                    style: TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.w700, 
                      fontSize: 12,
                      fontFamily: ThixPolicy.fontFamily,
                    ), 
                    decoration: _deco(l10n.t('admin_limits_max_transaction') ?? 'Max / transaction (panier)', Icons.shopping_cart_outlined),
                  ),
                ),
                const Divider(color: EventTheme.border, height: 32),
                Semantics(
                  toggled: _requireId,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero, 
                    activeColor: Colors.white, 
                    value: _requireId, 
                    onChanged: (v) => setState(() => _requireId = v), 
                    title: Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 16, color: Colors.white), 
                        SizedBox(width: ThixPolicy.s8), 
                        Text(
                          l10n.t('admin_limits_require_thix_id') ?? 'Vérification THIX ID requise', 
                          style: ThixPolicy.labelStyle.copyWith(
                            color: Colors.white, 
                            fontSize: 11, 
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ), 
                    subtitle: Padding(
                      padding: const EdgeInsets.only(left: 24, top: 4), 
                      child: Text(
                        l10n.t('admin_limits_require_thix_id_desc') ?? 'Recommandé pour les événements à forte demande.', 
                        style: ThixPolicy.microStyle.copyWith(
                          color: EventTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ThixPolicy.s16),
          Container(
            padding: EdgeInsets.all(ThixPolicy.s14),
            decoration: BoxDecoration(
              color: EventTheme.surface, 
              borderRadius: BorderRadius.circular(14), 
              border: Border.all(color: EventTheme.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Colors.white), 
                const SizedBox(width: 10), 
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text(
                        l10n.t('admin_limits_info_title') ?? 'Architecture Sécurisée', 
                        style: ThixPolicy.labelStyle.copyWith(
                          color: Colors.white, 
                          fontSize: 11, 
                          fontWeight: FontWeight.w800,
                        ),
                      ), 
                      const SizedBox(height: 4), 
                      Text(
                        l10n.t('admin_limits_info_desc') ?? 'Ces limites sont appliquées et vérifiées directement par les fonctions SQL (Edge Functions) en temps réel pour empêcher toute race condition (fraude).', 
                        style: ThixPolicy.microStyle.copyWith(
                          color: EventTheme.textMuted, 
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label, 
    labelStyle: ThixPolicy.captionStyle.copyWith(color: EventTheme.textMuted), 
    prefixIcon: Icon(icon, size: 16, color: EventTheme.textMuted), 
    filled: true, 
    fillColor: EventTheme.surfaceAlt, 
    contentPadding: EdgeInsets.symmetric(horizontal: ThixPolicy.s14, vertical: ThixPolicy.s12), 
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14), 
      borderSide: const BorderSide(color: EventTheme.border),
    ), 
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14), 
      borderSide: const BorderSide(color: EventTheme.border),
    ), 
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14), 
      borderSide: const BorderSide(color: Colors.white24),
    ),
  );
}

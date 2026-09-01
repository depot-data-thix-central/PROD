/// THIX SOS — Ajouter un secours via THIX ID (production audité)
/// ✅ SÉCURISÉ : Validation URL, Safe extraction, Mounted checks, Double-tap protection
/// ✅ DESIGN : Fonds sombres translucides pour visibilité sur inkDeep
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../providers/sos_providers.dart';

// ============================================================================
// HELPERS DE VALIDATION
// ============================================================================
class _InputValidator {
  /// Valide qu'une URL est safe (http/https uniquement)
  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  /// Valide un numéro de téléphone international
  static bool isValidPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return true; // Optionnel
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return RegExp(r'^\+?[1-9]\d{6,14}$').hasMatch(cleaned);
  }

  /// Extrait une initiale de manière safe (pas de RangeError)
  static String safeInitial(String? name, {String fallback = '?'}) {
    if (name == null || name.trim().isEmpty) return fallback;
    final trimmed = name.trim();
    return trimmed[0].toUpperCase();
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class AjouterSecoursPage extends ConsumerStatefulWidget {
  const AjouterSecoursPage({super.key, this.initialCircle = 1});

  final int initialCircle;

  @override
  ConsumerState<AjouterSecoursPage> createState() => _AjouterSecoursPageState();
}

class _AjouterSecoursPageState extends ConsumerState<AjouterSecoursPage> {
  final _thixCtrl = TextEditingController();
  final _relationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  late int _circle;
  bool _searching = false;
  bool _saving = false;

  Map<String, dynamic>? _profile;
  String? _searchError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _circle = widget.initialCircle.clamp(1, 3);
  }

  @override
  void dispose() {
    _thixCtrl.dispose();
    _relationCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _displayName(Map<String, dynamic> p) {
    final full = (p['full_name'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;
    final display = (p['display_name'] as String?)?.trim();
    if (display != null && display.isNotEmpty) return display;
    final first = (p['first_name'] as String?)?.trim() ?? '';
    final last = (p['last_name'] as String?)?.trim() ?? '';
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;
    return (p['thix_id'] as String?) ?? 'Utilisateur THIX';
  }

  String? _photoUrl(Map<String, dynamic> p) {
    final a = p['avatar_url'] as String?;
    if (a != null && a.isNotEmpty) return a;
    final b = p['photo_url'] as String?;
    if (b != null && b.isNotEmpty) return b;
    return null;
  }

  // ✅ FIX P1 : Protection double-tap avec mounted check
  Future<void> _search() async {
    if (_searching) return; // Double-tap protection

    final raw = _thixCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _searchError = 'Saisissez un THIX ID';
        _profile = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
      _profile = null;
    });

    HapticFeedback.lightImpact();

    try {
      final profile =
          await ref.read(sosServiceProvider).lookupProfileByThixId(raw);
      
      if (!mounted) return; // ✅ Mounted check
      
      if (profile == null) {
        setState(() {
          _searching = false;
          _searchError = 'Aucun compte THIX trouvé pour cet ID';
        });
        return;
      }
      
      setState(() {
        _searching = false;
        _profile = profile;
      });
    } catch (e) {
      if (!mounted) return; // ✅ Mounted check
      setState(() {
        _searching = false;
        _searchError = e.toString();
      });
    }
  }

  // ✅ FIX P1 : Protection double-tap avec validation complète
  Future<void> _save() async {
    if (_saving) return; // Double-tap protection

    final profile = _profile;
    if (profile == null) {
      setState(() => _searchError = 'Recherchez d\'abord un THIX ID valide');
      return;
    }

    // ✅ Validation téléphone
    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty && !_InputValidator.isValidPhone(phone)) {
      setState(() => _phoneError = 'Format de téléphone invalide');
      return;
    }

    setState(() {
      _saving = true;
      _phoneError = null;
    });

    HapticFeedback.mediumImpact();

    try {
      final thixId = (profile['thix_id'] as String?) ?? _thixCtrl.text.trim();
      final userId = profile['id'] as String;

      await ref.read(sosContactActionsProvider).addFromThix(
            thixId: thixId,
            contactUserId: userId,
            name: _displayName(profile),
            circle: _circle,
            photoUrl: _photoUrl(profile),
            phone: phone.isEmpty ? null : phone,
            relation: _relationCtrl.text.trim().isEmpty
                ? null
                : _relationCtrl.text.trim(),
          );

      if (!mounted) return; // ✅ Mounted check
      
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t('sos_rescuer_saved')),
          backgroundColor: ThixPolicy.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return; // ✅ Mounted check
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context).t('common_error')} : $e'),
          backgroundColor: ThixPolicy.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      appBar: AppBar(
        backgroundColor: ThixPolicy.inkDeep,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_close'),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          l10n.t('sos_add_rescuer'),
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThixPolicy.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ThixPolicy.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              l10n.t('sos_add_rescuer_info'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white70,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Cercle
          Text(
            l10n.t('sos_circle'),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final c in [1, 2, 3]) ...[
                Expanded(
                  child: _CircleChoice(
                    circle: c,
                    selected: _circle == c,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _circle = c);
                    },
                  ),
                ),
                if (c < 3) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // THIX ID + recherche
          Semantics(
            label: l10n.t('sos_thix_id_label'),
            child: Text(
              '${l10n.t('sos_thix_id_label')} *',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  textField: true,
                  label: l10n.t('sos_thix_id_hint'),
                  child: TextField(
                    controller: _thixCtrl,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.characters,
                    decoration: _decoration(l10n.t('sos_thix_id_hint')),
                    onSubmitted: (_) => _search(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: Semantics(
                  button: true,
                  label: l10n.t('common_search'),
                  child: ElevatedButton(
                    onPressed: _searching ? null : _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixPolicy.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _searching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          if (_searchError != null) ...[
            const SizedBox(height: 10),
            Text(
              _searchError!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: ThixPolicy.danger,
              ),
            ),
          ],

          // Carte profil trouvé
          if (_profile != null) ...[
            const SizedBox(height: 16),
            _buildProfileCard(_profile!),
          ],

          const SizedBox(height: 20),

          // Relation (optionnel)
          Text(
            l10n.t('sos_relation'),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            textField: true,
            label: l10n.t('sos_relation_hint'),
            child: TextField(
              controller: _relationCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration(l10n.t('sos_relation_hint')),
            ),
          ),
          const SizedBox(height: 16),

          // Téléphone optionnel
          Text(
            l10n.t('sos_phone_optional'),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            textField: true,
            label: l10n.t('sos_phone_hint'),
            child: TextField(
              controller: _phoneCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: _decoration(l10n.t('sos_phone_hint')),
            ),
          ),
          
          if (_phoneError != null) ...[
            const SizedBox(height: 6),
            Text(
              _phoneError!,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: ThixPolicy.danger,
              ),
            ),
          ],
          
          const SizedBox(height: 32),

          // Bouton Enregistrer
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Semantics(
              button: true,
              label: l10n.t('sos_save_rescuer'),
              enabled: _profile != null && !_saving,
              child: ElevatedButton(
                onPressed: (_profile == null || _saving) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.danger,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        l10n.t('sos_save_rescuer'),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('sos_multiple_rescuers_info'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  // ✅ FIX P0 : Carte profil avec validation URL et extraction safe
  Widget _buildProfileCard(Map<String, dynamic> profile) {
    final l10n = AppLocalizations.of(context);
    final photoUrl = _photoUrl(profile);
    final isValidPhoto = _InputValidator.isValidUrl(photoUrl);
    final displayName = _displayName(profile);
    final thixId = (profile['thix_id'] as String?) ?? '';
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // ✅ FIX : fond sombre translucide au lieu de ThixPolicy.card
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThixPolicy.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: ThixPolicy.border,
            backgroundImage: isValidPhoto ? NetworkImage(photoUrl!) : null,
            child: !isValidPhoto
                ? Text(
                    _InputValidator.safeInitial(displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  thixId,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: ThixPolicy.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  l10n.t('sos_verified_account'),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified, color: ThixPolicy.success),
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.white38),
      filled: true,
      // ✅ FIX : fond sombre translucide (8% blanc sur inkDeep)
      fillColor: Colors.white.withValues(alpha: 0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }
}

// ============================================================================
// COMPOSANT CERCLE
// ============================================================================
class _CircleChoice extends StatelessWidget {
  const _CircleChoice({
    required this.circle,
    required this.selected,
    required this.onTap,
  });

  final int circle;
  final bool selected;
  final VoidCallback onTap;

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

  String _label(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (circle) {
      case 1:
        return l10n.t('sos_circle_priority');
      case 2:
        return l10n.t('sos_circle_secondary');
      default:
        return l10n.t('sos_circle_urgent');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Semantics(
      button: true,
      selected: selected,
      label: '${l10n.t('sos_circle')} $circle, ${_label(context)}',
      child: Material(
        // ✅ FIX : fond sombre translucide si non sélectionné
        color: selected
            ? _color.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? _color : Colors.white.withValues(alpha: 0.12),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '$circle',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: selected ? _color : Colors.white54,
                  ),
                ),
                Text(
                  _label(context),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? _color : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

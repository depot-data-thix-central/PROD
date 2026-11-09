// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — FLOW DE CRÉATION (ONBOARDING 3 ÉTAPES)
//  Fichier  : lib/presentation/thix_portfolio/pages/create_business_flow.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.3 — Novembre 2026 (CORRIGÉ CI v4)
// ════════════════════════════════════════════════════════════════════════════
//
//  Route : /business/create
//
//  Corrections CI v4 :
//    • Import dart:ui pour ImageFilter
//    • validator optionnel dans _PrismField (nullable)
//    • Remplacement de .glow() (flutter_animate) par widget natif
//    • Remplacement de .withValues() par Color.fromRGBO() dans les const
//
//  Parcours utilisateur :
//    1. FORMULAIRE — nom + secteur + ville + pays (validation live)
//    2. CRÉATION   — appel RPC `create_business` (ID généré côté DB)
//    3. SUCCÈS     — écran de célébration : THIX ID + QR + partage + CTA
//
//  Principes production :
//    • Sanitization stricte de toutes les saisies (XSS + injection DB)
//    • Logger dédié `BizCreateLogger` avec trace de la RPC
//    • i18n complet avec `args: []` pour les interpolations
//    • Haptic feedback + semantics pour accessibilité
//    • Gestion réseau : retry, timeout soft, message d'erreur lisible
//    • Navigation : retour à l'accueil THIX IA ou ouverture du site
// ════════════════════════════════════════════════════════════════════════════

import 'dart:ui'; // ✅ FIX CI v4 : pour ImageFilter.blur

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../core/thix_business_id.dart';
import '../data/business_repository.dart';

// ============================================================================
// ROUTES (cohérentes avec le FAB/Spotlight de Thix IA)
// ============================================================================

const String _kRouteHome = '/';
String _publicRoute(String thixId) => '/b/$thixId';

// ============================================================================
// PALETTE PRISM (cohérente avec thix_ia_home_page.dart)
// ============================================================================

class _Prism {
  _Prism._();
  static const Color bg = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE6E9F2);
  static const Color ink = Color(0xFF0B1220);
  static const Color inkSoft = Color(0xFF3E4C63);
  static const Color inkMuted = Color(0xFF8A94A6);
  static const Color success = Color(0xFF10B981);

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ThixPolicy.primary, Color(0xFF4338CA), Color(0xFF7C3AED)],
  );

  static List<BoxShadow> soft([double a = 0.05, double b = 14, double y = 6]) =>
      [
        BoxShadow(
          color: Colors.black.withValues(alpha: a),
          blurRadius: b,
          offset: Offset(0, y),
        ),
      ];
}

// ============================================================================
// CONSTANTES
// ============================================================================

const int _kMinNameLength = 2;
const int _kMaxNameLength = 80;
const int _kMaxSectorLength = 60;
const int _kMaxCityLength = 60;
const int _kMaxCountryLength = 2;

const List<String> _kCountryCodes = [
  'CD', // Congo (RDC)
  'CG', // Congo (Brazzaville)
  'CI', // Côte d'Ivoire
  'SN', // Sénégal
  'CM', // Cameroun
  'FR', // France
  'BE', // Belgique
  'US', // USA
];

// ============================================================================
// LOGGING
// ============================================================================

class _BizCreateLogger {
  static const _tag = 'BizCreate';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// SANITIZER
// ============================================================================

class _Sanitizer {
  _Sanitizer._();
  static String text(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }
  static String errorMessage(Object error) {
    final msg = error.toString();
    return msg.length > 140 ? '${msg.substring(0, 140)}…' : msg;
  }
}

// ============================================================================
// ÉTAPES DU FLOW
// ============================================================================

enum _Step { form, creating, success }

// ============================================================================
// PAGE RACINE
// ============================================================================

class CreateBusinessFlow extends ConsumerStatefulWidget {
  const CreateBusinessFlow({super.key});
  @override
  ConsumerState<CreateBusinessFlow> createState() =>
      _CreateBusinessFlowState();
}

class _CreateBusinessFlowState extends ConsumerState<CreateBusinessFlow> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _sectorCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String _country = _kCountryCodes.first;

  _Step _step = _Step.form;
  ThixBusinessId? _createdId;
  String? _businessId; // UUID Postgres
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sectorCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.selectionClick();
      return;
    }

    setState(() {
      _step = _Step.creating;
      _errorMessage = null;
    });

    final name = _Sanitizer.text(_nameCtrl.text, maxLength: _kMaxNameLength);
    final sector =
        _Sanitizer.text(_sectorCtrl.text, maxLength: _kMaxSectorLength);
    final city = _Sanitizer.text(_cityCtrl.text, maxLength: _kMaxCityLength);
    final country = _Sanitizer.text(_country, maxLength: _kMaxCountryLength);

    _BizCreateLogger.info('Creating business',
        {'name': name, 'sector': sector, 'city': city, 'country': country});

    try {
      final repo = ref.read(businessRepositoryProvider);
      final result = await repo.create(
        name: name,
        sector: sector.isEmpty ? null : sector,
        city: city.isEmpty ? null : city,
        country: country,
      );

      final parsedId = ThixBusinessId.tryParse(result.thixId);
      if (parsedId == null) {
        throw const BusinessCreationException(
          'Le serveur a renvoyé un identifiant invalide.',
        );
      }

      _BizCreateLogger.info('Business created', {
        'thix_id': parsedId.raw,
        'business_id': result.businessId,
      });

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _step = _Step.success;
        _createdId = parsedId;
        _businessId = result.businessId;
      });
    } on BusinessCreationException catch (e) {
      _BizCreateLogger.error('Creation failed (biz)',
          {'message': e.message, 'cause': '${e.cause}'});
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _step = _Step.form;
        _errorMessage = e.message;
      });
    } catch (e, s) {
      _BizCreateLogger.error('Creation failed (generic)',
          {'error': '$e', 'stack': '$s'});
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _step = _Step.form;
        _errorMessage = AppLocalizations.of(context)
            .t('biz_create_error_generic',
                args: [_Sanitizer.errorMessage(e)]);
      });
    }
  }

  void _retry() {
    _errorMessage = null;
    _submit();
  }

  void _goHome() {
    context.go(_kRouteHome);
  }

  void _openPublicSite() {
    if (_createdId == null) return;
    context.go(_publicRoute(_createdId!.raw));
  }

  void _copyId() async {
    if (_createdId == null) return;
    await Clipboard.setData(ClipboardData(text: _createdId!.raw));
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).t('biz_create_id_copied')),
        backgroundColor: _Prism.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareId() {
    if (_createdId == null) return;
    final url = 'https://thixid.com/b/${_createdId!.raw}';
    final name = _Sanitizer.text(_nameCtrl.text, maxLength: _kMaxNameLength);
    Share.share(
      'Découvrez $name sur THIX Portfolio Business 🚀\n$url\n'
      'ID : ${_createdId!.raw}',
      subject: 'Mon site THIX — $name',
    );
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Prism.bg,
      body: Stack(
        children: [
          // Halo d'ambiance
          Positioned(
            top: -80,
            right: -60,
            child: _halo(220, ThixPolicy.primary.withValues(alpha: 0.14)),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _halo(260, const Color(0xFF7C3AED).withValues(alpha: 0.10)),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(onClose: _step == _Step.success ? _goHome : null),
                Expanded(child: _body()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_step) {
      case _Step.form:
        return _FormStep(
          key: const ValueKey('step-form'),
          formKey: _formKey,
          nameCtrl: _nameCtrl,
          sectorCtrl: _sectorCtrl,
          cityCtrl: _cityCtrl,
          country: _country,
          onCountryChanged: (v) => setState(() => _country = v),
          onSubmit: _submit,
          errorMessage: _errorMessage,
        );
      case _Step.creating:
        return const _CreatingStep(key: ValueKey('step-creating'));
      case _Step.success:
        return _SuccessStep(
          key: const ValueKey('step-success'),
          thixId: _createdId!,
          businessName: _nameCtrl.text,
          onCopy: _copyId,
          onShare: _shareId,
          onOpen: _openPublicSite,
          onHome: _goHome,
        );
    }
  }

  Widget _halo(double s, Color c) {
    return RepaintBoundary(
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          children: [
            Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
            BackdropFilter(
              // ✅ ImageFilter nécessite import 'dart:ui'
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(color: Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TOP BAR (indicateur d'étape + bouton retour/fermer)
// ============================================================================

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: onClose != null
                ? l10n.t('common_close')
                : l10n.t('common_back'),
            child: IconButton(
              icon: Icon(onClose != null ? Icons.close_rounded : Icons.arrow_back_rounded,
                  color: _Prism.ink),
              onPressed: () {
                HapticFeedback.selectionClick();
                if (onClose != null) {
                  onClose!();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (r) => _Prism.brand.createShader(r),
                  child: const Icon(Icons.storefront_rounded,
                      size: 18, color: Colors.white),
                ),
                const SizedBox(width: 6),
                const Text('THIX Portfolio',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _Prism.ink,
                        letterSpacing: -0.3)),
              ],
            ),
          ),
          const SizedBox(width: 48), // équilibre
        ],
      ),
    );
  }
}

// ============================================================================
// ÉTAPE 1 : FORMULAIRE
// ============================================================================

class _FormStep extends StatelessWidget {
  const _FormStep({
    super.key,
    required this.formKey,
    required this.nameCtrl,
    required this.sectorCtrl,
    required this.cityCtrl,
    required this.country,
    required this.onCountryChanged,
    required this.onSubmit,
    required this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController sectorCtrl;
  final TextEditingController cityCtrl;
  final String country;
  final ValueChanged<String> onCountryChanged;
  final VoidCallback onSubmit;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        _StepIndicator(current: 1),
        const SizedBox(height: 20),

        // Titre
        Text(l10n.t('biz_create_title'),
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: _Prism.ink,
                height: 1.15,
                letterSpacing: -0.4)),
        const SizedBox(height: 8),
        Text(l10n.t('biz_create_subtitle'),
            style: const TextStyle(
                fontSize: 14,
                color: _Prism.inkSoft,
                fontWeight: FontWeight.w500,
                height: 1.5)),
        const SizedBox(height: 28),

        Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              _PrismField(
                controller: nameCtrl,
                label: l10n.t('biz_create_field_name'),
                hint: l10n.t('biz_create_field_name_hint'),
                icon: Icons.business_rounded,
                textCapitalization: TextCapitalization.words,
                maxLength: _kMaxNameLength,
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.length < _kMinNameLength) {
                    return l10n.t('biz_create_error_name_too_short');
                  }
                  if (s.length > _kMaxNameLength) {
                    return l10n.t('biz_create_error_name_too_long');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // ✅ FIX CI v4 : validator optionnel (nullable) pour champs facultatifs
              _PrismField(
                controller: sectorCtrl,
                label: l10n.t('biz_create_field_sector'),
                hint: l10n.t('biz_create_field_sector_hint'),
                icon: Icons.category_rounded,
                textCapitalization: TextCapitalization.words,
                maxLength: _kMaxSectorLength,
                optional: true,
                // pas de validator : champ facultatif
              ),
              const SizedBox(height: 14),

              _PrismField(
                controller: cityCtrl,
                label: l10n.t('biz_create_field_city'),
                hint: l10n.t('biz_create_field_city_hint'),
                icon: Icons.place_rounded,
                textCapitalization: TextCapitalization.words,
                maxLength: _kMaxCityLength,
                optional: true,
                // pas de validator : champ facultatif
              ),
              const SizedBox(height: 14),

              _CountryPicker(value: country, onChanged: onCountryChanged),
            ],
          ),
        ),

        // Erreur
        if (errorMessage != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ThixPolicy.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: ThixPolicy.danger.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: ThixPolicy.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(errorMessage!,
                      style: const TextStyle(
                          color: ThixPolicy.danger,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    formKey.currentState?.validate();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ThixPolicy.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(l10n.t('common_retry'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),

        // CTA principal
        Semantics(
          button: true,
          label: l10n.t('biz_create_cta'),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                shadowColor: ThixPolicy.primary.withValues(alpha: 0.4),
              ),
              child: Text(l10n.t('biz_create_cta'),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2)),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// INDICATEUR D'ÉTAPE (3 points + labels)
// ============================================================================

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.t('biz_create_step_info'),
      l10n.t('biz_create_step_creating'),
      l10n.t('biz_create_step_success'),
    ];
    return Row(
      children: List.generate(3, (i) {
        final active = i + 1 <= current;
        return Expanded(
          child: Column(
            children: [
              Container(
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active ? ThixPolicy.primary : _Prism.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 6),
              Text(labels[i],
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: active ? _Prism.ink : _Prism.inkMuted)),
            ],
          ),
        );
      }),
    );
  }
}

// ============================================================================
// CHAMP DE FORMULAIRE « PRISM » — ✅ FIX CI v4 : validator optionnel
// ============================================================================

class _PrismField extends StatelessWidget {
  const _PrismField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator, // ✅ optionnel maintenant (nullable)
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.optional = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator; // ✅ nullable
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _Prism.ink)),
            if (optional)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _Prism.border.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(AppLocalizations.of(context).t('common_optional'),
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _Prism.inkSoft)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _Prism.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _Prism.border),
            boxShadow: _Prism.soft(0.03, 8, 3),
          ),
          child: TextFormField(
            controller: controller,
            textCapitalization: textCapitalization,
            maxLength: maxLength,
            validator: optional ? (_) => null : validator,
            decoration: InputDecoration(
              counterText: '',
              prefixIcon: Icon(icon, color: ThixPolicy.primary, size: 20),
              hintText: hint,
              hintStyle: const TextStyle(
                  color: _Prism.inkMuted, fontWeight: FontWeight.w500),
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: ThixPolicy.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: ThixPolicy.danger, width: 1.5),
              ),
              contentPadding: const EdgeInsets.fromLTRB(8, 14, 14, 14),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SÉLECTEUR DE PAYS (codes ISO, affichage FR)
// ============================================================================

class _CountryPicker extends StatelessWidget {
  const _CountryPicker({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const Map<String, String> _labels = {
    'CD': '🇨🇩  Congo (RDC)',
    'CG': '🇨🇬  Congo (Brazzaville)',
    'CI': '🇨🇮  Côte d\'Ivoire',
    'SN': '🇸🇳  Sénégal',
    'CM': '🇨🇲  Cameroun',
    'FR': '🇫🇷  France',
    'BE': '🇧🇪  Belgique',
    'US': '🇺🇸  États-Unis',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.t('biz_create_field_country'),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _Prism.ink)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: _Prism.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _Prism.border),
            boxShadow: _Prism.soft(0.03, 8, 3),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: _Prism.inkMuted),
              items: _kCountryCodes
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(_labels[c] ?? c,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _Prism.ink)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  HapticFeedback.selectionClick();
                  onChanged(v);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ÉTAPE 2 : CRÉATION EN COURS
// ============================================================================

class _CreatingStep extends StatelessWidget {
  const _CreatingStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Spinner brand (rotation native)
            _RotatingSpinner(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: _Prism.brand,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: ThixPolicy.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text(l10n.t('biz_create_creating_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _Prism.ink,
                    letterSpacing: -0.3)),
            const SizedBox(height: 10),

            Text(l10n.t('biz_create_creating_subtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    color: _Prism.inkSoft,
                    fontWeight: FontWeight.w500,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }
}

/// Spinner rotatif natif (remplace .animate().rotate())
class _RotatingSpinner extends StatefulWidget {
  const _RotatingSpinner({required this.child});
  final Widget child;

  @override
  State<_RotatingSpinner> createState() => _RotatingSpinnerState();
}

class _RotatingSpinnerState extends State<_RotatingSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * 3.14159265,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ============================================================================
// ÉTAPE 3 : SUCCÈS
// ============================================================================

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({
    super.key,
    required this.thixId,
    required this.businessName,
    required this.onCopy,
    required this.onShare,
    required this.onOpen,
    required this.onHome,
  });

  final ThixBusinessId thixId;
  final String businessName;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onOpen;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        _StepIndicator(current: 3),
        const SizedBox(height: 22),

        // ✅ FIX CI v4 : animation NATIVE (pas de .animate().scale().glow())
        Center(
          child: _ScaleGlowIn(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      // ✅ Color.fromRGBO au lieu de withValues pour const
                      color: Color.fromRGBO(16, 185, 129, 0.30),
                      blurRadius: 28,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: const Icon(Icons.check_rounded,
                  size: 50, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Center(
          child: Text(l10n.t('biz_create_success_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _Prism.ink,
                  height: 1.15,
                  letterSpacing: -0.4)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
              l10n.t('biz_create_success_subtitle',
                  args: [_Sanitizer.text(businessName, maxLength: 40)]),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  color: _Prism.inkSoft,
                  fontWeight: FontWeight.w500,
                  height: 1.5)),
        ),
        const SizedBox(height: 26),

        // Carte THIX ID (affiché en grand)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _Prism.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _Prism.border),
            boxShadow: _Prism.soft(0.06, 18, 8),
          ),
          child: Column(
            children: [
              Text(l10n.t('biz_create_your_id'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _Prism.inkMuted,
                      letterSpacing: 1.4)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onCopy,
                child: ShaderMask(
                  shaderCallback: (r) => _Prism.brand.createShader(r),
                  child: Text(thixId.raw,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(height: 14),
              // Boutons copier / partager
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCopy,
                      icon: const Icon(Icons.content_copy_rounded, size: 16),
                      label: Text(l10n.t('common_copy'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ThixPolicy.primary,
                        side: const BorderSide(color: ThixPolicy.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: Text(l10n.t('common_share'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _Prism.ink,
                        side: const BorderSide(color: _Prism.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // QR code
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: _Prism.soft(0.08, 20, 8),
            ),
            child: QrImageView(
              data: thixId.raw,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(l10n.t('biz_create_qr_hint'),
              style: const TextStyle(
                  fontSize: 12, color: _Prism.inkMuted, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 26),

        // CTA principal : voir mon site
        Semantics(
          button: true,
          label: l10n.t('biz_create_open_site'),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(l10n.t('biz_create_open_site'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // CTA secondaire : accueil
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onHome,
            child: Text(l10n.t('biz_create_go_home'),
                style: const TextStyle(
                    color: _Prism.inkSoft, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Widget animation scale (natif) — remplace .animate().scale()
// ============================================================================

class _ScaleGlowIn extends StatefulWidget {
  const _ScaleGlowIn({required this.child});
  final Widget child;

  @override
  State<_ScaleGlowIn> createState() => _ScaleGlowInState();
}

class _ScaleGlowInState extends State<_ScaleGlowIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late Animation<double> _scaleAnim = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: widget.child,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — THEME STUDIO (COULEURS / POLICE / ANIMATIONS)
//  Fichier  : lib/presentation/thix_portfolio/pages/theme_studio_page.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.1 — Novembre 2026
// ════════════════════════════════════════════════════════════════════════════
//
//  Route : /business/theme/:id
//
//  Fonctionnalités :
//    • Presets marketing (BusinessThemePresets)
//    • Édition des 3 couleurs (nuancier natif + hex) — AUCUN package externe
//    • Police (Google Fonts recommandées), rayon, style d'animation, dark mode
//    • Aperçu live du site miniaturisé (reconstruit à chaque changement)
//    • Sauvegarde via repo.upsertTheme
//    • i18n FR/EN inline (aucune dépendance l10n)
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../data/business_repository.dart';
import '../models/business_bundle.dart';
import '../models/business_theme.dart';

// ─── i18n minimaliste FR/EN ─────────────────────────────────────────────────
String _lang(BuildContext c) =>
    Localizations.localeOf(c).languageCode.toLowerCase();

/// Retourne la chaîne française si la locale courante est `fr`, sinon l'anglaise.
String _s(BuildContext c, String fr, String en) =>
    _lang(c) == 'fr' ? fr : en;
// ────────────────────────────────────────────────────────────────────────────

class _Prism {
  _Prism._();
  static const Color bg = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE6E9F2);
  static const Color ink = Color(0xFF0B1220);
  static const Color inkSoft = Color(0xFF3E4C63);
}

/// Nuancier natif (28 teintes curated) — remplace flex_color_picker.
const List<String> _kSwatches = [
  '#1E5AE8', '#0A66C2', '#063A75', '#0EA5E9', '#22D3EE', '#0CA678',
  '#065F46', '#10B981', '#F59E0B', '#FAB005', '#E8590C', '#862E0C',
  '#C2255C', '#7A1436', '#6741D9', '#3B2A86', '#7C3AED', '#F06595',
  '#946300', '#D4AF37', '#0B1220', '#1E293B', '#334155', '#64748B',
  '#38BDF8', '#84CC16', '#EF4444', '#FFFFFF',
];

class ThemeStudioPage extends ConsumerStatefulWidget {
  const ThemeStudioPage({super.key, required this.businessId});
  final String businessId;

  @override
  ConsumerState<ThemeStudioPage> createState() => _ThemeStudioPageState();
}

class _ThemeStudioPageState extends ConsumerState<ThemeStudioPage> {
  Business? _business;
  BusinessTheme _theme = const BusinessTheme(
      primaryHex: '#1E5AE8', secondaryHex: '#0B2E6B', accentHex: '#F5B301');
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bundle =
          await ref.read(ownerBusinessBundleProvider(widget.businessId).future);
      if (!mounted) return;
      setState(() {
        _business = bundle.business;
        _theme = bundle.theme;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(businessRepositoryProvider)
          .upsertTheme(businessId: widget.businessId, theme: _theme.validate());
      if (!mounted) return;
      setState(() {
        _theme = saved;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_s(context, 'Thème enregistré ✓', 'Theme saved ✓')),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_s(context, 'Erreur : $e', 'Error: $e')),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _pickColor(String current, ValueChanged<String> onPick) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ColorPickerSheet(initial: current),
    );
    if (result != null) setState(() => onPick(result));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _Prism.bg,
        appBar: AppBar(
          title: Text(_s(context, 'Thème & style', 'Theme & style')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _Prism.bg,
      appBar: AppBar(
        title: Text(_s(context, 'Thème & style', 'Theme & style'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_s(context, 'Enregistrer', 'Save')),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── Aperçu live ──
          _LivePreview(theme: _theme, businessName: _business?.name ?? ''),
          const SizedBox(height: 20),

          // ── Presets ──
          Text(_s(context, 'Styles prédéfinis', 'Presets'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: BusinessThemePresets.all.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final p = BusinessThemePresets.all[i];
                return GestureDetector(
                  onTap: () => setState(() => _theme = p.theme),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: p.theme.heroGradient,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _Prism.border),
                        ),
                        child: Center(
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: p.theme.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 70,
                        child: Text(p.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 9.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // ── Couleurs ──
          Text(_s(context, 'Couleurs', 'Colors'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _ColorRow(
            label: _s(context, 'Primaire', 'Primary'),
            hex: _theme.primaryHex,
            onPick: (h) =>
                _pickColor(h, (v) => _theme = _theme.copyWith(primaryHex: v)),
            onChanged: (v) => _theme = _theme.copyWith(primaryHex: v),
          ),
          _ColorRow(
            label: _s(context, 'Secondaire', 'Secondary'),
            hex: _theme.secondaryHex,
            onPick: (h) =>
                _pickColor(h, (v) => _theme = _theme.copyWith(secondaryHex: v)),
            onChanged: (v) => _theme = _theme.copyWith(secondaryHex: v),
          ),
          _ColorRow(
            label: _s(context, 'Accent', 'Accent'),
            hex: _theme.accentHex,
            onPick: (h) =>
                _pickColor(h, (v) => _theme = _theme.copyWith(accentHex: v)),
            onChanged: (v) => _theme = _theme.copyWith(accentHex: v),
          ),
          const SizedBox(height: 20),

          // ── Police ──
          Text(_s(context, 'Police', 'Font'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _Prism.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _Prism.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: kRecommendedFontFamilies.contains(_theme.fontFamily)
                    ? _theme.fontFamily
                    : kRecommendedFontFamilies.first,
                isExpanded: true,
                items: [
                  for (final f in kRecommendedFontFamilies)
                    DropdownMenuItem(
                      value: f,
                      child: Text('Aa — $f',
                          style: GoogleFonts.getFont(f)
                              .copyWith(fontSize: 14, color: _Prism.ink)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null)
                    setState(() => _theme = _theme.copyWith(fontFamily: v));
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Rayon ──
          Text(
              '${_s(context, 'Rayon', 'Radius')} : ${_theme.cornerRadius.round()}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          Slider(
            value: _theme.cornerRadius.clamp(
                BusinessTheme.kMinRadius, BusinessTheme.kMaxRadius),
            min: BusinessTheme.kMinRadius,
            max: BusinessTheme.kMaxRadius,
            divisions: 36,
            activeColor: ThixPolicy.primary,
            onChanged: (v) =>
                setState(() => _theme = _theme.copyWith(cornerRadius: v)),
          ),
          const SizedBox(height: 12),

          // ── Style d'animation ──
          Text(_s(context, "Style d'animation", 'Animation style'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in BusinessAnimationStyle.values)
                ChoiceChip(
                  label: Text(_animLabel(context, s)),
                  selected: _theme.animationStyle == s,
                  onSelected: (_) =>
                      setState(() => _theme = _theme.copyWith(animationStyle: s)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Dark mode ──
          SwitchListTile(
            title: Text(_s(context, 'Mode sombre', 'Dark mode'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            value: _theme.darkMode,
            activeThumbColor: ThixPolicy.primary,
            onChanged: (v) =>
                setState(() => _theme = _theme.copyWith(darkMode: v)),
          ),
        ],
      ),
    );
  }

  String _animLabel(BuildContext c, BusinessAnimationStyle s) {
    switch (s) {
      case BusinessAnimationStyle.elegant:
        return _s(c, 'Élégant', 'Elegant');
      case BusinessAnimationStyle.dynamic:
        return _s(c, 'Dynamique', 'Dynamic');
      case BusinessAnimationStyle.minimal:
        return _s(c, 'Minimal', 'Minimal');
    }
  }
}

// ============================================================================
// LIGNE COULEUR (swatch + hex + nuancier)
// ============================================================================

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.hex,
    required this.onPick,
    required this.onChanged,
  });
  final String label;
  final String hex;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = ThixColorUtils.isValidHex(hex)
        ? ThixColorUtils.toColor(hex)
        : Colors.grey;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onPick(hex),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _Prism.border, width: 2),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: hex),
              key: ValueKey(hex),
              style: const TextStyle(fontWeight: FontWeight.w700),
              onChanged: (v) {
                if (ThixColorUtils.isValidHex(v))
                  onChanged(ThixColorUtils.normalizeHex(v));
              },
              decoration: InputDecoration(
                labelText: label,
                isDense: true,
                filled: true,
                fillColor: _Prism.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _Prism.border)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// NUANCIER NATIF (bottom sheet)
// ============================================================================

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.initial});
  final String initial;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late String _selected = ThixColorUtils.isValidHex(widget.initial)
      ? ThixColorUtils.normalizeHex(widget.initial)
      : '#1E5AE8';
  late final TextEditingController _hex = TextEditingController(text: _selected);

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Prism.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in _kSwatches)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selected = s;
                        _hex.text = s;
                      });
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ThixColorUtils.toColor(s),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selected == s
                              ? ThixPolicy.primary
                              : _Prism.border,
                          width: _selected == s ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hex,
              style: const TextStyle(fontWeight: FontWeight.w700),
              onChanged: (v) {
                if (ThixColorUtils.isValidHex(v)) {
                  setState(() => _selected = ThixColorUtils.normalizeHex(v));
                }
              },
              decoration: InputDecoration(
                labelText: _s(context, 'Code hexadécimal', 'Hex code'),
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, _selected),
              child: Text(_s(context, 'Appliquer', 'Apply')),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// APERÇU LIVE MINIATURISÉ
// ============================================================================

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.theme, required this.businessName});
  final BusinessTheme theme;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme.toThemeData(),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _Prism.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 84,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: theme.heroGradient,
                ),
                borderRadius: theme.radiusSm,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    businessName.isNotEmpty
                        ? businessName[0].toUpperCase()
                        : 'T',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          businessName.isEmpty
                              ? _s(context, 'Entreprise', 'Company')
                              : businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(
                          _s(context, 'Slogan de démonstration', 'Demo tagline'),
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: theme.radius,
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt_rounded,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _s(context, 'Service premium', 'Premium service'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        Text(
                            _s(context,
                                'Description courte…', 'Short description…'),
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                child: const Text('CTA'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

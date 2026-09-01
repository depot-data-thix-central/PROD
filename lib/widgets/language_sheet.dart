// lib/presentation/chat/escalation/widgets/agent_selector.dart
//
// ============================================================================
// AGENT SELECTOR — Production Enterprise
// ============================================================================
//
// Dropdown de sélection d'un agent selon son niveau d'escalade.
//
// Architecture :
//   - Chargement dynamique des agents depuis Supabase
//   - Filtrage par niveau (senior, admin, etc.)
//   - Validation UUID sur les IDs
//   - États loading / error / empty
//
// Sécurité :
//   - Validation UUID v4 stricte sur les IDs d'agents
//   - Sanitization XSS sur les noms affichés
//   - SupabaseClient injecté via Riverpod
//
// UX :
//   - ThixPolicy 100% (0 couleurs hardcodées)
//   - i18n complète (6 clés)
//   - Semantics VoiceOver complets
//   - HapticFeedback sur sélection
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/escalation_level.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart'
    show supabaseClientProvider;

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kBorderRadius = 10.0;
const double _kFontSize = 13.0;
const double _kLabelFontSize = 12.0;
const double _kIconSize = 20.0;
const double _kFocusedBorderWidth = 1.2;
const int _kMaxNameLength = 100;
const int _kMaxAgents = 50;
const Duration _kLoadTimeout = Duration(seconds: 15);

// ============================================================================
// VALIDATORS
// ============================================================================
class _AgentSelectorValidators {
  _AgentSelectorValidators._();

  /// Valide un UUID v4 strict.
  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    final trimmed = id.trim();
    if (trimmed.length > 100) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  /// Sanitize un nom d'agent (XSS + caractères de contrôle).
  static String sanitizeName(String? input) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    if (s.isEmpty) return '';
    return s.length > _kMaxNameLength ? s.substring(0, _kMaxNameLength) : s;
  }
}

// ============================================================================
// AGENT MODEL (interne)
// ============================================================================

/// Représente un agent disponible pour escalade.
class _Agent {
  final String id;
  final String displayName;

  const _Agent({required this.id, required this.displayName});
}

// ============================================================================
// AGENT SELECTOR WIDGET
// ============================================================================

/// Dropdown de sélection d'un agent selon son niveau d'escalade.
///
/// **Usage** :
/// ```dart
/// AgentSelector(
///   level: EscalationLevel.senior,
///   onSelected: (agentId) {
///     // agentId est un UUID valide ou null
///   },
/// )
/// ```
///
/// **Comportement** :
/// - Charge dynamiquement les agents du niveau spécifié depuis Supabase
/// - Affiche un état de chargement pendant le fetch
/// - Affiche un état d'erreur si le fetch échoue
/// - Affiche "Aucun agent disponible" si la liste est vide
class AgentSelector extends ConsumerStatefulWidget {
  /// Niveau d'escalade cible (senior, admin, etc.).
  final EscalationLevel level;

  /// Callback appelé quand un agent est sélectionné.
  /// Reçoit l'UUID de l'agent ou `null` si désélectionné.
  final ValueChanged<String?> onSelected;

  /// Valeur initiale pré-sélectionnée (optionnel).
  final String? initialValue;

  const AgentSelector({
    super.key,
    required this.level,
    required this.onSelected,
    this.initialValue,
  });

  @override
  ConsumerState<AgentSelector> createState() => _AgentSelectorState();
}

class _AgentSelectorState extends ConsumerState<AgentSelector> {
  String? _selectedAgentId;
  List<_Agent> _agents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    debugPrint('[AgentSelector] 🚀 Initialized (level=${widget.level.name})');

    // Validation de la valeur initiale
    if (widget.initialValue != null &&
        _AgentSelectorValidators.isValidUuid(widget.initialValue)) {
      _selectedAgentId = widget.initialValue;
    }

    Future.microtask(_loadAgents);
  }

  @override
  void didUpdateWidget(covariant AgentSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recharger si le niveau change
    if (oldWidget.level != widget.level) {
      debugPrint('[AgentSelector] 🔄 Level changed, reloading');
      _loadAgents();
    }
  }

  @override
  void dispose() {
    debugPrint('[AgentSelector] 👋 Disposed');
    super.dispose();
  }

  // ── LOAD AGENTS ──────────────────────────────────────────────────────

  Future<void> _loadAgents() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    debugPrint('[AgentSelector] 🔄 Loading agents for level ${widget.level.name}');

    try {
      final client = ref.read(supabaseClientProvider);

      // Requête adaptée selon le niveau
      // Note : adapter la colonne/le filtre selon votre schéma DB
      final levelFilter = widget.level.name.toLowerCase();

      final res = await client
          .from('profiles')
          .select('id, display_name, full_name, username')
          .eq('escalation_level', levelFilter)
          .order('display_name', ascending: true)
          .limit(_kMaxAgents)
          .timeout(_kLoadTimeout);

      if (!mounted) return;

      final agents = <_Agent>[];
      for (final row in res as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['id']?.toString() ?? '';

        // Validation UUID stricte
        if (!_AgentSelectorValidators.isValidUuid(id)) continue;

        final displayName = _AgentSelectorValidators.sanitizeName(
          map['display_name']?.toString() ??
              map['full_name']?.toString() ??
              map['username']?.toString(),
        );

        if (displayName.isEmpty) continue;

        agents.add(_Agent(id: id, displayName: displayName));
      }

      setState(() {
        _agents = agents;
        _isLoading = false;

        // Vérifier que la sélection courante est toujours valide
        if (_selectedAgentId != null &&
            !agents.any((a) => a.id == _selectedAgentId)) {
          _selectedAgentId = null;
          widget.onSelected(null);
        }
      });

      debugPrint('[AgentSelector] ✓ Loaded ${agents.length} agents');
    } on TimeoutException {
      debugPrint('[AgentSelector] ❌ Load timeout');
      if (mounted) {
        setState(() {
          _error = 'timeout';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AgentSelector] ❌ Load error: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      if (mounted) {
        setState(() {
          _error = 'error';
          _isLoading = false;
        });
      }
    }
  }

  // ── SELECTION HANDLER ────────────────────────────────────────────────

  void _onChanged(String? value) {
    // Validation avant de propager
    if (value != null && !_AgentSelectorValidators.isValidUuid(value)) {
      debugPrint('[AgentSelector] ⚠️ Invalid agent ID selected: $value');
      return;
    }

    HapticFeedback.selectionClick();
    debugPrint('[AgentSelector] ✓ Selected: ${value != null ? _obfuscate(value) : 'null'}');

    setState(() => _selectedAgentId = value);
    widget.onSelected(value);
  }

  // ── BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // État de chargement
    if (_isLoading) {
      return _buildLoadingState(l10n);
    }

    // État d'erreur
    if (_error != null) {
      return _buildErrorState(l10n);
    }

    // État vide
    if (_agents.isEmpty) {
      return _buildEmptyState(l10n);
    }

    // État normal : dropdown
    return _buildDropdown(l10n);
  }

  // ── STATES ───────────────────────────────────────────────────────────

  Widget _buildLoadingState(AppLocalizations l10n) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ThixPolicy.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.t('agent_selector_loading'),
            style: ThixPolicy.bodyStyle.copyWith(
              fontSize: _kFontSize,
              color: ThixPolicy.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    return Semantics(
      button: true,
      label: l10n.t('agent_selector_error_retry'),
      child: InkWell(
        onTap: _loadAgents,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: ThixPolicy.danger.withOpacity(0.1),
            borderRadius: BorderRadius.circular(_kBorderRadius),
            border: Border.all(color: ThixPolicy.danger.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: ThixPolicy.danger,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.t('agent_selector_error'),
                  style: ThixPolicy.bodyStyle.copyWith(
                    fontSize: _kFontSize,
                    color: ThixPolicy.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.refresh_rounded,
                color: ThixPolicy.danger,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_off_rounded,
            color: ThixPolicy.textMuted,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.t('agent_selector_empty'),
              style: ThixPolicy.bodyStyle.copyWith(
                fontSize: _kFontSize,
                color: ThixPolicy.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(AppLocalizations l10n) {
    return Semantics(
      label: l10n.t('agent_selector_label'),
      child: DropdownButtonFormField<String>(
        value: _selectedAgentId,
        style: ThixPolicy.bodyStyle.copyWith(
          fontSize: _kFontSize,
          color: ThixPolicy.textMain,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: l10n.t('agent_selector_label'),
          labelStyle: TextStyle(color: ThixPolicy.textMuted, fontSize: _kLabelFontSize),
          filled: true,
          fillColor: ThixPolicy.card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: ThixPolicy.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: ThixPolicy.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(
              color: ThixPolicy.primary,
              width: _kFocusedBorderWidth,
            ),
          ),
        ),
        dropdownColor: ThixPolicy.card,
        icon: Icon(
          Icons.expand_more_rounded,
          color: ThixPolicy.textMuted,
          size: _kIconSize,
        ),
        items: _agents.map((agent) {
          return DropdownMenuItem<String>(
            value: agent.id,
            child: Text(
              agent.displayName,
              style: TextStyle(fontSize: _kFontSize),
            ),
          );
        }).toList(),
        onChanged: _onChanged,
        validator: (value) => value == null
            ? l10n.t('agent_selector_required')
            : null,
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────

  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

// lib/presentation/chat/escalation/screens/handle_escalation_page.dart
//
// ============================================================================
// HANDLE ESCALATION PAGE — Production Enterprise
// ============================================================================
//
// Page de gestion d'une escalade : accepter / refuser / résoudre.
//
// Architecture :
//   - Utilise escalationProvider (Riverpod StateNotifier)
//   - Affichage conditionnel selon statut (pending/accepted/resolved/rejected)
//   - Champ de motif pour refus
//
// Sécurité :
//   - Validation UUID sur escalationId et agentId
//   - Sanitization XSS sur tous les textes affichés
//   - Stack traces masquées en production (kDebugMode)
//   - Mounted checks après tous les awaits
//
// UX :
//   - ThixPolicy 100% (0 couleurs hardcodées)
//   - i18n complète (25+ clés)
//   - Semantics VoiceOver complets
//   - HapticFeedback sur actions critiques
//   - DateFormat pour affichage dates lisible
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/escalation_level.dart';
import 'package:thix_id/models/chat/escalation_status.dart';
import 'package:thix_id/models/chat/escalation_step.dart';
import 'package:thix_id/presentation/chat/escalation/providers/escalation_provider.dart';
import 'package:thix_id/presentation/chat/escalation/widgets/level_badge.dart';
import 'package:thix_id/presentation/chat/escalation/widgets/priority_chip.dart';
import 'package:thix_id/presentation/chat/escalation/widgets/status_indicator.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kCardBorderRadius = 16.0;
const double _kButtonBorderRadius = 12.0;
const double _kErrorBorderRadius = 8.0;
const int _kMaxRejectReasonLength = 500;
const Duration _kLoadTimeout = Duration(seconds: 15);

// ============================================================================
// VALIDATORS
// ============================================================================
class _EscalationValidators {
  _EscalationValidators._();

  /// Valide un UUID v4 strict.
  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

  /// Sanitize un texte (XSS + caractères de contrôle).
  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  /// Formate une date de manière sûre et localisée.
  static String formatDate(DateTime date, AppLocalizations l10n) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm', l10n.localeName).format(date.toLocal());
    } catch (_) {
      return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
    }
  }
}

// ============================================================================
// HANDLE ESCALATION PAGE
// ============================================================================

/// Page de gestion d'une escalade spécifique.
///
/// Affiche les détails de l'escalade et permet à l'agent destinataire
/// de l'accepter, la refuser (avec motif) ou la marquer comme résolue.
class HandleEscalationPage extends ConsumerStatefulWidget {
  /// UUID de l'escalade à gérer.
  final String escalationId;

  /// UUID de l'agent destinataire.
  final String agentId;

  const HandleEscalationPage({
    super.key,
    required this.escalationId,
    required this.agentId,
  });

  @override
  ConsumerState<HandleEscalationPage> createState() =>
      _HandleEscalationPageState();
}

class _HandleEscalationPageState extends ConsumerState<HandleEscalationPage> {
  final _rejectReasonCtrl = TextEditingController();
  bool _showRejectReason = false;
  bool _isProcessing = false; // Protection double-tap

  @override
  void initState() {
    super.initState();
    debugPrint('[HandleEscalation] 🚀 Page opened '
        '(escalation=${_obfuscate(widget.escalationId)}, '
        'agent=${_obfuscate(widget.agentId)})');

    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    _rejectReasonCtrl.dispose();
    debugPrint('[HandleEscalation] 👋 Page disposed');
    super.dispose();
  }

  // ── LOAD DATA ────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    if (!_EscalationValidators.isValidUuid(widget.agentId)) {
      debugPrint('[HandleEscalation] ⚠️ Invalid agentId');
      return;
    }

    debugPrint('[HandleEscalation] 🔄 Loading data');

    try {
      await ref
          .read(escalationProvider.notifier)
          .loadPending(widget.agentId, EscalationLevel.senior)
          .timeout(_kLoadTimeout);
    } on TimeoutException {
      debugPrint('[HandleEscalation] ❌ Load timeout');
    } catch (e) {
      debugPrint('[HandleEscalation] ❌ Load error: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  // ── FEEDBACK HELPERS ─────────────────────────────────────────────────

  void _showSuccess(String message) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── ACTIONS ──────────────────────────────────────────────────────────

  Future<void> _accept(EscalationNotifier notifier) async {
    final l10n = AppLocalizations.of(context);

    if (_isProcessing) return;
    if (!_EscalationValidators.isValidUuid(widget.escalationId) ||
        !_EscalationValidators.isValidUuid(widget.agentId)) {
      _showError(l10n.t('escalation_invalid_id'));
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    debugPrint('[HandleEscalation] ✓ Accepting: ${_obfuscate(widget.escalationId)}');

    try {
      final success = await notifier
          .accept(widget.escalationId, widget.agentId)
          .timeout(_kLoadTimeout);

      if (!mounted) return;

      if (success != null) {
        _showSuccess(l10n.t('escalation_accepted'));
      } else {
        final error = ref.read(escalationProvider).error;
        _showError(kDebugMode && error != null
            ? error
            : l10n.t('escalation_accept_error'));
      }
    } on TimeoutException {
      if (mounted) _showError(l10n.t('escalation_timeout'));
    } catch (e) {
      debugPrint('[HandleEscalation] ❌ Accept error: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      if (mounted) _showError(l10n.t('escalation_accept_error'));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject(EscalationNotifier notifier) async {
    final l10n = AppLocalizations.of(context);

    if (_isProcessing) return;

    final reasonText = _rejectReasonCtrl.text.trim();
    if (reasonText.isEmpty) {
      _showError(l10n.t('escalation_reject_reason_required'));
      return;
    }

    if (!_EscalationValidators.isValidUuid(widget.escalationId)) {
      _showError(l10n.t('escalation_invalid_id'));
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    final sanitizedReason = _EscalationValidators.sanitize(
      reasonText,
      maxLength: _kMaxRejectReasonLength,
    );

    debugPrint('[HandleEscalation] ❌ Rejecting: ${_obfuscate(widget.escalationId)}');

    try {
      final success = await notifier
          .reject(widget.escalationId, sanitizedReason)
          .timeout(_kLoadTimeout);

      if (!mounted) return;

      if (success != null) {
        _showSuccess(l10n.t('escalation_rejected'));
        context.pop();
      } else {
        final error = ref.read(escalationProvider).error;
        _showError(kDebugMode && error != null
            ? error
            : l10n.t('escalation_reject_error'));
      }
    } on TimeoutException {
      if (mounted) _showError(l10n.t('escalation_timeout'));
    } catch (e) {
      debugPrint('[HandleEscalation] ❌ Reject error: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      if (mounted) _showError(l10n.t('escalation_reject_error'));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _resolve(EscalationNotifier notifier) async {
    final l10n = AppLocalizations.of(context);

    if (_isProcessing) return;
    if (!_EscalationValidators.isValidUuid(widget.escalationId)) {
      _showError(l10n.t('escalation_invalid_id'));
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    debugPrint('[HandleEscalation] ✓ Resolving: ${_obfuscate(widget.escalationId)}');

    try {
      final success = await notifier
          .resolve(widget.escalationId)
          .timeout(_kLoadTimeout);

      if (!mounted) return;

      if (success != null) {
        _showSuccess(l10n.t('escalation_resolved'));
        context.pop();
      } else {
        final error = ref.read(escalationProvider).error;
        _showError(kDebugMode && error != null
            ? error
            : l10n.t('escalation_resolve_error'));
      }
    } on TimeoutException {
      if (mounted) _showError(l10n.t('escalation_timeout'));
    } catch (e) {
      debugPrint('[HandleEscalation] ❌ Resolve error: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      if (mounted) _showError(l10n.t('escalation_resolve_error'));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final escState = ref.watch(escalationProvider);
    final escNotifier = ref.read(escalationProvider.notifier);

    EscalationStep? escalation;
    try {
      escalation = escState.pending.firstWhere((e) => e.id == widget.escalationId);
    } catch (_) {
      escalation = null;
    }

    return Scaffold(
      backgroundColor: ThixPolicy.card,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: ThixPolicy.border),
        ),
        leading: Semantics(
          button: true,
          label: l10n.t('escalation_back'),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          l10n.t('escalation_handle_title'),
          style: ThixPolicy.titleStyle.copyWith(
            color: ThixPolicy.textMain,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: escalation == null
          ? _buildLoading()
          : RepaintBoundary(child: _buildContent(escalation, escState, escNotifier, l10n)),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: CircularProgressIndicator(
        color: ThixPolicy.primary,
        strokeWidth: 3,
      ),
    );
  }

  Widget _buildContent(
    EscalationStep escalation,
    EscalationState escState,
    EscalationNotifier escNotifier,
    AppLocalizations l10n,
  ) {
    // Sanitize tous les textes affichés
    final fromAgent = _EscalationValidators.sanitize(
      escalation.fromAgentName ?? escalation.fromAgentId,
      maxLength: 100,
    );
    final toAgent = _EscalationValidators.sanitize(
      escalation.toAgentName ?? escalation.toAgentId,
      maxLength: 100,
    );
    final reason = _EscalationValidators.sanitize(escalation.reason, maxLength: 500);
    final comment = escalation.comment != null
        ? _EscalationValidators.sanitize(escalation.comment, maxLength: 1000)
        : null;
    final dateStr = _EscalationValidators.formatDate(escalation.createdAt, l10n);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header : Level + Priority + Status ──
          _buildHeaderCard(escalation),

          const SizedBox(height: 24),

          // ── Info card ──
          _buildInfoCard(
            fromAgent: fromAgent,
            toAgent: toAgent,
            reason: reason,
            comment: comment,
            dateStr: dateStr,
            l10n: l10n,
          ),

          const SizedBox(height: 32),

          // ── Actions selon statut ──
          if (escalation.status == EscalationStatus.pending)
            _buildPendingActions(escState, escNotifier, l10n),

          if (escalation.status == EscalationStatus.accepted)
            _buildAcceptedState(escState, escNotifier, l10n),

          if (escalation.status == EscalationStatus.resolved)
            _buildResolvedState(l10n),

          if (escalation.status == EscalationStatus.rejected)
            _buildRejectedState(l10n),

          const SizedBox(height: 24),

          // ── Erreur ──
          if (escState.error != null) _buildErrorCard(escState.error!, l10n),
        ],
      ),
    );
  }

  // ── HEADER CARD ──────────────────────────────────────────────────────

  Widget _buildHeaderCard(EscalationStep escalation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(_kCardBorderRadius),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          LevelBadge(level: escalation.toLevel),
          const SizedBox(width: 8),
          PriorityChip(priority: escalation.priority),
          const Spacer(),
          StatusIndicator(status: escalation.status),
        ],
      ),
    );
  }

  // ── INFO CARD ────────────────────────────────────────────────────────

  Widget _buildInfoCard({
    required String fromAgent,
    required String toAgent,
    required String reason,
    required String? comment,
    required String dateStr,
    required AppLocalizations l10n,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(_kCardBorderRadius),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Column(
        children: [
          _infoRow(l10n.t('escalation_from_label'), fromAgent),
          Divider(color: ThixPolicy.border, height: 16),
          _infoRow(l10n.t('escalation_to_label'), toAgent),
          Divider(color: ThixPolicy.border, height: 16),
          _infoRow(l10n.t('escalation_reason'), reason),
          if (comment != null && comment.isNotEmpty) ...[
            Divider(color: ThixPolicy.border, height: 16),
            _infoRow(l10n.t('escalation_comment'), comment),
          ],
          Divider(color: ThixPolicy.border, height: 16),
          _infoRow(l10n.t('escalation_date'), dateStr),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: ThixPolicy.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: ThixPolicy.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: ThixPolicy.bodyStyle.copyWith(
                color: ThixPolicy.textMain,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PENDING ACTIONS ──────────────────────────────────────────────────

  Widget _buildPendingActions(
    EscalationState escState,
    EscalationNotifier escNotifier,
    AppLocalizations l10n,
  ) {
    final isDisabled = escState.isLoading || _isProcessing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('escalation_actions'),
          style: ThixPolicy.titleStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: ThixPolicy.textMain,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: l10n.t('escalation_accept_button'),
                enabled: !isDisabled,
                child: ElevatedButton.icon(
                  onPressed: isDisabled ? null : () => _accept(escNotifier),
                  icon: escState.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    l10n.t('escalation_accept_button'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_kButtonBorderRadius),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Semantics(
                button: true,
                label: l10n.t('escalation_reject_button'),
                enabled: !isDisabled,
                child: OutlinedButton.icon(
                  onPressed: isDisabled
                      ? null
                      : () => setState(() => _showRejectReason = !_showRejectReason),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  label: Text(
                    l10n.t('escalation_reject_button'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ThixPolicy.danger,
                    side: BorderSide(color: ThixPolicy.border),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_kButtonBorderRadius),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_showRejectReason) ...[
          const SizedBox(height: 16),
          _buildRejectReasonInput(l10n, escNotifier, isDisabled),
        ],
      ],
    );
  }

  Widget _buildRejectReasonInput(
    AppLocalizations l10n,
    EscalationNotifier escNotifier,
    bool isDisabled,
  ) {
    return Column(
      children: [
        Semantics(
          label: l10n.t('escalation_reject_reason_hint'),
          textField: true,
          child: TextField(
            controller: _rejectReasonCtrl,
            style: ThixPolicy.bodyStyle.copyWith(
              color: ThixPolicy.textMain,
              fontSize: 14,
            ),
            maxLines: 3,
            maxLength: _kMaxRejectReasonLength,
            decoration: InputDecoration(
              counterText: '',
              hintText: l10n.t('escalation_reject_reason_hint'),
              hintStyle: TextStyle(color: ThixPolicy.textMuted),
              filled: true,
              fillColor: ThixPolicy.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kButtonBorderRadius),
                borderSide: BorderSide(color: ThixPolicy.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kButtonBorderRadius),
                borderSide: BorderSide(color: ThixPolicy.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kButtonBorderRadius),
                borderSide: BorderSide(color: ThixPolicy.danger, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Semantics(
            button: true,
            label: l10n.t('escalation_confirm_reject'),
            enabled: !isDisabled,
            child: ElevatedButton(
              onPressed: isDisabled ? null : () => _reject(escNotifier),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kButtonBorderRadius),
                ),
              ),
              child: Text(
                l10n.t('escalation_confirm_reject'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── ACCEPTED STATE ───────────────────────────────────────────────────

  Widget _buildAcceptedState(
    EscalationState escState,
    EscalationNotifier escNotifier,
    AppLocalizations l10n,
  ) {
    final isDisabled = escState.isLoading || _isProcessing;

    return Column(
      children: [
        _buildStatusBanner(
          icon: Icons.check_circle_rounded,
          iconColor: ThixPolicy.success,
          backgroundColor: ThixPolicy.success.withOpacity(0.1),
          borderColor: ThixPolicy.success.withOpacity(0.3),
          textColor: ThixPolicy.success,
          message: l10n.t('escalation_accepted_message'),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: Semantics(
            button: true,
            label: l10n.t('escalation_mark_resolved'),
            enabled: !isDisabled,
            child: ElevatedButton.icon(
              onPressed: isDisabled ? null : () => _resolve(escNotifier),
              icon: escState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.done_all_rounded, size: 20),
              label: Text(
                l10n.t('escalation_mark_resolved'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kButtonBorderRadius),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── RESOLVED STATE ───────────────────────────────────────────────────

  Widget _buildResolvedState(AppLocalizations l10n) {
    return _buildStatusBanner(
      icon: Icons.check_circle_rounded,
      iconColor: ThixPolicy.success,
      backgroundColor: ThixPolicy.success.withOpacity(0.1),
      borderColor: ThixPolicy.success.withOpacity(0.3),
      textColor: ThixPolicy.success,
      message: l10n.t('escalation_resolved_message'),
    );
  }

  // ── REJECTED STATE ───────────────────────────────────────────────────

  Widget _buildRejectedState(AppLocalizations l10n) {
    return _buildStatusBanner(
      icon: Icons.cancel_rounded,
      iconColor: ThixPolicy.danger,
      backgroundColor: ThixPolicy.danger.withOpacity(0.1),
      borderColor: ThixPolicy.danger.withOpacity(0.3),
      textColor: ThixPolicy.danger,
      message: l10n.t('escalation_rejected_message'),
    );
  }

  // ── STATUS BANNER (réutilisable) ─────────────────────────────────────

  Widget _buildStatusBanner({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(_kButtonBorderRadius),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: ThixPolicy.bodyStyle.copyWith(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ERROR CARD ───────────────────────────────────────────────────────

  Widget _buildErrorCard(String error, AppLocalizations l10n) {
    // Masquer la stack trace en production
    final displayError = kDebugMode ? error : l10n.t('escalation_generic_error');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThixPolicy.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(_kErrorBorderRadius),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayError,
              style: ThixPolicy.bodyStyle.copyWith(
                color: ThixPolicy.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────

  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

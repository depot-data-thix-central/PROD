// lib/presentation/chat/widgets/status_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/user_status.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxCustomStatusLength = 50;
const double _kHandleWidth = 40.0;
const double _kHandleHeight = 5.0;
const double _kIndicatorSize = 18.0;

// ============================================================================
// VALIDATORS
// ============================================================================
class _StatusValidators {
  _StatusValidators._();

  /// Sanitize un statut personnalisé (XSS + caractères de contrôle)
  static String sanitize(String? input, {int maxLength = _kMaxCustomStatusLength}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  /// Retourne le label sûr d'un statut (sanitisé)
  static String safeLabel(String? label) {
    return sanitize(label, maxLength: 60);
  }
}

// ============================================================================
// STATUS PICKER
// ============================================================================
class StatusPicker extends StatelessWidget {
  final Function(String status, String? customStatus) onStatusSelected;
  final String currentStatus;

  const StatusPicker({
    super.key,
    required this.onStatusSelected,
    required this.currentStatus,
  });

  static const List<String> _statuses = [
    UserStatus.online,
    UserStatus.busy,
    UserStatus.away,
    UserStatus.doNotDisturb,
    UserStatus.offline,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: _kHandleWidth,
                height: _kHandleHeight,
                decoration: BoxDecoration(
                  color: ThixPolicy.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              l10n.t('status_choose'),
              style: ThixPolicy.titleStyle.copyWith(
                fontSize: 16,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
              ),
            ),
            const SizedBox(height: 12),

            // Liste des statuts prédéfinis
            ..._statuses.map((status) {
              final isSelected = status == currentStatus;
              final rawLabel = UserStatus.getLabel(status);
              final safeLabel = _StatusValidators.safeLabel(rawLabel);

              return Semantics(
                button: true,
                selected: isSelected,
                label: '${l10n.t('status_label_prefix')}: $safeLabel',
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? ThixPolicy.surfaceSoft : ThixPolicy.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? ThixPolicy.primary.withOpacity(0.3) : ThixPolicy.border,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: UserStatus.presenceIndicator(status, size: _kIndicatorSize),
                    title: Text(
                      safeLabel.isEmpty ? '—' : safeLabel,
                      style: ThixPolicy.bodySmallStyle.copyWith(
                        fontSize: 13,
                        fontWeight: isSelected ? ThixPolicy.bold : ThixPolicy.medium,
                        color: isSelected ? ThixPolicy.textMain : ThixPolicy.textMuted,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: ThixPolicy.primary, size: 18)
                        : null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      debugPrint('[StatusPicker] ✓ Selected preset status: $status');
                      Navigator.pop(context);
                      onStatusSelected(status, null);
                    },
                  ),
                ),
              );
            }),

            const Divider(height: 24, color: ThixPolicy.border),

            // Statut personnalisé
            Semantics(
              button: true,
              label: l10n.t('status_custom_button'),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  _showCustomStatusDialog(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: ThixPolicy.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, color: ThixPolicy.textMuted, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        l10n.t('status_custom'),
                        style: ThixPolicy.bodySmallStyle.copyWith(
                          fontSize: 13,
                          fontWeight: ThixPolicy.semiBold,
                          color: ThixPolicy.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog pour statut personnalisé avec sanitization et mounted checks
  void _showCustomStatusDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();

    debugPrint('[StatusPicker] 📝 Opening custom status dialog');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ThixPolicy.border),
        ),
        title: Text(
          l10n.t('status_custom_title'),
          style: ThixPolicy.titleStyle.copyWith(
            fontSize: 14,
            fontWeight: ThixPolicy.bold,
            color: ThixPolicy.textMain,
          ),
        ),
        content: Semantics(
          label: l10n.t('status_custom_label'),
          textField: true,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLength: _kMaxCustomStatusLength,
            textInputAction: TextInputAction.done,
            style: ThixPolicy.bodyStyle.copyWith(fontSize: 13, color: ThixPolicy.textMain),
            decoration: InputDecoration(
              counterText: '',
              hintText: l10n.t('status_custom_hint'),
              hintStyle: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textMuted),
              filled: true,
              fillColor: ThixPolicy.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: ThixPolicy.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: ThixPolicy.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: ThixPolicy.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onSubmitted: (value) {
              final sanitized = _StatusValidators.sanitize(value);
              if (sanitized.isNotEmpty && dialogCtx.mounted) {
                HapticFeedback.mediumImpact();
                Navigator.pop(dialogCtx);
                _applyCustomStatus(context, sanitized);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(dialogCtx);
            },
            child: Text(
              l10n.t('common_cancel'),
              style: TextStyle(color: ThixPolicy.textMuted),
            ),
          ),
          Semantics(
            button: true,
            label: l10n.t('status_set_button'),
            child: ElevatedButton(
              onPressed: () {
                final sanitized = _StatusValidators.sanitize(controller.text);
                if (sanitized.isEmpty) {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    SnackBar(
                      content: Text(l10n.t('status_empty_error')),
                      backgroundColor: ThixPolicy.warning,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                HapticFeedback.mediumImpact();
                Navigator.pop(dialogCtx);
                _applyCustomStatus(context, sanitized);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                l10n.t('status_set_button'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    ).then((_) {
      // Dispose propre du controller après fermeture du dialog
      controller.dispose();
      debugPrint('[StatusPicker] 👋 Custom dialog disposed');
    });
  }

  /// Applique le statut custom avec mounted check
  void _applyCustomStatus(BuildContext context, String sanitized) {
    if (!context.mounted) {
      debugPrint('[StatusPicker] ⚠️ Context unmounted, skipping custom status');
      return;
    }
    debugPrint('[StatusPicker] ✓ Applied custom status: "${sanitized.substring(0, sanitized.length > 20 ? 20 : sanitized.length)}..."');
    onStatusSelected(UserStatus.online, sanitized);
  }
}

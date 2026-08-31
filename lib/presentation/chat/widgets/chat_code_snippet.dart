// lib/presentation/chat/widgets/chat_code_snippet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxCodeLength = 5000;
const int _kMaxLanguageLength = 20;
const double _kCodeFontSize = 12.0;
const double _kCodeLineHeight = 1.4;
const double _kHeaderRadius = 12.0;
const double _kBadgeRadius = 6.0;
const double _kLanguageFontSize = 9.0;
const double _kCopyIconSize = 14.0;
const double _kCopyFontSize = 11.0;

// ============================================================================
// VALIDATORS
// ============================================================================
class _SnippetValidators {
  _SnippetValidators._();

  /// Sanitize le nom du langage (alphanumérique + quelques symboles)
  static String sanitizeLanguage(String? lang) {
    if (lang == null || lang.trim().isEmpty) return 'plaintext';
    final cleaned = lang.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_+-]'), '');
    if (cleaned.isEmpty) return 'plaintext';
    return cleaned.length > _kMaxLanguageLength
        ? cleaned.substring(0, _kMaxLanguageLength)
        : cleaned;
  }

  /// Sanitize le code : retire les caractères de contrôle dangereux
  /// mais GARDE les symboles de code (< > & etc.) car HighlightView les échappe
  static String sanitizeCode(String? code) {
    if (code == null || code.isEmpty) return '';
    // Retirer seulement les caractères de contrôle (pas les < > & du code)
    var s = code.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    // Tronquer si trop long
    if (s.length > _kMaxCodeLength) {
      s = s.substring(0, _kMaxCodeLength);
    }
    return s;
  }

  /// Vérifie si le code a été tronqué
  static bool isTruncated(String? code) {
    if (code == null) return false;
    return code.length > _kMaxCodeLength;
  }
}

// ============================================================================
// CHAT CODE SNIPPET
// ============================================================================

/// Affiche un snippet de code avec coloration syntaxique et bouton copier.
///
/// Le code est tronqué à [_kMaxCodeLength] caractères pour éviter les freezes.
/// Un avertissement est affiché si le code a été tronqué.
class ChatCodeSnippet extends StatelessWidget {
  /// Code source à afficher
  final String code;

  /// Langage de programmation (ex: 'dart', 'javascript', 'python')
  final String language;

  const ChatCodeSnippet({
    super.key,
    required this.code,
    this.language = 'text',
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeLang = _SnippetValidators.sanitizeLanguage(language);
    final safeCode = _SnippetValidators.sanitizeCode(code);
    final isTruncated = _SnippetValidators.isTruncated(code);

    // Langage pour HighlightView ('text' → 'plaintext')
    final highlightLang = safeLang == 'text' ? 'plaintext' : safeLang;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: ThixPolicy.surfaceSoft,
          borderRadius: BorderRadius.circular(_kHeaderRadius),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header : badge langage + bouton copier ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_kHeaderRadius),
                ),
                border: Border(bottom: BorderSide(color: ThixPolicy.border)),
              ),
              child: Row(
                children: [
                  // Badge langage
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ThixPolicy.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(_kBadgeRadius),
                      border: Border.all(
                        color: ThixPolicy.primary.withOpacity(0.15),
                      ),
                    ),
                    child: Text(
                      safeLang.toUpperCase(),
                      style: TextStyle(
                        color: ThixPolicy.primary,
                        fontSize: _kLanguageFontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Bouton copier
                  Semantics(
                    button: true,
                    label: l10n.t('snippet_copy_code'),
                    child: InkWell(
                      onTap: () => _handleCopy(context, l10n, safeCode),
                      borderRadius: BorderRadius.circular(_kBadgeRadius),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              color: ThixPolicy.textMuted,
                              size: _kCopyIconSize,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.t('snippet_copy'),
                              style: TextStyle(
                                fontSize: _kCopyFontSize,
                                color: ThixPolicy.textMuted,
                                fontWeight: FontWeight.w600,
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

            // ── Code avec coloration syntaxique ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: HighlightView(
                safeCode,
                language: highlightLang,
                theme: githubTheme,
                padding: EdgeInsets.zero,
                textStyle: TextStyle(
                  fontSize: _kCodeFontSize,
                  fontFamily: 'monospace',
                  height: _kCodeLineHeight,
                  color: ThixPolicy.textMain,
                ),
              ),
            ),

            // ── Avertissement de troncature ──
            if (isTruncated)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ThixPolicy.warning.withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(_kHeaderRadius),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: ThixPolicy.warning.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: ThixPolicy.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.t('snippet_truncated'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: ThixPolicy.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Gère la copie du code dans le presse-papier avec mounted check
  void _handleCopy(
    BuildContext context,
    AppLocalizations l10n,
    String codeToCopy,
  ) {
    HapticFeedback.selectionClick();
    debugPrint('[CodeSnippet] 📋 Copying ${codeToCopy.length} chars');

    Clipboard.setData(ClipboardData(text: codeToCopy));

    // Mounted check avant d'afficher le SnackBar
    if (!context.mounted) {
      debugPrint('[CodeSnippet] ⚠️ Context unmounted, skipping SnackBar');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.t('snippet_copied'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: ThixPolicy.success,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

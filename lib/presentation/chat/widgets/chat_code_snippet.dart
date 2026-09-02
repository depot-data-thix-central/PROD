// lib/presentation/chat/widgets/chat_code_snippet.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/highlight.dart' show highlight;

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

// Couleurs thème GitHub (adaptées au thème THIX)
const Color _kCodeTextColor = Color(0xFF24292F);
const Map<String, Color> _kGithubTheme = {
  'keyword': Color(0xFFCF222E),
  'string': Color(0xFF0A3069),
  'number': Color(0xFF0550AE),
  'comment': Color(0xFF6E7781),
  'function': Color(0xFF8250DF),
  'title': Color(0xFF8250DF),
  'params': Color(0xFF24292F),
  'built_in': Color(0xFF953800),
  'literal': Color(0xFF0550AE),
  'type': Color(0xFFCF222E),
  'attr': Color(0xFF0550AE),
  'selector': Color(0xFF116329),
  'class': Color(0xFF953800),
  'meta': Color(0xFF6E7781),
  'regexp': Color(0xFF0A3069),
  'symbol': Color(0xFF0550AE),
  'variable': Color(0xFF953800),
  'tag': Color(0xFF116329),
  'name': Color(0xFF0550AE),
  'attribute': Color(0xFF0550AE),
};

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
  static String sanitizeCode(String? code) {
    if (code == null || code.isEmpty) return '';
    var s = code.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
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
/// ✅ Utilise le package `highlight` (core) au lieu de `flutter_highlight` (abandonné)
/// ✅ Coloration syntaxique custom avec thème GitHub adapté
/// ✅ Troncature à [_kMaxCodeLength] caractères pour éviter les freezes
/// ✅ Sanitization des inputs + mounted checks
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      color: ThixPolicy.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(_kBadgeRadius),
                      border: Border.all(
                        color: ThixPolicy.primary.withValues(alpha: 0.15),
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
              child: _buildHighlightedCode(safeCode, highlightLang),
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
                  color: ThixPolicy.warning.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(_kHeaderRadius),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: ThixPolicy.warning.withValues(alpha: 0.3),
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

  /// Construit le widget de code avec coloration syntaxique custom
  Widget _buildHighlightedCode(String code, String lang) {
    try {
      final result = highlight.parse(
        code,
        language: lang,
        autoDetection: lang == 'plaintext',
      );

      final spans = _buildTextSpans(result.nodes ?? []);

      return SelectableText.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: _kCodeFontSize,
            fontFamily: 'monospace',
            height: _kCodeLineHeight,
            color: _kCodeTextColor,
          ),
          children: spans.isEmpty
              ? [TextSpan(text: code)]
              : spans,
        ),
      );
    } catch (e) {
      debugPrint('[CodeSnippet] ⚠️ Highlight failed for "$lang": $e');
      // Fallback : afficher le code brut sans coloration
      return SelectableText(
        code,
        style: const TextStyle(
          fontSize: _kCodeFontSize,
          fontFamily: 'monospace',
          height: _kCodeLineHeight,
          color: _kCodeTextColor,
        ),
      );
    }
  }

  /// Convertit les nœuds highlight en TextSpan
  List<TextSpan> _buildTextSpans(List<dynamic> nodes) {
    final spans = <TextSpan>[];
    for (final node in nodes) {
      if (node.value != null) {
        spans.add(TextSpan(
          text: node.value,
          style: _getStyleForClass(node.className),
        ));
      } else if (node.children != null) {
        spans.addAll(_buildTextSpans(node.children));
      }
    }
    return spans;
  }

  /// Retourne le style correspondant à une classe highlight
  TextStyle _getStyleForClass(String? className) {
    if (className == null) return const TextStyle();
    
    // Certaines classes sont composées (ex: "hljs-keyword")
    final simpleClass = className
        .split(' ')
        .firstWhere((c) => _kGithubTheme.containsKey(c), orElse: () => '');
    
    final color = _kGithubTheme[simpleClass];
    if (color != null) {
      return TextStyle(color: color);
    }
    
    // Pour les commentaires, ajouter italique
    if (simpleClass == 'comment') {
      return const TextStyle(
        color: Color(0xFF6E7781),
        fontStyle: FontStyle.italic,
      );
    }
    
    return const TextStyle();
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

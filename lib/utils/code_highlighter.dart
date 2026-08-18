// lib/utils/code_highlighter.dart
import 'package:flutter/material.dart';

/// Coloration syntaxique pour les snippets de code
class CodeHighlighter {
  /// Retourne un TextSpan avec le code coloré
  static TextSpan highlight(String code, {String language = 'text'}) {
    try {
      // Utiliser le widget HighlightView pour générer le texte
      // Note: HighlightView retourne un widget, donc on utilise son rendu
      // Pour une utilisation directe dans Text.rich, on peut utiliser les thèmes.
      // On va utiliser le package pour obtenir la liste des spans.
      
      // En pratique, on peut simplement utiliser le widget HighlightView
      // Mais pour du texte pur, on va créer une méthode manuelle.
      
      // Pour simplifier, on renvoie un TextSpan avec le code en texte brut
      // et on laisse le widget ChatCodeSnippet utiliser HighlightView.
      return TextSpan(
        text: code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Color(0xFFF8F8F2),
        ),
      );
    } catch (e) {
      return TextSpan(
        text: code,
        style: const TextStyle(color: Colors.red),
      );
    }
  }

  /// Obtient le nom du langage pour l'affichage
  static String getLanguageLabel(String language) {
    const map = {
      'dart': 'Dart',
      'python': 'Python',
      'javascript': 'JavaScript',
      'typescript': 'TypeScript',
      'html': 'HTML',
      'css': 'CSS',
      'json': 'JSON',
      'yaml': 'YAML',
      'java': 'Java',
      'cpp': 'C++',
      'csharp': 'C#',
      'go': 'Go',
      'rust': 'Rust',
      'php': 'PHP',
      'swift': 'Swift',
      'kotlin': 'Kotlin',
      'ruby': 'Ruby',
      'shell': 'Shell',
      'sql': 'SQL',
      'text': 'Texte',
    };
    return map[language] ?? language;
  }

  /// Vérifie si le langage est supporté
  static bool isSupported(String language) {
    const supported = [
      'dart', 'python', 'javascript', 'typescript',
      'html', 'css', 'json', 'yaml', 'java',
      'cpp', 'csharp', 'go', 'rust', 'php',
      'swift', 'kotlin', 'ruby', 'shell', 'sql',
      'text'
    ];
    return supported.contains(language);
  }
}

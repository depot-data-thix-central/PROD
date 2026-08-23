// lib/presentation/thix_ia/core/utils/text_utils.dart

/// ============================================================================
/// TEXT UTILS - Formatage & UI helpers
/// ============================================================================

class TextUtils {
  TextUtils._();

  static String truncate(String text, int maxLength, {String ellipsis = '...'}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String toTitleCase(String text) {
    return text
       .split(' ')
       .map((w) => w.isEmpty? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
       .join(' ');
  }

  static String initials(String name, {int max = 2}) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(max).map((e) => e[0].toUpperCase()).join();
  }

  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String projectStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'Brouillon';
      case 'active':
        return 'Actif';
      case 'analyzing':
        return 'En analyse';
      case 'paused':
        return 'En pause';
      case 'archived':
        return 'Archivé';
      default:
        return status;
    }
  }

  static String confidenceLabel(double score) {
    if (score >= 0.85) return 'Très fiable';
    if (score >= 0.6) return 'Fiable';
    if (score >= 0.4) return 'À vérifier';
    return 'Incertain';
  }

  static String slugify(String text) {
    return text
       .toLowerCase()
       .trim()
       .replaceAll(RegExp(r'[^\w\s-]'), '')
       .replaceAll(RegExp(r'\s+'), '-')
       .replaceAll(RegExp(r'-+'), '-');
  }

  static bool isNullOrEmpty(String? text) => text == null || text.trim().isEmpty;

  static String orDash(String? text) => isNullOrEmpty(text)? '—' : text!;
}

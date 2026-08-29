import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class CreatePostValidators {
  CreatePostValidators._();

  // Limites production
  static const int maxTitleLength = 200;
  static const int maxSubtitleLength = 2000;
  static const int maxVideoSizeBytes = 500 * 1024 * 1024; // 500 MB
  static const int maxEpisodes = 20;
  static const double minPrice = 0.99;
  static const double maxPrice = 999.99;

  static const Set<String> allowedVideoExtensions = {
    '.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'
  };

  /// Sanitize un champ texte (anti-XSS)
  static String sanitize(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // Supprime les caractères de contrôle
        .trim();
  }

  /// Valide le titre
  static String? validateTitle(String title) {
    final sanitized = sanitize(title);
    if (sanitized.isEmpty) return 'Le titre est requis';
    if (sanitized.length < 3) return 'Le titre doit contenir au moins 3 caractères';
    if (sanitized.length > maxTitleLength) {
      return 'Le titre ne peut pas dépasser $maxTitleLength caractères';
    }
    return null;
  }

  /// Valide la description
  static String? validateSubtitle(String subtitle) {
    if (subtitle.trim().isEmpty) return null; // Optionnel
    final sanitized = sanitize(subtitle);
    if (sanitized.length > maxSubtitleLength) {
      return 'La description ne peut pas dépasser $maxSubtitleLength caractères';
    }
    return null;
  }

  /// Valide un fichier vidéo
  static String? validateVideoFile(PlatformFile? file) {
    if (file == null) return 'Veuillez sélectionner une vidéo';

    // Validation taille
    if (file.size > maxVideoSizeBytes) {
      final maxMB = (maxVideoSizeBytes / 1024 / 1024).toInt();
      return 'La vidéo est trop volumineuse (max $maxMB MB)';
    }

    // Validation extension
    final ext = p.extension(file.name).toLowerCase();
    if (!allowedVideoExtensions.contains(ext)) {
      return 'Format vidéo non supporté : $ext';
    }

    // Validation bytes disponibles
    if (file.bytes == null && file.path == null) {
      return 'Impossible de lire le fichier vidéo';
    }

    return null;
  }

  /// Valide le prix pour contenu payant
  static String? validatePrice(String priceText, bool isPaid) {
    if (!isPaid) return null;

    final price = double.tryParse(priceText.trim());
    if (price == null || price <= 0) {
      return 'Veuillez indiquer un prix valide';
    }
    if (price < minPrice) {
      return 'Le prix minimum est de \$$minPrice';
    }
    if (price > maxPrice) {
      return 'Le prix maximum est de \$$maxPrice';
    }
    return null;
  }

  /// Valide le nombre d'épisodes
  static String? validateEpisodeCount(int currentCount) {
    if (currentCount >= maxEpisodes) {
      return 'Maximum $maxEpisodes épisodes autorisés';
    }
    return null;
  }
}

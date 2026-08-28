import 'dart:math';

/// ============================================================================
/// THIX ID — Validation & Formatage (v2 sécurisée)
/// ============================================================================
/// ⚠️ IMPORTANT : Ce service ne génère JAMAIS de THIX ID officiel.
/// La génération est effectuée UNIQUEMENT côté serveur via la RPC
/// `generate_thix_id(country_code)` appelée par `finalize_registration`.
///
/// Ce service est limité à :
///   - Validation de format et checksum
///   - Extraction d'informations (date, pays)
///   - Formatage pour affichage (masquage, UI)
///   - Normalisation d'entrées utilisateur
///
/// Format officiel (serveur) :
///   THIX-CD-MMYY-RANDOM5-CODE3-CHECK
///   Exemple: THIX-CD-0826-84723-XYZ-4
/// ============================================================================
class ThixIdService {
  // ==========================================================================
  // CONSTANTES ET EXEMPLES UI
  // ==========================================================================
  
  /// Exemple d'un identifiant de format Legacy (v1)
  static const String exampleV1 = 'THIX-CD-ABC-23-A1B2-3';
  
  /// Exemple d'un identifiant au format Actuel (v2)
  static const String exampleV2 = 'THIX-CD-0826-84723-XYZ-4';

  static const String _fixedCountryCode = 'CD';
  static const String _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  
  /// ⚠️ DÉPRÉCIÉ : Ne pas utiliser pour générer des IDs officiels.
  /// Réservé aux tests unitaires et mocks.
  @Deprecated('Utilisez la RPC serveur generate_thix_id() pour les IDs officiels')
  static final Random _rnd = Random.secure();

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  /// Vérifie si un THIX ID a un format valide et un checksum correct.
  /// ⚠️ Ne garantit PAS que l'ID a été émis officiellement par le serveur.
  static bool isValid(String thixId) {
    final v = normalize(thixId);
    
    final isCurrent = RegExp(r'^THIX-CD-\d{4}-\d{5}-[A-Z]{3}-\d$').hasMatch(v);
    final isLegacy = RegExp(r'^THIX-CD-[A-Z]{1,3}-\d{2}-[A-Z0-9]{4}-\d$').hasMatch(v);
    
    if (!isCurrent && !isLegacy) return false;
    
    final body = v.substring(0, v.length - 2);
    final expected = _checksumDigit(body);
    final got = int.tryParse(v.substring(v.length - 1)) ?? -1;
    return expected == got;
  }

  /// Valide et retourne la raison si invalide.
  static ({bool valid, String? reason}) validateWithReason(String thixId) {
    final v = normalize(thixId);
    
    if (v.length < 20) {
      return (valid: false, reason: 'ID trop court');
    }
    
    if (!v.startsWith('THIX-')) {
      return (valid: false, reason: 'Doit commencer par THIX-');
    }
    
    if (!v.contains('-CD-')) {
      return (valid: false, reason: 'Le pays doit être CD (République Démocratique du Congo)');
    }
    
    final isCurrent = RegExp(r'^THIX-CD-\d{4}-\d{5}-[A-Z]{3}-\d$').hasMatch(v);
    final isLegacy = RegExp(r'^THIX-CD-[A-Z]{1,3}-\d{2}-[A-Z0-9]{4}-\d$').hasMatch(v);
    
    if (!isCurrent && !isLegacy) {
      return (valid: false, reason: 'Format invalide');
    }
    
    final body = v.substring(0, v.length - 2);
    final expected = _checksumDigit(body);
    final got = int.tryParse(v.substring(v.length - 1)) ?? -1;
    
    if (expected != got) {
      return (valid: false, reason: 'Somme de contrôle invalide');
    }
    
    return (valid: true, reason: null);
  }

  // ==========================================================================
  // NORMALISATION
  // ==========================================================================

  /// Retourne le code pays (toujours CD).
  static String inferCountryCode({String? selectedOrUserProvided}) {
    return _fixedCountryCode;
  }

  /// Normalise une entrée utilisateur en THIX ID canonique.
  static String normalize(String input) {
    var v = input.trim().toUpperCase();
    v = v.replaceAll(RegExp(r'\s+'), '');
    v = v.replaceAll(RegExp(r'[^A-Z0-9-]'), '');

    if (v.startsWith('X-')) v = 'THI$v';
    if (v.startsWith('HIX-')) v = 'T$v';
    if (v.startsWith('IX-')) v = 'TH$v';

    if (!v.startsWith('THIX-')) {
      final looksLikeThixBody = RegExp(r'^[A-Z]{2}-').hasMatch(v);
      if (looksLikeThixBody) v = 'THIX-$v';
    }

    v = v.replaceAll(RegExp(r'-{2,}'), '-');
    v = v.replaceAll(RegExp(r'^-+'), '');
    v = v.replaceAll(RegExp(r'-+$'), '');
    
    final parts = v.split('-');
    if (parts.length >= 2 && parts[0] == 'THIX') {
      parts[1] = _fixedCountryCode;
      v = parts.join('-');
    }
    
    return v;
  }

  // ==========================================================================
  // EXTRACTION D'INFORMATIONS
  // ==========================================================================

  /// Extrait les informations d'un THIX ID valide.
  static Map<String, String>? extractInfo(String thixId) {
    if (!isValid(thixId)) return null;
    
    final normalized = normalize(thixId);
    final parts = normalized.split('-');
    
    if (parts.length >= 6 && RegExp(r'^\d{4}$').hasMatch(parts[2])) {
      return {
        'prefix': parts[0],
        'country': parts[1],
        'date': parts[2],
        'random': parts[3],
        'code': parts[4],
        'checksum': parts[5],
      };
    }
    
    if (parts.length >= 6) {
      return {
        'prefix': parts[0],
        'country': parts[1],
        'initials': parts[2],
        'year': parts[3],
        'token': parts[4],
        'checksum': parts[5],
      };
    }
    
    return null;
  }

  /// Extrait la date approximative (mois/année) du THIX ID.
  static DateTime? extractDate(String thixId) {
    final info = extractInfo(thixId);
    if (info == null) return null;
    
    final dateStr = info['date'];
    if (dateStr != null && dateStr.length == 4) {
      final month = int.tryParse(dateStr.substring(0, 2));
      final year = int.tryParse('20${dateStr.substring(2, 4)}');
      if (month != null && year != null && month >= 1 && month <= 12) {
        return DateTime(year, month);
      }
    }
    
    final yearStr = info['year'];
    if (yearStr != null && yearStr.length == 2) {
      final year = int.tryParse('20$yearStr');
      if (year != null) {
        return DateTime(year);
      }
    }
    
    return null;
  }

  // ==========================================================================
  // FORMATAGE
  // ==========================================================================

  /// Masque le THIX ID pour affichage (ex: THIX-CD-****-*****-***-*).
  static String mask(String thixId, {bool showLast = false}) {
    if (!isValid(thixId)) return thixId;
    
    final parts = normalize(thixId).split('-');
    if (parts.length >= 6) {
      if (showLast) {
        return '${parts[0]}-${parts[1]}-****-*****-${parts[4]}-${parts[5]}';
      }
      return '${parts[0]}-${parts[1]}-****-*****-***-*';
    }
    return thixId;
  }

  /// Formatage élégant pour UI.
  static String toDisplayString(String thixId) {
    final normalized = normalize(thixId);
    final parts = normalized.split('-');
    if (parts.length >= 4) {
      return '${parts[0]}-${parts[1]}-${parts[2]}-${parts[3]}...';
    }
    return normalized;
  }

  // ==========================================================================
  // COMPARAISON
  // ==========================================================================

  /// Compare deux THIX ID par date de création.
  static int compareByDate(String a, String b) {
    final dateA = extractDate(a);
    final dateB = extractDate(b);
    if (dateA == null && dateB == null) return 0;
    if (dateA == null) return 1;
    if (dateB == null) return -1;
    return dateB.compareTo(dateA);
  }

  /// Vérifie si un ID est plus récent qu'un autre.
  static bool isNewerThan(String thixId, String other) {
    return compareByDate(thixId, other) < 0;
  }

  // ==========================================================================
  // MÉTHODES PRIVÉES
  // ==========================================================================

  static int _checksumDigit(String input) {
    final cleaned = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final digits = <int>[];
    for (final r in cleaned.runes) {
      final ch = String.fromCharCode(r);
      final v = _charValue(ch);
      if (v >= 10) {
        digits.add(v ~/ 10);
        digits.add(v % 10);
      } else {
        digits.add(v);
      }
    }
    return _luhnCheckDigit(digits);
  }

  static int _charValue(String ch) {
    final c = ch.codeUnitAt(0);
    if (c >= 48 && c <= 57) return c - 48;
    if (c >= 65 && c <= 90) return 10 + (c - 65);
    return 0;
  }

  static int _luhnCheckDigit(List<int> digits) {
    var sum = 0;
    var alt = true;
    for (var i = digits.length - 1; i >= 0; i--) {
      var d = digits[i];
      if (alt) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      alt = !alt;
    }
    return (10 - (sum % 10)) % 10;
  }
}

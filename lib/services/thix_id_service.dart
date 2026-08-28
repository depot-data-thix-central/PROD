import 'dart:math';

/// ============================================================================
/// THIX ID — Validation & Formatage (Global / Multi-pays)
/// ============================================================================
class ThixIdService {
  // ==========================================================================
  // EXEMPLES UI
  // ==========================================================================
  static const String exampleV1 = 'THIX-CD-ABC-23-A1B2-3';
  static const String exampleV2 = 'THIX-FR-0826-84723-XYZ-4';
  
  static const String _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  /// Vérifie si un THIX ID a un format valide et un checksum correct.
  static bool isValid(String thixId) {
    final v = normalize(thixId);
    
    // [A-Z]{2} remplace "CD" pour accepter n'importe quel pays (FR, SN, US...)
    final isCurrent = RegExp(r'^THIX-[A-Z]{2}-\d{4}-\d{5}-[A-Z]{3}-\d$').hasMatch(v);
    final isLegacy = RegExp(r'^THIX-[A-Z]{2}-[A-Z]{1,3}-\d{2}-[A-Z0-9]{4}-\d$').hasMatch(v);
    
    if (!isCurrent && !isLegacy) return false;
    
    final body = v.substring(0, v.length - 2);
    final expected = _checksumDigit(body);
    final got = int.tryParse(v.substring(v.length - 1)) ?? -1;
    return expected == got;
  }

  /// Valide et retourne la raison si invalide.
  static ({bool valid, String? reason}) validateWithReason(String thixId) {
    final v = normalize(thixId);
    
    if (v.length < 20) return (valid: false, reason: 'ID trop court');
    if (!v.startsWith('THIX-')) return (valid: false, reason: 'Doit commencer par THIX-');
    
    final isCurrent = RegExp(r'^THIX-[A-Z]{2}-\d{4}-\d{5}-[A-Z]{3}-\d$').hasMatch(v);
    final isLegacy = RegExp(r'^THIX-[A-Z]{2}-[A-Z]{1,3}-\d{2}-[A-Z0-9]{4}-\d$').hasMatch(v);
    
    if (!isCurrent && !isLegacy) {
      if (!RegExp(r'^THIX-[A-Z]{2}-').hasMatch(v)) {
        return (valid: false, reason: 'Code pays invalide (doit être 2 lettres, ex: CD, FR, US)');
      }
      return (valid: false, reason: 'Format invalide');
    }
    
    final body = v.substring(0, v.length - 2);
    final expected = _checksumDigit(body);
    final got = int.tryParse(v.substring(v.length - 1)) ?? -1;
    
    if (expected != got) return (valid: false, reason: 'Somme de contrôle invalide');
    
    return (valid: true, reason: null);
  }

  // ==========================================================================
  // NORMALISATION
  // ==========================================================================

  /// Définit le code pays (CD par défaut si rien n'est fourni, mais dynamique)
  static String inferCountryCode({String? selectedOrUserProvided}) {
    if (selectedOrUserProvided != null && selectedOrUserProvided.length == 2) {
      return selectedOrUserProvided.toUpperCase();
    }
    return 'XX'; // Code générique international
  }

  /// Normalise une entrée utilisateur en THIX ID canonique.
  static String normalize(String input, {String? defaultCountry}) {
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
    
    // Si l'utilisateur a oublié le pays, on peut l'injecter
    final parts = v.split('-');
    if (parts.length >= 2 && parts[0] == 'THIX') {
      if (parts[1].length != 2 && defaultCountry != null) {
        parts.insert(1, defaultCountry.toUpperCase());
        v = parts.join('-');
      }
    }
    
    return v;
  }

  static String? canonicalizeOrNull(String input) {
    if (!isValid(input)) return null;
    return normalize(input);
  }

  // ==========================================================================
  // EXTRACTION D'INFORMATIONS
  // ==========================================================================
  static Map<String, String>? extractInfo(String thixId) {
    if (!isValid(thixId)) return null;
    
    final normalized = normalize(thixId);
    final parts = normalized.split('-');
    
    if (parts.length >= 6 && RegExp(r'^\d{4}$').hasMatch(parts[2])) {
      return {
        'prefix': parts[0],
        'country': parts[1], // Capture dynamique (CD, FR, US...)
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
    return null;
  }

  // ==========================================================================
  // FORMATAGE ET COMPARAISON
  // ==========================================================================
  static String mask(String thixId, {bool showLast = false}) {
    if (!isValid(thixId)) return thixId;
    final parts = normalize(thixId).split('-');
    if (parts.length >= 6) {
      if (showLast) return '${parts[0]}-${parts[1]}-****-*****-${parts[4]}-${parts[5]}';
      return '${parts[0]}-${parts[1]}-****-*****-***-*';
    }
    return thixId;
  }

  static String toDisplayString(String thixId) {
    final normalized = normalize(thixId);
    final parts = normalized.split('-');
    if (parts.length >= 4) return '${parts[0]}-${parts[1]}-${parts[2]}-${parts[3]}...';
    return normalized;
  }

  static int compareByDate(String a, String b) {
    final dateA = extractDate(a);
    final dateB = extractDate(b);
    if (dateA == null && dateB == null) return 0;
    if (dateA == null) return 1;
    if (dateB == null) return -1;
    return dateB.compareTo(dateA);
  }

  static bool isNewerThan(String thixId, String other) {
    return compareByDate(thixId, other) < 0;
  }

  // ==========================================================================
  // MÉTHODES PRIVÉES (Calcul du Checksum)
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

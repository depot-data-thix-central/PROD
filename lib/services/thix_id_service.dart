// lib/services/thix_id_service.dart
import 'dart:math';

/// THIX ID generation + validation utilities.
///
/// Country is FIXED to CD (République Démocratique du Congo).
/// 
/// Format actuel (recommandé) :
///   THIX-CD-MMYY-RANDOM5-CODE3-CHECK
///   Exemple: THIX-CD-0520-84723-XYZ-4
///
/// Format legacy (compatible) :
///   THIX-CD-INITIALS-YY-TOKEN4-CHECK
///   Exemple: THIX-CD-NLU-26-K8P4-7
class ThixIdService {
  // ==========================================================================
  // CONSTANTES
  // ==========================================================================
  
  /// Code pays fixé à la RDC
  static const String _fixedCountryCode = 'CD';
  
  /// Alphabet pour les lettres
  static const String _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  
  /// Générateur aléatoire sécurisé
  static final Random _rnd = Random.secure();
  
  /// Exemple du format actuel
  static const String exampleV2 = 'THIX-CD-0520-84723-XYZ-4';
  
  /// Exemple du format legacy
  static const String exampleV1 = 'THIX-CD-NLU-26-K8P4-7';

  // ==========================================================================
  // MÉTHODES PUBLIQUES - GÉNÉRATION
  // ==========================================================================

  /// Génère un THIX ID avec le pays fixé à CD
  static String generate({DateTime? now}) {
    final ts = now ?? DateTime.now();
    final mm = ts.month.toString().padLeft(2, '0');
    final yy = (ts.year % 100).toString().padLeft(2, '0');
    final mmyy = '$mm$yy';

    final random5 = List.generate(5, (_) => _rnd.nextInt(10)).join();
    final code3 = String.fromCharCodes(
      List.generate(3, (_) => _letters.codeUnitAt(_rnd.nextInt(_letters.length)))
    );
    
    final body = 'THIX-$_fixedCountryCode-$mmyy-$random5-$code3';
    final checksum = _checksumDigit(body);
    return '$body-$checksum';
  }

  /// Génère un THIX ID avec un préfixe optionnel (ex: pour entreprise)
  static String generateWithPrefix({
    String? prefix,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    final mm = ts.month.toString().padLeft(2, '0');
    final yy = (ts.year % 100).toString().padLeft(2, '0');
    final mmyy = '$mm$yy';

    final random5 = List.generate(5, (_) => _rnd.nextInt(10)).join();
    final code3 = String.fromCharCodes(
      List.generate(3, (_) => _letters.codeUnitAt(_rnd.nextInt(_letters.length)))
    );
    
    final prefixPart = (prefix != null && prefix.isNotEmpty) ? '-$prefix' : '';
    final body = 'THIX-$_fixedCountryCode$prefixPart-$mmyy-$random5-$code3';
    final checksum = _checksumDigit(body);
    return '$body-$checksum';
  }

  /// Génère plusieurs THIX ID d'un coup (batch)
  static List<String> generateBatch({
    int count = 10,
    DateTime? now,
  }) {
    return List.generate(count, (_) => generate(now: now));
  }

  /// Génère des THIX ID uniques sans doublon
  static List<String> generateUniqueBatch({
    int count = 10,
    DateTime? now,
  }) {
    final Set<String> ids = {};
    while (ids.length < count) {
      ids.add(generate(now: now));
    }
    return ids.toList();
  }

  // ==========================================================================
  // MÉTHODES PUBLIQUES - NORMALISATION
  // ==========================================================================

  /// Retourne le code pays (toujours CD)
  static String inferCountryCode({String? selectedOrUserProvided}) {
    return _fixedCountryCode;
  }

  /// Normalise une entrée utilisateur en THIX ID canonique
  static String normalize(String input) {
    var v = input.trim().toUpperCase();
    v = v.replaceAll(RegExp(r'\s+'), '');
    v = v.replaceAll(RegExp(r'[^A-Z0-9-]'), '');

    // Corrige les préfixes partiels
    if (v.startsWith('X-')) v = 'THI$v';
    if (v.startsWith('HIX-')) v = 'T$v';
    if (v.startsWith('IX-')) v = 'TH$v';

    // Ajoute le préfixe manquant
    if (!v.startsWith('THIX-')) {
      final looksLikeThixBody = RegExp(r'^[A-Z]{2}-').hasMatch(v);
      if (looksLikeThixBody) v = 'THIX-$v';
    }

    // Nettoie les tirets en double
    v = v.replaceAll(RegExp(r'-{2,}'), '-');
    v = v.replaceAll(RegExp(r'^-+'), '');
    v = v.replaceAll(RegExp(r'-+$'), '');
    
    // Force le code pays à CD
    final parts = v.split('-');
    if (parts.length >= 2 && parts[0] == 'THIX') {
      parts[1] = _fixedCountryCode;
      v = parts.join('-');
    }
    
    return v;
  }

  // ==========================================================================
  // MÉTHODES PUBLIQUES - VALIDATION
  // ==========================================================================

  /// Vérifie si un THIX ID est valide
  static bool isValid(String thixId) {
    final v = normalize(thixId);
    
    // Format actuel
    final isCurrent = RegExp(r'^THIX-CD-\d{4}-\d{5}-[A-Z]{3}-\d$').hasMatch(v);
    // Format legacy
    final isLegacy = RegExp(r'^THIX-CD-[A-Z]{1,3}-\d{2}-[A-Z0-9]{4}-\d$').hasMatch(v);
    
    if (!isCurrent && !isLegacy) return false;
    
    final body = v.substring(0, v.length - 2);
    final expected = _checksumDigit(body);
    final got = int.tryParse(v.substring(v.length - 1)) ?? -1;
    return expected == got;
  }

  /// Valide et retourne la raison si invalide
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
      return (valid: false, reason: 'Somme de contrôle invalide (attendu: $expected, reçu: $got)');
    }
    
    return (valid: true, reason: null);
  }

  // ==========================================================================
  // MÉTHODES PUBLIQUES - EXTRACTION D'INFORMATIONS
  // ==========================================================================

  /// Extrait les informations d'un THIX ID valide
  static Map<String, String>? extractInfo(String thixId) {
    if (!isValid(thixId)) return null;
    
    final normalized = normalize(thixId);
    final parts = normalized.split('-');
    
    // Format actuel (6 parties)
    if (parts.length >= 6 && RegExp(r'^\d{4}$').hasMatch(parts[2])) {
      return {
        'prefix': parts[0],      // THIX
        'country': parts[1],     // CD
        'date': parts[2],        // MMYY
        'random': parts[3],      // 5 chiffres
        'code': parts[4],        // 3 lettres
        'checksum': parts[5],    // 1 chiffre
      };
    }
    
    // Format legacy
    if (parts.length >= 6) {
      return {
        'prefix': parts[0],      // THIX
        'country': parts[1],     // CD
        'initials': parts[2],    // Initiales (1-3 lettres)
        'year': parts[3],        // YY (2 chiffres)
        'token': parts[4],       // 4 caractères
        'checksum': parts[5],    // 1 chiffre
      };
    }
    
    return null;
  }

  /// Extrait la date approximative (mois/année) du THIX ID
  static DateTime? extractDate(String thixId) {
    final info = extractInfo(thixId);
    if (info == null) return null;
    
    // Format actuel
    final dateStr = info['date'];
    if (dateStr != null && dateStr.length == 4) {
      final month = int.tryParse(dateStr.substring(0, 2));
      final year = int.tryParse('20${dateStr.substring(2, 4)}');
      if (month != null && year != null && month >= 1 && month <= 12) {
        return DateTime(year, month);
      }
    }
    
    // Format legacy (seulement l'année)
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
  // MÉTHODES PUBLIQUES - FORMATAGE
  // ==========================================================================

  /// Masque le THIX ID pour affichage (ex: THIX-CD-****-*****-***-*)
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

  /// Formatage élégant pour UI
  static String toDisplayString(String thixId) {
    final normalized = normalize(thixId);
    final parts = normalized.split('-');
    if (parts.length >= 4) {
      return '${parts[0]}-${parts[1]}-${parts[2]}-${parts[3]}...';
    }
    return normalized;
  }

  // ==========================================================================
  // MÉTHODES PUBLIQUES - COMPARAISON
  // ==========================================================================

  /// Compare deux THIX ID par date de création
  static int compareByDate(String a, String b) {
    final dateA = extractDate(a);
    final dateB = extractDate(b);
    if (dateA == null && dateB == null) return 0;
    if (dateA == null) return 1;
    if (dateB == null) return -1;
    return dateB.compareTo(dateA);
  }

  /// Vérifie si un ID est plus récent qu'un autre
  static bool isNewerThan(String thixId, String other) {
    return compareByDate(thixId, other) < 0;
  }

  // ==========================================================================
  // MÉTHODES PUBLIQUES - STATISTIQUES
  // ==========================================================================

  /// Statistiques sur une liste de THIX ID
  static Map<String, dynamic> getStatistics(List<String> ids) {
    final valid = ids.where((id) => isValid(id)).length;
    final invalid = ids.length - valid;
    final unique = ids.toSet().length;
    
    final years = <String>[];
    for (final id in ids) {
      final date = extractDate(id);
      if (date != null) {
        years.add(date.year.toString());
      }
    }
    
    final yearCount = <String, int>{};
    for (final year in years) {
      yearCount[year] = (yearCount[year] ?? 0) + 1;
    }
    
    return {
      'total': ids.length,
      'valid': valid,
      'invalid': invalid,
      'unique': unique,
      'duplicates': ids.length - unique,
      'years': yearCount,
    };
  }

  // ==========================================================================
  // MÉTHODES PRIVÉES
  // ==========================================================================

  /// Calcule le checksum (chiffre de contrôle)
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

  /// Convertit un caractère en valeur numérique
  static int _charValue(String ch) {
    final c = ch.codeUnitAt(0);
    if (c >= 48 && c <= 57) return c - 48;      // 0-9
    if (c >= 65 && c <= 90) return 10 + (c - 65); // A-Z → 10-35
    return 0;
  }

  /// Algorithme de Luhn modifié
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

  /// Tente de corriger un THIX ID mal saisi
  static String? canonicalizeOrNull(String input) {
    final v = normalize(input);

    // Format actuel sans checksum
    final currentNoCheck = RegExp(r'^THIX-CD-\d{4}-\d{5}-[A-Z]{3}$');
    if (currentNoCheck.hasMatch(v)) {
      final c = _checksumDigit(v);
      return '$v-$c';
    }

    // Format actuel avec checksum (peut-être faux)
    final currentMaybe = RegExp(r'^(THIX-CD-\d{4}-\d{5}-[A-Z]{3})-(\d)$');
    final m1 = currentMaybe.firstMatch(v);
    if (m1 != null) {
      final body = m1.group(1)!;
      final c = _checksumDigit(body);
      return '$body-$c';
    }

    // Format legacy sans checksum
    final legacyNoCheck = RegExp(r'^THIX-CD-[A-Z]{1,3}-\d{2}-[A-Z0-9]{4}$');
    if (legacyNoCheck.hasMatch(v)) {
      final c = _checksumDigit(v);
      return '$v-$c';
    }

    // Format legacy avec checksum (peut-être faux)
    final legacyMaybe = RegExp(r'^(THIX-CD-[A-Z]{1,3}-\d{2}-[A-Z0-9]{4})-(\d)$');
    final m2 = legacyMaybe.firstMatch(v);
    if (m2 != null) {
      final body = m2.group(1)!;
      final c = _checksumDigit(body);
      return '$body-$c';
    }

    return null;
  }
}

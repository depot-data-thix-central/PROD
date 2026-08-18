// lib/presentation/thix_sante/core/thix_id_validator.dart
// =============================================================================
// Module: THIX SANTE - Core - Validateur officiel THIX ID
// Role: Génération + Validation officielle + Compatibilité recherche doctors
// Format officiel: THIX-{PAYS}-{MMAA}-{5 chiffres}-{3 lettres}-{cle}
// Exemple: THIX-CD-0726-48392-NJK-7
// Compat: Accepte aussi THIX-DOC001 pour test/doctors
// =============================================================================

import 'dart:math';

class ThixIdValidator {
  ThixIdValidator._();

  static const Map<String, String> _countryCodes = {
    'Republique Democratique du Congo': 'CD',
    'Rwanda': 'RW',
    'Burundi': 'BI',
    'Ouganda': 'UG',
    'Angola': 'AO',
    'Cote dIvoire': 'CI',
    'Senegal': 'SN',
    'Cameroun': 'CM',
    'France': 'FR',
    'Belgique': 'BE',
    'Canada': 'CA',
    'Etats-Unis': 'US',
    'Autre': 'XX',
  };

  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  /// Génère un THIX ID officiel - INCHANGÉ de ton mémoire
  static String generate(String countryName) {
    final Random secureRand = Random.secure();
    final String codePays = _countryCodes[countryName]?? 'XX';
    final DateTime now = DateTime.now();
    final String datePart = '${now.month.toString().padLeft(2, '0')}${now.year.toString().substring(2)}';
    final int variablePart = secureRand.nextInt(90000) + 10000;
    final String complementPart = String.fromCharCodes(
      Iterable.generate(3, (_) => _alphabet.codeUnitAt(secureRand.nextInt(_alphabet.length))),
    );
    final int checkDigit = secureRand.nextInt(10);
    return 'THIX-$codePays-$datePart-$variablePart-$complementPart-$checkDigit';
  }

  /// Format officiel strict (mémoire)
  static final RegExp _officialPattern = RegExp(r'^THIX-[A-Z]{2}-\d{4}-\d{5}-[A-Z]{3}-\d$');

  /// Format simple pour doctors de test / QR rapide
  static final RegExp _simplePattern = RegExp(r'^THIX-[A-Z0-9]{3,20}$');

  /// Validation flexible pour UI : accepte officiel OU simple
  static bool isValidFormat(String thixId) {
    if (thixId.isEmpty) return false;
    final cleanId = clean(thixId);
    // Accepte officiel OU simple OU juste ID court (DOC001)
    return _officialPattern.hasMatch(cleanId) ||
           _simplePattern.hasMatch(cleanId) ||
           RegExp(r'^[A-Z0-9]{6,}$').hasMatch(cleanId);
  }

  /// Validation stricte officielle uniquement (pour inscription patient)
  static bool isStrictOfficialFormat(String thixId) {
    if (thixId.isEmpty) return false;
    return _officialPattern.hasMatch(clean(thixId));
  }

  static String clean(String thixId) => thixId.trim().toUpperCase().replaceAll(' ', '');

  /// Nettoie et normalise pour recherche DB
  static String normalizeForSearch(String thixId){
    var c = clean(thixId);
    // Enlève tirets pour comparaison fallback
    return c;
  }

  static List<String> get availableCountries => _countryCodes.keys.toList();
  static String getCountryCode(String country) => _countryCodes[country]?? 'XX';

  /// Génère THIX ID court pour doctors de test (non officiel)
  static String generateSimpleDoctorId(){
    final rand = Random.secure();
    final num = rand.nextInt(900)+100;
    return 'THIX-DOC${num.toString().padLeft(3,'0')}';
  }
}

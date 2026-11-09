// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — COUCHE CORE
//  Fichier  : lib/presentation/thix_portfolio/core/thix_business_id.dart
//  Module   : THIX Portfolio Business (sites entreprises par identifiant)
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.0 — Novembre 2026
// ════════════════════════════════════════════════════════════════════════════
//
//  FORMAT PUBLIC (v2) : THIX-BIZ-YYMM-SSSSS-LLL-K
//    • YYMM   : année (2 chiffres) + mois de création        → 2611
//    • SSSSS  : séquence aléatoire 5 chiffres (Random.secure) → 48259
//    • LLL    : 3 lettres, alphabet sans I ni O (ambigus)     → KQT
//    • K      : clé de contrôle (SHA-256 → mod 10)            → 7
//
//  FORMAT LEGACY (v1) : THIX-BIZ-000001 (séquentiel interne, toujours accepté)
//
//  Exemple complet : THIX-BIZ-2611-48259-KQT-7
//
//  Responsabilités :
//    1. Générer des identifiants uniques, vérifiables et lisibles ;
//    2. Normaliser / réhydrater toute saisie utilisateur (espaces, minuscules,
//       forme compacte scannée depuis un QR) ;
//    3. Valider la clé de contrôle avant tout appel réseau (offline-first) ;
//    4. Fournir les représentations : display, compact (QR), urlSlug, masked.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Exception levée lorsqu'une saisie n'est pas un THIX ID Business valide.
@immutable
class ThixIdFormatException implements Exception {
  const ThixIdFormatException(this.input, [this.reason]);

  /// Saisie brute à l'origine de l'erreur.
  final String input;

  /// Explication technique optionnelle (logs / debug uniquement).
  final String? reason;

  @override
  String toString() => 'ThixIdFormatException: « $input » n\'est pas un '
      'THIX ID Business valide'
      '${reason == null ? '.' : ' ($reason)'}';
}

/// Composants décomposés d'un identifiant v2 (immutable, testable).
@immutable
class ThixBusinessIdParts {
  const ThixBusinessIdParts({
    required this.yearMonth,
    required this.sequence,
    required this.letters,
    required this.checkKey,
  });

  /// `YYMM` — ex. `2611` pour novembre 2026.
  final String yearMonth;

  /// `SSSSS` — séquence aléatoire 5 chiffres.
  final String sequence;

  /// `LLL` — 3 lettres de l'alphabet sûr.
  final String letters;

  /// `K` — clé de contrôle (0-9).
  final String checkKey;

  /// Mois de création déduit de l'identifiant (utile stats / tri).
  DateTime get creationMonth {
    final yy = int.parse(yearMonth.substring(0, 2));
    final mm = int.parse(yearMonth.substring(2, 4));
    return DateTime(2000 + yy, mm);
  }

  @override
  String toString() =>
      'ThixBusinessIdParts(yearMonth: $yearMonth, sequence: $sequence, '
      'letters: $letters, checkKey: $checkKey)';
}

/// Identifiant unique d'une entreprise THIX (value object immutable).
///
/// ```dart
/// final id = ThixBusinessId.generate();          // création
/// final ok = ThixBusinessId.isValid(saisieUser); // validation offline
/// final parsed = ThixBusinessId.tryParse(qrData); // lecture QR / recherche
/// ```
@immutable
class ThixBusinessId {
  const ThixBusinessId._({
    required this.raw,
    required this.isLegacy,
    this.parts,
  });

  // ── Constantes publiques ──────────────────────────────────────────────────

  /// Préfixe commun à tous les identifiants entreprises.
  static const String prefix = 'THIX-BIZ';

  /// Préfixe compact (QR, saisie vocale, URL courtes).
  static const String compactPrefix = 'THIXBIZ';

  /// Nombre de tentatives avant échec de [generateUnique].
  static const int maxUniqueAttempts = 16;

  // ── Constantes internes ───────────────────────────────────────────────────

  /// Alphabet volontairement privé de I et O (confusion avec 1 et 0).
  static const String _letterPool = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const String _digitPool = '0123456789';

  static final RegExp _v2Regex =
      RegExp(r'^THIX-BIZ-(\d{4})-(\d{5})-([A-Z]{3})-(\d)$');
  static final RegExp _legacyRegex = RegExp(r'^THIX-BIZ-(\d{6})$');
  static final RegExp _compactV2Regex =
      RegExp(r'^THIXBIZ(\d{4})(\d{5})([A-Z]{3})(\d)$');
  static final RegExp _whitespaceRegex = RegExp(r'\s+');

  // ── État ──────────────────────────────────────────────────────────────────

  /// Forme canonique : `THIX-BIZ-2611-48259-KQT-7`.
  final String raw;

  /// Composants structurés (null pour un identifiant legacy).
  final ThixBusinessIdParts? parts;

  /// `true` si format v1 séquentiel (`THIX-BIZ-000001`).
  final bool isLegacy;

  // ── Génération ────────────────────────────────────────────────────────────

  /// Génère un nouvel identifiant v2, cryptographiquement aléatoire.
  ///
  /// [now] et [random] sont injectables pour les tests unitaires.
  factory ThixBusinessId.generate({DateTime? now, Random? random}) {
    final date = now ?? DateTime.now();
    final rnd = random ?? Random.secure();

    final yearMonth =
        '${(date.year % 100).toString().padLeft(2, '0')}'
        '${date.month.toString().padLeft(2, '0')}';
    final sequence = _randomToken(rnd, 5, _digitPool);
    final letters = _randomToken(rnd, 3, _letterPool);

    final core = '$prefix-$yearMonth-$sequence-$letters';
    final key = computeCheckKey(core);
    final raw = '$core-$key';

    return ThixBusinessId._(
      raw: raw,
      isLegacy: false,
      parts: ThixBusinessIdParts(
        yearMonth: yearMonth,
        sequence: sequence,
        letters: letters,
        checkKey: key,
      ),
    );
  }

  /// Génère un identifiant **garanti libre** en interrogeant [exists]
  /// (typiquement : requête Supabase `select id ... eq('thix_id', candidate)`).
  ///
  /// Lève [StateError] après [maxAttempts] collisions (quasi impossible :
  /// espace de 10^5 × 26^3 ≈ 1,75 milliard de combinaisons par mois).
  static Future<ThixBusinessId> generateUnique(
    Future<bool> Function(String candidate) exists, {
    Random? random,
    int maxAttempts = maxUniqueAttempts,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final candidate = ThixBusinessId.generate(random: random);
      if (!await exists(candidate.raw)) return candidate;
    }
    throw StateError(
      'THIX ID : impossible de générer un identifiant business unique '
      'après $maxAttempts tentatives.',
    );
  }

  static String _randomToken(Random rnd, int length, String pool) =>
      List.generate(length, (_) => pool[rnd.nextInt(pool.length)]).join();

  // ── Normalisation & analyse ───────────────────────────────────────────────

  /// Normalise une saisie utilisateur : trim, majuscules, espaces supprimés.
  /// Ne supprime **pas** les tirets (forme canonique conservée).
  static String normalize(String input) =>
      input.trim().toUpperCase().replaceAll(_whitespaceRegex, '');

  /// Analyse stricte : lève [ThixIdFormatException] si invalide.
  /// À utiliser côté création / admin uniquement.
  factory ThixBusinessId.parse(String input) {
    final parsed = tryParse(input);
    if (parsed == null) throw ThixIdFormatException(input);
    return parsed;
  }

  /// Analyse tolérante : retourne `null` si invalide.
  /// Accepte : forme canonique, forme compacte (QR), minuscules, espaces.
  static ThixBusinessId? tryParse(String input) {
    var candidate = normalize(input);
    if (candidate.isEmpty) return null;

    // Forme compacte scannée (QR / NFC / saisie vocale) → réhydratation.
    final compact = _compactV2Regex.firstMatch(candidate);
    if (compact != null) {
      candidate = '$prefix-${compact.group(1)}-${compact.group(2)}'
          '-${compact.group(3)}-${compact.group(4)}';
    }

    // Format v2 avec vérification de la clé de contrôle.
    final v2 = _v2Regex.firstMatch(candidate);
    if (v2 != null) {
      final core = '$prefix-${v2.group(1)}-${v2.group(2)}-${v2.group(3)}';
      if (computeCheckKey(core) != v2.group(4)) return null;
      return ThixBusinessId._(
        raw: candidate,
        isLegacy: false,
        parts: ThixBusinessIdParts(
          yearMonth: v2.group(1)!,
          sequence: v2.group(2)!,
          letters: v2.group(3)!,
          checkKey: v2.group(4)!,
        ),
      );
    }

    // Format legacy v1 (séquentiel interne).
    if (_legacyRegex.hasMatch(candidate)) {
      return ThixBusinessId._(raw: candidate, isLegacy: true);
    }

    return null;
  }

  /// Validation rapide, 100 % offline (idéale dans la barre de recherche
  /// avant tout appel réseau).
  static bool isValid(String input) => tryParse(input) != null;

  // ── Clé de contrôle ───────────────────────────────────────────────────────

  /// Calcule la clé `K` d'un core `THIX-BIZ-YYMM-SSSSS-LLL` (SHA-256 mod 10).
  static String computeCheckKey(String core) =>
      '${sha256.convert(utf8.encode(core)).bytes.first % 10}';

  /// Revérifie la clé de contrôle de l'instance courante.
  bool verifyChecksum() {
    if (isLegacy) return true;
    final core = raw.substring(0, raw.lastIndexOf('-'));
    return computeCheckKey(core) == parts?.checkKey;
  }

  // ── Représentations ───────────────────────────────────────────────────────

  /// Forme compacte sans tirets : `THIXBIZ261148259KQT7` (QR, NFC, vocal).
  String get compact => raw.replaceAll('-', '');

  /// Slug URL minuscule : `thix-biz-2611-48259-kqt-7` (route `/b/:id`).
  String get urlSlug => raw.toLowerCase();

  /// Forme canonique affichée à l'écran.
  String get display => raw;

  /// Forme masquée pour listes publiques / logs : `THIX-BIZ-2611-•••••-KQT-•`.
  String get masked {
    if (isLegacy) return raw;
    final p = parts!;
    return '$prefix-${p.yearMonth}-•••••-${p.letters}-•';
  }

  // ── Value object ──────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ThixBusinessId && other.raw == raw);

  @override
  int get hashCode => raw.hashCode;

  @override
  String toString() => raw;
}

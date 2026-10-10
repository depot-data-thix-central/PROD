import 'package:flutter/material.dart';

/// ============================================================================
/// CurrencyRegistry
/// ============================================================================
///
/// Registre centralisé de toutes les devises supportées par THIX.
///
/// Couvre :
/// - 40+ devises africaines (UEMOA, CEMAC, SADC, EAC, etc.)
/// - Devises internationales majeures (USD, EUR, GBP, CNY)
/// - Métadonnées : symbole, code ISO, locale, format décimal
///
/// Chaque devise est identifiée par son code ISO 4217.
/// ============================================================================
class CurrencyRegistry {
  CurrencyRegistry._();

  static const List<ThixCurrency> all = [
    // ════════════════════════════════════════════════════════════
    // ZONE UEMOA — Franc CFA (XOF) — 8 pays
    // ════════════════════════════════════════════════════════════
    ThixCurrency(
      code: 'XOF',
      name: 'Franc CFA (UEMOA)',
      symbol: 'CFA',
      locale: 'fr_FR',
      decimalDigits: 0,
      region: CurrencyRegion.westAfrica,
      countries: ['Sénégal', 'Mali', 'Burkina Faso', 'Niger', 'Bénin', 'Togo', 'Côte d\'Ivoire', 'Guinée-Bissau'],
      isPopular: true,
    ),

    // ════════════════════════════════════════════════════════════
    // ZONE CEMAC — Franc CFA (XAF) — 6 pays
    // ════════════════════════════════════════════════════════════
    ThixCurrency(
      code: 'XAF',
      name: 'Franc CFA (CEMAC)',
      symbol: 'FCFA',
      locale: 'fr_FR',
      decimalDigits: 0,
      region: CurrencyRegion.centralAfrica,
      countries: ['Cameroun', 'Congo', 'Gabon', 'Tchad', 'RCA', 'Guinée Équatoriale'],
      isPopular: true,
    ),

    // ════════════════════════════════════════════════════════════
    // AFRIQUE CENTRALE & EST
    // ════════════════════════════════════════════════════════════
    ThixCurrency(
      code: 'CDF',
      name: 'Franc congolais',
      symbol: 'CDF',
      locale: 'fr_FR',
      decimalDigits: 0,
      region: CurrencyRegion.centralAfrica,
      countries: ['RD Congo'],
      isPopular: true,
    ),
    ThixCurrency(
      code: 'RWF',
      name: 'Franc rwandais',
      symbol: 'RF',
      locale: 'fr_FR',
      decimalDigits: 0,
      region: CurrencyRegion.eastAfrica,
      countries: ['Rwanda'],
    ),
    ThixCurrency(
      code: 'BIF',
      name: 'Franc burundais',
      symbol: 'FBu',
      locale: 'fr_FR',
      decimalDigits: 0,
      region: CurrencyRegion.eastAfrica,
      countries: ['Burundi'],
    ),

    // ════════════════════════════════════════════════════════════
    // AFRIQUE DE L'EST (EAC) — Shillings
    // ════════════════════════════════════════════════════════════
    ThixCurrency(
      code: 'KES',
      name: 'Shilling kényan',
      symbol: 'KSh',
      locale: 'en_KE',
      decimalDigits: 2,
      region: CurrencyRegion.eastAfrica,
      countries: ['Kenya'],
      isPopular: true,
    ),
    ThixCurrency(
      code: 'TZS',
      name: 'Shilling tanzanien',
      symbol: 'TSh',
      locale: 'en_TZ',
      decimalDigits: 0,
      region: CurrencyRegion.eastAfrica,
      countries: ['Tanzanie'],
    ),
    ThixCurrency(
      code: 'UGX',
      name: 'Shilling ougandais',
      symbol: 'USh',
      locale: 'en_UG',
      decimalDigits: 0,
      region: CurrencyRegion.eastAfrica,
      countries: ['Ouganda'],
    ),
    ThixCurrency(
      code: 'ETB',
      name: 'Birr éthiopien',
      symbol: 'Br',
      locale: 'am_ET',
      decimalDigits: 2,
      region: CurrencyRegion.eastAfrica,
      countries: ['Éthiopie'],
    ),
    ThixCurrency(
      code: 'SOS',
      name: 'Shilling somalien',
      symbol: 'Sh.So.',
      locale: 'so_SO',
      decimalDigits: 0,
      region: CurrencyRegion.eastAfrica,
      countries: ['Somalie'],
    ),
    ThixCurrency(
      code: 'DJF',
      name: 'Franc djiboutien',
      symbol: 'Fdj',
      locale: 'fr_DJ',
      decimalDigits: 0,
      region: CurrencyRegion.eastAfrica,
      countries: ['Djibouti'],
    ),
    ThixCurrency(
      code: 'ERN',
      name: 'Nakfa érythréen',
      symbol: 'Nkf',
      locale: 'en_ER',
      decimalDigits: 2,
      region: CurrencyRegion.eastAfrica,
      countries: ['Érythrée'],
    ),
    ThixCurrency(
      code: 'SDG',
      name: 'Livre soudanaise',
      symbol: 'ج.س.',
      locale: 'ar_SD',
      decimalDigits: 2,
      region: CurrencyRegion.northAfrica,
      countries: ['Soudan'],
    ),
    ThixCurrency(
      code: 'SSP',
      name: 'Livre sud-soudanaise',
      symbol: 'SS£',
      locale: 'en_SS',
      decimalDigits: 2,
      region: CurrencyRegion.eastAfrica,
      countries: ['Soudan du Sud'],
    ),

    // ════════════════════════════════════════════════════════════
    // AFRIQUE DE L'OUEST (hors UEMOA)
    // ════════════════════════════════════════════════════════════
    ThixCurrency(
      code: 'NGN',
      name: 'Naira nigérian',
      symbol: '₦',
      locale: 'en_NG',
      decimalDigits: 2,
      region: CurrencyRegion.westAfrica,
      countries: ['Nigeria'],
      isPopular: true,
    ),
    ThixCurrency(
      code: 'GHS',
      name: 'Cedi ghanéen',
      symbol: 'GH₵',
      locale: 'en_GH',
      decimalDigits: 2,
      region: CurrencyRegion.westAfrica,
      countries: ['Ghana'],
      isPopular: true,
    ),
    ThixCurrency(
      code: 'GNF',
      name: 'Franc guinéen',
      symbol: 'FG',
      locale: 'fr_GN',
      decimalDigits: 0,
      region: CurrencyRegion.westAfrica,
      countries: ['Guinée'],
    ),
    ThixCurrency(
      code: 'SLL',
      name: 'Leone sierra-léonais',
      symbol: 'Le',
      locale: 'en_SL',
      decimalDigits: 2,
      region: CurrencyRegion.westAfrica,
      countries: ['Sierra Leone'],
    ),
    ThixCurrency(
      code: 'LRD',
      name: 'Dollar libérien',
      symbol: 'L\$',
      locale: 'en_LR',
      decimalDigits: 2,
      region: CurrencyRegion.westAfrica,
      countries: ['Liberia'],
    ),
    ThixCurrency(
      code: 'GMD',
      name: 'Dalasi gambien',
      symbol: 'D',
      locale: 'en_GM',
      decimalDigits: 2,
      region: CurrencyRegion.westAfrica,
      countries: ['Gambie'],
    ),
    ThixCurrency(
      code: 'MRU',
      name: 'Ouguiya mauritanien',
      symbol: 'UM',
      locale: 'fr_MR',
      decimalDigits: 2,
      region: CurrencyRegion.westAfrica,
      countries: ['Mauritanie'],
    ),
    ThixCurrency(
      code: 'CVE',
      name: 'Escudo cap-verdien',
      symbol: '\$',
      locale: 'pt_CV',
      decimalDigits: 2,
      region: CurrencyRegion.westAfrica,
      countries: ['Cap-Vert'],
    ),

    // ════════════════════════════════════════════════════════════
    // AFRIQUE DU NORD
    // ════════════════════════════════════════════════════════════
    ThixCurrency(
      code: 'MAD',
      name: 'Dirham marocain',
      symbol: 'DH',
      locale: 'fr_MA',
      decimalDigits: 2,
      region: CurrencyRegion.northAfrica,
      countries: ['Maroc'],
      isPopular: true,
    ),
    ThixCurrency(
      code: 'DZD',
      name: 'Dinar algérien',
      symbol: 'DA',
      locale: 'ar_DZ',
      decimalDigits: 2,
      region: CurrencyRegion.northAfrica,
      countries: ['Algérie'],
    ),
    ThixCurrency(
      code: 'TND',
      name: 'Dinar tunisien',
      symbol: 'DT',
      locale: 'ar_TN',
      decimalDigits: 3,
      region: CurrencyRegion.northAfrica,
      countries: ['Tunisie'],
    ),
    ThixCurrency(
      code: 'EGP',
      name: 'Livre égyptienne',
      symbol: 'E£',
      locale: 'ar_EG',
      decimalDigits: 2,
      region: CurrencyRegion.northAfrica,
      countries: ['Égypte'],
      isPopular: true,
    ),
    ThixCurrency(
      code: 'LYD',
      name: 'Dinar libyen',
      symbol: 'LD',
      locale: 'ar_LY',
      decimalDigits: 3,
      region: CurrencyRegion.northAfrica,
      countries: ['Libye'],
    ),

    // ════════════════════════════════════════════════════════════
    // AFRIQUE AUSTRALE (SADC)
    // ════════════════════════════════════════════════════════════
    ThixCurrency(
      code: 'ZAR',
      name: 'Rand sud-africain',
      symbol: 'R',
      locale: 'en_ZA',
      decimalDigits: 2,
      region: CurrencyRegion.southernAfrica,
      countries: ['Afrique du Sud'],
      isPopular: true,
    ),
    ThixCurrency(
      code: 'BWP',
      name: 'Pula botswanaise',
      symbol: 'P',
      locale: 'en_BW',
      decimalDigits: 2,
      region: CurrencyRegion.southernAfrica,
      countries: ['Botswana'],
    ),
    ThixCurrency(
      code: 'NAD',
      name: 'Dollar namibien',
      symbol: 'N\$',
      locale: 'en_NA',
      decimalDigits: 2,
      region: CurrencyRegion.southernAfrica,
      countries: ['Namibie'],
    ),
    ThixCurrency(
      code: 'ZMW',
      name: 'Kwacha zambien',
      symbol: 'ZK',
      locale: 'en_ZM',
      decimalDigits: 2,
      region: CurrencyRegion.southernAfrica,
      countries: ['Zambie'],
    ),
    ThixCurrency(
      code: 'MWK',
      name: 'Kwacha malawite',
      symbol: 'MK',
      locale: 'en_MW',
      decimalDigits: 2,
      region: CurrencyRegion.southernAfrica,
      countries: ['Malawi'],
    ),
    ThixCurrency(
      code: 'MZN',
      name: 'Metical mozambicain',
      symbol: 'MT',
      locale: 'pt_MZ',
      decimalDigits: 2,
      region: CurrencyRegion.southernAfrica,
      countries: ['Mozambique'],
    ),
    ThixCurrency(
      code: 'AOA',
      name: 'Kwanza angolais',
      symbol: 'Kz',
      locale: 'pt_AO',
      decimalDigits: 2,
      region: CurrencyRegion.southernAfrica,
      countries: ['Angola'],
    ),
    ThixCurrency(
      code: 'ZWL',
      name: 'Dollar zimbabwéen',
      symbol: 'Z\$',
      locale: 'en_ZW',
      decimalDigits: 2,
      region: CurrencyRegion.southernAfrica,
      countries: ['Zimbabwe'],
    ),
    ThixCurrency(
      code: 'SZL',
      name: 'Lilangeni swazi',
      symbol: 'L',
      locale: 'en_SZ',
      decimalDigits: 2,
      region: CurrencyRegion.southernAfrica,
      countries: ['Eswatini'],
    ),
    ThixCurrency(
      code: 'LSL',
      name: 'Loti lesothan',
      symbol: 'L',
      locale: 'en_LS',
      decimalDigits: 2,
      region: CurrencyRegion.southernAfrica,
      countries: ['Lesotho'],
    ),

    // ════════════════════════════════════════════════════════════
    // ÎLES DE L'OCÉAN INDIEN
    // ════════════════════════════════════════════════════════════
    ThixCurrency(
      code: 'MGA',
      name: 'Ariary malgache',
      symbol: 'Ar',
      locale: 'fr_MG',
      decimalDigits: 0,
      region: CurrencyRegion.indianOcean,
      countries: ['Madagascar'],
    ),
    ThixCurrency(
      code: 'MUR',
      name: 'Roupie mauricienne',
      symbol: '₨',
      locale: 'en_MU',
      decimalDigits: 2,
      region: CurrencyRegion.indianOcean,
      countries: ['Maurice'],
    ),
    ThixCurrency(
      code: 'SCR',
      name: 'Roupie seychelloise',
      symbol: '₨',
      locale: 'en_SC',
      decimalDigits: 2,
      region: CurrencyRegion.indianOcean,
      countries: ['Seychelles'],
    ),
    ThixCurrency(
      code: 'KMF',
      name: 'Franc comorien',
      symbol: 'CF',
      locale: 'fr_KM',
      decimalDigits: 0,
      region: CurrencyRegion.indianOcean,
      countries: ['Comores'],
    ),

    // ════════════════════════════════════════════════════════════
    // DEVISES INTERNATIONALES MAJEURES
    // ════════════════════════════════════════════════════════════
    ThixCurrency(
      code: 'USD',
      name: 'Dollar américain',
      symbol: '\$',
      locale: 'en_US',
      decimalDigits: 2,
      region: CurrencyRegion.international,
      countries: ['USA', 'International'],
      isPopular: true,
    ),
    ThixCurrency(
      code: 'EUR',
      name: 'Euro',
      symbol: '€',
      locale: 'fr_FR',
      decimalDigits: 2,
      region: CurrencyRegion.international,
      countries: ['Zone Euro'],
      isPopular: true,
    ),
    ThixCurrency(
      code: 'GBP',
      name: 'Livre sterling',
      symbol: '£',
      locale: 'en_GB',
      decimalDigits: 2,
      region: CurrencyRegion.international,
      countries: ['Royaume-Uni'],
    ),
    ThixCurrency(
      code: 'CNY',
      name: 'Yuan chinois',
      symbol: '¥',
      locale: 'zh_CN',
      decimalDigits: 2,
      region: CurrencyRegion.international,
      countries: ['Chine'],
    ),
    ThixCurrency(
      code: 'CAD',
      name: 'Dollar canadien',
      symbol: 'CA\$',
      locale: 'en_CA',
      decimalDigits: 2,
      region: CurrencyRegion.international,
      countries: ['Canada'],
    ),
  ];

  /// Récupère une devise par son code ISO. Retourne USD par défaut.
  static ThixCurrency byCode(String code) {
    return all.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => all.firstWhere((c) => c.code == 'USD'),
    );
  }

  /// Devises populaires (affichées en premier dans le sélecteur).
  static List<ThixCurrency> get popular =>
      all.where((c) => c.isPopular).toList();

  /// Devises groupées par région.
  static Map<CurrencyRegion, List<ThixCurrency>> get byRegion {
    final map = <CurrencyRegion, List<ThixCurrency>>{};
    for (final c in all) {
      map.putIfAbsent(c.region, () => []).add(c);
    }
    return map;
  }

  /// Devise par défaut selon le pays de l'utilisateur (à adapter).
  static ThixCurrency defaultForCountry(String? countryCode) {
    if (countryCode == null) return byCode('XOF');
    switch (countryCode.toUpperCase()) {
      case 'CD': return byCode('CDF');
      case 'NG': return byCode('NGN');
      case 'GH': return byCode('GHS');
      case 'KE': return byCode('KES');
      case 'ZA': return byCode('ZAR');
      case 'MA': return byCode('MAD');
      case 'EG': return byCode('EGP');
      case 'CM':
      case 'GA':
      case 'TD':
      case 'CG':
        return byCode('XAF');
      case 'SN':
      case 'ML':
      case 'BF':
      case 'CI':
      case 'BJ':
      case 'TG':
      case 'NE':
        return byCode('XOF');
      default: return byCode('USD');
    }
  }
}

/// Régions géographiques pour grouper les devises.
enum CurrencyRegion {
  westAfrica('Afrique de l\'Ouest'),
  centralAfrica('Afrique Centrale'),
  eastAfrica('Afrique de l\'Est'),
  northAfrica('Afrique du Nord'),
  southernAfrica('Afrique Australe'),
  indianOcean('Océan Indien'),
  international('International');

  final String label;
  const CurrencyRegion(this.label);
}

/// Représentation complète d'une devise THIX.
class ThixCurrency {
  final String code;        // ISO 4217 (ex: "XOF")
  final String name;        // Nom lisible (ex: "Franc CFA (UEMOA)")
  final String symbol;      // Symbole (ex: "CFA", "₦", "€")
  final String locale;      // Locale pour formatage (ex: "fr_FR")
  final int decimalDigits;  // Nombre de décimales (0, 2 ou 3)
  final CurrencyRegion region;
  final List<String> countries;
  final bool isPopular;

  const ThixCurrency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.locale,
    required this.decimalDigits,
    required this.region,
    this.countries = const [],
    this.isPopular = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThixCurrency &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '$code ($symbol)';
}

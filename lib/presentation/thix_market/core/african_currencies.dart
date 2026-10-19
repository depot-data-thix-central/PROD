// lib/presentation/thix_market/core/african_currencies.dart
// 54 devises africaines avec code ISO-4217, symbole et drapeau

class AfricanCurrency {
  final String code;        // ISO-4217 : USD, CDF, XOF...
  final String symbol;      // $, FC, €...
  final String country;     // Code ISO-2 du pays (pour fallback)
  final String nameFr;
  final String nameEn;
  final String nameSw;

  const AfricanCurrency({
    required this.code,
    required this.symbol,
    required this.country,
    required this.nameFr,
    required this.nameEn,
    required this.nameSw,
  });

  String displayName(String lang) {
    switch (lang) {
      case 'sw': return nameSw;
      case 'en': return nameEn;
      default: return nameFr;
    }
  }

  String get label => '$symbol  $code';
}

class AfricanCurrencies {
  AfricanCurrencies._();

  // Devise par défaut (RDC)
  static const String defaultCode = 'CDF';

  static const List<AfricanCurrency> all = [
    // ─── Afrique du Nord ───
    AfricanCurrency(code: 'DZD', symbol: r'دج', country: 'DZ', nameFr: 'Dinar algérien', nameEn: 'Algerian Dinar', nameSw: 'Dinari ya Aljeria'),
    AfricanCurrency(code: 'EGP', symbol: r'E£', country: 'EG', nameFr: 'Livre égyptienne', nameEn: 'Egyptian Pound', nameSw: 'Pauni ya Misri'),
    AfricanCurrency(code: 'LYD', symbol: r'ل.د', country: 'LY', nameFr: 'Dinar libyen', nameEn: 'Libyan Dinar', nameSw: 'Dinari ya Libya'),
    AfricanCurrency(code: 'MAD', symbol: 'DH', country: 'MA', nameFr: 'Dirham marocain', nameEn: 'Moroccan Dirham', nameSw: 'Dirham ya Moroko'),
    AfricanCurrency(code: 'TND', symbol: 'DT', country: 'TN', nameFr: 'Dinar tunisien', nameEn: 'Tunisian Dinar', nameSw: 'Dinari ya Tunisia'),

    // ─── Afrique de l'Ouest ───
    AfricanCurrency(code: 'XOF', symbol: 'CFA', country: 'BJ', nameFr: 'Franc CFA (BCEAO)', nameEn: 'West African CFA Franc', nameSw: 'Faranga CFA (BCEAO)'),
    // XOF couvre : Bénin, Burkina Faso, Côte d'Ivoire, Guinée-Bissau, Mali, Niger, Sénégal, Togo
    AfricanCurrency(code: 'GMD', symbol: 'D', country: 'GM', nameFr: 'Dalasi gambien', nameEn: 'Gambian Dalasi', nameSw: 'Dalasi ya Gambia'),
    AfricanCurrency(code: 'GHS', symbol: r'₵', country: 'GH', nameFr: 'Cedi ghanéen', nameEn: 'Ghanaian Cedi', nameSw: 'Sedi ya Ghana'),
    AfricanCurrency(code: 'GNF', symbol: 'FG', country: 'GN', nameFr: 'Franc guinéen', nameEn: 'Guinean Franc', nameSw: 'Faranga ya Gine'),
    AfricanCurrency(code: 'LRD', symbol: r'L$', country: 'LR', nameFr: 'Dollar libérien', nameEn: 'Liberian Dollar', nameSw: 'Dola ya Liberia'),
    AfricanCurrency(code: 'MRU', symbol: 'UM', country: 'MR', nameFr: 'Ouguiya mauritanien', nameEn: 'Mauritanian Ouguiya', nameSw: 'Ouguiya ya Mauritania'),
    AfricanCurrency(code: 'NGN', symbol: r'₦', country: 'NG', nameFr: 'Naira nigérian', nameEn: 'Nigerian Naira', nameSw: 'Naira ya Nigeria'),
    AfricanCurrency(code: 'SLL', symbol: 'Le', country: 'SL', nameFr: 'Leone sierra-léonais', nameEn: 'Sierra Leonean Leone', nameSw: 'Leone ya Sierra Leone'),
    AfricanCurrency(code: 'CVE', symbol: r'$', country: 'CV', nameFr: 'Escudo capverdien', nameEn: 'Cape Verdean Escudo', nameSw: 'Eskudo ya Kepuvede'),

    // ─── Afrique Centrale ───
    AfricanCurrency(code: 'XAF', symbol: 'FCFA', country: 'CM', nameFr: 'Franc CFA (BEAC)', nameEn: 'Central African CFA Franc', nameSw: 'Faranga CFA (BEAC)'),
    // XAF couvre : Cameroun, Centrafrique, Congo, Gabon, Guinée équatoriale, Tchad
    AfricanCurrency(code: 'CDF', symbol: 'FC', country: 'CD', nameFr: 'Franc congolais', nameEn: 'Congolese Franc', nameSw: 'Faranga ya Kongo'),
    AfricanCurrency(code: 'AOA', symbol: 'Kz', country: 'AO', nameFr: 'Kwanza angolais', nameEn: 'Angolan Kwanza', nameSw: 'Kwanza ya Angola'),

    // ─── Afrique de l'Est ───
    AfricanCurrency(code: 'BIF', symbol: 'FBu', country: 'BI', nameFr: 'Franc burundais', nameEn: 'Burundian Franc', nameSw: 'Faranga ya Burundi'),
    AfricanCurrency(code: 'DJF', symbol: 'Fdj', country: 'DJ', nameFr: 'Franc djiboutien', nameEn: 'Djiboutian Franc', nameSw: 'Faranga ya Djibouti'),
    AfricanCurrency(code: 'ERN', symbol: 'Nfk', country: 'ER', nameFr: 'Nakfa érythréen', nameEn: 'Eritrean Nakfa', nameSw: 'Nakfa ya Eritrea'),
    AfricanCurrency(code: 'ETB', symbol: 'Br', country: 'ET', nameFr: 'Birr éthiopien', nameEn: 'Ethiopian Birr', nameSw: 'Birr ya Uhabeshi'),
    AfricanCurrency(code: 'KES', symbol: 'KSh', country: 'KE', nameFr: 'Shilling kényan', nameEn: 'Kenyan Shilling', nameSw: 'Shilingi ya Kenya'),
    AfricanCurrency(code: 'KMF', symbol: 'CF', country: 'KM', nameFr: 'Franc comorien', nameEn: 'Comorian Franc', nameSw: 'Faranga ya Komori'),
    AfricanCurrency(code: 'MGA', symbol: 'Ar', country: 'MG', nameFr: 'Ariary malgache', nameEn: 'Malagasy Ariary', nameSw: 'Ariari ya Madagaska'),
    AfricanCurrency(code: 'MUR', symbol: r'₨', country: 'MU', nameFr: 'Roupie mauricienne', nameEn: 'Mauritian Rupee', nameSw: 'Rupia ya Morisi'),
    AfricanCurrency(code: 'RWF', symbol: 'FRw', country: 'RW', nameFr: 'Franc rwandais', nameEn: 'Rwandan Franc', nameSw: 'Faranga ya Rwanda'),
    AfricanCurrency(code: 'SCR', symbol: r'₨', country: 'SC', nameFr: 'Roupie seychelloise', nameEn: 'Seychellois Rupee', nameSw: 'Rupia ya Shelisheli'),
    AfricanCurrency(code: 'SOS', symbol: 'Sh', country: 'SO', nameFr: 'Shilling somalien', nameEn: 'Somali Shilling', nameSw: 'Shilingi ya Somalia'),
    AfricanCurrency(code: 'SSP', symbol: r'£', country: 'SS', nameFr: 'Livre sud-soudanaise', nameEn: 'South Sudanese Pound', nameSw: 'Pauni ya Sudan Kusini'),
    AfricanCurrency(code: 'SDG', symbol: r'ج.س.', country: 'SD', nameFr: 'Livre soudanaise', nameEn: 'Sudanese Pound', nameSw: 'Pauni ya Sudan'),
    AfricanCurrency(code: 'TZS', symbol: 'TSh', country: 'TZ', nameFr: 'Shilling tanzanien', nameEn: 'Tanzanian Shilling', nameSw: 'Shilingi ya Tanzania'),
    AfricanCurrency(code: 'UGX', symbol: 'USh', country: 'UG', nameFr: 'Shilling ougandais', nameEn: 'Ugandan Shilling', nameSw: 'Shilingi ya Uganda'),

    // ─── Afrique Australe ───
    AfricanCurrency(code: 'BWP', symbol: 'P', country: 'BW', nameFr: 'Pula botswanais', nameEn: 'Botswana Pula', nameSw: 'Pula ya Botswana'),
    AfricanCurrency(code: 'SZL', symbol: 'L', country: 'SZ', nameFr: 'Lilangeni eswatinien', nameEn: 'Swazi Lilangeni', nameSw: 'Lilangeni ya Uswazi'),
    AfricanCurrency(code: 'LSL', symbol: 'L', country: 'LS', nameFr: 'Loti lesothan', nameEn: 'Lesotho Loti', nameSw: 'Loti ya Lesoto'),
    AfricanCurrency(code: 'MWK', symbol: 'MK', country: 'MW', nameFr: 'Kwacha malawien', nameEn: 'Malawian Kwacha', nameSw: 'Kwacha ya Malawi'),
    AfricanCurrency(code: 'MZN', symbol: 'MT', country: 'MZ', nameFr: 'Metical mozambicain', nameEn: 'Mozambican Metical', nameSw: 'Metikali ya Msumbiji'),
    AfricanCurrency(code: 'NAD', symbol: r'N$', country: 'NA', nameFr: 'Dollar namibien', nameEn: 'Namibian Dollar', nameSw: 'Dola ya Namibia'),
    AfricanCurrency(code: 'ZAR', symbol: 'R', country: 'ZA', nameFr: 'Rand sud-africain', nameEn: 'South African Rand', nameSw: 'Randi ya Afrika Kusini'),
    AfricanCurrency(code: 'ZMW', symbol: 'ZK', country: 'ZM', nameFr: 'Kwacha zambien', nameEn: 'Zambian Kwacha', nameSw: 'Kwacha ya Zambia'),
    AfricanCurrency(code: 'ZWL', symbol: r'Z$', country: 'ZW', nameFr: 'Dollar zimbabwéen', nameEn: 'Zimbabwean Dollar', nameSw: 'Dola ya Zimbabwe'),

    // ─── Devise internationale acceptée partout ───
    AfricanCurrency(code: 'USD', symbol: r'$', country: 'US', nameFr: 'Dollar américain', nameEn: 'US Dollar', nameSw: 'Dola ya Marekani'),
  ];

  static final Map<String, AfricanCurrency> _byCode = {
    for (final c in all) c.code: c,
  };

  static AfricanCurrency? byCode(String? code) {
    if (code == null || code.trim().isEmpty) return null;
    return _byCode[code.trim().toUpperCase()];
  }

  /// Devise recommandée pour un pays donné
  static AfricanCurrency forCountry(String? countryCode) {
    if (countryCode == null) return _byCode['CDF']!;
    final match = all.firstWhere(
      (c) => c.country == countryCode.toUpperCase(),
      orElse: () => _byCode['CDF']!,
    );
    return match;
  }

  /// Liste triée par langue (FR par défaut)
  static List<AfricanCurrency> sorted(String lang) {
    final list = [...all];
    list.sort((a, b) => a.displayName(lang).compareTo(b.displayName(lang)));
    return list;
  }
}

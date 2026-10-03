// lib/presentation/thix_market/core/african_countries.dart
// 54 pays africains : code ISO-2, nom FR, drapeau emoji calculé depuis le code.

class AfricanCountry {
  final String code;
  final String name;
  const AfricanCountry(this.code, this.name);

  /// Drapeau emoji calculé depuis le code ISO (ex: CD -> 🇨🇩)
  String get flag => AfricanCountries.flagOf(code);

  String get label => '$flag  $name';
}

class AfricanCountries {
  AfricanCountries._();

  static const String defaultCode = 'CD';

  static const List<AfricanCountry> all = [
    AfricanCountry('DZ', 'Algérie'),
    AfricanCountry('AO', 'Angola'),
    AfricanCountry('BJ', 'Bénin'),
    AfricanCountry('BW', 'Botswana'),
    AfricanCountry('BF', 'Burkina Faso'),
    AfricanCountry('BI', 'Burundi'),
    AfricanCountry('CV', 'Cap-Vert'),
    AfricanCountry('CM', 'Cameroun'),
    AfricanCountry('CF', 'Centrafrique'),
    AfricanCountry('TD', 'Tchad'),
    AfricanCountry('KM', 'Comores'),
    AfricanCountry('CG', 'Congo'),
    AfricanCountry('CD', 'RDC'),
    AfricanCountry('CI', "Côte d'Ivoire"),
    AfricanCountry('DJ', 'Djibouti'),
    AfricanCountry('EG', 'Égypte'),
    AfricanCountry('GQ', 'Guinée équatoriale'),
    AfricanCountry('ER', 'Érythrée'),
    AfricanCountry('SZ', 'Eswatini'),
    AfricanCountry('ET', 'Éthiopie'),
    AfricanCountry('GA', 'Gabon'),
    AfricanCountry('GM', 'Gambie'),
    AfricanCountry('GH', 'Ghana'),
    AfricanCountry('GN', 'Guinée'),
    AfricanCountry('GW', 'Guinée-Bissau'),
    AfricanCountry('KE', 'Kenya'),
    AfricanCountry('LS', 'Lesotho'),
    AfricanCountry('LR', 'Libéria'),
    AfricanCountry('LY', 'Libye'),
    AfricanCountry('MG', 'Madagascar'),
    AfricanCountry('MW', 'Malawi'),
    AfricanCountry('ML', 'Mali'),
    AfricanCountry('MR', 'Mauritanie'),
    AfricanCountry('MU', 'Maurice'),
    AfricanCountry('MA', 'Maroc'),
    AfricanCountry('MZ', 'Mozambique'),
    AfricanCountry('NA', 'Namibie'),
    AfricanCountry('NE', 'Niger'),
    AfricanCountry('NG', 'Nigéria'),
    AfricanCountry('RW', 'Rwanda'),
    AfricanCountry('ST', 'Sao Tomé-et-Principe'),
    AfricanCountry('SN', 'Sénégal'),
    AfricanCountry('SC', 'Seychelles'),
    AfricanCountry('SL', 'Sierra Leone'),
    AfricanCountry('SO', 'Somalie'),
    AfricanCountry('ZA', 'Afrique du Sud'),
    AfricanCountry('SS', 'Soudan du Sud'),
    AfricanCountry('SD', 'Soudan'),
    AfricanCountry('TZ', 'Tanzanie'),
    AfricanCountry('TG', 'Togo'),
    AfricanCountry('TN', 'Tunisie'),
    AfricanCountry('UG', 'Ouganda'),
    AfricanCountry('ZM', 'Zambie'),
    AfricanCountry('ZW', 'Zimbabwe'),
  ];

  static final Map<String, AfricanCountry> _byCode = {
    for (final c in all) c.code: c,
  };

  static AfricanCountry? byCode(String? code) {
    if (code == null || code.trim().isEmpty) return null;
    return _byCode[code.trim().toUpperCase()];
  }

  /// CD -> 🇨🇩
  static String flagOf(String? code) {
    if (code == null || code.trim().length != 2) return '';
    final up = code.trim().toUpperCase();
    return String.fromCharCodes(up.codeUnits.map((c) => 0x1F1E6 + (c - 0x41)));
  }

  /// "Lubumbashi, RDC 🇨🇩" (ou juste la ville si le pays est inconnu)
  static String locationLine({required String city, String? code}) {
    final country = byCode(code);
    final c = city.trim();
    if (country == null) return c;
    if (c.isEmpty) return '${country.name} ${country.flag}';
    return '$c, ${country.name} ${country.flag}';
  }
}

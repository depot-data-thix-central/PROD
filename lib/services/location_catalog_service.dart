import 'package:flutter/foundation.dart';

/// Lightweight local catalog used for dependent dropdowns.
///
/// This avoids external APIs and keeps the UX responsive offline.
///
/// Note: the dataset is intentionally small (starter set). You can extend it
/// anytime without breaking existing saved values.
@immutable
class LocationCatalogService {
  /// RDC provinces (26).
  ///
  /// Naming is normalized to match the user's requested canonical labels.
  static const List<String> provinces = [
    'Kinshasa',
    'Kongo Central',
    'Kwango',
    'Kwilu',
    'Mai-Ndombe',
    'Kasaï',
    'Kasaï Central',
    'Kasaï Oriental',
    'Lomami',
    'Sankuru',
    'Sud-Ubangi',
    'Nord-Ubangi',
    'Mongala',
    'Tshuapa',
    'Équateur',
    'Tshopo',
    'Bas-Uele',
    'Haut-Uele',
    'Ituri',
    'Nord-Kivu',
    'Sud-Kivu',
    'Maniema',
    'Tanganyika',
    'Haut-Lomami',
    'Lualaba',
    'Haut-Katanga',
  ];

  /// Territories by province (starter set).
  ///
  /// For now we prioritize the provinces explicitly requested by the user.
  /// You can extend this map at any time without breaking saved values.
  static const Map<String, List<String>> territoriesByProvince = {
    'Nord-Kivu': ['Beni', 'Lubero', 'Rutshuru', 'Masisi', 'Walikale'],
    'Sud-Kivu': ['Fizi', 'Uvira', 'Kabare', 'Kalehe', 'Walungu'],
    'Ituri': ['Aru', 'Djugu', 'Irumu', 'Mambasa'],
    'Kongo Central': ['Lukula', 'Mbanza-Ngungu', 'Madimba', 'Songololo', 'Seke-Banza'],
    'Kwilu': ['Bulungu', 'Gungu', 'Idiofa', 'Masimanimba'],
    'Kwango': ['Kenge', 'Feshi', 'Kahemba', 'Kasongo-Lunda'],
    'Lualaba': ['Dilolo', 'Lubudi', 'Mutshatsha', 'Kapanga'],
    'Haut-Katanga': ['Kasenga', 'Kipushi', 'Mitwaba', 'Pweto', 'Sakania'],
    // Kinshasa's administrative areas can be modeled differently; keeping empty for now.
    'Kinshasa': const [],
  };

  static const Map<String, List<String>> citiesByProvince = {
    'Kinshasa': ['Kinshasa'],
    'Haut-Katanga': ['Lubumbashi', 'Likasi'],
    'Lualaba': ['Kolwezi'],
    'Kasaï Oriental': ['Mbuji-Mayi'],
    'Kasaï Central': ['Kananga'],
    'Tshopo': ['Kisangani'],
    'Sud-Kivu': ['Bukavu', 'Uvira'],
    'Nord-Kivu': ['Goma', 'Beni', 'Butembo'],
    'Kongo Central': ['Matadi'],
    'Kwilu': ['Kikwit'],
    'Kasaï': ['Tshikapa'],
    'Ituri': ['Bunia'],
    'Tanganyika': ['Kalemie'],
    'Sud-Ubangi': ['Gemena'],
    'Mongala': ['Lisala'],
    'Équateur': ['Mbandaka'],
  };

  static const Map<String, List<String>> communesByCity = {
    'Kinshasa': [
      'Bandalungwa',
      'Barumbu',
      'Bumbu',
      'Gombe',
      'Kalamu',
      'Kasa-Vubu',
      'Kimbanseke',
      'Kinshasa',
      'Kintambo',
      'Lemba',
      'Limete',
      'Lingwala',
      'Makala',
      'Maluku',
      'Masina',
      'Matete',
      'Mont Ngafula',
      'Ndjili',
      'Ngaba',
      'Ngaliema',
      'Nsele',
    ],
    // Other cities can be filled as needed.
  };

  static List<String> territoriesFor(String? province) {
    final p = (province ?? '').trim();
    if (p.isEmpty) return const [];
    return territoriesByProvince[p] ?? const [];
  }

  static List<String> citiesFor(String? province) {
    final p = (province ?? '').trim();
    if (p.isEmpty) return const [];
    return citiesByProvince[p] ?? const [];
  }

  static List<String> communesFor(String? city) {
    final c = (city ?? '').trim();
    if (c.isEmpty) return const [];
    return communesByCity[c] ?? const [];
  }
}

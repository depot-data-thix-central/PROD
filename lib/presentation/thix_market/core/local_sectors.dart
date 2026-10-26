// lib/presentation/thix_market/core/local_sectors.dart
// ============================================================================
// RÉFÉRENTIEL DES SECTEURS LOCAUX — tous secteurs (pas seulement grocery)
// ============================================================================

import 'package:flutter/material.dart';

class LocalSector {
  final String id;
  final String labelFr;
  final String labelEn;
  final String labelSw;
  final IconData icon;
  final Color color;
  final String defaultUnit;

  const LocalSector({
    required this.id,
    required this.labelFr,
    required this.labelEn,
    required this.labelSw,
    required this.icon,
    required this.color,
    this.defaultUnit = 'pcs',
  });

  String label(String lang) {
    if (lang == 'sw') return labelSw;
    if (lang == 'fr') return labelFr;
    return labelEn;
  }
}

/// 17 secteurs couvrant toute l'économie locale (incluant Thé/Tisanes, Épices, etc.)
const List<LocalSector> kLocalSectors = [
  // 🌿 Alimentaire & Agriculture
  LocalSector(id: 'produce',        labelFr: 'Agriculture & Maraîchage', labelEn: 'Farming & Produce',      labelSw: 'Kilimo na Mboga',     icon: Icons.eco_rounded,                  color: Color(0xFF16A34A), defaultUnit: 'kg'),
  LocalSector(id: 'livestock',      labelFr: 'Élevage & Viandes',        labelEn: 'Livestock & Meat',       labelSw: 'Mifugo na Nyama',     icon: Icons.restaurant_rounded,           color: Color(0xFFDC2626), defaultUnit: 'kg'),
  LocalSector(id: 'fish',           labelFr: 'Pêche & Poissons',         labelEn: 'Fisheries',              labelSw: 'Uvuvi na Samaki',     icon: Icons.set_meal_rounded,             color: Color(0xFF0891B2), defaultUnit: 'kg'),
  
  // 🍵 NOUVEAU : Thé & Tisanes (demandé explicitement)
  LocalSector(id: 'tea_herbal',     labelFr: 'Thé & Tisanes',            labelEn: 'Tea & Herbal Infusions', labelSw: 'Chai na Tisanes',     icon: Icons.local_drink_rounded,          color: Color(0xFF059669), defaultUnit: 'boite'),
  
  // 🧂 NOUVEAU : Épices & Condiments (très important localement)
  LocalSector(id: 'spices',         labelFr: 'Épices & Condiments',      labelEn: 'Spices & Condiments',    labelSw: 'Viungo na Viungo',    icon: Icons.restaurant_menu_rounded,      color: Color(0xFFB45309), defaultUnit: 'sachet'),
  
  // 🌾 NOUVEAU : Céréales & Légumineuses
  LocalSector(id: 'cereals_legumes',labelFr: 'Céréales & Légumineuses',  labelEn: 'Cereals & Legumes',      labelSw: 'Nafaka na Maharage',  icon: Icons.grain_rounded,                color: Color(0xFFD97706), defaultUnit: 'kg'),
  
  // 🏭 NOUVEAU : Produits transformés locaux
  LocalSector(id: 'processed',      labelFr: 'Produits transformés',     labelEn: 'Processed Products',     labelSw: 'Bidhaa zilizochakatwa',icon: Icons.factory_rounded,               color: Color(0xFF4F46E5), defaultUnit: 'pcs'),
  
  // 🍯 NOUVEAU : Miel & Produits de la ruche
  LocalSector(id: 'honey_bee',      labelFr: 'Miel & Produits de la ruche', labelEn: 'Honey & Bee Products', labelSw: 'Asali na Bidhaa za Nyuki', icon: Icons.bug_report_rounded,        color: Color(0xFFF59E0B), defaultUnit: 'pot'),

  // 🎨 Artisanat & Industrie légère
  LocalSector(id: 'crafts',         labelFr: 'Artisanat & Métiers d\'art', labelEn: 'Crafts & Handicrafts', labelSw: 'Ufundi na Usanii',    icon: Icons.brush_rounded,                color: Color(0xFF9333EA), defaultUnit: 'pcs'),
  LocalSector(id: 'textile',        labelFr: 'Textile & Mode locale',    labelEn: 'Local Textile & Fashion',labelSw: 'Nguo na Mitindo',     icon: Icons.checkroom_rounded,            color: Color(0xFFDB2777), defaultUnit: 'pcs'),
  LocalSector(id: 'beauty',         labelFr: 'Cosmétique & Beauté',      labelEn: 'Local Beauty',           labelSw: 'Urembo wa Ndani',     icon: Icons.spa_rounded,                  color: Color(0xFFEC4899), defaultUnit: 'pcs'),
  
  // 🥤 Boissons (hors thé/tisanes)
  LocalSector(id: 'drinks',         labelFr: 'Boissons locales',         labelEn: 'Local Drinks',           labelSw: 'Vinywaji vya Ndani',  icon: Icons.local_bar_rounded,            color: Color(0xFF2563EB), defaultUnit: 'L'),

  // 🌲 Ressources naturelles & BTP
  LocalSector(id: 'forestry',       labelFr: 'Bois & Foresterie',        labelEn: 'Wood & Forestry',        labelSw: 'Miti na Msitu',       icon: Icons.forest_rounded,               color: Color(0xFF0D9488), defaultUnit: 'm'),
  LocalSector(id: 'minerals',       labelFr: 'Mines & Minéraux',         labelEn: 'Mining & Minerals',      labelSw: 'Madini',              icon: Icons.terrain_rounded,              color: Color(0xFF64748B), defaultUnit: 'kg'),
  LocalSector(id: 'construction',   labelFr: 'Matériaux & Construction', labelEn: 'Building Materials',     labelSw: 'Vifaa vya Ujenzi',    icon: Icons.construction_rounded,         color: Color(0xFFEA580C), defaultUnit: 'pcs'),
  
  // 🏠 Vie quotidienne & Services
  LocalSector(id: 'homecare',       labelFr: 'Entretien & Maison',       labelEn: 'Home & Care',            labelSw: 'Nyumba na Usafi',     icon: Icons.clean_hands_rounded,          color: Color(0xFF0EA5E9), defaultUnit: 'pcs'),
  LocalSector(id: 'services',       labelFr: 'Services locaux',          labelEn: 'Local Services',         labelSw: 'Huduma za Ndani',     icon: Icons.miscellaneous_services_rounded, color: Color(0xFFF59E0B), defaultUnit: 'pcs'),
];

LocalSector? localSectorById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final s in kLocalSectors) {
    if (s.id == id) return s;
  }
  return null;
}

// ============================================================================
// CERTIFICATIONS / LABELS LOCAUX
// ============================================================================
class LocalCertification {
  final String id;
  final String labelFr;
  final String labelEn;
  final IconData icon;
  const LocalCertification(this.id, this.labelFr, this.labelEn, this.icon);

  String label(String lang) => lang == 'fr' ? labelFr : labelEn;
}

const List<LocalCertification> kLocalCertifications = [
  LocalCertification('bio',        'Biologique',               'Organic',                Icons.eco_rounded),
  LocalCertification('equitable',  'Commerce équitable',       'Fair trade',             Icons.handshake_rounded),
  LocalCertification('artisanal',  'Fait main',                'Handmade',               Icons.brush_rounded),
  LocalCertification('coop',       'Coopérative',              'Cooperative',            Icons.groups_rounded),
  LocalCertification('ig',         'Indication géographique',  'Geographical indication',Icons.place_rounded),
  LocalCertification('naturel',    '100% naturel',             '100% natural',           Icons.local_florist_rounded),
  LocalCertification('femme',      'Producteur femme',         'Women producer',         Icons.favorite_rounded), // Ajout pertinent pour l'impact social
];

// ============================================================================
// UNITÉS DE MESURE (même référentiel que le formulaire supermarché)
// ============================================================================
const List<Map<String, String>> kLocalUnits = [
  {'value': 'pcs', 'label': 'Pièce (pcs)'},
  {'value': 'kg', 'label': 'Kilogramme (kg)'},
  {'value': 'g', 'label': 'Gramme (g)'},
  {'value': 'L', 'label': 'Litre (L)'},
  {'value': 'mL', 'label': 'Millilitre (mL)'},
  {'value': 'sachet', 'label': 'Sachet'},
  {'value': 'paquet', 'label': 'Paquet'},
  {'value': 'boite', 'label': 'Boîte'},
  {'value': 'bouteille', 'label': 'Bouteille'},
  {'value': 'carton', 'label': 'Carton'},
  {'value': 'douzaine', 'label': 'Douzaine'},
  {'value': 'pot', 'label': 'Pot'}, // Ajouté pour le miel/confitures
  {'value': 'botte', 'label': 'Botte'}, // Ajouté pour les légumes/herbes
  {'value': 'm', 'label': 'Mètre (m)'},
  {'value': 'cm', 'label': 'Centimètre (cm)'},
];

String kLocalUnitLabel(String? value) {
  if (value == null || value.isEmpty) return '';
  for (final u in kLocalUnits) {
    if (u['value'] == value) return u['label']!;
  }
  return value;
}

// Couleurs de l'espace local (header vert type "grocery")
const Color kLocalGreen = Color(0xFF159A44);
const Color kLocalGreenDeep = Color(0xFF0B6B31);
const Color kLocalGreenSoft = Color(0xFFE7F6EC);
const Color kLocalGreen2 = Color(0xFF149A4A); // Ajouté pour compatibilité avec les widgets existants

// lib/presentation/thix_weeding/pages/provider_portal/offers/offer_type_fields.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// THIX WEDDING — CHAMPS SPÉCIFIQUES PAR TYPE D'OFFRE (Production v2)
/// ✅ Traiteur : Capacité, type menu, cuisines, options diététiques
/// ✅ Salle : Capacité, équipements, superficie, parking
/// ✅ MC : Langues, style, expérience, équipements
/// ✅ Gâteau : Tailles, saveurs, design, allergènes
/// ✅ DJ : Styles musicaux, équipements, playlist
/// ═══════════════════════════════════════════════════════════════════════

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color blue = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color red = Color(0xFFEF4444);
}

// ═══════════════════════════════════════════════════════════════════════
// TRAITEUR
// ═══════════════════════════════════════════════════════════════════════

class TraiteurFields extends StatefulWidget {
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const TraiteurFields({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<TraiteurFields> createState() => _TraiteurFieldsState();
}

class _TraiteurFieldsState extends State<TraiteurFields> {
  late int _minGuests;
  late int _maxGuests;
  late String _menuType;
  final List<String> _cuisines = [];
  final List<String> _dietaryOptions = [];
  late bool _includesService;
  late bool _includesDrinks;
  late bool _includesDecoration;
  late int _staffCount;

  final List<String> _availableCuisines = [
    'Africaine',
    'Européenne',
    'Asiatique',
    'Orientale',
    'Végétarienne',
    'Halal',
    'Casher',
    'Fusion',
  ];

  final List<String> _availableDietary = [
    'Végétarien',
    'Vegan',
    'Sans gluten',
    'Sans lactose',
    'Halal',
    'Casher',
  ];

  final List<String> _menuTypes = ['Buffet', 'Assise', 'Cocktail', 'Food trucks'];

  @override
  void initState() {
    super.initState();
    _minGuests = widget.data['min_guests'] ?? 50;
    _maxGuests = widget.data['max_guests'] ?? 300;
    _menuType = widget.data['menu_type'] ?? 'Buffet';
    _cuisines.addAll(List<String>.from(widget.data['cuisines'] ?? ['Africaine']));
    _dietaryOptions.addAll(List<String>.from(widget.data['dietary_options'] ?? []));
    _includesService = widget.data['includes_service'] ?? true;
    _includesDrinks = widget.data['includes_drinks'] ?? false;
    _includesDecoration = widget.data['includes_decoration'] ?? false;
    _staffCount = widget.data['staff_count'] ?? 5;
  }

  void _updateData() {
    widget.onChanged({
      'min_guests': _minGuests,
      'max_guests': _maxGuests,
      'menu_type': _menuType,
      'cuisines': _cuisines,
      'dietary_options': _dietaryOptions,
      'includes_service': _includesService,
      'includes_drinks': _includesDrinks,
      'includes_decoration': _includesDecoration,
      'staff_count': _staffCount,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant, color: _P.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Détails Traiteur',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Capacité invités
          Text(
            'Capacité (nombre d\'invités)',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  label: 'Minimum',
                  value: _minGuests,
                  min: 10,
                  max: _maxGuests - 10,
                  step: 10,
                  onChanged: (v) {
                    setState(() => _minGuests = v);
                    _updateData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  label: 'Maximum',
                  value: _maxGuests,
                  min: _minGuests + 10,
                  max: 1000,
                  step: 10,
                  onChanged: (v) {
                    setState(() => _maxGuests = v);
                    _updateData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Type de menu
          Text(
            'Type de service',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _menuTypes.map((type) {
              final selected = _menuType == type;
              return GestureDetector(
                onTap: () {
                  setState(() => _menuType = type);
                  _updateData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? _P.amber : _P.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? _P.amber : _P.line),
                  ),
                  child: Text(
                    type,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : _P.ink,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Cuisines
          Text(
            'Cuisines proposées',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableCuisines.map((cuisine) {
              final selected = _cuisines.contains(cuisine);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _cuisines.remove(cuisine);
                    } else {
                      _cuisines.add(cuisine);
                    }
                  });
                  _updateData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _P.amber.withOpacity(0.15) : _P.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _P.amber : _P.line,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected)
                        const Icon(Icons.check_circle, size: 14, color: _P.amber),
                      if (selected) const SizedBox(width: 4),
                      Text(
                        cuisine,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? _P.amber : _P.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Options diététiques
          Text(
            'Options diététiques disponibles',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableDietary.map((option) {
              final selected = _dietaryOptions.contains(option);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _dietaryOptions.remove(option);
                    } else {
                      _dietaryOptions.add(option);
                    }
                  });
                  _updateData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _P.green.withOpacity(0.15) : _P.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _P.green : _P.line,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected)
                        const Icon(Icons.check_circle, size: 14, color: _P.green),
                      if (selected) const SizedBox(width: 4),
                      Text(
                        option,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? _P.green : _P.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Personnel
          _NumberField(
            label: 'Nombre de serveurs/personnel',
            value: _staffCount,
            min: 1,
            max: 50,
            step: 1,
            onChanged: (v) {
              setState(() => _staffCount = v);
              _updateData();
            },
          ),
          const SizedBox(height: 20),

          // Services inclus
          _SwitchTile(
            icon: Icons.room_service,
            title: 'Service inclus',
            subtitle: 'Maîtres d\'hôtel et serveurs',
            value: _includesService,
            color: _P.blue,
            onChanged: (v) {
              setState(() => _includesService = v);
              _updateData();
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.local_bar,
            title: 'Boissons incluses',
            subtitle: 'Eau, sodas, jus (hors alcool)',
            value: _includesDrinks,
            color: _P.purple,
            onChanged: (v) {
              setState(() => _includesDrinks = v);
              _updateData();
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.palette,
            title: 'Décoration tables incluse',
            subtitle: 'Nappes, couverts, centres de table',
            value: _includesDecoration,
            color: _P.rose,
            onChanged: (v) {
              setState(() => _includesDecoration = v);
              _updateData();
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SALLE
// ═══════════════════════════════════════════════════════════════════════

class SalleFields extends StatefulWidget {
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const SalleFields({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<SalleFields> createState() => _SalleFieldsState();
}

class _SalleFieldsState extends State<SalleFields> {
  late int _capacity;
  late int _surface;
  late bool _hasParking;
  late int _parkingSpaces;
  late bool _hasKitchen;
  late bool _hasSoundSystem;
  late bool _hasLighting;
  late bool _hasAC;
  late bool _isAccessible;
  late String _venueType;

  final List<String> _venueTypes = [
    'Salle de fête',
    'Hôtel',
    'Restaurant',
    'Château',
    'Jardin/Tente',
    'Rooftop',
  ];

  @override
  void initState() {
    super.initState();
    _capacity = widget.data['capacity'] ?? 100;
    _surface = widget.data['surface'] ?? 200;
    _hasParking = widget.data['has_parking'] ?? false;
    _parkingSpaces = widget.data['parking_spaces'] ?? 0;
    _hasKitchen = widget.data['has_kitchen'] ?? false;
    _hasSoundSystem = widget.data['has_sound_system'] ?? false;
    _hasLighting = widget.data['has_lighting'] ?? false;
    _hasAC = widget.data['has_ac'] ?? true;
    _isAccessible = widget.data['is_accessible'] ?? true;
    _venueType = widget.data['venue_type'] ?? 'Salle de fête';
  }

  void _updateData() {
    widget.onChanged({
      'capacity': _capacity,
      'surface': _surface,
      'has_parking': _hasParking,
      'parking_spaces': _parkingSpaces,
      'has_kitchen': _hasKitchen,
      'has_sound_system': _hasSoundSystem,
      'has_lighting': _hasLighting,
      'has_ac': _hasAC,
      'is_accessible': _isAccessible,
      'venue_type': _venueType,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.meeting_room, color: _P.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Détails Salle',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Type de lieu
          Text(
            'Type de lieu',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _venueTypes.map((type) {
              final selected = _venueType == type;
              return GestureDetector(
                onTap: () {
                  setState(() => _venueType = type);
                  _updateData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? _P.blue : _P.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? _P.blue : _P.line),
                  ),
                  child: Text(
                    type,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : _P.ink,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Capacité et superficie
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  label: 'Capacité (personnes)',
                  value: _capacity,
                  min: 10,
                  max: 1000,
                  step: 10,
                  onChanged: (v) {
                    setState(() => _capacity = v);
                    _updateData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  label: 'Superficie (m²)',
                  value: _surface,
                  min: 20,
                  max: 2000,
                  step: 10,
                  onChanged: (v) {
                    setState(() => _surface = v);
                    _updateData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Parking
          _SwitchTile(
            icon: Icons.local_parking,
            title: 'Parking disponible',
            subtitle: _hasParking ? '${_parkingSpaces} places' : 'Non disponible',
            value: _hasParking,
            color: _P.purple,
            onChanged: (v) {
              setState(() => _hasParking = v);
              if (!v) _parkingSpaces = 0;
              _updateData();
            },
          ),
          if (_hasParking) ...[
            const SizedBox(height: 12),
            _NumberField(
              label: 'Nombre de places de parking',
              value: _parkingSpaces,
              min: 0,
              max: 200,
              step: 5,
              onChanged: (v) {
                setState(() => _parkingSpaces = v);
                _updateData();
              },
            ),
          ],
          const SizedBox(height: 20),

          // Équipements
          Text(
            'Équipements inclus',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
          ),
          const SizedBox(height: 12),
          _SwitchTile(
            icon: Icons.kitchen,
            title: 'Cuisine équipée',
            subtitle: 'Pour le traiteur',
            value: _hasKitchen,
            color: _P.amber,
            onChanged: (v) {
              setState(() => _hasKitchen = v);
              _updateData();
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.speaker,
            title: 'Système sonore',
            subtitle: 'Sono et micro',
            value: _hasSoundSystem,
            color: _P.purple,
            onChanged: (v) {
              setState(() => _hasSoundSystem = v);
              _updateData();
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.light,
            title: 'Éclairage',
            subtitle: 'Jeux de lumières',
            value: _hasLighting,
            color: _P.rose,
            onChanged: (v) {
              setState(() => _hasLighting = v);
              _updateData();
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.ac_unit,
            title: 'Climatisation',
            subtitle: 'Air conditionné',
            value: _hasAC,
            color: _P.blue,
            onChanged: (v) {
              setState(() => _hasAC = v);
              _updateData();
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.accessible,
            title: 'Accessible PMR',
            subtitle: 'Personnes à mobilité réduite',
            value: _isAccessible,
            color: _P.green,
            onChanged: (v) {
              setState(() => _isAccessible = v);
              _updateData();
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// MC (Maître de Cérémonie)
// ═══════════════════════════════════════════════════════════════════════

class MCFields extends StatefulWidget {
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const MCFields({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<MCFields> createState() => _MCFieldsState();
}

class _MCFieldsState extends State<MCFields> {
  final List<String> _languages = [];
  late String _style;
  late int _experienceYears;
  late bool _hasOwnEquipment;
  late bool _canSing;
  late bool _canDance;

  final List<String> _availableLanguages = [
    'Français',
    'Anglais',
    'Lingala',
    'Swahili',
    'Kikongo',
    'Tshiluba',
  ];

  final List<String> _styles = [
    'Classique',
    'Dynamique',
    'Humoristique',
    'Traditionnel',
    'Moderne',
  ];

  @override
  void initState() {
    super.initState();
    _languages.addAll(List<String>.from(widget.data['languages'] ?? ['Français']));
    _style = widget.data['style'] ?? 'Classique';
    _experienceYears = widget.data['experience_years'] ?? 5;
    _hasOwnEquipment = widget.data['has_own_equipment'] ?? true;
    _canSing = widget.data['can_sing'] ?? false;
    _canDance = widget.data['can_dance'] ?? false;
  }

  void _updateData() {
    widget.onChanged({
      'languages': _languages,
      'style': _style,
      'experience_years': _experienceYears,
      'has_own_equipment': _hasOwnEquipment,
      'can_sing': _canSing,
      'can_dance': _canDance,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mic, color: _P.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Détails MC',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Langues
          Text(
            'Langues parlées',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableLanguages.map((lang) {
              final selected = _languages.contains(lang);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _languages.remove(lang);
                    } else {
                      _languages.add(lang);
                    }
                  });
                  _updateData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _P.purple.withOpacity(0.15) : _P.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _P.purple : _P.line,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected)
                        const Icon(Icons.check_circle, size: 14, color: _P.purple),
                      if (selected) const SizedBox(width: 4),
                      Text(
                        lang,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? _P.purple : _P.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Style
          Text(
            'Style d\'animation',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _styles.map((style) {
              final selected = _style == style;
              return GestureDetector(
                onTap: () {
                  setState(() => _style = style);
                  _updateData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? _P.purple : _P.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? _P.purple : _P.line),
                  ),
                  child: Text(
                    style,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : _P.ink,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Expérience
          _NumberField(
            label: 'Années d\'expérience',
            value: _experienceYears,
            min: 0,
            max: 30,
            step: 1,
            onChanged: (v) {
              setState(() => _experienceYears = v);
              _updateData();
            },
          ),
          const SizedBox(height: 20),

          // Compétences
          _SwitchTile(
            icon: Icons.record_voice_over,
            title: 'Peut chanter',
            subtitle: 'Animations chantées',
            value: _canSing,
            color: _P.rose,
            onChanged: (v) {
              setState(() => _canSing = v);
              _updateData();
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.music_note,
            title: 'Peut danser/animer',
            subtitle: 'Chorégraphies et jeux',
            value: _canDance,
            color: _P.amber,
            onChanged: (v) {
              setState(() => _canDance = v);
              _updateData();
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.mic_external_on,
            title: 'Équipement propre',
            subtitle: 'Micro et sono fournis',
            value: _hasOwnEquipment,
            color: _P.blue,
            onChanged: (v) {
              setState(() => _hasOwnEquipment = v);
              _updateData();
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// GÂTEAU (Pâtissier)
// ═══════════════════════════════════════════════════════════════════════

class GateauFields extends StatefulWidget {
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const GateauFields({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<GateauFields> createState() => _GateauFieldsState();
}

class _GateauFieldsState extends State<GateauFields> {
  late int _tiers;
  late int _servings;
  final List<String> _flavors = [];
  final List<String> _designs = [];
  final List<String> _allergens = [];
  late bool _customDesign;
  late bool _deliveryIncluded;
  late bool _setupIncluded;

  final List<String> _availableFlavors = [
    'Vanille',
    'Chocolat',
    'Fraise',
    'Caramel',
    'Red Velvet',
    'Citron',
    'Café',
    'Pistache',
  ];

  final List<String> _availableDesigns = [
    'Classique',
    'Moderne',
    'Fleurs fraîches',
    'Thème africain',
    'Pièce montée',
    'Naked cake',
  ];

  final List<String> _availableAllergens = [
    'Gluten',
    'Lactose',
    'Œufs',
    'Noix',
    'Arachides',
  ];

  @override
  void initState() {
    super.initState();
    _tiers = widget.data['tiers'] ?? 3;
    _servings = widget.data['servings'] ?? 100;
    _flavors.addAll(List<String>.from(widget.data['flavors'] ?? ['Vanille']));
    _designs.addAll(List<String>.from(widget.data['designs'] ?? ['Classique']));
    _allergens.addAll(List<String>.from(widget.data['allergens'] ?? []));
    _customDesign = widget.data['custom_design'] ?? true;
    _deliveryIncluded = widget.data['delivery_included'] ?? true;
    _setupIncluded = widget.data['setup_included'] ?? true;
  }

  void _updateData() {
    widget.onChanged({
      'tiers': _tiers,
      'servings': _servings,
      'flavors': _flavors,
      'designs': _designs,
      'allergens': _allergens,
      'custom_design': _customDesign,
      'delivery_included': _deliveryIncluded,
      'setup_included': _setupIncluded,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.rose.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cake, color: _P.rose, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Détails Gâteau',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Taille
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  label: 'Nombre d\'étages',
                  value: _tiers,
                  min: 1,
                  max: 7,
                  step: 1,
                  onChanged: (v) {
                    setState(() => _tiers = v);
                    _updateData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  label: 'Parts',
                  value: _servings,
                  min: 10,
                  max: 500,
                  step: 10,
                  onChanged: (v) {
                    setState(() => _servings = v);
                    _updateData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Saveurs
          Text(
            'Saveurs proposées',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableFlavors.map((flavor) {
              final selected = _flavors.contains(flavor);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _flavors.remove(flavor);
                    } else {
                      _flavors.add(flavor);
                    }
                  });
                  _updateData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _P.rose.withOpacity(0.15) : _P.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _P.rose : _P.line,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected)
                        const Icon(Icons.check_circle, size: 14, color: _P.rose),
                      if (selected) const SizedBox(width: 4),
                      Text(
                        flavor,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? _P.rose : _P.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Designs
          Text(
            'Styles de design',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableDesigns.map((design) {
              final selected = _designs.contains(design);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _designs.remove(design);
                    } else {
                      _designs.add(design);
                    }
                  });
                  _updateData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _P.purple.withOpacity(0.15) : _P.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _P.purple : _P.line,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected)
                        const Icon(Icons.check_circle, size: 14, color: _P.purple),
                      if (selected) const SizedBox(width: 4),
                      Text(
                        design,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? _P.purple : _P.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Allergènes
          Text(
            'Allergènes présents (information clients)',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableAllergens.map((allergen) {
              final selected = _allergens.contains(allergen);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _allergens.remove(allergen);
                    } else {
                      _allergens.add(allergen);
                    }
                  });
                  _updateData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _P.amber.withOpacity(0.15) : _P.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _P.amber : _P.line,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected)
                        const Icon(Icons.warning, size: 14, color: _P.amber),
                      if (selected) const SizedBox(width: 4),
                      Text(
                        allergen,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? _P.amber : _P.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Services
          _SwitchTile(
            icon: Icons.design_services,
            title: 'Design personnalisé',
            subtitle: 'Sur mesure selon vos envies',
            value: _customDesign,
            color: _P.rose,
            onChanged: (v) {
              setState(() => _customDesign = v);
              _updateData();
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.local_shipping,
            title: 'Livraison incluse',
            subtitle: 'Transport jusqu\'au lieu',
            value: _deliveryIncluded,
            color: _P.blue,
            onChanged: (v) {
              setState(() => _deliveryIncluded = v);
              _updateData();
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.build,
            title: 'Installation incluse',
            subtitle: 'Montage sur place',
            value: _setupIncluded,
            color: _P.green,
            onChanged: (v) {
              setState(() => _setupIncluded = v);
              _updateData();
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DJ
// ═══════════════════════════════════════════════════════════════════════

class DJFields extends StatefulWidget {
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const DJFields({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<DJFields> createState() => _DJFieldsState();
}

class _DJFieldsState extends State<DJFields> {
  final List<String> _musicGenres = [];
  late int _experienceYears;
  late bool _hasOwnEquipment;
  late bool _hasLighting;
  late bool _acceptsRequests;
  late bool _canMC;

  final List<String> _availableGenres = [
    'Afrobeat',
    'Rumba',
    'Hip-Hop',
    'R&B',
    'Pop',
    'House',
    'Soukous',
    'Gospel',
    'Jazz',
    'Latino',
  ];

  @override
  void initState() {
    super.initState();
    _musicGenres.addAll(List<String>.from(widget.data['music_genres'] ?? ['Afrobeat']));
    _experienceYears = widget.data['experience_years'] ?? 5;
    _hasOwnEquipment = widget.data['has_own_equipment'] ?? true;
    _hasLighting = widget.data['has_lighting'] ?? false;
    _acceptsRequests = widget.data['accepts_requests'] ?? true;
    _canMC = widget.data['can_mc'] ?? false;
  }

  void _updateData() {
    widget.onChanged({
      'music_genres': _musicGenres,
      'experience_years': _experienceYears,
      'has_own_equipment': _hasOwnEquipment,
      'has_lighting': _hasLighting,
      'accepts_requests': _acceptsRequests,
      'can_mc': _canMC,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.music_note, color: _P.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Détails DJ',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Genres musicaux
          Text(
            'Genres musicaux',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableGenres.map((genre) {
              final selected = _musicGenres.contains(genre);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _musicGenres.remove(genre);
                    } else {
                      _musicGenres.add(genre);
                    }
                  });
                  _updateData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _P.blue.withOpacity(0.15) : _P.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _P.blue : _P.line,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected)
                        const Icon(Icons.check_circle, size: 14, color: _P.blue),
                      if (selected) const SizedBox(width: 4),
                      Text(
                        genre,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? _P.blue : _P.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Expérience
          _NumberField(
            label: 'Années d\'expérience',
            value: _experienceYears,
            min: 0,
            max: 30,
            step: 1,
            onChanged: (v) {
              setState(() => _experienceYears = v);
              _updateData();
            },
          ),
          const SizedBox(height: 20),

          // Services
          _SwitchTile(
            icon: Icons.speaker,
            title: 'Équipement propre',
            subtitle: 'Sono, platines, table de mixage',
            value: _hasOwnEquipment,
            color: _P.blue,
            onChanged: (v) {
              setState(() => _hasOwnEquipment = v);
              _updateData();
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.light,
            title: 'Jeux de lumières',
            subtitle: 'Lighting et effets',
            value: _hasLighting,
            color: _P.purple,
            onChanged: (v) {
              setState(() => _hasLighting = v);
              _updateData();
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.queue_music,
            title: 'Accepte les requêtes',
            subtitle: 'Playlist personnalisable',
            value: _acceptsRequests,
            color: _P.green,
            onChanged: (v) {
              setState(() => _acceptsRequests = v);
              _updateData();
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.mic,
            title: 'Peut animer (MC)',
            subtitle: 'Animation micro incluse',
            value: _canMC,
            color: _P.rose,
            onChanged: (v) {
              setState(() => _canMC = v);
              _updateData();
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WIDGETS COMMUNS
// ═══════════════════════════════════════════════════════════════════════

class _NumberField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StepButton(
                icon: Icons.remove_circle_outline,
                onPressed: value > min ? () => onChanged(value - step) : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$value',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink),
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add_circle_outline,
                onPressed: value < max ? () => onChanged(value + step) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 22,
          color: onPressed != null ? _P.rose : _P.line,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.05) : _P.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? color.withOpacity(0.3) : _P.line,
          width: value ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }
}

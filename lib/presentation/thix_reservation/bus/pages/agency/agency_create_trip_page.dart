import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';
import 'package:thix_id/core/utils/currency_formatter.dart';
import 'package:thix_id/core/providers/currency_provider.dart';

import '../../providers/agency_dashboard_provider.dart';

/// ============================================================================
/// AgencyCreateTripPage
/// ============================================================================
///
/// Page de création d'un nouveau trajet pour les agences.
///
/// Features :
/// - Formulaire structuré en 4 sections (Trajet, Horaires, Prix, Configuration)
/// - Multi-devises global avec conversion live (40+ devises)
/// - Sélecteur de ville en bottom sheet (20+ villes RDC + Afrique)
/// - Date/Time picker avec locale
/// - Sélection visuelle du type de bus (cards avec icônes)
/// - Sélection d'équipements (chips grid)
/// - Preview visuelle du trajet
/// - Validation en temps réel avec messages traduits
/// - Auto-remplissage intelligent (station = ville par défaut)
/// - Estimation automatique de durée
/// - Skeleton loader pendant la soumission
/// - Haptic feedback sur toutes les interactions
/// - i18n complète (FR/EN/LN)
/// - Accessibilité (Semantics)
/// - Design system ThixPolicy
///
/// ============================================================================
class AgencyCreateTripPage extends ConsumerStatefulWidget {
  const AgencyCreateTripPage({super.key});

  @override
  ConsumerState<AgencyCreateTripPage> createState() =>
      _AgencyCreateTripPageState();
}

class _AgencyCreateTripPageState extends ConsumerState<AgencyCreateTripPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _depStationCtrl = TextEditingController();
  final _arrStationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController(text: '50');
  final _currencyCtrl = TextEditingController();

  // État du formulaire
  String? _fromCity;
  String? _toCity;
  String _busType = 'standard';
  final Set<String> _selectedAmenities = {};
  DateTime _depDate = DateTime.now().add(const Duration(days: 1, hours: 8));
  DateTime _arrDate = DateTime.now().add(const Duration(days: 1, hours: 14));

  // Erreurs de validation
  String? _fromError;
  String? _toError;
  String? _priceError;
  String? _seatsError;
  String? _dateError;

  // Liste des villes (à remplacer par API plus tard)
  static const _cities = [
    // RDC
    'Kinshasa', 'Lubumbashi', 'Kolwezi', 'Likasi', 'Goma', 'Bukavu',
    'Kisangani', 'Mbuji-Mayi', 'Kananga', 'Matadi', 'Mbandaka', 'Beni',
    'Butembo', 'Bunia', 'Uvira', 'Kikwit', 'Tshikapa', 'Kindu', 'Kalemie',
    'Isiro', 'Gemena', 'Lisala', 'Bandundu', 'Kenge', 'Inongo',
    // Afrique Centrale
    'Brazzaville', 'Pointe-Noire', 'Yaoundé', 'Douala', 'Libreville',
    'Bangui', 'N\'Djamena',
    // Afrique de l'Ouest
    'Abidjan', 'Dakar', 'Bamako', 'Ouagadougou', 'Lomé', 'Cotonou',
    'Niamey', 'Accra', 'Lagos',
    // Afrique de l'Est
    'Nairobi', 'Kampala', 'Kigali', 'Bujumbura', 'Dar es Salaam',
    'Addis-Abeba',
  ];

  // Équipements disponibles
  static const _amenities = [
    ('wifi', 'amenityWifi', Icons.wifi_rounded),
    ('ac', 'amenityAc', Icons.ac_unit_rounded),
    ('usb', 'amenityUsb', Icons.usb_rounded),
    ('toilet', 'amenityToilet', Icons.wc_rounded),
    ('tv', 'amenityTv', Icons.tv_rounded),
    ('snack', 'agencyTripAmenitySnack', Icons.restaurant_rounded),
    ('luggage', 'agencyTripAmenityLuggage', Icons.luggage_rounded),
    ('reclining', 'agencyTripAmenityReclining', Icons.airline_seat_recline_extra_rounded),
  ];

  // Types de bus
  static const _busTypes = [
    ('standard', 'agencyTripBusStandard', Icons.directions_bus_rounded, 'Standard'),
    ('climatise', 'agencyTripBusClim', Icons.ac_unit_rounded, 'Climatisé'),
    ('vip', 'agencyTripBusVip', Icons.star_rounded, 'VIP'),
    ('sleeper', 'agencyTripBusSleeper', Icons.bed_rounded, 'Couchette'),
  ];

  @override
  void initState() {
    super.initState();
    _priceCtrl.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    _depStationCtrl.dispose();
    _arrStationCtrl.dispose();
    _priceCtrl.dispose();
    _seatsCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  void _onPriceChanged() {
    setState(() {
      _priceError = null;
    });
  }

  void _validateForm() {
    final l10n = context.l10n;
    bool isValid = true;

    // Validation villes
    if (_fromCity == null || _fromCity!.isEmpty) {
      setState(() => _fromError = l10n.agencyTripErrorCityRequired);
      isValid = false;
    } else {
      setState(() => _fromError = null);
    }

    if (_toCity == null || _toCity!.isEmpty) {
      setState(() => _toError = l10n.agencyTripErrorCityRequired);
      isValid = false;
    } else if (_fromCity == _toCity) {
      setState(() => _toError = l10n.agencyTripErrorSameCity);
      isValid = false;
    } else {
      setState(() => _toError = null);
    }

    // Validation dates
    if (!_arrDate.isAfter(_depDate)) {
      setState(() => _dateError = l10n.agencyTripErrorDateOrder);
      isValid = false;
    } else if (_depDate.isBefore(DateTime.now())) {
      setState(() => _dateError = l10n.agencyTripErrorDatePast);
      isValid = false;
    } else {
      setState(() => _dateError = null);
    }

    // Validation prix
    final price = int.tryParse(_priceCtrl.text.trim());
    if (price == null || price <= 0) {
      setState(() => _priceError = l10n.agencyTripErrorPriceInvalid);
      isValid = false;
    } else if (price < 1000) {
      setState(() => _priceError = l10n.agencyTripErrorPriceTooLow);
      isValid = false;
    } else {
      setState(() => _priceError = null);
    }

    // Validation places
    final seats = int.tryParse(_seatsCtrl.text.trim());
    if (seats == null || seats <= 0) {
      setState(() => _seatsError = l10n.agencyTripErrorSeatsInvalid);
      isValid = false;
    } else if (seats > 100) {
      setState(() => _seatsError = l10n.agencyTripErrorSeatsTooMany);
      isValid = false;
    } else {
      setState(() => _seatsError = null);
    }

    if (!isValid) {
      HapticFeedback.mediumImpact();
    }

    return isValid;
  }

  Future<void> _submit() async {
    if (!_validateForm()) return;

    final l10n = context.l10n;
    final currencyState = ref.read(currencyProvider);

    // Convertir le prix en CDF pour le stockage
    final priceInDisplayCurrency = int.parse(_priceCtrl.text.trim());
    final priceInCdf = currencyState.convert(
      priceInDisplayCurrency,
      fromCurrency: currencyState.currency.code,
      toCurrency: 'CDF',
    ).round();

    final notifier = ref.read(agencyDashboardProvider.notifier);

    HapticFeedback.mediumImpact();

    final success = await notifier.createTrip(
      from: _fromCity!,
      to: _toCity!,
      departureStation: _depStationCtrl.text.trim().isEmpty
          ? _fromCity!
          : _depStationCtrl.text.trim(),
      arrivalStation: _arrStationCtrl.text.trim().isEmpty
          ? _toCity!
          : _arrStationCtrl.text.trim(),
      departureTime: _depDate,
      arrivalTime: _arrDate,
      price: priceInCdf,
      totalSeats: int.parse(_seatsCtrl.text.trim()),
      busType: _busType,
      amenities: _selectedAmenities.toList(),
    );

    if (!mounted) return;

    if (success) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: ThixPolicy.s8),
              Expanded(child: Text(l10n.agencyTripSuccessMessage)),
            ],
          ),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          ),
        ),
      );
      context.pop();
    } else {
      final error = ref.read(agencyDashboardProvider).error;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: ThixPolicy.s8),
              Expanded(child: Text(error ?? l10n.agencyTripErrorMessage)),
            ],
          ),
          backgroundColor: ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          ),
        ),
      );
    }
  }

  Future<void> _pickDateTime({required bool isDeparture}) async {
    final l10n = context.l10n;
    final initial = isDeparture ? _depDate : _arrDate;

    HapticFeedback.lightImpact();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: Localizations.localeOf(context),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ThixPolicy.domainReservation,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ThixPolicy.domainReservation,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null || !mounted) return;

    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isDeparture) {
        _depDate = value;
        if (!_arrDate.isAfter(_depDate)) {
          _arrDate = _depDate.add(const Duration(hours: 6));
        }
      } else {
        _arrDate = value;
      }
      _dateError = null;
    });

    HapticFeedback.selectionClick();
  }

  void _showCitySelector({required bool isDeparture}) async {
    final l10n = context.l10n;
    HapticFeedback.lightImpact();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CitySelectorSheet(
        title: isDeparture
            ? l10n.agencyTripSelectDeparture
            : l10n.agencyTripSelectArrival,
        cities: _cities,
        currentCity: isDeparture ? _fromCity : _toCity,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (isDeparture) {
          _fromCity = result;
          _fromError = null;
          if (_depStationCtrl.text.trim().isEmpty) {
            _depStationCtrl.text = result;
          }
        } else {
          _toCity = result;
          _toError = null;
          if (_arrStationCtrl.text.trim().isEmpty) {
            _arrStationCtrl.text = result;
          }
        }
      });
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(agencyDashboardProvider);
    final currencyState = ref.watch(currencyProvider);
    final domainColor = ThixPolicy.domainReservation;

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
          tooltip: l10n.commonBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.agencyTripCreateTitle,
              style: ThixPolicy.titleStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                fontSize: 16,
                color: ThixPolicy.textMain,
              ),
            ),
            if (state.myAgency?.name != null)
              Text(
                state.myAgency!.name,
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                ),
              ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(ThixPolicy.s16),
          children: [
            // Preview du trajet
            if (_fromCity != null && _toCity != null)
              Padding(
                padding: EdgeInsets.only(bottom: ThixPolicy.s16),
                child: _TripPreviewCard(
                  fromCity: _fromCity!,
                  toCity: _toCity!,
                  depDate: _depDate,
                  arrDate: _arrDate,
                  domainColor: domainColor,
                ),
              ),

            // Section 1: Trajet
            _FormSection(
              icon: Icons.route_rounded,
              title: l10n.agencyTripSectionRoute,
              domainColor: domainColor,
              children: [
                _CitySelector(
                  label: l10n.agencyTripDepartureCity,
                  value: _fromCity,
                  placeholder: l10n.agencyTripSelectDeparture,
                  icon: Icons.my_location_rounded,
                  error: _fromError,
                  onTap: () => _showCitySelector(isDeparture: true),
                  domainColor: domainColor,
                ),
                SizedBox(height: ThixPolicy.s14),
                _CitySelector(
                  label: l10n.agencyTripArrivalCity,
                  value: _toCity,
                  placeholder: l10n.agencyTripSelectArrival,
                  icon: Icons.location_on_rounded,
                  error: _toError,
                  onTap: () => _showCitySelector(isDeparture: false),
                  domainColor: domainColor,
                ),
                SizedBox(height: ThixPolicy.s14),
                _StationInput(
                  label: l10n.agencyTripDepartureStation,
                  controller: _depStationCtrl,
                  hint: _fromCity ?? l10n.agencyTripStationHint,
                  icon: Icons.departure_board_rounded,
                  domainColor: domainColor,
                ),
                SizedBox(height: ThixPolicy.s14),
                _StationInput(
                  label: l10n.agencyTripArrivalStation,
                  controller: _arrStationCtrl,
                  hint: _toCity ?? l10n.agencyTripStationHint,
                  icon: Icons.place_rounded,
                  domainColor: domainColor,
                ),
              ],
            ),
            SizedBox(height: ThixPolicy.s20),

            // Section 2: Horaires
            _FormSection(
              icon: Icons.schedule_rounded,
              title: l10n.agencyTripSectionSchedule,
              domainColor: domainColor,
              children: [
                _DateTimeTile(
                  label: l10n.agencyTripDepartureDateTime,
                  value: _depDate,
                  icon: Icons.flight_takeoff_rounded,
                  onTap: () => _pickDateTime(isDeparture: true),
                  domainColor: domainColor,
                ),
                SizedBox(height: ThixPolicy.s10),
                _DateTimeTile(
                  label: l10n.agencyTripArrivalDateTime,
                  value: _arrDate,
                  icon: Icons.flight_land_rounded,
                  onTap: () => _pickDateTime(isDeparture: false),
                  domainColor: domainColor,
                ),
                if (_dateError != null) ...[
                  SizedBox(height: ThixPolicy.s8),
                  _ErrorText(message: _dateError!),
                ],
                if (_depDate.isBefore(_arrDate)) ...[
                  SizedBox(height: ThixPolicy.s10),
                  _DurationInfo(
                    duration: _arrDate.difference(_depDate),
                    domainColor: domainColor,
                  ),
                ],
              ],
            ),
            SizedBox(height: ThixPolicy.s20),

            // Section 3: Prix et capacité
            _FormSection(
              icon: Icons.payments_rounded,
              title: l10n.agencyTripSectionPricing,
              domainColor: domainColor,
              children: [
                _PriceInput(
                  controller: _priceCtrl,
                  currency: currencyState.currency,
                  error: _priceError,
                  domainColor: domainColor,
                ),
                SizedBox(height: ThixPolicy.s14),
                _SeatsInput(
                  controller: _seatsCtrl,
                  error: _seatsError,
                  domainColor: domainColor,
                ),
              ],
            ),
            SizedBox(height: ThixPolicy.s20),

            // Section 4: Configuration du bus
            _FormSection(
              icon: Icons.directions_bus_rounded,
              title: l10n.agencyTripSectionBusConfig,
              domainColor: domainColor,
              children: [
                _BusTypeSelector(
                  selected: _busType,
                  onChanged: (type) {
                    HapticFeedback.selectionClick();
                    setState(() => _busType = type);
                  },
                  domainColor: domainColor,
                ),
                SizedBox(height: ThixPolicy.s16),
                _AmenitiesSelector(
                  selected: _selectedAmenities,
                  onChanged: (amenities) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedAmenities
                      ..clear()
                      ..addAll(amenities));
                  },
                  domainColor: domainColor,
                ),
              ],
            ),
            SizedBox(height: ThixPolicy.s32),

            // Bouton de soumission
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: state.isCreating ? null : _submit,
                icon: state.isCreating
                    ? const SizedBox.shrink()
                    : const Icon(Icons.check_rounded, color: Colors.white),
                label: state.isCreating
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: ThixPolicy.s10),
                          Text(
                            l10n.agencyTripCreating,
                            style: ThixPolicy.titleStyle.copyWith(
                              color: Colors.white,
                              fontWeight: ThixPolicy.bold,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        l10n.agencyTripPublishButton,
                        style: ThixPolicy.titleStyle.copyWith(
                          color: Colors.white,
                          fontWeight: ThixPolicy.bold,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: domainColor,
                  disabledBackgroundColor: ThixPolicy.textMuted,
                  disabledForegroundColor: Colors.white70,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  ),
                ),
              ),
            ),
            SizedBox(height: ThixPolicy.s32),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// _FormSection — Section de formulaire avec titre et icône
/// ============================================================================
class _FormSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color domainColor;
  final List<Widget> children;

  const _FormSection({
    required this.icon,
    required this.title,
    required this.domainColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(ThixPolicy.s8),
                decoration: BoxDecoration(
                  color: domainColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                ),
                child: Icon(icon, size: 18, color: domainColor),
              ),
              SizedBox(width: ThixPolicy.s10),
              Expanded(
                child: Text(
                  title,
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 15,
                    color: ThixPolicy.textMain,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ThixPolicy.s16),
          ...children,
        ],
      ),
    );
  }
}

/// ============================================================================
/// _CitySelector — Sélecteur de ville avec bottom sheet
/// ============================================================================
class _CitySelector extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final String? error;
  final VoidCallback onTap;
  final Color domainColor;

  const _CitySelector({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.icon,
    required this.error,
    required this.onTap,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, required: true),
        SizedBox(height: ThixPolicy.s6),
        Semantics(
          button: true,
          label: '$label: ${value ?? placeholder}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s14,
                  vertical: ThixPolicy.s14,
                ),
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  border: Border.all(
                    color: error != null ? ThixPolicy.danger : ThixPolicy.border,
                    width: error != null ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: domainColor),
                    SizedBox(width: ThixPolicy.s10),
                    Expanded(
                      child: Text(
                        value ?? placeholder,
                        style: ThixPolicy.bodyStyle.copyWith(
                          color: value != null
                              ? ThixPolicy.textMain
                              : ThixPolicy.textMuted,
                          fontWeight: value != null
                              ? ThixPolicy.semiBold
                              : ThixPolicy.regular,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: ThixPolicy.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          SizedBox(height: ThixPolicy.s6),
          _ErrorText(message: error!),
        ],
      ],
    );
  }
}

/// ============================================================================
/// _CitySelectorSheet — Bottom sheet pour sélectionner une ville
/// ============================================================================
class _CitySelectorSheet extends StatefulWidget {
  final String title;
  final List<String> cities;
  final String? currentCity;

  const _CitySelectorSheet({
    required this.title,
    required this.cities,
    required this.currentCity,
  });

  @override
  State<_CitySelectorSheet> createState() => _CitySelectorSheetState();
}

class _CitySelectorSheetState extends State<_CitySelectorSheet> {
  String _searchQuery = '';

  List<String> get _filteredCities {
    if (_searchQuery.isEmpty) return widget.cities;
    return widget.cities
        .where((c) => c.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final domainColor = ThixPolicy.domainReservation;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.r2Xl)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: ThixPolicy.s12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ThixPolicy.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          SizedBox(height: ThixPolicy.s20),

          // Title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
            child: Row(
              children: [
                Icon(Icons.location_city_rounded, color: domainColor, size: 24),
                SizedBox(width: ThixPolicy.s10),
                Text(
                  widget.title,
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ThixPolicy.s16),

          // Search
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: l10n.agencyTripSearchCity,
                prefixIcon: Icon(Icons.search_rounded, color: ThixPolicy.textSecondary),
                filled: true,
                fillColor: ThixPolicy.surfaceSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s16,
                  vertical: ThixPolicy.s12,
                ),
              ),
            ),
          ),
          SizedBox(height: ThixPolicy.s16),

          // Cities list
          Expanded(
            child: _filteredCities.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: ThixPolicy.textMuted,
                        ),
                        SizedBox(height: ThixPolicy.s12),
                        Text(
                          l10n.agencyTripNoCityFound,
                          style: ThixPolicy.bodySmallStyle.copyWith(
                            color: ThixPolicy.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredCities.length,
                    itemBuilder: (context, index) {
                      final city = _filteredCities[index];
                      final isSelected = city == widget.currentCity;

                      return ListTile(
                        leading: isSelected
                            ? Icon(Icons.check_circle_rounded, color: domainColor)
                            : Icon(Icons.location_city_rounded, color: ThixPolicy.textSecondary),
                        title: Text(
                          city,
                          style: ThixPolicy.bodyStyle.copyWith(
                            fontWeight: isSelected ? ThixPolicy.bold : ThixPolicy.medium,
                            color: isSelected ? domainColor : ThixPolicy.textMain,
                          ),
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context, city);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _StationInput — Input pour le nom de la station
/// ============================================================================
class _StationInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color domainColor;

  const _StationInput({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, required: false),
        SizedBox(height: ThixPolicy.s6),
        TextFormField(
          controller: controller,
          style: ThixPolicy.bodyStyle.copyWith(
            fontWeight: ThixPolicy.medium,
            color: ThixPolicy.textMain,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: ThixPolicy.bodyStyle.copyWith(
              color: ThixPolicy.textMuted,
            ),
            prefixIcon: Icon(icon, size: 18, color: domainColor),
            filled: true,
            fillColor: ThixPolicy.surfaceSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: BorderSide(color: ThixPolicy.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: BorderSide(color: domainColor, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: ThixPolicy.s14,
              vertical: ThixPolicy.s14,
            ),
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// _DateTimeTile — Tuile pour sélectionner date et heure
/// ============================================================================
class _DateTimeTile extends StatelessWidget {
  final String label;
  final DateTime value;
  final IconData icon;
  final VoidCallback onTap;
  final Color domainColor;

  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final formattedDate = DateFormat('EEE d MMM yyyy', locale).format(value);
    final formattedTime = DateFormat('HH:mm', locale).format(value);

    return Semantics(
      button: true,
      label: '$label: $formattedDate à $formattedTime',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: ThixPolicy.s14,
              vertical: ThixPolicy.s14,
            ),
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: Border.all(color: ThixPolicy.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ThixPolicy.s8),
                  decoration: BoxDecoration(
                    color: domainColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                  ),
                  child: Icon(icon, size: 18, color: domainColor),
                ),
                SizedBox(width: ThixPolicy.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: ThixPolicy.microStyle.copyWith(
                          color: ThixPolicy.textSecondary,
                          fontWeight: ThixPolicy.medium,
                        ),
                      ),
                      SizedBox(height: ThixPolicy.s4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formattedDate,
                              style: ThixPolicy.bodySmallStyle.copyWith(
                                fontWeight: ThixPolicy.semiBold,
                                color: ThixPolicy.textMain,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ThixPolicy.s8,
                              vertical: ThixPolicy.s4,
                            ),
                            decoration: BoxDecoration(
                              color: domainColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                            ),
                            child: Text(
                              formattedTime,
                              style: ThixPolicy.labelStyle.copyWith(
                                color: domainColor,
                                fontWeight: ThixPolicy.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.edit_calendar_rounded,
                  size: 18,
                  color: ThixPolicy.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _DurationInfo — Affichage de la durée estimée
/// ============================================================================
class _DurationInfo extends StatelessWidget {
  final Duration duration;
  final Color domainColor;

  const _DurationInfo({
    required this.duration,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s12),
      decoration: BoxDecoration(
        color: domainColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(color: domainColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: domainColor,
          ),
          SizedBox(width: ThixPolicy.s8),
          Expanded(
            child: Text(
              l10n.agencyTripEstimatedDuration(hours, minutes),
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: domainColor,
                fontWeight: ThixPolicy.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _PriceInput — Input de prix avec conversion multi-devises
/// ============================================================================
class _PriceInput extends ConsumerWidget {
  final TextEditingController controller;
  final Currency currency;
  final String? error;
  final Color domainColor;

  const _PriceInput({
    required this.controller,
    required this.currency,
    required this.error,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final price = int.tryParse(controller.text.trim());
    String? conversionPreview;

    if (price != null && price > 0) {
      // Convertir en CDF pour la preview
      int priceInCdf;
if (currencyState.currency.code == 'CDF') {
  priceInCdf = priceInDisplayCurrency;
} else {
  // Utiliser le taux inverse depuis les exchangeRates du provider
  final rate = currencyState.exchangeRates['${currencyState.currency.code}_CDF'];
  priceInCdf = rate != null 
      ? (priceInDisplayCurrency * rate).round() 
      : priceInDisplayCurrency; // Fallback si taux indisponible
}

      if (currency.code != 'CDF') {
        conversionPreview = l10n.agencyTripPriceConversion(
          CurrencyFormatter.format(priceInCdf, currency: 'CDF'),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: l10n.agencyTripPricePerSeat, required: true),
        SizedBox(height: ThixPolicy.s6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: ThixPolicy.bodyStyle.copyWith(
            fontWeight: ThixPolicy.bold,
            color: ThixPolicy.textMain,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: ThixPolicy.bodyStyle.copyWith(
              color: ThixPolicy.textMuted,
            ),
            prefixIcon: Icon(Icons.payments_rounded, size: 18, color: domainColor),
            suffixIcon: Container(
              padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s12),
              alignment: Alignment.centerRight,
              child: Text(
                currency.symbol,
                style: ThixPolicy.labelStyle.copyWith(
                  color: domainColor,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
            ),
            errorText: error,
            filled: true,
            fillColor: ThixPolicy.surfaceSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: BorderSide(
                color: error != null ? ThixPolicy.danger : ThixPolicy.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: BorderSide(
                color: error != null ? ThixPolicy.danger : domainColor,
                width: 1.5,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: ThixPolicy.s14,
              vertical: ThixPolicy.s14,
            ),
          ),
        ),
        if (conversionPreview != null) ...[
          SizedBox(height: ThixPolicy.s8),
          Container(
            padding: EdgeInsets.all(ThixPolicy.s10),
            decoration: BoxDecoration(
              color: ThixPolicy.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(ThixPolicy.rXs),
              border: Border.all(color: ThixPolicy.info.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: ThixPolicy.info),
                SizedBox(width: ThixPolicy.s8),
                Expanded(
                  child: Text(
                    conversionPreview,
                    style: ThixPolicy.microStyle.copyWith(
                      color: ThixPolicy.info,
                      fontWeight: ThixPolicy.semiBold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// ============================================================================
/// _SeatsInput — Input pour le nombre de places
/// ============================================================================
class _SeatsInput extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final Color domainColor;

  const _SeatsInput({
    required this.controller,
    required this.error,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: l10n.agencyTripTotalSeats, required: true),
        SizedBox(height: ThixPolicy.s6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: ThixPolicy.bodyStyle.copyWith(
            fontWeight: ThixPolicy.bold,
            color: ThixPolicy.textMain,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: '50',
            hintStyle: ThixPolicy.bodyStyle.copyWith(
              color: ThixPolicy.textMuted,
            ),
            prefixIcon: Icon(Icons.event_seat_rounded, size: 18, color: domainColor),
            suffixIcon: Icon(Icons.people_outline_rounded, size: 18, color: ThixPolicy.textSecondary),
            errorText: error,
            filled: true,
            fillColor: ThixPolicy.surfaceSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: BorderSide(
                color: error != null ? ThixPolicy.danger : ThixPolicy.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: BorderSide(
                color: error != null ? ThixPolicy.danger : domainColor,
                width: 1.5,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: ThixPolicy.s14,
              vertical: ThixPolicy.s14,
            ),
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// _BusTypeSelector — Sélecteur visuel du type de bus
/// ============================================================================
class _BusTypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final Color domainColor;

  const _BusTypeSelector({
    required this.selected,
    required this.onChanged,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: l10n.agencyTripBusType, required: true),
        SizedBox(height: ThixPolicy.s10),
        Wrap(
          spacing: ThixPolicy.s10,
          runSpacing: ThixPolicy.s10,
          children: _busTypes.map((type) {
            final (value, labelKey, icon, defaultLabel) = type;
            final isSelected = value == selected;

            final label = _translateLabel(l10n, labelKey) ?? defaultLabel;

            return Semantics(
              button: true,
              selected: isSelected,
              label: label,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged(value),
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 180),
                    width: (MediaQuery.of(context).size.width - 62) / 2,
                    padding: EdgeInsets.all(ThixPolicy.s14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? domainColor.withValues(alpha: 0.12)
                          : ThixPolicy.surfaceSoft,
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      border: Border.all(
                        color: isSelected ? domainColor : ThixPolicy.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          icon,
                          size: 28,
                          color: isSelected ? domainColor : ThixPolicy.textSecondary,
                        ),
                        SizedBox(height: ThixPolicy.s8),
                        Text(
                          label,
                          style: ThixPolicy.labelStyle.copyWith(
                            color: isSelected ? domainColor : ThixPolicy.textMain,
                            fontWeight: ThixPolicy.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String? _translateLabel(dynamic l10n, String key) {
    try {
      switch (key) {
        case 'agencyTripBusStandard':
          return l10n.agencyTripBusStandard;
        case 'agencyTripBusClim':
          return l10n.agencyTripBusClim;
        case 'agencyTripBusVip':
          return l10n.agencyTripBusVip;
        case 'agencyTripBusSleeper':
          return l10n.agencyTripBusSleeper;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}

/// ============================================================================
/// _AmenitiesSelector — Sélecteur d'équipements (chips)
/// ============================================================================
class _AmenitiesSelector extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final Color domainColor;

  const _AmenitiesSelector({
    required this.selected,
    required this.onChanged,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: l10n.agencyTripAmenities, required: false),
        SizedBox(height: ThixPolicy.s10),
        Wrap(
          spacing: ThixPolicy.s8,
          runSpacing: ThixPolicy.s8,
          children: _amenities.map((amenity) {
            final (value, labelKey, icon) = amenity;
            final isSelected = selected.contains(value);

            final label = _translateLabel(l10n, labelKey);

            return Semantics(
              button: true,
              selected: isSelected,
              label: label,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final newSet = Set<String>.from(selected);
                    if (isSelected) {
                      newSet.remove(value);
                    } else {
                      newSet.add(value);
                    }
                    onChanged(newSet);
                  },
                  borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(
                      horizontal: ThixPolicy.s12,
                      vertical: ThixPolicy.s8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? domainColor.withValues(alpha: 0.12)
                          : ThixPolicy.surfaceSoft,
                      borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                      border: Border.all(
                        color: isSelected ? domainColor : ThixPolicy.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 14,
                          color: isSelected ? domainColor : ThixPolicy.textSecondary,
                        ),
                        SizedBox(width: ThixPolicy.s6),
                        Text(
                          label,
                          style: ThixPolicy.labelStyle.copyWith(
                            color: isSelected ? domainColor : ThixPolicy.textMain,
                            fontWeight: ThixPolicy.semiBold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _translateLabel(dynamic l10n, String key) {
    try {
      switch (key) {
        case 'amenityWifi':
          return l10n.amenityWifi;
        case 'amenityAc':
          return l10n.amenityAc;
        case 'amenityUsb':
          return l10n.amenityUsb;
        case 'amenityToilet':
          return l10n.amenityToilet;
        case 'amenityTv':
          return l10n.amenityTv;
        case 'agencyTripAmenitySnack':
          return l10n.agencyTripAmenitySnack;
        case 'agencyTripAmenityLuggage':
          return l10n.agencyTripAmenityLuggage;
        case 'agencyTripAmenityReclining':
          return l10n.agencyTripAmenityReclining;
        default:
          return key;
      }
    } catch (_) {
      return key;
    }
  }
}

/// ============================================================================
/// _TripPreviewCard — Carte de preview du trajet
/// ============================================================================
class _TripPreviewCard extends ConsumerWidget {
  final String fromCity;
  final String toCity;
  final DateTime depDate;
  final DateTime arrDate;
  final Color domainColor;

  const _TripPreviewCard({
    required this.fromCity,
    required this.toCity,
    required this.depDate,
    required this.arrDate,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final depTime = DateFormat('HH:mm', locale).format(depDate);
    final arrTime = DateFormat('HH:mm', locale).format(arrDate);
    final depDay = DateFormat('d MMM', locale).format(depDate);
    final arrDay = DateFormat('d MMM', locale).format(arrDate);

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            domainColor,
            domainColor.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        boxShadow: [
          BoxShadow(
            color: domainColor.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.directions_bus_rounded, color: Colors.white, size: 20),
              SizedBox(width: ThixPolicy.s8),
              Text(
                l10n.agencyTripPreviewTitle,
                style: ThixPolicy.labelStyle.copyWith(
                  color: Colors.white,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: ThixPolicy.s14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      depTime,
                      style: ThixPolicy.h2Style.copyWith(
                        color: Colors.white,
                        fontWeight: ThixPolicy.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: ThixPolicy.s4),
                    Text(
                      fromCity,
                      style: ThixPolicy.bodySmallStyle.copyWith(
                        color: Colors.white,
                        fontWeight: ThixPolicy.semiBold,
                      ),
                    ),
                    Text(
                      depDay,
                      style: ThixPolicy.microStyle.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 24,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      arrTime,
                      style: ThixPolicy.h2Style.copyWith(
                        color: Colors.white,
                        fontWeight: ThixPolicy.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: ThixPolicy.s4),
                    Text(
                      toCity,
                      style: ThixPolicy.bodySmallStyle.copyWith(
                        color: Colors.white,
                        fontWeight: ThixPolicy.semiBold,
                      ),
                    ),
                    Text(
                      arrDay,
                      style: ThixPolicy.microStyle.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _FieldLabel — Label de champ avec indicateur requis
/// ============================================================================
class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;

  const _FieldLabel({
    required this.label,
    required this.required,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Text(
          label,
          style: ThixPolicy.labelStyle.copyWith(
            color: ThixPolicy.textMain,
            fontWeight: ThixPolicy.semiBold,
            fontSize: 12,
          ),
        ),
        if (required) ...[
          SizedBox(width: ThixPolicy.s4),
          Text(
            '*',
            style: ThixPolicy.labelStyle.copyWith(
              color: ThixPolicy.danger,
              fontWeight: ThixPolicy.bold,
            ),
          ),
        ],
        if (!required) ...[
          SizedBox(width: ThixPolicy.s4),
          Text(
            '(${l10n.commonOptional})',
            style: ThixPolicy.microStyle.copyWith(
              color: ThixPolicy.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// ============================================================================
/// _ErrorText — Texte d'erreur
/// ============================================================================
class _ErrorText extends StatelessWidget {
  final String message;

  const _ErrorText({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: ThixPolicy.danger,
        ),
        SizedBox(width: ThixPolicy.s6),
        Expanded(
          child: Text(
            message,
            style: ThixPolicy.microStyle.copyWith(
              color: ThixPolicy.danger,
              fontWeight: ThixPolicy.medium,
            ),
          ),
        ),
      ],
    );
  }
}

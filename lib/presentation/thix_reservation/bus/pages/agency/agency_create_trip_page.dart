// lib/presentation/thix_reservation/bus/pages/agency/agency_create_trip_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../providers/agency_dashboard_provider.dart';

class AgencyCreateTripPage extends ConsumerStatefulWidget {
  const AgencyCreateTripPage({super.key});

  @override
  ConsumerState<AgencyCreateTripPage> createState() => _AgencyCreateTripPageState();
}

class _AgencyCreateTripPageState extends ConsumerState<AgencyCreateTripPage> {
  static const _cities = [
    'Kinshasa',
    'Lubumbashi',
    'Kolwezi',
    'Likasi',
    'Goma',
    'Bukavu',
    'Kisangani',
    'Mbuji-Mayi',
    'Kananga',
    'Matadi',
    'Mbandaka',
    'Beni',
    'Butembo',
    'Bunia',
    'Uvira',
    'Kikwit',
    'Tshikapa',
    'Kindu',
    'Kalemie',
    'Isiro',
  ];

  static const double _usdToCdf = 2850;

  final _formKey = GlobalKey<FormState>();
  final _depStationCtrl = TextEditingController();
  final _arrStationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController(text: '50');

  String? _from;
  String? _to;
  String _busType = 'standard';
  String _currency = 'CDF';
  DateTime _depDate = DateTime.now().add(const Duration(days: 1, hours: 8));
  DateTime _arrDate = DateTime.now().add(const Duration(days: 1, hours: 14));

  @override
  void dispose() {
    _depStationCtrl.dispose();
    _arrStationCtrl.dispose();
    _priceCtrl.dispose();
    _seatsCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '\( {two(d.day)}/ \){two(d.month)}/${d.year}   \( {two(d.hour)}: \){two(d.minute)}';
  }

  Future<void> _pickDateTime({required bool isDeparture}) async {
    final initial = isDeparture ? _depDate : _arrDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: ThixPolicy.primary),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: ThixPolicy.primary),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isDeparture) {
        _depDate = value;
        if (!_arrDate.isAfter(_depDate)) {
          _arrDate = _depDate.add(const Duration(hours: 6));
        }
      } else {
        _arrDate = value;
      }
    });
  }

  int _priceInCdf() {
    final raw = int.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (_currency == 'USD') {
      return (raw * _usdToCdf).round();
    }
    return raw;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_from == null || _to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis les villes de départ et d\'arrivée')),
      );
      return;
    }
    if (_from == _to) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le départ et l\'arrivée doivent être différents')),
      );
      return;
    }
    if (!_arrDate.isAfter(_depDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L\'arrivée doit être après le départ')),
      );
      return;
    }

    final notifier = ref.read(agencyDashboardProvider.notifier);
    final success = await notifier.createTrip(
      from: _from!,
      to: _to!,
      departureStation: _depStationCtrl.text.trim().isEmpty ? _from! : _depStationCtrl.text.trim(),
      arrivalStation: _arrStationCtrl.text.trim().isEmpty ? _to! : _arrStationCtrl.text.trim(),
      departureTime: _depDate,
      arrivalTime: _arrDate,
      price: _priceInCdf(),
      totalSeats: int.parse(_seatsCtrl.text.trim()),
      busType: _busType,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trajet créé avec succès !'),
          backgroundColor: ThixPolicy.success,
        ),
      );
      context.pop();
    } else {
      final error = ref.read(agencyDashboardProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Erreur lors de la création'),
          backgroundColor: ThixPolicy.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agencyDashboardProvider);
    final previewCdf = int.tryParse(_priceCtrl.text.trim());
    final preview = previewCdf == null
        ? ''
        : (_currency == 'USD'
            ? '≈ ${(previewCdf * _usdToCdf).toStringAsFixed(0)} CDF'
            : '≈ ${(previewCdf / _usdToCdf).toStringAsFixed(2)} USD');

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Créer un nouveau trajet',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThixPolicy.rXl),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowCard(),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCityField(
                  label: 'Ville de départ',
                  value: _from,
                  icon: Icons.my_location_rounded,
                  onChanged: (v) {
                    setState(() {
                      _from = v;
                      if (_depStationCtrl.text.trim().isEmpty && v != null) {
                        _depStationCtrl.text = v;
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),
                _buildCityField(
                  label: 'Ville d\'arrivée',
                  value: _to,
                  icon: Icons.location_on_rounded,
                  onChanged: (v) {
                    setState(() {
                      _to = v;
                      if (_arrStationCtrl.text.trim().isEmpty && v != null) {
                        _arrStationCtrl.text = v;
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  label: 'Gare / Station de départ',
                  controller: _depStationCtrl,
                  icon: Icons.departure_board_rounded,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  label: 'Gare / Station d\'arrivée',
                  controller: _arrStationCtrl,
                  icon: Icons.place_rounded,
                ),
                const SizedBox(height: 8),
                _buildDateTile(
                  label: 'Date et heure de départ',
                  value: _fmt(_depDate),
                  icon: Icons.schedule_rounded,
                  onTap: () => _pickDateTime(isDeparture: true),
                ),
                _buildDateTile(
                  label: 'Date et heure d\'arrivée',
                  value: _fmt(_arrDate),
                  icon: Icons.flag_rounded,
                  onTap: () => _pickDateTime(isDeparture: false),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: _currency == 'USD' ? 'Prix (USD)' : 'Prix (CDF)',
                        controller: _priceCtrl,
                        icon: Icons.payments_rounded,
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 96,
                      child: DropdownButtonFormField<String>(
                        value: _currency,
                        decoration: _dropdownDeco('Devise'),
                        items: const [
                          DropdownMenuItem(value: 'CDF', child: Text('CDF')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (v) => setState(() => _currency = v ?? 'CDF'),
                      ),
                    ),
                  ],
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Nombre de places',
                        controller: _seatsCtrl,
                        icon: Icons.event_seat_rounded,
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _busType,
                        decoration: _dropdownDeco('Type de bus'),
                        items: const [
                          DropdownMenuItem(value: 'standard', child: Text('Standard')),
                          DropdownMenuItem(value: 'climatise', child: Text('Climatisé')),
                          DropdownMenuItem(value: 'vip', child: Text('VIP')),
                        ],
                        onChanged: (v) => setState(() => _busType = v ?? 'standard'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: state.isCreating ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixPolicy.primary,
                      disabledBackgroundColor: Colors.grey.shade300,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                    ),
                    child: state.isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Publier le trajet',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dropdownDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: ThixPolicy.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ThixPolicy.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildCityField({
    required String label,
    required String? value,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, size: 18, color: ThixPolicy.primary),
        filled: true,
        fillColor: ThixPolicy.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ThixPolicy.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDateTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: ThixPolicy.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar_rounded, size: 18, color: ThixPolicy.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ThixPolicy.textMain),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, size: 18, color: ThixPolicy.primary),
        filled: true,
        fillColor: ThixPolicy.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ThixPolicy.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

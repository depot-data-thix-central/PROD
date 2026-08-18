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
  final _formKey = GlobalKey<FormState>();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _depStationCtrl = TextEditingController();
  final _arrStationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController(text: '50');
  
  String _busType = 'standard';
  DateTime _depDate = DateTime.now().add(const Duration(days: 1));
  DateTime _arrDate = DateTime.now().add(const Duration(days: 1, hours: 5));

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _depStationCtrl.dispose();
    _arrStationCtrl.dispose();
    _priceCtrl.dispose();
    _seatsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(agencyDashboardProvider.notifier);

    final success = await notifier.createTrip(
      from: _fromCtrl.text.trim(),
      to: _toCtrl.text.trim(),
      departureStation: _depStationCtrl.text.trim(),
      arrivalStation: _arrStationCtrl.text.trim(),
      departureTime: _depDate,
      arrivalTime: _arrDate,
      price: int.parse(_priceCtrl.text.trim()),
      totalSeats: int.parse(_seatsCtrl.text.trim()),
      busType: _busType,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trajet créé avec succès !'), backgroundColor: ThixPolicy.success),
      );
      context.pop();
    } else {
      final error = ref.read(agencyDashboardProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Erreur lors de la création'), backgroundColor: ThixPolicy.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agencyDashboardProvider);

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
                _buildTextField(label: 'Ville de départ', controller: _fromCtrl, icon: Icons.my_location_rounded),
                const SizedBox(height: 14),
                _buildTextField(label: 'Ville d\'arrivée', controller: _toCtrl, icon: Icons.location_on_rounded),
                const SizedBox(height: 14),
                _buildTextField(label: 'Gare / Station de départ', controller: _depStationCtrl, icon: Icons.departure_board_rounded),
                const SizedBox(height: 14),
                _buildTextField(label: 'Gare / Station d\'arrivée', controller: _arrStationCtrl, icon: Icons.place_rounded),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildTextField(label: 'Prix (FCFA)', controller: _priceCtrl, icon: Icons.payments_rounded, isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(label: 'Nombre de places', controller: _seatsCtrl, icon: Icons.event_seat_rounded, isNumber: true)),
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
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Publier le trajet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, required IconData icon, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
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

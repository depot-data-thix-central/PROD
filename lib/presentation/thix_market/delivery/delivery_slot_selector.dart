// lib/presentation/thix_market/delivery/pages/client/delivery_slot_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// Importe le bon chemin vers ton delivery_provider.dart
import '../../providers/delivery_provider.dart';

class DeliverySlotSelector extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>)? onSlotSelected;

  const DeliverySlotSelector({super.key, this.onSlotSelected});

  @override
  ConsumerState<DeliverySlotSelector> createState() => _DeliverySlotSelectorState();
}

class _DeliverySlotSelectorState extends ConsumerState<DeliverySlotSelector> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  static const Color thixOrange = Color(0xFFE5592F);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Appel via Riverpod à l'initialisation
      ref.read(deliveryProvider).loadAvailableSlots(date: _selectedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Écoute réactive de l'état via Riverpod
    final provider = ref.watch(deliveryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── TITRE DATES ───
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Date de livraison',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF10192E)),
          ),
        ),

        // ─── SÉLECTEUR DE DATE HORIZONTAL ───
        SizedBox(
          height: 95,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 7, // Affiche les 7 prochains jours
            itemBuilder: (context, index) {
              final date = DateTime.now().add(Duration(days: index + 1));
              final isSelected = _selectedDate.year == date.year &&
                  _selectedDate.month == date.month &&
                  _selectedDate.day == date.day;
                  
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = date);
                  ref.read(deliveryProvider).loadAvailableSlots(date: date);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 75,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? thixOrange : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? thixOrange : Colors.grey[200]!,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(color: thixOrange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                    ] : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE', 'fr_FR').format(date).toUpperCase(), // Jour (ex: LUN)
                        style: TextStyle(
                          color: isSelected ? Colors.white70 : Colors.grey[500],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd').format(date), // Numéro (ex: 14)
                        style: TextStyle(
                          fontSize: 20,
                          color: isSelected ? Colors.white : const Color(0xFF10192E),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM', 'fr_FR').format(date), // Mois (ex: Févr)
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.white : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 16),
        
        // ─── TITRE CRÉNEAUX ───
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Créneaux horaires disponibles',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF10192E)),
          ),
        ),

        // ─── CRÉNEAUX DISPONIBLES (SLOTS) ───
        Expanded(
          child: provider.isLoadingSlots
              ? const Center(child: CircularProgressIndicator(color: thixOrange))
              : provider.availableSlots.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: provider.availableSlots.length,
                      itemBuilder: (context, index) {
                        final slot = provider.availableSlots[index];
                        final isSelected = provider.selectedSlot?['id'] == slot['id'];
                        
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? thixOrange.withOpacity(0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? thixOrange : Colors.grey[200]!, 
                              width: isSelected ? 2 : 1
                            ),
                          ),
                          child: RadioListTile<Map<String, dynamic>>(
                            value: slot,
                            groupValue: provider.selectedSlot,
                            onChanged: (value) {
                              // Sélection via Riverpod
                              ref.read(deliveryProvider).selectSlot(value!);
                              widget.onSlotSelected?.call(value);
                            },
                            title: Text(
                              '${slot['start_time']} - ${slot['end_time']}',
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? thixOrange : const Color(0xFF10192E),
                              ),
                            ),
                            subtitle: Text(
                              '${slot['available_count']} créneaux disponibles',
                              style: TextStyle(
                                color: isSelected ? thixOrange.withOpacity(0.8) : Colors.grey[500],
                                fontSize: 12
                              ),
                            ),
                            activeColor: thixOrange,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            secondary: Icon(
                              Icons.schedule_rounded, 
                              color: isSelected ? thixOrange : Colors.grey[400]
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ─── ÉTAT VIDE (AUCUN CRÉNEAU) ───
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun créneau',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF10192E)),
          ),
          const SizedBox(height: 8),
          Text(
            'Il n\'y a pas de créneau disponible\npour cette date.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}

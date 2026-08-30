// lib/presentation/thix_market/delivery/pages/client/delivery_slot_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../providers/delivery_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const int _kMinDaysAhead = 1;
const int _kMaxDaysAhead = 7;
const int _kMaxLabelLength = 40;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _SlotValidators {
  _SlotValidators._();

  static bool isValidDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minDate = today.add(const Duration(days: _kMinDaysAhead));
    final maxDate = today.add(const Duration(days: _kMaxDaysAhead));
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(minDate) && !d.isAfter(maxDate);
  }

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static int safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }

  static String pluralize(int count, String singular, String plural) {
    return count == 1 ? singular : plural;
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _SlotL10n on BuildContext {
  String slotT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;

  String formatTimeRange(String start, String end) {
    return '$start - $end';
  }

  String slotCountText(int count) {
    return slotT(
      _SlotValidators.pluralize(count, '$count créneau disponible', '$count créneaux disponibles'),
      _SlotValidators.pluralize(count, '$count slot available', '$count slots available'),
    );
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class DeliverySlotSelector extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>)? onSlotSelected;

  const DeliverySlotSelector({super.key, this.onSlotSelected});

  @override
  ConsumerState<DeliverySlotSelector> createState() => _DeliverySlotSelectorState();
}

class _DeliverySlotSelectorState extends ConsumerState<DeliverySlotSelector> {
  late DateTime _selectedDate;
  bool _isChangingDate = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().add(const Duration(days: _kMinDaysAhead));
    debugPrint('[DeliverySlot] 📅 Selector opened');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(deliveryProvider).loadAvailableSlots(date: _selectedDate);
    });
  }

  @override
  void dispose() {
    debugPrint('[DeliverySlot] 👋 Selector disposed');
    super.dispose();
  }

  Future<void> _selectDate(DateTime date) async {
    if (_isChangingDate) return;
    if (!_SlotValidators.isValidDate(date)) return;

    setState(() {
      _selectedDate = date;
      _isChangingDate = true;
    });
    HapticFeedback.selectionClick();
    debugPrint('[DeliverySlot] 📅 Date selected: ${DateFormat('yyyy-MM-dd').format(date)}');

    try {
      await ref.read(deliveryProvider).loadAvailableSlots(date: date);
    } catch (e) {
      debugPrint('[DeliverySlot] ❌ Load slots error: $e');
    } finally {
      if (mounted) setState(() => _isChangingDate = false);
    }
  }

  void _selectSlot(Map<String, dynamic> slot) {
    final id = slot['id']?.toString() ?? 'unknown';
    HapticFeedback.mediumImpact();
    debugPrint('[DeliverySlot] ✓ Slot selected: $id');
    ref.read(deliveryProvider).selectSlot(slot);
    widget.onSlotSelected?.call(slot);
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(deliveryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre dates
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            context.slotT('Date de livraison', 'Delivery date'),
            style: ThixPolicy.titleStyle.copyWith(
              fontSize: 16,
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
            ),
          ),
        ),

        // Sélecteur de dates horizontal
        _DateSelector(
          selectedDate: _selectedDate,
          isChanging: _isChangingDate,
          onDateSelected: _selectDate,
        ),

        const SizedBox(height: 16),

        // Titre créneaux
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                context.slotT('Créneaux horaires disponibles', 'Available time slots'),
                style: ThixPolicy.titleStyle.copyWith(
                  fontSize: 16,
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.textMain,
                ),
              ),
              const Spacer(),
              if (_isChangingDate)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                ),
            ],
          ),
        ),

        // Liste des créneaux
        Expanded(
          child: _buildSlotsBody(provider),
        ),
      ],
    );
  }

  Widget _buildSlotsBody(DeliveryProvider provider) {
    if (provider.isLoadingSlots && !_isChangingDate) {
      return const _SkeletonSlots();
    }

    if (provider.availableSlots.isEmpty) {
      return _EmptySlots(
        title: context.slotT('Aucun créneau', 'No slots'),
        subtitle: context.slotT(
          'Il n\'y a pas de créneau disponible\npour cette date.',
          'There are no available slots\nfor this date.',
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: ListView.builder(
        key: ValueKey(_selectedDate.toIso8601String()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: provider.availableSlots.length,
        itemBuilder: (context, index) {
          final slot = provider.availableSlots[index];
          final isSelected = provider.selectedSlot?['id'] == slot['id'];

          return _SlotCard(
            slot: slot,
            isSelected: isSelected,
            onSelect: () => _selectSlot(slot),
          );
        },
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final bool isChanging;
  final ValueChanged<DateTime> onDateSelected;

  const _DateSelector({
    required this.selectedDate,
    required this.isChanging,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.localeCode;

    return SizedBox(
      height: 95,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _kMaxDaysAhead,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index + _kMinDaysAhead));
          final isSelected = _isSameDay(selectedDate, date);

          final dayName = DateFormat('EEE', locale).format(date).toUpperCase();
          final dayNum = DateFormat('dd').format(date);
          final monthName = DateFormat('MMM', locale).format(date);

          return Semantics(
            button: true,
            selected: isSelected,
            label: '${context.slotT('Date', 'Date')}: $dayNum $monthName',
            enabled: !isChanging,
            child: GestureDetector(
              onTap: isChanging ? null : () => onDateSelected(date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 75,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? ThixPolicy.primary : ThixPolicy.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? ThixPolicy.primary : ThixPolicy.border.withOpacity(0.6),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: ThixPolicy.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : ThixPolicy.shadowSoft(opacity: 0.03),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayName,
                      style: ThixPolicy.captionStyle.copyWith(
                        color: isSelected ? Colors.white70 : ThixPolicy.textMuted,
                        fontWeight: ThixPolicy.semiBold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayNum,
                      style: ThixPolicy.titleStyle.copyWith(
                        fontSize: 20,
                        color: isSelected ? Colors.white : ThixPolicy.textMain,
                        fontWeight: ThixPolicy.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      monthName,
                      style: ThixPolicy.microStyle.copyWith(
                        fontSize: 11,
                        color: isSelected ? Colors.white : ThixPolicy.textMuted,
                        fontWeight: ThixPolicy.semiBold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _SlotCard extends StatelessWidget {
  final Map<String, dynamic> slot;
  final bool isSelected;
  final VoidCallback onSelect;

  const _SlotCard({
    required this.slot,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = _SlotValidators.sanitize(slot['start_time']?.toString(), maxLength: _kMaxLabelLength);
    final endTime = _SlotValidators.sanitize(slot['end_time']?.toString(), maxLength: _kMaxLabelLength);
    final availableCount = _SlotValidators.safeInt(slot['available_count']);

    final timeRange = context.formatTimeRange(
      startTime.isEmpty ? '--:--' : startTime,
      endTime.isEmpty ? '--:--' : endTime,
    );
    final countText = context.slotCountText(availableCount);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$timeRange, $countText',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? ThixPolicy.primary.withOpacity(0.05) : ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? ThixPolicy.primary : ThixPolicy.border.withOpacity(0.6),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? ThixPolicy.shadowSoft(opacity: 0.08) : ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: RadioListTile<Map<String, dynamic>>(
          value: slot,
          groupValue: null, // On gère la sélection manuellement via isSelected
          onChanged: (_) => onSelect(),
          title: Text(
            timeRange,
            style: ThixPolicy.labelStyle.copyWith(
              fontWeight: isSelected ? ThixPolicy.bold : ThixPolicy.semiBold,
              color: isSelected ? ThixPolicy.primary : ThixPolicy.textMain,
              fontSize: 15,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              countText,
              style: ThixPolicy.captionStyle.copyWith(
                color: isSelected ? ThixPolicy.primary.withOpacity(0.8) : ThixPolicy.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          activeColor: ThixPolicy.primary,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          secondary: Icon(
            Icons.schedule_rounded,
            color: isSelected ? ThixPolicy.primary : ThixPolicy.textMuted,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SKELETON & EMPTY STATES
// ============================================================================

class _SkeletonSlots extends StatelessWidget {
  const _SkeletonSlots();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 140, color: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  Container(height: 10, width: 120, color: Colors.grey.shade200),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySlots extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptySlots({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.textMuted.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_busy_rounded, size: 48, color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: ThixPolicy.h3Style.copyWith(
                fontSize: 18,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

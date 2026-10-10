import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';
import '../../providers/bus_search_provider.dart';
import 'city_picker_sheet.dart';
import 'passenger_picker_sheet.dart';

class TripSearchCard extends ConsumerWidget {
  final Color domainColor;
  final VoidCallback onSearch;

  const TripSearchCard({super.key, required this.domainColor, required this.onSearch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(busSearchProvider);

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s8, vertical: ThixPolicy.s4),
              decoration: BoxDecoration(color: domainColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(ThixPolicy.rXs)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.directions_bus_rounded, size: 14, color: domainColor),
                SizedBox(width: ThixPolicy.s4),
                Text(l10n.busSearchLabel, style: ThixPolicy.labelStyle.copyWith(color: domainColor, fontWeight: ThixPolicy.bold)),
              ]),
            ),
            const Spacer(),
            Text(l10n.busSearchQuickBooking, style: ThixPolicy.captionStyle),
          ]),
          SizedBox(height: ThixPolicy.s14),
          Row(children: [
            Expanded(child: _FieldBox(icon: Icons.my_location_rounded, label: l10n.busSearchDeparture, value: state.departureCity ?? l10n.busSearchChoose, domainColor: domainColor, onTap: () => _showCityPicker(context, ref, isDep: true))),
            SizedBox(width: ThixPolicy.s8),
            _SwapButton(domainColor: domainColor, onTap: () { if (state.departureCity != null && state.arrivalCity != null) ref.read(busSearchProvider.notifier).swapCities(); }),
            SizedBox(width: ThixPolicy.s8),
            Expanded(child: _FieldBox(icon: Icons.location_on_rounded, label: l10n.busSearchArrival, value: state.arrivalCity ?? l10n.busSearchChoose, domainColor: domainColor, onTap: () => _showCityPicker(context, ref, isDep: false))),
          ]),
          SizedBox(height: ThixPolicy.s10),
          Row(children: [
            Expanded(child: _FieldBox(icon: Icons.calendar_today_rounded, label: l10n.busSearchDate, value: DateFormat('dd/MM', Localizations.localeOf(context).toString()).format(state.departureDate), domainColor: domainColor, onTap: () => _pickDate(context, ref))),
            SizedBox(width: ThixPolicy.s8),
            Expanded(child: _FieldBox(icon: Icons.person_outline_rounded, label: l10n.busSearchPassengers, value: '${state.passengers}', domainColor: domainColor, onTap: () => _showPassengerPicker(context))),
            SizedBox(width: ThixPolicy.s10),
            SizedBox(height: 48, child: ElevatedButton(onPressed: onSearch, style: ElevatedButton.styleFrom(backgroundColor: domainColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)), padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s14)), child: Icon(Icons.search_rounded, color: Colors.white, size: 20, semanticLabel: l10n.busSearchButton))),
          ]),
        ],
      ),
    );
  }

  void _showCityPicker(BuildContext context, WidgetRef ref, {required bool isDep}) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => CityPickerSheet(isDep: isDep));
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), locale: Localizations.localeOf(context), builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: domainColor)), child: child!));
    if (d != null) ref.read(busSearchProvider.notifier).setDate(d);
  }

  void _showPassengerPicker(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => const PassengerPickerSheet());
  }
}

class _SwapButton extends StatefulWidget {
  final Color domainColor;
  final VoidCallback onTap;
  const _SwapButton({required this.domainColor, required this.onTap});

  @override
  State<_SwapButton> createState() => _SwapButtonState();
}

class _SwapButtonState extends State<_SwapButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _rotation = Tween<double>(begin: 0, end: 0.5).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Semantics(button: true, label: context.l10n.busSearchSwap, child: Material(color: Colors.transparent, child: InkWell(onTap: () { _ctrl.forward(from: 0); widget.onTap(); }, borderRadius: BorderRadius.circular(999), child: RotationTransition(turns: _rotation, child: Container(width: 32, height: 32, decoration: BoxDecoration(color: widget.domainColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.swap_horiz_rounded, color: widget.domainColor, size: 16))))));
  }
}

class _FieldBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color domainColor;
  final VoidCallback onTap;

  const _FieldBox({required this.icon, required this.label, required this.value, required this.domainColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(ThixPolicy.rSm), child: Semantics(button: true, label: '$label: $value', child: Container(padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s12, vertical: ThixPolicy.s10), decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(ThixPolicy.rSm), border: Border.all(color: ThixPolicy.border)), child: Row(children: [Icon(icon, size: 16, color: domainColor), SizedBox(width: ThixPolicy.s8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: ThixPolicy.semiBold)), SizedBox(height: ThixPolicy.s2), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain))]))])))));
  }
}

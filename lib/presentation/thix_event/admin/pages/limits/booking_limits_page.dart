import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/admin_event_provider.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

class BookingLimitsPage extends ConsumerStatefulWidget {
  const BookingLimitsPage({super.key});
  @override ConsumerState<BookingLimitsPage> createState() => _BookingLimitsPageState();
}

class _BookingLimitsPageState extends ConsumerState<BookingLimitsPage> {
  String? _eventId;
  final _maxPerson = TextEditingController(text: '4');
  final _maxTrans = TextEditingController(text: '2');
  bool _requireId = false;
  bool _saving = false;

  @override void dispose() { _maxPerson.dispose(); _maxTrans.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_eventId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selectionne un evenement'))); return; }
    setState(() => _saving = true);
    try {
      await ref.read(adminEventServiceProvider).upsertBookingLimit(_eventId!, {'max_per_person': int.tryParse(_maxPerson.text)?? 4, 'max_per_transaction': int.tryParse(_maxTrans.text)?? 2, 'require_id_verification': _requireId});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limites enregistrees'), backgroundColor: Color(0xFF10B981)));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  @override Widget build(BuildContext context) {
    final events = ref.watch(adminEventProvider).eventsState.items;

    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(backgroundColor: _ThixColors.bg.withOpacity(0.85), elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)), title: const Text('Anti-Fraude & Limites', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: 16 + MediaQuery.of(context).padding.bottom, top: 12),
        decoration: const BoxDecoration(color: _ThixColors.surface, border: Border(top: BorderSide(color: _ThixColors.cardBorder))),
        child: SizedBox(height: 48, child: ElevatedButton.icon(onPressed: _saving? null : _save, icon: _saving? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.security_rounded, size: 16), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), label: Text(_saving? 'ENREGISTREMENT...' : 'ENREGISTRER', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)))),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Evenement cible', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _eventId, dropdownColor: _ThixColors.surface, style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: _deco('Selectionner un evenement', Icons.event_rounded),
          items: events.map((e) => DropdownMenuItem(value: e.id, child: Text(e.title, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _eventId = v),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _ThixColors.cardBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.rule_rounded, color: Colors.white, size: 16), SizedBox(width: 8), Text('Regles d achat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))]),
            const SizedBox(height: 16),
            TextFormField(controller: _maxPerson, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), decoration: _deco('Max / personne (global)', Icons.person_outline_rounded)),
            const SizedBox(height: 12),
            TextFormField(controller: _maxTrans, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), decoration: _deco('Max / transaction (panier)', Icons.shopping_cart_outlined)),
            const Divider(color: _ThixColors.cardBorder, height: 32),
            SwitchListTile(contentPadding: EdgeInsets.zero, activeColor: Colors.white, value: _requireId, onChanged: (v) => setState(() => _requireId = v), title: const Row(children: [Icon(Icons.badge_outlined, size: 16, color: Colors.white), SizedBox(width: 8), Text('Verification THIX ID requise', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))]), subtitle: const Padding(padding: EdgeInsets.only(left: 24, top: 4), child: Text('Recommande pour forte demande.', style: TextStyle(color: _ThixColors.textMuted, fontSize: 10)))),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _ThixColors.cardBorder)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, size: 16, color: Colors.white), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Architecture Scalable', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Limites appliquees via canUserBook() en SQL temps reel, anti race conditions.', style: TextStyle(color: _ThixColors.textMuted, fontSize: 10, height: 1.4))]))]),
        ),
      ]),
    );
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(labelText: label, labelStyle: const TextStyle(color: _ThixColors.textMuted, fontSize: 10), prefixIcon: Icon(icon, size: 16, color: _ThixColors.textMuted), filled: true, fillColor: _ThixColors.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _ThixColors.cardBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _ThixColors.cardBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white24)));
}

import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/event_model.dart';
import 'package:thix_id/models/ticket_tier.dart';
import '../../providers/admin_event_provider.dart';
import '../../services/admin_event_service.dart';
import '../../core/admin_guards.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

class EventCreateEditPage extends ConsumerStatefulWidget {
  final Event? eventToEdit;
  const EventCreateEditPage({super.key, this.eventToEdit});
  @override ConsumerState<EventCreateEditPage> createState() => _EventCreateEditPageState();
}

class _EventCreateEditPageState extends ConsumerState<EventCreateEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl, _descCtrl, _locationCtrl, _addressCtrl, _cityCtrl, _subCatCtrl, _orgCtrl, _phoneCtrl, _emailCtrl;
  late String _category, _currency, _status;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _saving = false;
  String _publishSection = 'upcoming';
  Uint8List? _imgBytes, _bannerBytes;
  final _picker = ImagePicker();
  List<Map<String,dynamic>> _tiers = [];

  @override void initState() {
    super.initState();
    final e = widget.eventToEdit;
    _titleCtrl = TextEditingController(text: e?.title?? '');
    _descCtrl = TextEditingController(text: e?.description?? '');
    _locationCtrl = TextEditingController(text: e?.location?? '');
    _addressCtrl = TextEditingController(text: e?.address?? '');
    _cityCtrl = TextEditingController(text: e?.city?? 'LUBUMBASH, RDC');
    _subCatCtrl = TextEditingController(text: e?.subCategory?? '');
    _orgCtrl = TextEditingController(text: e?.organizerName?? '');
    _phoneCtrl = TextEditingController(text: e?.contactPhone?? '');
    _emailCtrl = TextEditingController(text: e?.contactEmail?? '');
    _category = e?.category?? 'concert';
    _currency = e?.priceCurrency?? 'FC';
    _status = e?.status?? 'upcoming';
    _startDate = e?.startDate?? DateTime.now().add(const Duration(days: 7));
    _endDate = e?.endDate;
    _publishSection = e?.isFeatured == true? 'featured' : e?.isRecommended == true? 'recommended' : 'upcoming';
    if (e != null && e.ticketTiers.isNotEmpty) {
      _tiers = e.ticketTiers.map((t) => {'name': t.name, 'price': t.price, 'capacity': t.capacity}).toList();
    } else {
      _tiers = [{'name': 'Standard', 'price': e?.price?? 0.0, 'capacity': e?.capacity?? 100}];
    }
  }

  Future<void> _pick(bool isBanner) async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x != null) { final b = await x.readAsBytes(); setState(() => isBanner? _bannerBytes = b : _imgBytes = b); }
  }

  Future<DateTime?> _pickDateTime(DateTime init) async {
    final d = await showDatePicker(context: context, initialDate: init, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)), builder: (c, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _ThixColors.primary, surface: _ThixColors.surface)), child: child!));
    if (d == null) return null;
    if (!mounted) return d;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(init), builder: (c, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _ThixColors.primary)), child: child!));
    if (t == null) return d;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  void _addTierDialog() {
    final n = TextEditingController(); final p = TextEditingController(); final ca = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _ThixColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _ThixColors.cardBorder)),
      title: const Text('Ajouter classe', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, style: const TextStyle(color: Colors.white), decoration: _decoDialog('Nom ex: VVIP')), const SizedBox(height: 8), TextField(controller: p, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _decoDialog('Prix $_currency')), const SizedBox(height: 8), TextField(controller: ca, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _decoDialog('Capacite'))]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _ThixColors.textMuted))), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black), onPressed: () { if (n.text.isEmpty) return; setState(() => _tiers.add({'name': n.text.trim(), 'price': double.tryParse(p.text)?? 0.0, 'capacity': int.tryParse(ca.text)?? 0})); Navigator.pop(ctx); }, child: const Text('Ajouter'))],
    ));
  }

  Future<void> _save() async {
    final role = await AdminGuard.getCurrentRole();
    if (!AdminGuard.canWrite(role)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lecture seule'))); return; }
    if (!_formKey.currentState!.validate()) return;
    if (_tiers.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Au moins une classe'), backgroundColor: Colors.red)); return; }
    setState(() => _saving = true);
    try {
      final svc = ref.read(adminEventServiceProvider);
      final isFeatured = _publishSection == 'featured';
      final isRecommended = _publishSection == 'recommended';
      final totalCap = _tiers.fold<int>(0, (s, t) => s + (t['capacity'] as int));
      final minPrice = _tiers.map((t) => t['price'] as double).reduce((a,b) => a < b? a : b);
      final event = Event(
        id: widget.eventToEdit?.id?? '',
        title: _titleCtrl.text.trim(), description: _descCtrl.text.trim(), category: _category, subCategory: _subCatCtrl.text.trim().isEmpty? null : _subCatCtrl.text.trim(),
        location: _locationCtrl.text.trim(), address: _addressCtrl.text.trim().isEmpty? null : _addressCtrl.text.trim(), city: _cityCtrl.text.trim(),
        startDate: _startDate, endDate: _endDate, price: minPrice, priceCurrency: _currency, isFree: minPrice == 0 && _tiers.length == 1,
        capacity: totalCap, remainingTickets: widget.eventToEdit == null? totalCap : widget.eventToEdit?.remainingTickets,
        isFeatured: isFeatured, isRecommended: isRecommended, status: _status,
        organizerName: _orgCtrl.text.trim().isEmpty? null : _orgCtrl.text.trim(), contactPhone: _phoneCtrl.text.trim().isEmpty? null : _phoneCtrl.text.trim(), contactEmail: _emailCtrl.text.trim().isEmpty? null : _emailCtrl.text.trim(),
        viewsCount: widget.eventToEdit?.viewsCount?? 0, likesCount: widget.eventToEdit?.likesCount?? 0, sharesCount: widget.eventToEdit?.sharesCount?? 0,
        createdAt: widget.eventToEdit?.createdAt?? DateTime.now(), imageUrl: widget.eventToEdit?.imageUrl, bannerUrl: widget.eventToEdit?.bannerUrl,
        ticketTiers: _tiers.map<TicketTier>((t) => TicketTier.fromJson(t)).toList(),
      );
      await svc.upsertEvent(event, imageBytes: _imgBytes, bannerBytes: _bannerBytes);
      await ref.read(adminEventProvider.notifier).loadEvents(refresh: true);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evenement enregistre'), backgroundColor: Color(0xFF10B981))); Navigator.pop(context); }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  String _fmtDt(DateTime dt) => '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: _ThixColors.bg.withOpacity(0.85), elevation: 0,
              leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
              title: Text(widget.eventToEdit == null? 'Creer Event' : 'Modifier Event', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(padding: EdgeInsets.only(left: 16, right: 16, bottom: 16 + MediaQuery.of(context).padding.bottom, top: 8), child: SizedBox(height: 48, child: ElevatedButton(onPressed: _saving? null : _save, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: _saving? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : Text(widget.eventToEdit == null? 'CREER' : 'ENREGISTRER', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12))))),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [Expanded(child: _imgPicker('Cover', _imgBytes, widget.eventToEdit?.imageUrl, () => _pick(false))), const SizedBox(width: 12), Expanded(child: _imgPicker('Banner', _bannerBytes, widget.eventToEdit?.bannerUrl, () => _pick(true)))]),
          const SizedBox(height: 18),
          _field(_titleCtrl, 'Titre *', validator: (v) => v!.isEmpty? 'Requis' : null),
          const SizedBox(height: 12),
          _field(_descCtrl, 'Description *', maxLines: 4, validator: (v) => v!.length < 10? 'Min 10' : null),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: DropdownButtonFormField<String>(value: _category, dropdownColor: _ThixColors.surface, style: const TextStyle(color: Colors.white), decoration: _deco('Categorie'), items: ['concert','conference','sport','festival','theatre','autre'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _category = v!))), const SizedBox(width: 12), Expanded(child: _field(_subCatCtrl, 'Sous-categorie'))]),
          const SizedBox(height: 18),
          const Text('Date & Heure', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: InkWell(onTap: () async { final dt = await _pickDateTime(_startDate); if (dt != null) setState(() => _startDate = dt); }, child: InputDecorator(decoration: _deco('Debut'), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_fmtDt(_startDate), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)), const Icon(Icons.access_time_rounded, size: 14, color: _ThixColors.primary)])))), const SizedBox(width: 12), Expanded(child: InkWell(onTap: () async { final dt = await _pickDateTime(_endDate?? _startDate); if (dt != null) setState(() => _endDate = dt); }, child: InputDecorator(decoration: _deco('Fin (opt)'), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_endDate == null? 'Ajouter' : _fmtDt(_endDate!), style: const TextStyle(color: Colors.white, fontSize: 11)), const Icon(Icons.access_time_rounded, size: 14, color: _ThixColors.textMuted)]))))]),
          const SizedBox(height: 18),
          Row(children: [Expanded(child: _field(_cityCtrl, 'Ville *', validator: (v) => v!.isEmpty? 'Requis' : null)), const SizedBox(width: 12), Expanded(child: _field(_locationCtrl, 'Lieu *', validator: (v) => v!.isEmpty? 'Requis' : null))]),
          const SizedBox(height: 12),
          _field(_addressCtrl, 'Adresse'),
          const SizedBox(height: 18),
          Row(children: [Expanded(child: _field(_orgCtrl, 'Organisateur')), const SizedBox(width: 12), Expanded(child: _field(_phoneCtrl, 'Telephone'))]),
          const SizedBox(height: 12),
          _field(_emailCtrl, 'Email contact'),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Classes & Capacite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)), DropdownButton<String>(value: _currency, dropdownColor: _ThixColors.surface, underline: const SizedBox(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800), items: ['FC','USD','EUR'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _currency = v!))]),
          const SizedBox(height: 8),
          Container(decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _ThixColors.cardBorder)), child: Column(children: [..._tiers.asMap().entries.map((e) { final t = e.value; return ListTile(title: Text(t['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)), subtitle: Text('${t['price']} $_currency • ${t['capacity']} places', style: const TextStyle(color: _ThixColors.textMuted, fontSize: 11)), trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: _ThixColors.primary, size: 18), onPressed: () => setState(() => _tiers.removeAt(e.key)))); }), const Divider(color: _ThixColors.cardBorder, height: 1), InkWell(onTap: _addTierDialog, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)), child: const Padding(padding: EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 16), SizedBox(width: 8), Text('Ajouter VVIP, VIP...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))])))])),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(value: _status, dropdownColor: _ThixColors.surface, style: const TextStyle(color: Colors.white), decoration: _deco('Statut'), items: ['upcoming','ongoing','completed','cancelled'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _status = v!)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _publishSection, dropdownColor: _ThixColors.surface, style: const TextStyle(color: Colors.white), decoration: _deco('Visibilite'), items: const [DropdownMenuItem(value: 'upcoming', child: Text('Prochains (defaut)')), DropdownMenuItem(value: 'recommended', child: Text('Recommandes')), DropdownMenuItem(value: 'featured', child: Text('A la Une'))], onChanged: (v) => setState(() => _publishSection = v!)),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  // CORRECTION : Les parenthèses ont été équilibrées correctement à la fin de cette méthode (1 en moins)
  Widget _imgPicker(String label, Uint8List? bytes, String? url, VoidCallback tap) {
    return InkWell(onTap: tap, borderRadius: BorderRadius.circular(14), child: Container(height: 110, decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _ThixColors.cardBorder)), child: bytes != null? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(bytes, fit: BoxFit.cover)) : url != null? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(url, fit: BoxFit.cover)) : Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 18), const SizedBox(height: 6), Text(label, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700))])));
  }

  Widget _field(TextEditingController c, String label, {int maxLines = 1, TextInputType? keyboard, String? Function(String?)? validator}) {
    return TextFormField(controller: c, maxLines: maxLines, keyboardType: keyboard, validator: validator, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: _deco(label));
  }

  InputDecoration _deco(String label) => InputDecoration(labelText: label, labelStyle: const TextStyle(color: _ThixColors.textMuted, fontSize: 11), filled: true, fillColor: _ThixColors.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _ThixColors.cardBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _ThixColors.cardBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white24, width: 1.2)));
  
  InputDecoration _decoDialog(String label) => InputDecoration(labelText: label, labelStyle: const TextStyle(color: _ThixColors.textMuted, fontSize: 11), filled: true, fillColor: _ThixColors.surfaceAlt, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _ThixColors.cardBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _ThixColors.cardBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)));
}

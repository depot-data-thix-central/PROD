// lib/presentation/thix_weeding/pages/staff/prestataires/add_vendor_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

class AddVendorPage extends ConsumerStatefulWidget {
  final String weddingId;
  final String? editVendorId;
  const AddVendorPage({super.key, required this.weddingId, this.editVendorId});
  @override
  ConsumerState<AddVendorPage> createState() => _AddVendorPageState();
}

class _AddVendorPageState extends ConsumerState<AddVendorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _category = 'Traiteur';
  String _status = 'pending';
  bool _isLoading = false;
  bool _isInitLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.editVendorId != null) _loadVendor();
  }

  Future<void> _loadVendor() async {
    setState(() => _isInitLoading = true);
    try {
      final VendorModel v = await ref.read(vendorServiceProvider).getById(widget.editVendorId!);
      setState(() {
        _nameCtrl.text = v.name;
        _contactCtrl.text = v.contactName?? '';
        _phoneCtrl.text = v.phone?? '';
        _emailCtrl.text = v.email?? '';
        _priceCtrl.text = v.price?.toString()?? '';
        _notesCtrl.text = v.notes?? '';
        _category = v.category;
        _status = v.status;
      });
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'wedding_id': widget.weddingId,
      'name': _nameCtrl.text.trim(),
      'category': _category,
      'contact_name': _contactCtrl.text.trim().isEmpty? null : _contactCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim().isEmpty? null : _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim().isEmpty? null : _emailCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text) ?? 0,
      'status': _status,
      'notes': _notesCtrl.text.trim().isEmpty? null : _notesCtrl.text.trim(),
    };

    try {
      final service = ref.read(vendorServiceProvider);
      if (widget.editVendorId == null) {
        final VendorModel created = await service.create(data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Prestataire créé ID: ${created.id.substring(0, 8)}')));
      } else {
        await service.update(widget.editVendorId!, data);
      }
      ref.invalidate(vendorsProvider(widget.weddingId));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _contactCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose(); _priceCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editVendorId != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(isEdit? 'Modifier prestataire' : 'Ajouter prestataire'), backgroundColor: Colors.white),
      body: _isInitLoading ? const Center(child: CircularProgressIndicator()) : Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _Section(title: 'Entreprise', children: [
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom entreprise *', border: OutlineInputBorder()), validator: (v) => v==null||v.length<2? 'Requis' : null),
            const SizedBox(height: 12),
            DropdownButtonFormField(value: _category, decoration: const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'Traiteur', child: Text('Traiteur')), DropdownMenuItem(value: 'Photographe', child: Text('Photographe')), DropdownMenuItem(value: 'DJ', child: Text('DJ / Musique')), DropdownMenuItem(value: 'Décoration', child: Text('Décoration')), DropdownMenuItem(value: 'Salle', child: Text('Salle')), DropdownMenuItem(value: 'Autre', child: Text('Autre'))], onChanged: (v) => setState(() => _category = v!)),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Contact', children: [
            TextFormField(controller: _contactCtrl, decoration: const InputDecoration(labelText: 'Nom contact', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Contrat', children: [
            TextFormField(controller: _priceCtrl, decoration: const InputDecoration(labelText: 'Prix convenu FCFA', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payments)), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            DropdownButtonFormField(value: _status, decoration: const InputDecoration(labelText: 'Statut', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'pending', child: Text('En attente')), DropdownMenuItem(value: 'contacted', child: Text('Contacté')), DropdownMenuItem(value: 'booked', child: Text('Réservé')), DropdownMenuItem(value: 'paid', child: Text('Payé')), DropdownMenuItem(value: 'cancelled', child: Text('Annulé'))], onChanged: (v) => setState(() => _status = v!)),
            const SizedBox(height: 12),
            TextFormField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 3),
          ]),
          const SizedBox(height: 24),
          FilledButton(onPressed: _isLoading? null : _save, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading? const SizedBox(height:20,width:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : Text(isEdit? 'Mettre à jour' : 'Créer avec ID unique', style: const TextStyle(fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title; final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF0B3B8F))), const SizedBox(height: 12), ...children]));
}

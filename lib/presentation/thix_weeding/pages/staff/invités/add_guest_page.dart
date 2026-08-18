// lib/presentation/thix_weeding/pages/staff/invités/add_guest_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

class AddGuestPage extends ConsumerStatefulWidget {
  final String weddingId;
  final String? editGuestId;
  const AddGuestPage({super.key, required this.weddingId, this.editGuestId});
  @override
  ConsumerState<AddGuestPage> createState() => _AddGuestPageState();
}

class _AddGuestPageState extends ConsumerState<AddGuestPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String _group = 'Amis';
  int _count = 1;
  bool _isLoading = false;
  bool _isInitLoading = false;

  bool get _isEdit => widget.editGuestId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadEdit();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ================= DATA =================

  Future<void> _loadEdit() async {
    setState(() => _isInitLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('thix_weeding_guests')
          .select()
          .eq('id', widget.editGuestId!)
          .single();
      final g = GuestModel.fromJson(data);
      _nameCtrl.text = g.name;
      _phoneCtrl.text = g.phone ?? '';
      _emailCtrl.text = g.email ?? '';
      _group = g.groupName ?? 'Amis';
      _count = g.guestsCount;
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final supa = Supabase.instance.client;

      if (!_isEdit) {
        final inserted = await supa.from('thix_weeding_guests').insert({
          'wedding_id': widget.weddingId,
          'name': _nameCtrl.text.trim(),
          'phone':
              _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'email':
              _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          'group_name': _group,
          'guests_count': _count,
        }).select().single();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Invité créé ID: ${inserted['id'].toString().substring(0, 8)}',
              ),
            ),
          );
        }
      } else {
        await supa.from('thix_weeding_guests').update({
          'name': _nameCtrl.text.trim(),
          'phone':
              _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'email':
              _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          'group_name': _group,
          'guests_count': _count,
        }).eq('id', widget.editGuestId!);
      }

      ref.invalidate(guestsProvider(widget.weddingId));
      ref.invalidate(dashboardStatsProvider(widget.weddingId));

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    if (_isInitLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chargement...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier invité' : 'Ajouter un invité'),
        backgroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionCard(
              title: 'Identité',
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Groupe & nombre',
              children: [
                _buildGroupDropdown(),
                const SizedBox(height: 12),
                _buildCounter(),
              ],
            ),
            const SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupDropdown() => DropdownButtonFormField<String>(
        value: _group,
        decoration: const InputDecoration(
          labelText: 'Groupe',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.group),
        ),
        items: const [
          DropdownMenuItem(value: 'Famille', child: Text('Famille')),
          DropdownMenuItem(value: 'Amis', child: Text('Amis')),
          DropdownMenuItem(value: 'Collègues', child: Text('Collègues')),
          DropdownMenuItem(value: 'VIP', child: Text('VIP')),
        ],
        onChanged: (v) => setState(() => _group = v!),
      );

  Widget _buildCounter() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Text(
              'Nombre de personnes:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              onPressed: () =>
                  setState(() => _count = _count > 1 ? _count - 1 : 1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0B3B8F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_count',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _count++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      );

  Widget _buildSubmitButton() => FilledButton(
        onPressed: _isLoading ? null : _save,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _isEdit
                    ? 'Mettre à jour'
                    : 'Créer invité avec ID unique',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: Color(0xFF0B3B8F),
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );
}

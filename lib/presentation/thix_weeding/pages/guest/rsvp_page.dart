// lib/presentation/thix_weeding/pages/guest/rsvp_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/rsvp_provider.dart';

class RsvpPage extends ConsumerStatefulWidget {
  final String weddingId;
  const RsvpPage({super.key, required this.weddingId});

  @override
  ConsumerState<RsvpPage> createState() => _RsvpPageState();
}

class _RsvpPageState extends ConsumerState<RsvpPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _msgCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _msgCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final form = ref.read(rsvpFormProvider);
    ref.read(rsvpFormProvider.notifier).updateName(_nameCtrl.text);
    ref.read(rsvpFormProvider.notifier).updateMessage(_msgCtrl.text);

    final success = await ref.read(rsvpControllerProvider.notifier).submit(widget.weddingId);

    if (!mounted) return; // ANTI PILE CONTEXT
    if (success) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Merci!'),
          content: const Text('Votre réponse a été enregistrée avec succès.'),
          actions: [FilledButton(onPressed: () { if (ctx.mounted) ctx.pop(); if (mounted) context.pop(); }, child: const Text('Fermer'))],
        ),
      );
      ref.read(rsvpFormProvider.notifier).reset();
      _nameCtrl.clear();
      _msgCtrl.clear();
    } else {
      final err = ref.read(rsvpControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err?.toString()?? 'Erreur lors de l’envoi'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(rsvpFormProvider);
    final rsvpState = ref.watch(rsvpControllerProvider);
    final isLoading = rsvpState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmer ma présence'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.mounted) context.pop(); })),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.list(children: [
                const Text('RSVP', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFB84B5A))),
                const SizedBox(height: 8),
                const Text('Merci de confirmer avant le 15 décembre', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: 'Nom complet', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  validator: (v) => (v == null || v.trim().length < 2)? 'Min 2 caractères' : null,
                  onChanged: (v) => ref.read(rsvpFormProvider.notifier).updateName(v),
                ),
                const SizedBox(height: 20),
                const Text('Serez-vous présent?', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _StatusTile(title: 'Oui, avec joie!', subtitle: 'Je serai là', value: 'yes', group: form.status, onChanged: (v) => ref.read(rsvpFormProvider.notifier).updateStatus(v)),
                _StatusTile(title: 'Non, désolé', subtitle: 'Je ne pourrai pas venir', value: 'no', group: form.status, onChanged: (v) => ref.read(rsvpFormProvider.notifier).updateStatus(v)),
                _StatusTile(title: 'Peut-être', subtitle: 'Je confirmerai plus tard', value: 'maybe', group: form.status, onChanged: (v) => ref.read(rsvpFormProvider.notifier).updateStatus(v)),
                const SizedBox(height: 20),
                Row(children: [
                  const Text('Nombre d’invités', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(onPressed: () => ref.read(rsvpFormProvider.notifier).updateCount(form.count - 1), icon: const Icon(Icons.remove_circle_outline)),
                  Text('${form.count}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(onPressed: () => ref.read(rsvpFormProvider.notifier).updateCount(form.count + 1), icon: const Icon(Icons.add_circle_outline)),
                ]),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _msgCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: 'Message pour les mariés (optionnel)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  onChanged: (v) => ref.read(rsvpFormProvider.notifier).updateMessage(v),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: isLoading? null : _submit,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE25A6A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: isLoading? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Confirmer ma réponse', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final String group;
  final Function(String) onChanged;
  const _StatusTile({required this.title, required this.subtitle, required this.value, required this.group, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final selected = value == group;
    return Card(
      elevation: 0,
      color: selected? const Color(0xFFFFF0F2) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: selected? const Color(0xFFE25A6A) : Colors.grey.shade200)),
      child: RadioListTile(value: value, groupValue: group, onChanged: (v) => onChanged(v!), title: Text(title, style: TextStyle(fontWeight: selected? FontWeight.bold : FontWeight.normal)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 12))),
    );
  }
}

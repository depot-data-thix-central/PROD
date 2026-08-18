// lib/presentation/thix_weeding/pages/staff/my_weddings/create_wedding_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class CreateWeddingPage extends StatefulWidget {
  final String? weddingId;
  const CreateWeddingPage({super.key, this.weddingId});

  @override
  State<CreateWeddingPage> createState() => _CreateWeddingPageState();
}

class _CreateWeddingPageState extends State<CreateWeddingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _partner1Controller = TextEditingController();
  final _partner2Controller = TextEditingController();
  bool _isLoading = false;
  bool _isFetching = false;

  bool get _isEditing => widget.weddingId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadWeddingData();
    }
  }

  Future<void> _loadWeddingData() async {
    setState(() => _isFetching = true);
    try {
      final res = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select()
          .eq('id', widget.weddingId!)
          .single();

      _titleController.text = res['title'] ?? '';
      _partner1Controller.text = res['partner_one'] ?? '';
      _partner2Controller.text = res['partner_two'] ?? '';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _partner1Controller.dispose();
    _partner2Controller.dispose();
    super.dispose();
  }

  Future<void> _saveWedding() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez vous connecter')),
        );
        return;
      }

      // Typage explicite en Map<String, dynamic> pour éviter l'erreur de type
      final Map<String, dynamic> data = {
        'title': _titleController.text.trim(),
        'partner_one': _partner1Controller.text.trim(),
        'partner_two': _partner2Controller.text.trim(),
        'owner_id': user.id,
      };

      if (_isEditing) {
        await Supabase.instance.client
            .from('thix_weeding_weddings')
            .update(data)
            .eq('id', widget.weddingId!);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mariage mis à jour avec succès !'), backgroundColor: Colors.green),
        );
        context.pop();
      } else {
        data['invitation_published'] = false;
        final res = await Supabase.instance.client
            .from('thix_weeding_weddings')
            .insert(data)
            .select()
            .single();

        final newId = res['id'];
        if (!mounted) return;
        context.go('/thix-weeding/staff/$newId');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le mariage' : 'Créer un mariage'),
        backgroundColor: const Color(0xFFE93D6D),
        foregroundColor: Colors.white,
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE93D6D)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isEditing ? 'Mettre à jour les informations' : 'Informations principales',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2B5B)),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Nom de l\'événement (ex: Mariage de Jean & Marie)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _partner1Controller,
                      decoration: InputDecoration(
                        labelText: 'Nom du premier conjoint',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _partner2Controller,
                      decoration: InputDecoration(
                        labelText: 'Nom du deuxième conjoint',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveWedding,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE93D6D),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _isEditing ? 'Enregistrer les modifications' : 'Créer le mariage',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

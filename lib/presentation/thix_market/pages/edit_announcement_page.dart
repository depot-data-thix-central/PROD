// lib/presentation/thix_market/pages/edit_announcement_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/selling/publish_announcement_form.dart';

class EditAnnouncementPage extends StatefulWidget {
  final String announcementId;

  const EditAnnouncementPage({super.key, required this.announcementId});

  @override
  State<EditAnnouncementPage> createState() => _EditAnnouncementPageState();
}

class _EditAnnouncementPageState extends State<EditAnnouncementPage> {
  Map<String, dynamic>? _announcement;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAnnouncement();
  }

  Future<void> _loadAnnouncement() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('products')
          .select('*, shop:shops(id, name, owner_id)')
          .eq('id', widget.announcementId)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _errorMessage = 'Annonce introuvable';
          _isLoading = false;
        });
        return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      final shopOwnerId = response['shop']?['owner_id'] as String?;

      if (shopOwnerId != null && shopOwnerId != userId) {
        setState(() {
          _errorMessage = 'Vous n\'êtes pas autorisé à modifier cette annonce';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _announcement = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Modifier l\'annonce'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Modifier l\'annonce'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadAnnouncement,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2A4A),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    if (_announcement == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Modifier l\'annonce'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Aucune donnée disponible'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_announcement!['title'] ?? 'Modifier l\'annonce'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _showDeleteConfirmation(context),
          ),
        ],
      ),
      body: PublishAnnouncementForm(
        shopId: _announcement!['shop_id'] as String?,
        editAnnouncement: _announcement,
        onSuccess: (updatedData) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Annonce mise à jour avec succès'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, updatedData);
          }
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'annonce'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette annonce ? Cette action est irréversible.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => _deleteAnnouncement(context),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAnnouncement(BuildContext context) async {
    try {
      await Supabase.instance.client
          .from('products')
          .delete()
          .eq('id', widget.announcementId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Annonce supprimée'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, {'deleted': true});
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

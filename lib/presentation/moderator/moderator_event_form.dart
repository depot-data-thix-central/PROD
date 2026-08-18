// lib/presentation/moderator/moderator_event_form.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';

import '../../providers/event_provider.dart';
import '../../providers/moderator_provider.dart';
import '../../models/event_model.dart';

class ModeratorEventForm extends StatefulWidget {
  final Event? event; // Si fourni, on est en édition avec l'objet complet
  final String? eventId; // Si fourni, on charge l'événement depuis l'ID

  const ModeratorEventForm({super.key, this.event, this.eventId});

  @override
  State<ModeratorEventForm> createState() => _ModeratorEventFormState();
}

class _ModeratorEventFormState extends State<ModeratorEventForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();

  String? _category = 'musique';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isFree = false;
  File? _imageFile;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  // Pour l'édition : conserve l'événement original (si chargé)
  Event? _originalEvent;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    if (widget.event != null) {
      // Mode édition avec objet Event
      _loadEventData(widget.event!);
    } else if (widget.eventId != null) {
      // Mode édition avec ID : charger depuis le provider
      await _loadEventFromId(widget.eventId!);
    } else {
      // Mode création : valeurs par défaut
      _setDefaultValues();
    }
  }

  void _loadEventData(Event event) {
    setState(() {
      _originalEvent = event;
      _titleController.text = event.title;
      _descController.text = event.description;
      _locationController.text = event.location;
      _cityController.text = event.city ?? '';
      _priceController.text = event.price.toString();
      _capacityController.text = event.capacity?.toString() ?? '';
      _category = event.category;
      _startDate = event.startDate;
      _endDate = event.endDate;
      _isFree = event.isFree;
    });
  }

  void _setDefaultValues() {
    _startDate = DateTime.now().add(const Duration(days: 7));
    _endDate = null;
  }

  Future<void> _loadEventFromId(String id) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Utiliser EventProvider pour récupérer l'événement
      final eventProvider = context.read<EventProvider>();
      final event = await eventProvider.fetchEventById(id);
      if (event != null) {
        _loadEventData(event);
      } else {
        setState(() => _error = 'Événement introuvable');
      }
    } catch (e) {
      setState(() => _error = 'Erreur lors du chargement: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date de début')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final moderatorProvider = context.read<ModeratorProvider>();
      String? imageUrl;

      // Upload de l'image si une nouvelle a été sélectionnée
      if (_imageFile != null) {
        imageUrl = await moderatorProvider.uploadImage(_imageFile!.path);
        if (imageUrl == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de l\'upload de l\'image'), backgroundColor: Colors.orange),
          );
        }
      }

      final data = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _category!,
        'start_date': _startDate!.toIso8601String(),
        'end_date': _endDate?.toIso8601String(),
        'location': _locationController.text.trim(),
        'city': _cityController.text.trim(),
        'price': double.tryParse(_priceController.text) ?? 0,
        'is_free': _isFree,
        'capacity': int.tryParse(_capacityController.text),
        if (imageUrl != null) 'image_url': imageUrl,
      };

      if (_originalEvent != null) {
        // Mise à jour
        await moderatorProvider.updateEvent(_originalEvent!.id, data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Événement mis à jour'), backgroundColor: Colors.green),
        );
      } else {
        // Création
        await moderatorProvider.createEvent(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Événement créé'), backgroundColor: Colors.green),
        );
      }
      context.go('/moderator/events');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _originalEvent != null;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/moderator/events'),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier l\'événement' : 'Créer un événement'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.go('/moderator/events'),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Titre
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),

              // Catégorie
              DropdownButtonFormField<String>(
                value: _category,
                items: const [
                  DropdownMenuItem(value: 'musique', child: Text('🎵 Musique')),
                  DropdownMenuItem(value: 'conference', child: Text('🎤 Conférence')),
                  DropdownMenuItem(value: 'culture', child: Text('🎨 Culture')),
                  DropdownMenuItem(value: 'sport', child: Text('⚽ Sport')),
                  DropdownMenuItem(value: 'festival', child: Text('🎪 Festival')),
                  DropdownMenuItem(value: 'spectacle', child: Text('🎭 Spectacle')),
                  DropdownMenuItem(value: 'exposition', child: Text('🖼️ Exposition')),
                ],
                onChanged: (v) => setState(() => _category = v),
                decoration: const InputDecoration(
                  labelText: 'Catégorie *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 12),

              // Dates
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickStartDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date de début *',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _startDate != null
                                    ? DateFormat('dd/MM/yyyy HH:mm').format(_startDate!)
                                    : 'Choisir',
                                style: TextStyle(
                                  color: _startDate != null ? Colors.black : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: _pickEndDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date de fin (option)',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _endDate != null
                                    ? DateFormat('dd/MM/yyyy HH:mm').format(_endDate!)
                                    : 'Choisir',
                                style: TextStyle(
                                  color: _endDate != null ? Colors.black : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Lieu
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Lieu *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),

              // Ville
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Ville',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Prix et gratuit
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Prix (FCFA)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !_isFree,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CheckboxListTile(
                      value: _isFree,
                      onChanged: (v) => setState(() => _isFree = v!),
                      title: const Text('Gratuit'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Capacité
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(
                  labelText: 'Capacité totale (places)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              // Image
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      label: Text(
                        _imageFile != null
                            ? 'Image sélectionnée'
                            : (_originalEvent?.imageUrl != null
                                ? 'Remplacer l\'image'
                                : 'Choisir une image'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ),
                  if (_imageFile != null)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      onPressed: () => setState(() => _imageFile = null),
                    ),
                ],
              ),
              if (_imageFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Image.file(_imageFile!, height: 100, fit: BoxFit.cover),
                )
              else if (_originalEvent?.imageUrl != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Image.network(
                    _originalEvent!.imageUrl!,
                    height: 100,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 100,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stack) => Container(
                      height: 100,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Bouton enregistrer
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFF2D6CDF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('ENREGISTRER', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final dt = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (dt != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startDate ?? DateTime.now()),
      );
      if (time != null) {
        setState(() {
          _startDate = DateTime(dt.year, dt.month, dt.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _pickEndDate() async {
    final initialDate = _endDate ?? _startDate ?? DateTime.now().add(const Duration(days: 7));
    final dt = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (dt != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_endDate ?? initialDate),
      );
      if (time != null) {
        setState(() {
          _endDate = DateTime(dt.year, dt.month, dt.day, time.hour, time.minute);
        });
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer définitivement cet événement ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(_);
              try {
                await context.read<ModeratorProvider>().deleteEvent(_originalEvent!.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Événement supprimé'), backgroundColor: Colors.green),
                );
                context.go('/moderator/events');
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

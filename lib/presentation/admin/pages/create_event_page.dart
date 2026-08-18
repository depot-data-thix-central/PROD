// lib/presentation/admin/pages/create_event_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../providers/event_provider.dart';
import '../../../models/event_model.dart';

class CreateEventPage extends ConsumerStatefulWidget {
  final Event? event;

  const CreateEventPage({super.key, this.event});

  @override
  ConsumerState<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends ConsumerState<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  
  String _selectedCategory = 'musique';
  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = TimeOfDay.now();
  bool _isFree = false;
  bool _isFeatured = false;
  String? _imageUrl;
  
  Uint8List? _imageBytes;
  String? _imageFileName;
  
  bool _isLoading = false;

  final List<Map<String, String>> _categories = [
    {'value': 'musique', 'label': 'Musique & Concerts'},
    {'value': 'conference', 'label': 'Conférences & Séminaires'},
    {'value': 'culture', 'label': 'Culture & Art'},
    {'value': 'sport', 'label': 'Sport & Loisirs'},
    {'value': 'festival', 'label': 'Festivals & Soirées'},
    {'value': 'spectacle', 'label': 'Spectacles'},
    {'value': 'exposition', 'label': 'Expositions'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _descriptionController.text = widget.event!.description;
      _locationController.text = widget.event!.location;
      _cityController.text = widget.event!.city ?? '';
      _addressController.text = widget.event!.address ?? '';
      _selectedCategory = widget.event!.category;
      _startDate = widget.event!.startDate;
      _startTime = TimeOfDay.fromDateTime(widget.event!.startDate);
      _isFree = widget.event!.isFree;
      _isFeatured = widget.event!.isFeatured;
      _imageUrl = widget.event!.imageUrl;
      if (!_isFree) {
        _priceController.text = widget.event!.price.toStringAsFixed(0);
      }
      if (widget.event!.capacity != null) {
        _capacityController.text = widget.event!.capacity.toString();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _imageBytes = result.files.first.bytes;
          _imageFileName = result.files.first.name;
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de l\'image');
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (time != null) {
      setState(() => _startTime = time);
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageBytes == null || _imageFileName == null) return _imageUrl;
    
    // Utilisation de bookingProvider pour accéder à la méthode uploadImage définie dans event_provider.dart
    final bookingSvc = ref.read(bookingProvider);
    return await bookingSvc.uploadImage(_imageBytes!, _imageFileName!);
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final uploadedImageUrl = await _uploadImage();
      
      final startDateTime = DateTime(
        _startDate.year, _startDate.month, _startDate.day,
        _startTime.hour, _startTime.minute,
      );
      
      final service = ref.read(eventServiceProvider);
      
      if (widget.event != null) {
        await service.updateEvent(widget.event!.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'category': _selectedCategory,
          'start_date': startDateTime.toIso8601String(),
          'location': _locationController.text.trim(),
          'city': _cityController.text.trim(),
          'address': _addressController.text.trim(),
          'price': _isFree ? 0 : double.parse(_priceController.text.trim()),
          'is_free': _isFree,
          'capacity': _capacityController.text.trim().isEmpty ? null : int.parse(_capacityController.text.trim()),
          'image_url': uploadedImageUrl,
          'is_featured': _isFeatured,
        });
        _showSuccess('Événement modifié avec succès');
      } else {
        await service.createEvent(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          startDate: startDateTime,
          location: _locationController.text.trim(),
          city: _cityController.text.trim(),
          address: _addressController.text.trim(),
          price: _isFree ? 0 : double.parse(_priceController.text.trim()),
          isFree: _isFree,
          capacity: _capacityController.text.trim().isEmpty ? null : int.parse(_capacityController.text.trim()),
          imageUrl: uploadedImageUrl,
          isFeatured: _isFeatured,
        );
        _showSuccess('Événement créé avec succès');
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('Erreur: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1B3D),
        elevation: 0,
        title: Text(
          widget.event != null ? 'Modifier l\'événement' : 'Nouvel événement',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveEvent,
            child: Text(
              widget.event != null ? 'MODIFIER' : 'CRÉER',
              style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImageSection(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Titre de l\'événement',
                        hintText: 'Nom accrocheur...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.trim().isEmpty == true ? 'Titre requis' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Description complète...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => v?.trim().isEmpty == true ? 'Description requise' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat['value'],
                          child: Text(cat['label']!, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(
                              '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Lieu',
                        hintText: 'Nom du lieu',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.trim().isEmpty == true ? 'Lieu requis' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'Ville',
                              hintText: 'Kinshasa, Lubumbashi...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Adresse',
                              hintText: 'Optionnel',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      value: _isFree,
                      onChanged: (v) => setState(() => _isFree = v),
                      title: const Text('Événement gratuit'),
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFFD4AF37),
                    ),
                    if (!_isFree) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Prix',
                          hintText: '5000',
                          suffixText: 'FC',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v?.trim().isEmpty == true ? 'Prix requis' : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Capacité',
                        hintText: 'Nombre de places (optionnel)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      value: _isFeatured,
                      onChanged: (v) => setState(() => _isFeatured = v),
                      title: const Text('Mettre à la une'),
                      subtitle: const Text('Apparaîtra en vedette sur la page d\'accueil'),
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFFD4AF37),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Image de l\'événement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _imageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity),
                  )
                : _imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(_imageUrl!, fit: BoxFit.cover, width: double.infinity),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('Ajouter une image', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          Text('JPG, PNG, WEBP', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                        ],
                      ),
          ),
        ),
        if (_imageBytes != null || _imageUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () => setState(() {
                _imageBytes = null;
                _imageFileName = null;
                _imageUrl = null;
              }),
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('Supprimer l\'image', style: TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }
}

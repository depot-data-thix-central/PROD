// lib/presentation/thix_market/widgets/shops/manage_shop_widget.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';

class ManageShopWidget extends StatefulWidget {
  final String shopId;
  final Function(Map<String, dynamic>)? onUpdate;

  const ManageShopWidget({super.key, required this.shopId, this.onUpdate});

  @override
  State<ManageShopWidget> createState() => _ManageShopWidgetState();
}

class _ManageShopWidgetState extends State<ManageShopWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  Map<String, dynamic> _shop = {};
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  File? _newLogo;
  File? _newCover;
  String? _category;
  
  final List<Map<String, String>> _categories = [
    {'id': 'fashion', 'name': 'Mode & Accessoires'},
    {'id': 'electronics', 'name': 'Électronique'},
    {'id': 'home', 'name': 'Maison & Jardin'},
    {'id': 'services', 'name': 'Services'},
    {'id': 'vehicles', 'name': 'Véhicules'},
    {'id': 'realestate', 'name': 'Immobilier'},
    {'id': 'food', 'name': 'Alimentation'},
    {'id': 'beauty', 'name': 'Beauté & Bien-être'},
    {'id': 'sports', 'name': 'Sports & Loisirs'},
    {'id': 'other', 'name': 'Autres'},
  ];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadShopData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadShopData() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await Supabase.instance.client
          .from('shops')
          .select()
          .eq('id', widget.shopId)
          .single();
      
      setState(() {
        _shop = response;
        _nameController.text = _shop['name'] ?? '';
        _descriptionController.text = _shop['description'] ?? '';
        _addressController.text = _shop['address'] ?? '';
        _phoneController.text = _shop['phone'] ?? '';
        _emailController.text = _shop['email'] ?? '';
        _category = _shop['category'];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading shop: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadImage(File imageFile, String path) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${const Uuid().v4()}.$fileExt';
      final filePath = '$path/$fileName';
      
      await Supabase.instance.client.storage
          .from('shop_images')
          .upload(filePath, imageFile);
      
      return Supabase.instance.client.storage
          .from('shop_images')
          .getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _updateShop() async {
    setState(() => _isSaving = true);
    
    try {
      String? logoUrl = _shop['logo_url'];
      String? coverUrl = _shop['cover_url'];
      
      if (_newLogo != null) {
        logoUrl = await _uploadImage(_newLogo!, 'logos');
      }
      
      if (_newCover != null) {
        coverUrl = await _uploadImage(_newCover!, 'covers');
      }
      
      final response = await Supabase.instance.client
          .from('shops')
          .update({
            'name': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'category': _category,
            'address': _addressController.text.trim(),
            'phone': _phoneController.text.trim(),
            'email': _emailController.text.trim(),
            'logo_url': logoUrl,
            'cover_url': coverUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.shopId)
          .select()
          .single();
      
      widget.onUpdate?.call(response);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boutique mise à jour')),
        );
        _loadShopData();
      }
    } catch (e) {
      debugPrint('Error updating shop: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Preview de la boutique
        SizedBox(
          height: 200,
          child: Stack(
            children: [
              // Cover Web-Safe
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: _newCover != null
                        ? FileImage(_newCover!) as ImageProvider
                        : (_shop['cover_url'] != null && _shop['cover_url'].toString().isNotEmpty
                            ? NetworkImage(_shop['cover_url'])
                            : const AlwaysStoppedAnimation(Colors.transparent)) as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
                child: (_shop['cover_url'] == null || _shop['cover_url'].toString().isEmpty) && _newCover == null
                    ? Container(
                        color: const Color(0xFFE5592F).withOpacity(0.1),
                        child: const Center(
                          child: Icon(Icons.store, size: 50, color: Colors.grey),
                        ),
                      )
                    : null,
              ),
              // Logo Web-Safe
              Positioned(
                bottom: 0,
                left: 16,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _newLogo != null
                        ? Image.file(_newLogo!, fit: BoxFit.cover)
                        : (_shop['logo_url'] != null && _shop['logo_url'].toString().isNotEmpty
                            ? Image.network(
                                _shop['logo_url'],
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                                },
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                              )
                            : Container(
                                color: const Color(0xFFE5592F).withOpacity(0.1),
                                child: const Icon(
                                  Icons.store,
                                  size: 40,
                                  color: Color(0xFFE5592F),
                                ),
                              )),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Onglets
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Informations'),
            Tab(text: 'Images'),
            Tab(text: 'Avancé'),
          ],
          indicatorColor: const Color(0xFFE5592F),
          labelColor: const Color(0xFFE5592F),
        ),
        
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInfoTab(),
              _buildImagesTab(),
              _buildAdvancedTab(),
            ],
          ),
        ),
        
        // Bouton sauvegarder
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _updateShop,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5592F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sauvegarder les modifications'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nom de la boutique',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: InputDecoration(
              labelText: 'Catégorie',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _categories.map((category) {
              return DropdownMenuItem(
                value: category['id'],
                child: Text(category['name']!),
              );
            }).toList(),
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Adresse',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'Téléphone',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.email),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Logo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _pickImage(true),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _newLogo != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_newLogo!, fit: BoxFit.cover),
                    )
                  : (_shop['logo_url'] != null && _shop['logo_url'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            _shop['logo_url'],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                            },
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 4),
                            Text('Modifier', style: TextStyle(color: Colors.grey[500])),
                          ],
                        )),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bannière',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _pickImage(false),
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _newCover != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_newCover!, fit: BoxFit.cover),
                    )
                  : (_shop['cover_url'] != null && _shop['cover_url'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            _shop['cover_url'],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                            },
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 4),
                            Text('Ajouter une bannière', style: TextStyle(color: Colors.grey[500])),
                          ],
                        )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Statut de la boutique'),
            subtitle: Text(_getStatusText(_shop['status'])),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(_shop['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getStatusText(_shop['status']),
                style: TextStyle(color: _getStatusColor(_shop['status'])),
              ),
            ),
          ),
          const Divider(),
          
          // Verification
          SwitchListTile(
            title: const Text('Boutique vérifiée'),
            subtitle: const Text('Augmente la confiance des acheteurs'),
            value: _shop['is_verified'] ?? false,
            onChanged: (value) {
              // Seulement pour les admins
            },
            activeColor: const Color(0xFFE5592F),
          ),
          const Divider(),
          
          // Delete shop
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Supprimer la boutique', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Cette action est irréversible'),
            onTap: _confirmDelete,
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(bool isLogo) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (image != null) {
        setState(() {
          if (isLogo) {
            _newLogo = File(image.path);
          } else {
            _newCover = File(image.path);
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la boutique'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette boutique ?\n\n'
          'Cette action supprimera tous les produits et est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client
                  .from('shops')
                  .delete()
                  .eq('id', widget.shopId);
              if (mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'pending': return Colors.orange;
      case 'suspended': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'active': return 'Active';
      case 'pending': return 'En attente';
      case 'suspended': return 'Suspendue';
      default: return 'Inconnu';
    }
  }
}

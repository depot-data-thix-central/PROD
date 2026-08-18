import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class CreateShopForm extends StatefulWidget {
  final Function(Map<String, dynamic>)? onSuccess;
  final Function(String)? onError;

  const CreateShopForm({super.key, this.onSuccess, this.onError});

  @override
  State<CreateShopForm> createState() => _CreateShopFormState();
}

class _CreateShopFormState extends State<CreateShopForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  File? _logoFile;
  File? _coverFile;
  String? _category;
  bool _isLoading = false;
  bool _acceptTerms = false;

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
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, bool isLogo) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          if (isLogo) {
            _logoFile = File(image.path);
          } else {
            _coverFile = File(image.path);
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showImageSourceDialog(bool isLogo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choisir une image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildImageSourceButton(
                    icon: Icons.camera_alt,
                    label: 'Appareil photo',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera, isLogo);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildImageSourceButton(
                    icon: Icons.photo_library,
                    label: 'Galerie',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery, isLogo);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE5592F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 32, color: const Color(0xFFE5592F)),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<String?> _uploadImage(File imageFile, String path) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${const Uuid().v4()}.$fileExt';
      final filePath = '$path/$fileName';
      
      await Supabase.instance.client.storage
          .from('shop_images')
          .upload(filePath, imageFile);
      
      final publicUrl = Supabase.instance.client.storage
          .from('shop_images')
          .getPublicUrl(filePath);
      
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _createShop() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez accepter les conditions')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? logoUrl;
      String? coverUrl;

      // Upload logo
      if (_logoFile != null) {
        logoUrl = await _uploadImage(_logoFile!, 'logos');
      }

      // Upload cover
      if (_coverFile != null) {
        coverUrl = await _uploadImage(_coverFile!, 'covers');
      }

      // Créer la boutique
      final response = await Supabase.instance.client
          .from('shops')
          .insert({
            'name': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'category': _category,
            'address': _addressController.text.trim(),
            'phone': _phoneController.text.trim(),
            'email': _emailController.text.trim(),
            'logo_url': logoUrl,
            'cover_url': coverUrl,
            'owner_id': Supabase.instance.client.auth.currentUser!.id,
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      widget.onSuccess?.call(response);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Boutique créée avec succès ! En attente de validation.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error creating shop: $e');
      widget.onError?.call(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            const Text(
              'Logo de la boutique',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showImageSourceDialog(true),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _logoFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(_logoFile!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey[400]),
                          const SizedBox(height: 4),
                          Text(
                            'Ajouter',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Cover
            const Text(
              'Bannière de couverture',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showImageSourceDialog(false),
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _coverFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(_coverFile!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 4),
                          Text(
                            'Ajouter une bannière',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Nom
            const Text(
              'Nom de la boutique *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Ex: Mode Express',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un nom';
                }
                if (value.length < 3) {
                  return 'Nom trop court';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Catégorie
            const Text(
              'Catégorie *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              hint: const Text('Sélectionner une catégorie'),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category['id'],
                  child: Text(category['name']!),
                );
              }).toList(),
              onChanged: (value) => setState(() => _category = value),
              validator: (value) {
                if (value == null) return 'Veuillez sélectionner une catégorie';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            const Text(
              'Description',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Décrivez votre boutique...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Adresse
            const Text(
              'Adresse',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                hintText: 'Votre adresse physique',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),

            // Téléphone
            const Text(
              'Téléphone',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Ex: +225 07 07 07 07 07',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),

            // Email
            const Text(
              'Email',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'contact@votreboutique.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 24),

            // Conditions
            Row(
              children: [
                Checkbox(
                  value: _acceptTerms,
                  onChanged: (value) => setState(() => _acceptTerms = value ?? false),
                  activeColor: const Color(0xFFE5592F),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black87),
                      children: [
                        const TextSpan(text: 'J\'accepte les '),
                        TextSpan(
                          text: 'conditions d\'utilisation',
                          style: const TextStyle(
                            color: Color(0xFFE5592F),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(text: ' de THIX Market'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bouton créer
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createShop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5592F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Créer ma boutique',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

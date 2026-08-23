// lib/presentation/thix_market/widgets/live/create_live_form.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

// Importation de la page de streaming
import '../../pages/live_stream_page.dart';

class CreateLiveForm extends StatefulWidget {
  final String shopId;
  final Function(Map<String, dynamic>)? onSuccess;

  const CreateLiveForm({super.key, required this.shopId, this.onSuccess});

  @override
  State<CreateLiveForm> createState() => _CreateLiveFormState();
}

class _CreateLiveFormState extends State<CreateLiveForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _thumbnail;
  List<String> _selectedProductIds = [];
  bool _hasAuction = false;
  double _startingPrice = 0;
  DateTime? _auctionEndTime;
  bool _isLoading = false;

  List<Map<String, dynamic>> _availableProducts = [];
  bool _loadingProducts = true;

  final ImagePicker _picker = ImagePicker();

  // Couleurs de l'application
  static const Color navy = Color(0xFF1B2A4A);
  static const Color gold = Color(0xFFC9962C);
  static const Color danger = Color(0xFFE53935);
  static const Color textMuted = Color(0xFF8A8FA3);
  static const Color bgApp = Color(0xFFF6F7FB);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select('id, title, price, image_url')
          .eq('shop_id', widget.shopId)
          .eq('status', 'active');
      setState(() {
        _availableProducts = List<Map<String, dynamic>>.from(response);
        _loadingProducts = false;
      });
    } catch (e) {
      debugPrint('Error loading products: $e');
      setState(() => _loadingProducts = false);
    }
  }

  Future<void> _pickThumbnail() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _thumbnail = File(image.path));
    }
  }

  Future<String?> _uploadThumbnail() async {
    if (_thumbnail == null) return null;
    try {
      final fileExt = _thumbnail!.path.split('.').last;
      final fileName = '${const Uuid().v4()}.$fileExt';
      final filePath = 'live_thumbnails/$fileName';

      await Supabase.instance.client.storage
          .from('live_images')
          .upload(filePath, _thumbnail!);

      return Supabase.instance.client.storage
          .from('live_images')
          .getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Error uploading thumbnail: $e');
      rethrow;
    }
  }

  Future<void> _processLive({required bool startNow}) async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_thumbnail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez ajouter une miniature'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_hasAuction && _startingPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez définir un prix de départ valide'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_hasAuction && _auctionEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez définir une date de fin pour les enchères'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Upload du thumbnail
      final thumbnailUrl = await _uploadThumbnail();

      // 2. Générer un channelName unique
      final channelName = 'live_${DateTime.now().millisecondsSinceEpoch}';

      // 3. Appeler la Edge Function pour obtenir le token Agora
      String token;
      try {
        final tokenResponse = await Supabase.instance.client.functions.invoke(
          'generate-rtc-token',
          body: {'channelName': channelName},
        );
        token = tokenResponse.data['token'];
        if (token.isEmpty) throw Exception('Token Agora vide');
      } catch (e) {
        debugPrint('⚠️ Agora token generation failed: $e');
        token = 'test_token_${DateTime.now().millisecondsSinceEpoch}';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Token Agora de test généré (fonction indisponible)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // 4. Définir le statut et l'heure en fonction du bouton cliqué
      final liveStatus = startNow ? 'live' : 'scheduled';
      final startTimeString = startNow 
          ? DateTime.now().toIso8601String() 
          : DateTime.now().add(const Duration(minutes: 5)).toIso8601String();

      // 5. Créer l'enregistrement du live
      final liveData = {
        'shop_id': widget.shopId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'thumbnail_url': thumbnailUrl,
        'channel_name': channelName,
        'token': token,
        'products': _selectedProductIds,
        'has_auction': _hasAuction,
        'starting_price': _hasAuction ? _startingPrice : null,
        'auction_end_time': _hasAuction ? _auctionEndTime?.toIso8601String() : null,
        'status': liveStatus,
        'scheduled_start': startTimeString,
        'started_at': startNow ? startTimeString : null,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await Supabase.instance.client
          .from('lives')
          .insert(liveData)
          .select()
          .single();

      widget.onSuccess?.call(response);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(startNow ? 'Live lancé avec succès !' : 'Live programmé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 🟢 REDIRECTION VERS LE LECTEUR VIDÉO
        if (startNow) {
          // Si c'est un direct, on ouvre la page vidéo en tant que vendeur (isHost: true)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LiveStreamPage(
                liveId: response['id'].toString(),
                channelName: channelName,
                token: token,
                isHost: true, 
              ),
            ),
          );
        } else {
          // Si c'est juste programmé, on ferme le formulaire et on rentre à l'accueil
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error creating live: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${e.toString()}'),
            backgroundColor: danger,
          ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            const Text(
              'Miniature *',
              style: TextStyle(fontWeight: FontWeight.w500, color: navy),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickThumbnail,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: bgApp,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _thumbnail != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_thumbnail!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 40,
                            color: textMuted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ajouter une miniature',
                            style: TextStyle(color: textMuted),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Titre
            const Text(
              'Titre *',
              style: TextStyle(fontWeight: FontWeight.w500, color: navy),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Ex: Vente flash mode été',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: gold, width: 2),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),

            // Description
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.w500, color: navy),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Décrivez votre live...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: gold, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Produits disponibles
            const Text(
              'Produits à présenter',
              style: TextStyle(fontWeight: FontWeight.w500, color: navy),
            ),
            const SizedBox(height: 8),
            if (_loadingProducts)
              const Center(child: CircularProgressIndicator(color: gold))
            else if (_availableProducts.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgApp,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Aucun produit disponible dans cette boutique',
                    style: TextStyle(color: textMuted),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableProducts.map((product) {
                  final isSelected = _selectedProductIds.contains(product['id']);
                  return FilterChip(
                    label: Text(
                      product['title'] ?? 'Sans titre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedProductIds.add(product['id']);
                        } else {
                          _selectedProductIds.remove(product['id']);
                        }
                      });
                    },
                    selectedColor: gold.withOpacity(0.2),
                    checkmarkColor: gold,
                    avatar: product['image_url'] != null && product['image_url'].toString().isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              product['image_url'],
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                );
                              },
                              errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 16),
                            ),
                          )
                        : null,
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),

            // Enchères
            SwitchListTile(
              title: const Text(
                'Activer les enchères',
                style: TextStyle(color: navy),
              ),
              value: _hasAuction,
              onChanged: (value) => setState(() => _hasAuction = value),
              activeColor: gold,
              contentPadding: EdgeInsets.zero,
            ),

            if (_hasAuction) ...[
              const SizedBox(height: 12),
              const Text(
                'Prix de départ *',
                style: TextStyle(fontWeight: FontWeight.w500, color: navy),
              ),
              const SizedBox(height: 4),
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: 'FCFA',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: gold, width: 2),
                  ),
                ),
                onChanged: (v) => _startingPrice = double.tryParse(v) ?? 0,
                validator: (v) => _hasAuction && (v == null || v.isEmpty)
                    ? 'Champ requis'
                    : null,
              ),
              const SizedBox(height: 12),
              const Text(
                'Fin des enchères *',
                style: TextStyle(fontWeight: FontWeight.w500, color: navy),
              ),
              const SizedBox(height: 4),
              ListTile(
                title: Text(
                  _auctionEndTime != null
                      ? '${_auctionEndTime!.day}/${_auctionEndTime!.month}/${_auctionEndTime!.year} ${_auctionEndTime!.hour}:${_auctionEndTime!.minute.toString().padLeft(2, '0')}'
                      : 'Sélectionner une date',
                  style: TextStyle(
                    color: _auctionEndTime != null ? navy : textMuted,
                  ),
                ),
                trailing: const Icon(Icons.calendar_today, color: gold),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now().add(const Duration(hours: 2)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 18, minute: 0),
                    );
                    if (time != null) {
                      setState(() {
                        _auctionEndTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
              ),
            ],

            const SizedBox(height: 24),

            // --- DOUBLE BOUTON ---
            Column(
              children: [
                // 🔴 BOUTON : Lancer le live maintenant
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _processLive(startNow: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: danger, // Rouge pour le direct
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20, height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                          )
                        : const Text('Lancer le live maintenant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // 🟡 BOUTON : Programmer le live
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => _processLive(startNow: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: gold,
                      side: const BorderSide(color: gold, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Programmer pour plus tard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

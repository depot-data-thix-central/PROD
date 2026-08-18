// lib/presentation/thix_market/widgets/search/image_search_scanner.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageSearchScanner extends StatefulWidget {
  final Function(Map<String, dynamic>? result) onResult;
  final Function(List<Map<String, dynamic>> results)? onMultipleResults;

  const ImageSearchScanner({
    super.key,
    required this.onResult,
    this.onMultipleResults,
  });

  @override
  State<ImageSearchScanner> createState() => _ImageSearchScannerState();
}

class _ImageSearchScannerState extends State<ImageSearchScanner> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _scanHistory = [];

  // ============================================================
  // CHARTE ÉLITE (identique à MarketHomePage)
  // ============================================================
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color navy = Color(0xFF123B7A);
  static const Color primaryBlue = Color(0xFF2D6CDF);
  static const Color softBlue = Color(0xFFEFF5FF);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF10192E);
  static const Color mutedText = Color(0xFF7386A8);
  static const Color gold = Color(0xFFE3B23C);
  static const Color danger = Color(0xFFFF5B3D);
  static const Color bgApp = Color(0xFFF7FAFF);

  @override
  void initState() {
    super.initState();
    _loadScanHistory();
  }

  Future<void> _loadScanHistory() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('image_search_history')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _scanHistory = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error loading scan history: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la sélection de l\'image';
        _isProcessing = false;
      });
    }
  }

  Future<void> _processImage(File imageFile) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await Supabase.instance.client
          .functions
          .invoke('image-search', body: {
            'image': base64Image,
            'return_similar': true,
            'limit': 10,
          });

      final result = response.data;

      if (result != null) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await Supabase.instance.client
              .from('image_search_history')
              .insert({
                'user_id': userId,
                'image_url': result['uploaded_image_url'] ?? '',
                'result_count': result['matches']?.length ?? 0,
                'created_at': DateTime.now().toIso8601String(),
              });
        }

        if (result['matches'] != null && result['matches'].isNotEmpty) {
          if (result['matches'].length == 1) {
            widget.onResult(result['matches'][0]);
          } else {
            widget.onMultipleResults?.call(List<Map<String, dynamic>>.from(result['matches']));
          }
        } else {
          widget.onResult(null);
          setState(() {
            _errorMessage = 'Aucun produit trouvé pour cette image';
          });
        }

        await _loadScanHistory();
      }

      if (mounted) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
      setState(() {
        _errorMessage = 'Erreur lors de la recherche par image. Vérifiez votre connexion.';
        _isProcessing = false;
      });
    }
  }

  void _showSourceSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: pureWhite,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choisir une image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: darkText),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Appareil photo',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Galerie',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [softBlue, Color(0xFFE3EDFF)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: primaryBlue.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            child: Icon(icon, size: 32, color: primaryBlue),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkText)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Bouton principal ──────────────────────────────────
          InkWell(
            onTap: _showSourceSelector,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 130,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [navy, primaryBlue],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 12)),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isProcessing)
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 32, color: Colors.white),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      _isProcessing ? 'Recherche en cours...' : 'Scanner par image',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    if (!_isProcessing)
                      Text(
                        'Prenez une photo ou choisissez une image',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: danger.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 20, color: danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(fontSize: 13, color: danger, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ─── Historique des scans ─────────────────────────────
          if (_scanHistory.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Recherches récentes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkText),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _scanHistory.length,
                itemBuilder: (context, index) {
                  final scan = _scanHistory[index];
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CachedNetworkImage(
                            imageUrl: scan['image_url'] ?? '',
                            height: 60,
                            width: 60,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 60,
                              width: 60,
                              color: softBlue,
                              child: const Icon(Icons.image_rounded, color: mutedText),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              height: 60,
                              width: 60,
                              color: softBlue,
                              child: const Icon(Icons.broken_image_rounded, color: mutedText),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${scan['result_count']} résultats',
                          style: TextStyle(fontSize: 10, color: mutedText, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          // ─── Conseils ──────────────────────────────────────────
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: softBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: primaryBlue.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Icon(Icons.tips_and_updates_rounded, size: 20, color: gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Conseils pour un meilleur résultat',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Utilisez une image claire et bien éclairée\n• Cadrez bien le produit\n• Évitez les arrière-plans chargés',
                        style: TextStyle(fontSize: 10.5, color: mutedText, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Résultats multiples ──────────────────────────────────────────────
class MultipleResultsDialog extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final Function(Map<String, dynamic>) onSelect;

  const MultipleResultsDialog({
    super.key,
    required this.results,
    required this.onSelect,
  });

  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color navy = Color(0xFF123B7A);
  static const Color primaryBlue = Color(0xFF2D6CDF);
  static const Color gold = Color(0xFFE3B23C);
  static const Color mutedText = Color(0xFF7386A8);
  static const Color softBlue = Color(0xFFEFF5FF);
  static const Color pureWhite = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: pureWhite,
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plusieurs résultats trouvés',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navyDeep),
            ),
            const SizedBox(height: 4),
            Text(
              'Sélectionnez le produit correspondant',
              style: TextStyle(color: mutedText, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final product = results[index];
                  final currency = product['currency'] ?? 'CDF';
                  final symbol = currency == 'USD' ? '\$' : 'FC';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: softBlue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: product['image_url'] ?? '',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_rounded, color: mutedText),
                          ),
                        ),
                      ),
                      title: Text(
                        product['title'] ?? 'Sans titre',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: navyDeep),
                      ),
                      subtitle: Text(
                        '${(product['price'] as num?)?.toInt() ?? 0} $symbol',
                        style: TextStyle(color: mutedText),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [primaryBlue, navy],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${product['similarity_score']?.toInt() ?? 0}%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        onSelect(product);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

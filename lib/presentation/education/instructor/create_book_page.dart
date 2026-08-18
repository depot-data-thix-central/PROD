// lib/presentation/education/instructor/create_book_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

class _C {
  static const bg = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const primary = Color(0xFF2D6CDF);
  static const textMain = Color(0xFF1E293B);
  static const textMuted = Color(0xFF7386A8);
  static const border = Color(0xFFE2E8F0);
  static const red = Color(0xFFEF4444);
  static const green = Color(0xFF2ECC71);
}

class CreateBookPage extends ConsumerStatefulWidget {
  final String? bookId;
  const CreateBookPage({super.key, this.bookId});

  @override
  ConsumerState<CreateBookPage> createState() => _CreateBookPageState();
}

class _CreateBookPageState extends ConsumerState<CreateBookPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String _imageUrl = '';
  String _selectedCurrency = 'FC';
  String? _shelfCode; // null = nouvelle étagère auto
  String _category = 'Général';
  List<String> _existingShelves = [];

  bool _isLoading = false;
  bool _isInitLoading = false;
  bool _isUploadingImage = false;
  bool _loadingShelves = false;

  @override
  void initState() {
    super.initState();
    _loadShelves();
    if (widget.bookId != null) {
      _loadExistingBook();
    } else {
      final userMeta = Supabase.instance.client.auth.currentUser?.userMetadata;
      if (userMeta != null && userMeta['name'] != null) {
        _authorController.text = userMeta['name'];
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String _generateShelfCode(String author) {
    final name = author.trim().isEmpty ? 'Auteur' : author.trim();
    final hash = name.hashCode.abs().toRadixString(16).toUpperCase();
    final short =
        hash.length >= 4 ? hash.substring(0, 4) : hash.padLeft(4, '0');
    return 'THIX-B-$short';
  }

  Future<void> _loadShelves() async {
    setState(() => _loadingShelves = true);
    try {
      final res = await Supabase.instance.client
          .from('books')
          .select('shelf_code')
          .not('shelf_code', 'is', null);
      final codes = (res as List)
          .map((e) => e['shelf_code'] as String?)
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
      if (mounted) setState(() => _existingShelves = codes);
    } catch (e) {
      debugPrint('Erreur chargement étagères: $e');
    } finally {
      if (mounted) setState(() => _loadingShelves = false);
    }
  }

  Future<void> _loadExistingBook() async {
    setState(() => _isInitLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('books')
          .select()
          .eq('id', widget.bookId!)
          .single();

      if (mounted) {
        setState(() {
          _titleController.text = data['title']?.toString() ?? '';
          _authorController.text = data['author']?.toString() ?? '';
          _descriptionController.text = data['description']?.toString() ?? '';
          _priceController.text = data['price']?.toString() ?? '0';
          _selectedCurrency = data['currency']?.toString() ?? 'FC';
          _imageUrl = data['image_url']?.toString() ??
              data['cover_url']?.toString() ??
              '';
          _shelfCode = data['shelf_code']?.toString();
          _category = data['category']?.toString() ?? 'Général';
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement livre : $e');
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  Future<void> _pickAndUploadCoverImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes == null) return;

        setState(() => _isUploadingImage = true);

        final ext = file.extension ?? 'jpg';
        final fileName =
            'book_cover_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final filePath = 'books/covers/$fileName';

        await Supabase.instance.client.storage
            .from('course-media')
            .uploadBinary(filePath, bytes);

        final publicUrl = Supabase.instance.client.storage
            .from('course-media')
            .getPublicUrl(filePath);

        setState(() {
          _imageUrl = publicUrl;
          _isUploadingImage = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Couverture uploadée !'),
              backgroundColor: _C.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur upload image : $e'),
            backgroundColor: _C.red,
          ),
        );
      }
    }
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isUploadingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Patientez pendant l\'upload de l\'image.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté.');

      final author = _authorController.text.trim();
      final payload = {
        'title': _titleController.text.trim(),
        'author': author,
        'description': _descriptionController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'currency': _selectedCurrency,
        'image_url': _imageUrl.isEmpty ? null : _imageUrl,
        'shelf_code': _shelfCode ?? _generateShelfCode(author),
        'category': _category,
        'updated_at': DateTime.now().toIso8601String(),
      };

      String? bookId = widget.bookId;

      if (widget.bookId == null) {
        payload['instructor_id'] = userId;
        payload['created_at'] = DateTime.now().toIso8601String();
        final res = await Supabase.instance.client
            .from('books')
            .insert(payload)
            .select('id')
            .single();
        bookId = res['id'] as String?;
      } else {
        await Supabase.instance.client
            .from('books')
            .update(payload)
            .eq('id', widget.bookId!);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.bookId == null
              ? 'Livre créé ! Ajoutez maintenant le contenu.'
              : 'Livre mis à jour !'),
          backgroundColor: _C.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (widget.bookId == null && bookId != null) {
        context.pushReplacement('/instructor/books/$bookId/content');
      } else {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: _C.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.bookId != null;
    final previewShelf = _shelfCode ??
        _generateShelfCode(
            _authorController.text.isEmpty ? 'Auteur' : _authorController.text);

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Modifier le livre' : 'Ajouter un livre',
          style: const TextStyle(
              fontWeight: FontWeight.w800, color: _C.textMain, fontSize: 18),
        ),
        backgroundColor: _C.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.textMain),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isInitLoading
          ? const Center(child: CircularProgressIndicator(color: _C.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ========== INFORMATIONS GÉNÉRALES ==========
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informations générales',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _C.textMain),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _titleController,
                            label: 'Titre du livre',
                            icon: Icons.title_rounded,
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _authorController,
                            label: 'Auteur',
                            icon: Icons.person_outline_rounded,
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Requis' : null,
                            onChanged: (_) => setState(() {}), // refresh preview étagère
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _descriptionController,
                            label: 'Description',
                            icon: Icons.description_outlined,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildTextField(
                                  controller: _priceController,
                                  label: 'Prix',
                                  icon: Icons.payments_outlined,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  hintText: '0 = Gratuit',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedCurrency,
                                  dropdownColor: _C.surface,
                                  style: const TextStyle(
                                      color: _C.textMain,
                                      fontWeight: FontWeight.w600),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'FC', child: Text('FC')),
                                    DropdownMenuItem(
                                        value: 'USD', child: Text('USD')),
                                    DropdownMenuItem(
                                        value: 'EUR', child: Text('EUR')),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _selectedCurrency = v!),
                                  decoration: _inputDecoration(
                                      'Devise', Icons.currency_exchange_rounded),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // —— CATÉGORIE ——
                          DropdownButtonFormField<String>(
                            value: _category,
                            dropdownColor: _C.surface,
                            decoration: _inputDecoration(
                                'Catégorie', Icons.category_outlined),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Général', child: Text('Général')),
                              DropdownMenuItem(
                                  value: 'Entrepreneuriat',
                                  child: Text('Entrepreneuriat')),
                              DropdownMenuItem(
                                  value: 'Droit', child: Text('Droit')),
                              DropdownMenuItem(
                                  value: 'Nouveau', child: Text('Nouveau')),
                              DropdownMenuItem(
                                  value: 'À venir', child: Text('À venir')),
                              DropdownMenuItem(
                                  value: 'Éducation', child: Text('Éducation')),
                            ],
                            onChanged: (v) =>
                                setState(() => _category = v ?? 'Général'),
                          ),
                          const SizedBox(height: 16),

                          // —— ÉTAGÈRE ——
                          DropdownButtonFormField<String?>(
                            value: _shelfCode,
                            dropdownColor: _C.surface,
                            decoration:
                                _inputDecoration('Étagère', Icons.shelves),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Nouvelle étagère (auto)'),
                              ),
                              ..._existingShelves.map(
                                (s) => DropdownMenuItem<String?>(
                                  value: s,
                                  child: Text(s),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _shelfCode = v),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _shelfCode == null
                                ? 'Code généré : $previewShelf'
                                : 'Étagère sélectionnée : $_shelfCode',
                            style: const TextStyle(
                                fontSize: 12, color: _C.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ========== COUVERTURE ==========
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Image de couverture',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _C.textMain),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _isUploadingImage
                                ? null
                                : _pickAndUploadCoverImage,
                            child: Container(
                              width: double.infinity,
                              height: 160,
                              decoration: BoxDecoration(
                                color: _C.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _C.border),
                                image: _imageUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(_imageUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _isUploadingImage
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : _imageUrl.isEmpty
                                      ? const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                                size: 40,
                                                color: _C.textMuted),
                                            SizedBox(height: 8),
                                            Text(
                                              'Appuyer pour choisir une image',
                                              style: TextStyle(
                                                  color: _C.textMuted,
                                                  fontSize: 13),
                                            ),
                                          ],
                                        )
                                      : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Le contenu (chapitres & sections) se gère après la création du livre.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _C.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bouton
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveBook,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing
                                    ? 'Enregistrer les modifications'
                                    : 'Créer le livre',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!isEditing)
                      const Text(
                        'Après création, vous serez redirigé pour ajouter les chapitres et sections.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: _C.textMuted),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? hintText,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: _inputDecoration(label, icon, hintText: hintText),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon,
      {String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon, color: _C.textMuted, size: 20),
      filled: true,
      fillColor: _C.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

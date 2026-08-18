
// lib/presentation/education/instructor/courses/course_create_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/presentation/education/providers/education_provider.dart';
import 'package:thix_id/presentation/education/models/module.dart';
import 'package:thix_id/presentation/education/models/lesson.dart';
import 'package:thix_id/presentation/education/instructor/content/module_management_page.dart';
import 'package:thix_id/presentation/education/widgets/common/education_category_chip.dart';
import 'package:thix_id/presentation/education/widgets/certificate_canvas.dart';

class CourseCreatePage extends ConsumerStatefulWidget {
  final String? courseId;
  const CourseCreatePage({super.key, this.courseId});

  @override
  ConsumerState<CourseCreatePage> createState() => _CourseCreatePageState();
}

class _CourseCreatePageState extends ConsumerState<CourseCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructorController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _tagsController = TextEditingController();

  // Certificat
  final _certHeaderController =
      TextEditingController(text: 'certifie que');
  final _certBodyController = TextEditingController(
    text:
        'a complété avec succès l\'intégralité de la formation et a satisfait à toutes les exigences requises.',
  );
  final _certFooterController =
      TextEditingController(text: 'Fait à Kinshasa');
  final _certSignatoryNameController = TextEditingController();
  final _certSignatoryTitleController =
      TextEditingController(text: 'Directeur pédagogique');

  String _level = 'beginner';
  String? _categoryId;
  String _currency = 'USD';
  bool _isFree = false;
  bool _isCertifying = false;
  bool _isLoading = false;
  bool _isInitLoading = false;
  List<Module> _modules = [];

  Uint8List? _coverImageBytes;
  bool _isUploadingImage = false;

  String _certTemplateId = 'classic_navy';
  String? _certLogoUrl;
  String? _certSignatureUrl;
  bool _uploadingCertLogo = false;
  bool _uploadingCertSign = false;

  static const _templates = <(String, String, Color)>[
    ('classic_navy', 'Classic Navy', Color(0xFF0B1F3A)),
    ('modern_minimal', 'Modern Minimal', Color(0xFF0F172A)),
    ('royal_gold', 'Royal Gold', Color(0xFF10206B)),
    ('academic_serif', 'Academic Serif', Color(0xFF1E293B)),
    ('tech_blue', 'Tech Blue', Color(0xFF0C4A6E)),
    ('emerald_elite', 'Emerald Elite', Color(0xFF064E3B)),
    ('crimson_honor', 'Crimson Honor', Color(0xFF7F1D1D)),
    ('slate_pro', 'Slate Pro', Color(0xFF334155)),
    ('ivory_tradition', 'Ivory Tradition', Color(0xFF44403C)),
    ('midnight_prestige', 'Midnight Prestige', Color(0xFF020617)),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.courseId != null) {
      _loadCourse();
    } else {
      final user = Supabase.instance.client.auth.currentUser;
      final userName = user?.userMetadata?['full_name'] ??
          user?.userMetadata?['name'];
      if (userName != null) {
        _instructorController.text = userName.toString();
        _certSignatoryNameController.text = userName.toString();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructorController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _tagsController.dispose();
    _certHeaderController.dispose();
    _certBodyController.dispose();
    _certFooterController.dispose();
    _certSignatoryNameController.dispose();
    _certSignatoryTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadCourse() async {
    setState(() => _isInitLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('formations')
          .select('*, modules(*, lessons(*))')
          .eq('id', widget.courseId!)
          .single();

      if (!mounted) return;
      setState(() {
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _instructorController.text = data['instructor_name'] ?? '';
        _priceController.text = (data['price'] ?? 0).toString();
        _categoryId = data['category_id'];
        _level = data['level'] ?? 'beginner';
        _currency = data['currency'] ?? 'USD';
        _imageUrlController.text = data['image_url'] ?? '';
        _isFree = data['is_free'] ?? false;
        _isCertifying = data['is_certifying'] ?? false;
        _certTemplateId =
            data['certificate_template_id'] ?? 'classic_navy';
        if (data['certificate_header'] != null) {
          _certHeaderController.text = data['certificate_header'];
        }
        if (data['certificate_body'] != null) {
          _certBodyController.text = data['certificate_body'];
        }
        if (data['certificate_footer'] != null) {
          _certFooterController.text = data['certificate_footer'];
        }
        _certLogoUrl = data['certificate_logo_url'];
        _certSignatureUrl = data['certificate_signature_url'];
        if (data['certificate_signatory_name'] != null) {
          _certSignatoryNameController.text =
              data['certificate_signatory_name'];
        }
        if (data['certificate_signatory_title'] != null) {
          _certSignatoryTitleController.text =
              data['certificate_signatory_title'];
        }
        if (data['tags'] != null && data['tags'] is List) {
          _tagsController.text = (data['tags'] as List).join(', ');
        }
        if (data['modules'] != null) {
          _modules = (data['modules'] as List).map((mJson) {
            final module = Module.fromJson(mJson);
            if (mJson['lessons'] != null) {
              module.lessons = (mJson['lessons'] as List)
                  .map((lJson) => Lesson.fromJson(lJson))
                  .toList();
              module.lessons!
                  .sort((a, b) => a.order.compareTo(b.order));
            }
            return module;
          }).toList();
        }
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement cours : $e');
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      setState(() {
        _coverImageBytes = bytes;
        _isUploadingImage = true;
      });

      final ext = file.extension ?? 'jpg';
      final fileName =
          'cover_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final filePath = 'courses/covers/$fileName';

      await Supabase.instance.client.storage
          .from('course-media')
          .uploadBinary(filePath, bytes);
      final publicUrl = Supabase.instance.client.storage
          .from('course-media')
          .getPublicUrl(filePath);

      setState(() {
        _imageUrlController.text = publicUrl;
        _isUploadingImage = false;
      });
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur upload image.'),
          backgroundColor: ThixPolicy.danger,
        ));
      }
    }
  }

  Future<void> _uploadCertAsset({required bool isLogo}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      setState(() {
        if (isLogo) {
          _uploadingCertLogo = true;
        } else {
          _uploadingCertSign = true;
        }
      });

      final ext = file.extension ?? 'png';
      final name =
          '${isLogo ? 'logo' : 'sign'}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'certificates/$name';

      await Supabase.instance.client.storage
          .from('course-media')
          .uploadBinary(path, bytes);
      final url = Supabase.instance.client.storage
          .from('course-media')
          .getPublicUrl(path);

      setState(() {
        if (isLogo) {
          _certLogoUrl = url;
          _uploadingCertLogo = false;
        } else {
          _certSignatureUrl = url;
          _uploadingCertSign = false;
        }
      });
    } catch (e) {
      setState(() {
        _uploadingCertLogo = false;
        _uploadingCertSign = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload : $e'),
          backgroundColor: ThixPolicy.danger,
        ));
      }
    }
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez remplir les champs obligatoires.'),
        backgroundColor: ThixPolicy.warning,
      ));
      return;
    }
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez sélectionner une catégorie.'),
        backgroundColor: ThixPolicy.warning,
      ));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté.');

      final totalDuration = _modules.fold<int>(0, (sum, m) {
        final lessons = m.lessons ?? [];
        return sum +
            lessons.fold<int>(0, (s, l) => s + l.durationMinutes);
      });

      final formationData = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category_id': _categoryId,
        'user_id': userId,
        'instructor_id': userId,
        'created_by': userId,
        'instructor_name': _instructorController.text.trim(),
        'level': _level,
        'duration': totalDuration,
        'price': _isFree
            ? 0.0
            : (double.tryParse(_priceController.text) ?? 0.0),
        'currency': _currency,
        'image_url': _imageUrlController.text.trim(),
        'tags': _tagsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'is_free': _isFree,
        'is_certifying': _isCertifying,
        'status': 'draft',
        if (_isCertifying) ...{
          'certificate_template_id': _certTemplateId,
          'certificate_header': _certHeaderController.text.trim(),
          'certificate_body': _certBodyController.text.trim(),
          'certificate_footer': _certFooterController.text.trim(),
          'certificate_logo_url': _certLogoUrl,
          'certificate_signature_url': _certSignatureUrl,
          'certificate_signatory_name':
              _certSignatoryNameController.text.trim(),
          'certificate_signatory_title':
              _certSignatoryTitleController.text.trim(),
        },
      };

      if (widget.courseId == null) {
        final res = await Supabase.instance.client
            .from('formations')
            .insert(formationData)
            .select('id')
            .single();
        if (!mounted) return;
        context.pushReplacement('/instructor/courses/edit/${res['id']}');
      } else {
        await Supabase.instance.client
            .from('formations')
            .update(formationData)
            .eq('id', widget.courseId!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cours enregistré'),
          backgroundColor: Color(0xFF10B981),
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: ThixPolicy.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addModule() async {
    final newModule = await Navigator.push<Module>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ModuleManagementPage(courseId: widget.courseId),
      ),
    );
    if (newModule != null) setState(() => _modules.add(newModule));
  }

  void _editModule(Module module) async {
    final updated = await Navigator.push<Module>(
      context,
      MaterialPageRoute(
        builder: (_) => ModuleManagementPage(
          module: module,
          courseId: widget.courseId,
        ),
      ),
    );
    if (updated != null) {
      final index = _modules.indexOf(module);
      if (index != -1) setState(() => _modules[index] = updated);
    }
  }

  void _deleteModule(Module module) {
    setState(() => _modules.remove(module));
  }

  InputDecoration _inputDeco(String label,
      {IconData? icon, String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle:
          const TextStyle(color: ThixPolicy.textSecondary, fontSize: 14),
      hintStyle:
          const TextStyle(color: ThixPolicy.textMuted, fontSize: 13),
      filled: true,
      fillColor: ThixPolicy.surfaceSoft,
      prefixIcon: icon != null
          ? Icon(icon, color: ThixPolicy.textSecondary, size: 20)
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
        borderSide: const BorderSide(color: ThixPolicy.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
        borderSide: const BorderSide(color: ThixPolicy.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
        borderSide:
            const BorderSide(color: ThixPolicy.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: ThixPolicy.s16, vertical: ThixPolicy.s16),
    );
  }

  // 👇 MÉTHODE D'APERÇU DU CERTIFICAT INTÉGRÉE ET CORRIGÉE 👇
  void _showCertificatePreview() {
    final now = DateTime.now();
    // /!\ Assure-toi que CertificateData est bien importé en haut du fichier
    final data = CertificateData(
      academyName: _instructorController.text.trim().isEmpty
          ? 'THIX Academy'
          : _instructorController.text.trim(),
      header: _certHeaderController.text.trim().isEmpty
          ? 'certifie que'
          : _certHeaderController.text.trim(),
      learnerName: 'Jean Mukendi', // démo — en prod = profil apprenant
      body: _certBodyController.text.trim().isEmpty
          ? 'a complété avec succès la formation.'
          : _certBodyController.text.trim(),
      courseTitle: _titleController.text.trim().isEmpty
          ? 'Titre de la formation'
          : _titleController.text.trim(),
      footer: _certFooterController.text.trim().isEmpty
          ? 'Fait à Kinshasa'
          : _certFooterController.text.trim(),
      signatoryName: _certSignatoryNameController.text.trim().isEmpty
          ? 'Signataire'
          : _certSignatoryNameController.text.trim(),
      signatoryTitle: _certSignatoryTitleController.text.trim(),
      logoUrl: _certLogoUrl,
      signatureUrl: _certSignatureUrl,
      serial: 'THIX-CERT-${now.year}-PREVIEW',
      // Format de date corrigé avec l'interpolation standard Dart ($)
      dateLabel: '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
      templateId: _certTemplateId,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.92,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Aperçu certificat',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: CertificateCanvas(
                      data: data,
                      width: MediaQuery.of(ctx).size.width - 48,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  'Produit par THIX ID CENTRAL  ·  Aperçu non officiel',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCertificateSection() {
    return Container(
      margin: const EdgeInsets.only(top: ThixPolicy.s16),
      padding: const EdgeInsets.all(ThixPolicy.s20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text(
                'Configuration du certificat',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFF065F46),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Académie = ton profil formateur. Nom apprenant = son compte.',
            style: TextStyle(fontSize: 12, color: Color(0xFF047857)),
          ),
          const SizedBox(height: 16),

          const Text(
            'Modèle',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _templates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final t = _templates[i];
                final selected = _certTemplateId == t.$1;
                return GestureDetector(
                  onTap: () => setState(() => _certTemplateId = t.$1),
                  child: Container(
                    width: 100,
                    decoration: BoxDecoration(
                      color: t.$3,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF059669)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selected)
                          const Icon(Icons.check_circle,
                              color: Colors.white, size: 16),
                        const Spacer(),
                        Text(
                          t.$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _certHeaderController,
            decoration: _inputDeco('En-tête', icon: Icons.title_rounded),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _certBodyController,
            maxLines: 3,
            decoration:
                _inputDeco('Corps du texte', icon: Icons.notes_rounded),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _certFooterController,
            decoration:
                _inputDeco('Bas de page', icon: Icons.vertical_align_bottom),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _certSignatoryNameController,
            decoration: _inputDeco('Nom du signataire',
                icon: Icons.person_rounded),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _certSignatoryTitleController,
            decoration: _inputDeco('Titre du signataire',
                icon: Icons.badge_rounded),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploadingCertLogo
                      ? null
                      : () => _uploadCertAsset(isLogo: true),
                  icon: _uploadingCertLogo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_rounded, size: 18),
                  label: Text(
                    _certLogoUrl != null ? 'Logo ✓' : 'Logo académie',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploadingCertSign
                      ? null
                      : () => _uploadCertAsset(isLogo: false),
                  icon: _uploadingCertSign
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.draw_rounded, size: 18),
                  label: Text(
                    _certSignatureUrl != null
                        ? 'Signature ✓'
                        : 'Signature PNG',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          if (_certLogoUrl != null || _certSignatureUrl != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_certLogoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(_certLogoUrl!,
                        height: 48, width: 48, fit: BoxFit.contain),
                  ),
                if (_certLogoUrl != null && _certSignatureUrl != null)
                  const SizedBox(width: 12),
                if (_certSignatureUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(_certSignatureUrl!,
                        height: 48, width: 80, fit: BoxFit.contain),
                  ),
              ],
            ),
          ],
          
          // 👇 BOUTON AJOUTÉ POUR DÉCLENCHER L'APERÇU 👇
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showCertificatePreview,
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('Aperçu du certificat', style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final isNewCourse = widget.courseId == null;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          isNewCourse ? 'Créer un cours' : 'Modifier le cours',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: ThixPolicy.textMain,
            fontSize: 18,
          ),
        ),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: ThixPolicy.textMain),
          onPressed: () => context.pop(),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: ThixPolicy.s16),
              child: SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed:
                      _isLoading || _isInitLoading ? null : _saveCourse,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: ThixPolicy.onBrand,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    _isLoading ? 'En cours...' : 'Enregistrer',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: ThixPolicy.onBrand,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(ThixPolicy.rMd),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isInitLoading
          ? const Center(
              child: CircularProgressIndicator(color: ThixPolicy.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(ThixPolicy.s16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Couverture
                    const Text('Couverture du cours',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: ThixPolicy.s12),
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: ThixPolicy.tint,
                          borderRadius:
                              BorderRadius.circular(ThixPolicy.rLg),
                          border: Border.all(
                            color: ThixPolicy.primary.withOpacity(0.3),
                          ),
                          image: _imageUrlController.text.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(
                                      _imageUrlController.text),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _imageUrlController.text.isEmpty
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isUploadingImage)
                                    const CircularProgressIndicator()
                                  else ...[
                                    const Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 42,
                                        color: ThixPolicy.primary),
                                    const SizedBox(height: 8),
                                    const Text('Ajouter une image',
                                        style: TextStyle(
                                            color: ThixPolicy.primary,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ],
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s24),

                    // Infos générales
                    Container(
                      padding: const EdgeInsets.all(ThixPolicy.s20),
                      decoration: BoxDecoration(
                        color: ThixPolicy.card,
                        borderRadius:
                            BorderRadius.circular(ThixPolicy.rLg),
                        border: Border.all(color: ThixPolicy.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Informations Générales',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                          const SizedBox(height: ThixPolicy.s16),
                          TextFormField(
                            controller: _titleController,
                            decoration: _inputDeco('Titre du cours *'),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: ThixPolicy.s12),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: _inputDeco('Description globale'),
                            maxLines: 4,
                          ),
                          const SizedBox(height: ThixPolicy.s12),
                          TextFormField(
                            controller: _instructorController,
                            decoration: _inputDeco(
                              'Académie / Nom du formateur *',
                              icon: Icons.business_rounded,
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: ThixPolicy.s12),
                          TextFormField(
                            controller: _tagsController,
                            decoration: _inputDeco('Mots-clés',
                                hintText: 'Séparés par des virgules...',
                                icon: Icons.tag_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s24),

                    // Catégorie
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(ThixPolicy.s20),
                      decoration: BoxDecoration(
                        color: ThixPolicy.card,
                        borderRadius:
                            BorderRadius.circular(ThixPolicy.rLg),
                        border: Border.all(color: ThixPolicy.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Catégorie *',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                          const SizedBox(height: ThixPolicy.s16),
                          categoriesAsync.when(
                            data: (cats) => Wrap(
                              spacing: ThixPolicy.s8,
                              runSpacing: ThixPolicy.s8,
                              children: cats
                                  .map((c) => EducationCategoryChip(
                                        label: c.name,
                                        isSelected: _categoryId == c.id,
                                        onTap: () => setState(
                                            () => _categoryId = c.id),
                                      ))
                                  .toList(),
                            ),
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                            error: (_, __) => const Text(
                                'Erreur catégories',
                                style:
                                    TextStyle(color: ThixPolicy.danger)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s24),

                    // Détails & tarification + certificat
                    Container(
                      padding: const EdgeInsets.all(ThixPolicy.s20),
                      decoration: BoxDecoration(
                        color: ThixPolicy.card,
                        borderRadius:
                            BorderRadius.circular(ThixPolicy.rLg),
                        border: Border.all(color: ThixPolicy.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Détails & Tarification',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                          const SizedBox(height: ThixPolicy.s16),
                          DropdownButtonFormField<String>(
                            value: _level,
                            items: const [
                              DropdownMenuItem(
                                  value: 'beginner',
                                  child: Text('Débutant')),
                              DropdownMenuItem(
                                  value: 'intermediate',
                                  child: Text('Intermédiaire')),
                              DropdownMenuItem(
                                  value: 'advanced',
                                  child: Text('Avancé')),
                            ],
                            onChanged: (v) =>
                                setState(() => _level = v!),
                            decoration: _inputDeco(
                                'Niveau de difficulté',
                                icon: Icons.leaderboard_rounded),
                          ),
                          const SizedBox(height: ThixPolicy.s16),
                          SwitchListTile(
                            title: const Text('Cours Gratuit',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                            subtitle: const Text(
                                'Ce cours sera accessible gratuitement.',
                                style: TextStyle(fontSize: 12)),
                            value: _isFree,
                            activeColor: ThixPolicy.primary,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (v) {
                              setState(() {
                                _isFree = v;
                                if (v) _priceController.clear();
                              });
                            },
                          ),
                          if (!_isFree) ...[
                            const SizedBox(height: ThixPolicy.s12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _priceController,
                                    decoration: _inputDeco('Prix',
                                        icon: Icons.sell_rounded),
                                    keyboardType: TextInputType.number,
                                    validator: (v) =>
                                        v == null || v.isEmpty
                                            ? 'Requis'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: ThixPolicy.s12),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    value: _currency,
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'USD',
                                          child: Text('USD \$')),
                                      DropdownMenuItem(
                                          value: 'FC', child: Text('FC')),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _currency = v!),
                                    decoration: _inputDeco('Devise'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1),
                          ),
                          SwitchListTile(
                            title: const Text('Cours Certifiant',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                            subtitle: const Text(
                                'Délivre un certificat à la fin de la formation.',
                                style: TextStyle(fontSize: 12)),
                            value: _isCertifying,
                            activeColor: ThixPolicy.domainLearning,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (v) =>
                                setState(() => _isCertifying = v),
                          ),
                          if (_isCertifying) _buildCertificateSection(),
                        ],
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s24),

                    // Modules
                    if (isNewCourse)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(ThixPolicy.s24),
                        decoration: BoxDecoration(
                          color: ThixPolicy.tint,
                          borderRadius:
                              BorderRadius.circular(ThixPolicy.rLg),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.lock_rounded, size: 40),
                            SizedBox(height: 12),
                            Text(
                              'Sauvegardez d\'abord le cours pour ajouter modules et leçons.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Modules du cours',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900)),
                          ElevatedButton.icon(
                            onPressed: _addModule,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Ajouter'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThixPolicy.inkDeep,
                              foregroundColor: ThixPolicy.onBrand,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: ThixPolicy.s16),
                      if (_modules.isEmpty)
                        const Center(
                          child: Text(
                              'Aucun module. Commencez par en ajouter un.'),
                        ),
                      ..._modules.asMap().entries.map((entry) {
                        final index = entry.key;
                        final module = entry.value;
                        return Container(
                          margin:
                              const EdgeInsets.only(bottom: ThixPolicy.s12),
                          decoration: BoxDecoration(
                            color: ThixPolicy.card,
                            borderRadius:
                                BorderRadius.circular(ThixPolicy.rMd),
                            border: Border.all(color: ThixPolicy.border),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${index + 1}'),
                            ),
                            title: Text(module.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${(module.lessons ?? []).length} leçon(s)'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded),
                                  onPressed: () => _editModule(module),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: ThixPolicy.danger),
                                  onPressed: () => _deleteModule(module),
                                ),
                              ],
                            ),
                            onTap: () => _editModule(module),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
    );
  }
}

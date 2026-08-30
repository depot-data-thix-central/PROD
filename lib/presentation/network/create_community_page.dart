// lib/presentation/network/create_community_page.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/presentation/network/communities_list_page.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _CommunityValidators {
  _CommunityValidators._();

  static const int maxLogoSizeMB = 3;
  static const int maxNameLength = 80;
  static const int minNameLength = 3;
  static const int maxDescriptionLength = 500;
  static const Duration uploadTimeout = Duration(seconds: 30);
  static const Duration createTimeout = Duration(seconds: 15);

  static const Set<String> allowedImageExts = {'jpg', 'jpeg', 'png', 'webp'};

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static String? validateName(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'Le nom est requis';
    if (clean.length < minNameLength) return 'Le nom doit faire au moins $minNameLength caractères';
    if (clean.length > maxNameLength) return 'Le nom ne peut pas dépasser $maxNameLength caractères';
    if (!RegExp(r'^[\p{L}\p{N}\s\-_.&]+$', unicode: true).hasMatch(clean)) {
      return 'Le nom contient des caractères invalides';
    }
    return null;
  }

  static String? validateDescription(String desc) {
    if (desc.trim().length > maxDescriptionLength) {
      return 'La description ne peut pas dépasser $maxDescriptionLength caractères';
    }
    return null;
  }

  static bool validateFileSize(int bytes, int maxMB) => bytes <= maxMB * 1024 * 1024;

  static bool validateFileExtension(String name, Set<String> allowed) {
    final ext = name.split('.').last.toLowerCase();
    return allowed.contains(ext);
  }

  static String? validateMime(Uint8List bytes) {
    if (bytes.length < 12) return 'Fichier trop petit';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return null; // JPEG
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return null; // PNG
    if (bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return null; // WebP
    return 'Format d\'image non supporté';
  }
}

// ============================================================================
// COMPRESSION ASYNCHRONE
// ============================================================================
Future<Uint8List> _compressLogoAsync(Uint8List bytes) async {
  if (kIsWeb) return bytes;
  try {
    return await compute((Uint8List input) async {
      return await FlutterImageCompress.compressWithList(
        input,
        minHeight: 512,
        minWidth: 512,
        quality: 88,
      );
    }, bytes);
  } catch (e) {
    debugPrint('[Community] Compression error: $e');
    return bytes;
  }
}

// ============================================================================
// COMPOSANT PRINCIPAL
// ============================================================================
class CreateCommunityPage extends ConsumerStatefulWidget {
  const CreateCommunityPage({super.key});
  @override
  ConsumerState<CreateCommunityPage> createState() => _CreateCommunityPageState();
}

class _CreateCommunityPageState extends ConsumerState<CreateCommunityPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _nameFocus = FocusNode();
  final _descFocus = FocusNode();

  Uint8List? _selectedLogoBytes;
  String? _selectedLogoExtension;
  bool _isUploading = false;
  bool _isCreating = false;
  String? _error;
  String? _uploadedLogoUrl; // Pour rollback

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _descriptionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      !_isCreating &&
      !_isUploading &&
      _nameController.text.trim().isNotEmpty &&
      _CommunityValidators.validateName(_nameController.text) == null;

  // ─── PICKER LOGO ───
  Future<void> _pickLogo() async {
    if (_isCreating) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      final file = result?.files.first;
      if (file == null || file.bytes == null) return;

      // Validation taille
      if (!_CommunityValidators.validateFileSize(file.bytes!.length, _CommunityValidators.maxLogoSizeMB)) {
        _showError('L\'image ne doit pas dépasser ${_CommunityValidators.maxLogoSizeMB}MB');
        return;
      }

      // Validation extension
      if (!_CommunityValidators.validateFileExtension(file.name, _CommunityValidators.allowedImageExts)) {
        _showError('Format non supporté (JPG, PNG, WebP)');
        return;
      }

      // Validation MIME
      final mimeErr = _CommunityValidators.validateMime(file.bytes!);
      if (mimeErr != null) {
        _showError(mimeErr);
        return;
      }

      setState(() {
        _selectedLogoBytes = file.bytes;
        _selectedLogoExtension = file.extension ?? 'jpg';
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('[Community] Pick logo error: $e');
      _showError('Erreur lors de la sélection');
    }
  }

  // ─── CRÉATION ───
  Future<void> _createCommunity() async {
    // Double-submit guard
    if (_isCreating || _isUploading) return;

    // Validations
    final name = _nameController.text.trim();
    final nameError = _CommunityValidators.validateName(name);
    if (nameError != null) {
      _showError(nameError);
      _nameFocus.requestFocus();
      return;
    }

    final descError = _CommunityValidators.validateDescription(_descriptionController.text);
    if (descError != null) {
      _showError(descError);
      _descFocus.requestFocus();
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    HapticFeedback.mediumImpact();

    try {
      String? bannerUrl;

      // Upload du logo (avec compression)
      if (_selectedLogoBytes != null) {
        setState(() => _isUploading = true);

        Uint8List uploadBytes = _selectedLogoBytes!;
        try {
          uploadBytes = await _compressLogoAsync(_selectedLogoBytes!);
        } catch (e) {
          debugPrint('[Community] Compression failed: $e');
        }

        bannerUrl = await ref
            .read(networkServiceProvider)
            .uploadImageBytes(
              uploadBytes,
              fileExtension: _selectedLogoExtension ?? 'jpg',
              bucket: 'community_banners',
            )
            .timeout(_CommunityValidators.uploadTimeout);

        _uploadedLogoUrl = bannerUrl;
        setState(() => _isUploading = false);
      }

      // Création de la communauté
      await ref
          .read(networkServiceProvider)
          .createCommunity(
            name: _CommunityValidators.sanitize(name, maxLength: _CommunityValidators.maxNameLength),
            description: _CommunityValidators.sanitize(_descriptionController.text, maxLength: _CommunityValidators.maxDescriptionLength),
            bannerUrl: bannerUrl,
          )
          .timeout(_CommunityValidators.createTimeout);

      // Invalidation AVANT pop (scalable)
      ref.invalidate(myCommunitiesProvider);
      ref.invalidate(allCommunitiesProvider);

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('Communauté créée avec succès !'),
            ],
          ),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
        ),
      );

      context.pop(true);
    } catch (e) {
      debugPrint('[Community] Create error: $e');

      // Rollback : supprimer le logo uploadé si la création a échoué
      if (_uploadedLogoUrl != null) {
        await _cleanupUploadedLogo();
      }

      if (!mounted) return;

      setState(() {
        _error = _parseErrorMessage(e);
        _isCreating = false;
        _isUploading = false;
      });
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _cleanupUploadedLogo() async {
    if (_uploadedLogoUrl == null) return;
    try {
      // Extraire le path du bucket
      final uri = Uri.parse(_uploadedLogoUrl!);
      final path = uri.path.replaceFirst('/storage/v1/object/public/', '');
      final bucket = path.split('/').first;
      final filePath = path.replaceFirst('$bucket/', '');
      await ref.read(supabaseClientProvider).storage.from(bucket).remove([filePath]);
      debugPrint('[Community] Logo cleaned up after failure');
    } catch (e) {
      debugPrint('[Community] Cleanup error: $e');
    }
    _uploadedLogoUrl = null;
  }

  String _parseErrorMessage(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('duplicate key') || msg.contains('unique')) {
      return 'Une communauté avec ce nom existe déjà';
    }
    if (msg.contains('timeout')) {
      return 'Délai d\'attente dépassé. Réessayez.';
    }
    if (msg.contains('network')) {
      return 'Erreur réseau. Vérifiez votre connexion.';
    }
    return 'Erreur lors de la création : ${e.toString().split('\n').first}';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
      ),
    );
    HapticFeedback.heavyImpact();
  }

  // ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isCreating && !_isUploading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && (_isCreating || _isUploading)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Création en cours, patientez...')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          backgroundColor: ThixPolicy.card,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Créer une communauté',
            style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
            onPressed: (_isCreating || _isUploading) ? null : () => context.pop(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _canCreate ? _createCommunity : null,
                style: TextButton.styleFrom(
                  backgroundColor: _canCreate ? ThixPolicy.gold : ThixPolicy.surfaceStrong,
                  foregroundColor: _canCreate ? ThixPolicy.inkDeep : ThixPolicy.textDisabled,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                ),
                child: _isCreating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.inkDeep))
                    : Text('Créer', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: _canCreate ? ThixPolicy.inkDeep : ThixPolicy.textDisabled)),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogoPicker(),
              const SizedBox(height: 32),
              _buildNameField(),
              const SizedBox(height: 20),
              _buildDescriptionField(),
              const SizedBox(height: 24),
              _buildPrivacyInfo(),
              if (_error != null) ...[
                const SizedBox(height: 20),
                _buildErrorCard(_error!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoPicker() {
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: (_isCreating || _isUploading) ? null : _pickLogo,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.gold, width: 2.5),
                color: ThixPolicy.card,
                boxShadow: ThixPolicy.shadowSoft(opacity: 0.08),
                image: _selectedLogoBytes != null
                    ? DecorationImage(image: MemoryImage(_selectedLogoBytes!), fit: BoxFit.cover)
                    : null,
              ),
              child: _selectedLogoBytes == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.groups_rounded, size: 40, color: ThixPolicy.gold.withOpacity(0.8)),
                          const SizedBox(height: 4),
                          Text('Logo', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.gold, fontWeight: ThixPolicy.bold)),
                        ],
                      ),
                    )
                  : null,
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: GestureDetector(
              onTap: (_isCreating || _isUploading) ? null : _pickLogo,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_isCreating || _isUploading) ? ThixPolicy.textMuted : ThixPolicy.gold,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: _isUploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    final nameError = _CommunityValidators.validateName(_nameController.text);
    final showHelper = _nameController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Nom', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
            const SizedBox(width: 4),
            Text('*', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          focusNode: _nameFocus,
          enabled: !_isCreating,
          maxLength: _CommunityValidators.maxNameLength,
          textCapitalization: TextCapitalization.words,
          style: ThixPolicy.bodyStyle,
          decoration: InputDecoration(
            hintText: 'Ex: THIX Innovators',
            hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
            prefixIcon: const Icon(Icons.groups_rounded, color: ThixPolicy.primary, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
            ),
            filled: true,
            fillColor: ThixPolicy.card,
            counterText: '',
          ),
        ),
        if (showHelper)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              nameError ?? '✓ Nom valide',
              style: ThixPolicy.captionStyle.copyWith(
                color: nameError != null ? ThixPolicy.danger : ThixPolicy.success,
                fontWeight: ThixPolicy.semiBold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    final currentLen = _descriptionController.text.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Description', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          focusNode: _descFocus,
          maxLines: 5,
          maxLength: _CommunityValidators.maxDescriptionLength,
          enabled: !_isCreating,
          style: ThixPolicy.bodyStyle,
          decoration: InputDecoration(
            hintText: 'Quel est l\'objectif de cette communauté ?',
            hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
            ),
            filled: true,
            fillColor: ThixPolicy.card,
            alignLabelWithHint: true,
            counterStyle: ThixPolicy.microStyle.copyWith(
              color: currentLen > _CommunityValidators.maxDescriptionLength * 0.9 ? ThixPolicy.danger : ThixPolicy.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.tint,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.primary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 20, color: ThixPolicy.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Communauté publique', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.primary)),
                const SizedBox(height: 4),
                Text(
                  'Tout le monde pourra la découvrir et la rejoindre. Vous serez automatiquement ajouté en tant que créateur.',
                  style: ThixPolicy.captionStyle.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThixPolicy.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.danger.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 20, color: ThixPolicy.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _CommunityValidators.sanitize(error),
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.danger, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

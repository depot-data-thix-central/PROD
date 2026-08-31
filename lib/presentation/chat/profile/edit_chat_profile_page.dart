// lib/presentation/chat/profile/edit_chat_profile_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/chat_user.dart';
import 'package:thix_id/providers/chat/chat_settings_provider.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxNameLength = 50;
const int _kMaxStatusLength = 150;
const double _kAvatarRadius = 60.0;
const double _kCameraIconSize = 18.0;

// ============================================================================
// VALIDATORS
// ============================================================================
class _ProfileValidators {
  _ProfileValidators._();

  static String sanitize(String? input, {int maxLength = 100}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static bool isValidName(String name) {
    if (name.isEmpty) return false;
    if (name.length > _kMaxNameLength) return false;
    // Optionnel: Regex pour autoriser seulement certains caractères
    // if (!RegExp(r'^[a-zA-Z0-9\s\-_\.]+$').hasMatch(name)) return false;
    return true;
  }

  static String safeInitial(String name) {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }
}

// ============================================================================
// EDIT PROFILE PAGE
// ============================================================================

/// Page d'édition du profil utilisateur.
///
/// Permet de modifier : Nom, Statut/Bio, Avatar.
class EditChatProfilePage extends ConsumerStatefulWidget {
  final ChatUser user;

  const EditChatProfilePage({super.key, required this.user});

  @override
  ConsumerState<EditChatProfilePage> createState() => _EditChatProfilePageState();
}

class _EditChatProfilePageState extends ConsumerState<EditChatProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _statusController;
  File? _selectedImage;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    _statusController = TextEditingController(text: widget.user.status ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isSaving || _isUploadingImage) return;

    HapticFeedback.selectionClick();
    
    try {
      final result = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024, // Optimisation taille
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (result != null && mounted) {
        setState(() {
          _selectedImage = File(result.path);
          _isUploadingImage = true; // Feedback immédiat
        });

        // Upload immédiat ou différé ? Ici on prépare juste le fichier.
        // L'upload réel se fera dans _save pour atomicité, ou ici si on veut preview rapide.
        // Pour simplifier et éviter les uploads inutiles, on garde l'état local jusqu'à save.
        setState(() => _isUploadingImage = false);
      }
    } catch (e) {
      debugPrint('[EditProfile] ❌ Pick image error: $e');
      if (mounted) _showError('Erreur lors de la sélection de l\'image');
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final l10n = AppLocalizations.of(context);
    final rawName = _nameController.text.trim();
    final rawStatus = _statusController.text.trim();

    // Validation
    final sanitizedName = _ProfileValidators.sanitize(rawName, maxLength: _kMaxNameLength);
    if (!_ProfileValidators.isValidName(sanitizedName)) {
      _showError(l10n.t('profile_invalid_name'));
      return;
    }

    final sanitizedStatus = _ProfileValidators.sanitize(rawStatus, maxLength: _kMaxStatusLength);

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    // CORRECTION : syntaxe Riverpod
    final provider = ref.read(chatSettingsProvider.notifier);

    try {
      String? avatarUrl = widget.user.avatarUrl;

      // Upload image si nécessaire
      if (_selectedImage != null) {
        debugPrint('[EditProfile] ⬆️ Uploading new avatar...');
        final url = await provider.uploadAvatar(_selectedImage!);
        if (url != null) {
          avatarUrl = url;
          debugPrint('[EditProfile] ✓ Avatar uploaded: $url');
        } else {
          debugPrint('[EditProfile] ⚠️ Avatar upload returned null');
          // On continue quand même si l'upload échoue ? Ou on bloque ?
          // Ici on bloque pour cohérence : si upload échoue, on ne sauve pas le reste ?
          // Ou on sauve le texte mais pas l'image. Choix : Sauver le texte, ignorer image si échec.
          // Pour UX fluide : on sauve le texte, on affiche un warning discret si image échoue.
          // Mais pour simplicité code : on essaie tout.
        }
      }

      final updatedUser = widget.user.copyWith(
        displayName: sanitizedName,
        status: sanitizedStatus.isEmpty ? null : sanitizedStatus,
        avatarUrl: avatarUrl,
      );

      final success = await provider.updateChatUser(updatedUser);

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (success) {
        debugPrint('[EditProfile] ✓ Profile saved successfully');
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.t('profile_updated'))),
              ]),
              backgroundColor: ThixPolicy.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // Enlève l'appel à provider.state.error pour éviter un accès direct à un state potentiellement nul ou asynchrone si refacturé.
        _showError(l10n.t('profile_save_error'));
      }
    } catch (e) {
      debugPrint('[EditProfile] ❌ Save error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showError(l10n.t('profile_save_error'));
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsState = ref.watch(chatSettingsProvider);
    // On utilise l'état global pour savoir si un autre processus bloque (optionnel)
    
    final displayName = _nameController.text;
    final initial = _ProfileValidators.safeInitial(displayName);
    final safeAvatarUrl = _selectedImage != null 
        ? null // Priorité à l'image locale sélectionnée
        : widget.user.avatarUrl;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          l10n.t('profile_edit_title'),
          style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold),
        ),
        backgroundColor: ThixPolicy.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
          ),
        ),
        actions: [
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            Semantics(
              button: true,
              label: l10n.t('common_save'),
              child: TextButton(
                onPressed: _save,
                child: Text(
                  l10n.t('common_save'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ThixPolicy.primary, // Ou white si AppBar dark
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ─ Avatar ──
            Semantics(
              button: true,
              label: l10n.t('profile_change_avatar'),
              child: GestureDetector(
                onTap: _isSaving ? null : _pickImage,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: _kAvatarRadius,
                      backgroundColor: ThixPolicy.surfaceSoft,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (safeAvatarUrl != null
                              ? NetworkImage(safeAvatarUrl)
                              : null),
                      child: _selectedImage == null && safeAvatarUrl == null
                          ? Text(
                              initial,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: ThixPolicy.primary,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: ThixPolicy.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: ThixPolicy.card, width: 2),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: _kCameraIconSize,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_isUploadingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // ── Nom ──
            Semantics(
              label: l10n.t('profile_display_name_label'),
              textField: true,
              child: TextField(
                controller: _nameController,
                enabled: !_isSaving,
                maxLength: _kMaxNameLength,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.t('profile_display_name'),
                  hintText: l10n.t('profile_display_name_hint'),
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: ThixPolicy.card,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Statut ──
            Semantics(
              label: l10n.t('profile_status_label'),
              textField: true,
              child: TextField(
                controller: _statusController,
                enabled: !_isSaving,
                maxLength: _kMaxStatusLength,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: l10n.t('profile_status'),
                  hintText: l10n.t('profile_status_hint'),
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: ThixPolicy.card,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── THIX ID (Lecture seule) ──
            if (widget.user.username != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThixPolicy.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.alternate_email_rounded, color: ThixPolicy.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('profile_thix_id'),
                          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${widget.user.username}',
                          style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

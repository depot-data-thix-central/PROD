// lib/presentation/home/dashboard_editors.dart
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/services/profile_photo_service.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/user_service.dart';
import 'package:thix_id/services/platform_file_from_path_stub.dart'
    if (dart.library.io) 'package:thix_id/services/platform_file_from_path_io.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 30);
const Duration _kUploadTimeout = Duration(seconds: 60);
const Duration _kRetryDelay = Duration(milliseconds: 500);
const int _kMaxRetries = 1;
const int _kMaxFileSizeBytes = 10 * 1024 * 1024; // 10MB
const int _kMaxNameLength = 80;
const int _kMaxBioLength = 1000;
const int _kMaxFieldLength = 120;
const int _kMaxDescriptionLength = 500;
const List<String> _kAllowedDocExtensions = ['pdf', 'png', 'jpg', 'jpeg'];
const List<String> _kAllowedImageExtensions = ['png', 'jpg', 'jpeg', 'webp'];

// ============================================================================
// VALIDATORS
// ============================================================================
class _EdValidators {
  _EdValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String sanitizeFileName(String? name) {
    if (name == null) return 'file';
    return name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  static bool isValidFileSize(int bytes) => bytes > 0 && bytes <= _kMaxFileSizeBytes;

  static bool isValidExtension(String? ext, List<String> allowed) {
    if (ext == null) return false;
    return allowed.contains(ext.toLowerCase());
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optionnel
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (!RegExp(r'^\+?[0-9]{6,15}$').hasMatch(cleaned)) {
      return 'Format invalide';
    }
    return null;
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Ressource introuvable.';
    if (msg.contains('too large') || msg.contains('size')) return 'Fichier trop volumineux.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _edRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
  Duration timeout = _kRequestTimeout,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Editors] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[Editors] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Editors] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// MODELS
// ============================================================================
class EvidenceFileRef {
  final String storagePathOrUrl;
  final String? label;

  const EvidenceFileRef({required this.storagePathOrUrl, this.label});

  static EvidenceFileRef? tryParse(dynamic data) {
    if (data is! Map) return null;
    final map = data.cast<String, dynamic>();
    final path = map['storagePathOrUrl'] ?? map['url'] ?? map['path'];
    if (path == null || path.toString().trim().isEmpty) return null;
    return EvidenceFileRef(
      storagePathOrUrl: _EdValidators.sanitize(path.toString(), maxLength: 300),
      label: _EdValidators.sanitize(map['label']?.toString(), maxLength: 100),
    );
  }

  Map<String, dynamic> toJson() => {
        'storagePathOrUrl': storagePathOrUrl,
        'label': label,
      };
}

// ============================================================================
// SHARED UI COMPONENTS
// ============================================================================

InputDecoration _inputDecor(String label, IconData icon, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, color: ThixPolicy.textMuted, size: 20),
    filled: true,
    fillColor: ThixPolicy.surfaceSoft,
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
      borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ThixPolicy.danger, width: 1),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

class _EditorSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _EditorSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: ThixPolicy.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 15,
                    color: ThixPolicy.primaryDeep,
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 24, color: ThixPolicy.border.withOpacity(0.6)),
          child,
        ],
      ),
    );
  }
}

/// Scaffold commun pour tous les editors (header + scroll + footer)
class _EditorSheetScaffold extends StatelessWidget {
  final String title;
  final bool isSaving;
  final VoidCallback onClose;
  final List<Widget> children;
  final Widget footer;

  const _EditorSheetScaffold({
    required this.title,
    required this.isSaving,
    required this.onClose,
    required this.children,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: ThixPolicy.surfaceSoft,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: ThixPolicy.titleStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        fontSize: 18,
                        color: ThixPolicy.primaryDeep,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Fermer',
                    enabled: !isSaving,
                    child: IconButton(
                      onPressed: isSaving ? null : onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: ThixPolicy.card,
              child: footer,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper pour picker des fichiers avec validation stricte
Future<List<PlatformFile>> _pickValidatedFiles({
  required BuildContext context,
  required bool allowMultiple,
  required List<String> allowedExtensions,
  required bool withData,
}) async {
  final l10n = AppLocalizations.of(context);
  try {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: allowMultiple,
      withData: withData,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (res == null || res.files.isEmpty) return [];

    final valid = <PlatformFile>[];
    for (final f in res.files) {
      // Validation taille
      if (!_EdValidators.isValidFileSize(f.size)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_EdValidators.sanitizeFileName(f.name)}: ${l10n.t('editors_file_too_large')} '
                '(${_EdValidators.formatFileSize(f.size)} / ${_EdValidators.formatFileSize(_kMaxFileSizeBytes)})',
              ),
              backgroundColor: ThixPolicy.danger,
            ),
          );
        }
        continue;
      }
      // Validation extension
      if (!_EdValidators.isValidExtension(f.extension, allowedExtensions)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_EdValidators.sanitizeFileName(f.name)}: ${l10n.t('editors_invalid_type')}'),
              backgroundColor: ThixPolicy.danger,
            ),
          );
        }
        continue;
      }
      valid.add(f);
    }
    return valid;
  } catch (e) {
    debugPrint('[Editors] ❌ Pick files error: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_EdValidators.friendlyError(e)),
          backgroundColor: ThixPolicy.danger,
        ),
      );
    }
    return [];
  }
}

/// Confirmation avant suppression
Future<bool> _confirmDelete(BuildContext context, String itemName) async {
  final l10n = AppLocalizations.of(context);
  HapticFeedback.mediumImpact();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ThixPolicy.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: ThixPolicy.danger, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.t('editors_delete_title'),
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: Text(
        "${l10n.t('editors_delete_confirm')} $itemName",
        style: ThixPolicy.bodyStyle,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.t('common_cancel')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: ThixPolicy.danger,
            foregroundColor: Colors.white,
          ),
          child: Text(l10n.t('common_delete')),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

// ============================================================================
// PROFILE EDITOR
// ============================================================================
class ProfileEditorSheet {
  static Future<void> show(
    BuildContext context, {
    required ThixProfile profile,
    required ProfileService profileService,
    required dynamic authUser,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfileEditorBody(
        profile: profile,
        profileService: profileService,
        authUser: authUser,
      ),
    );
  }
}

class _ProfileEditorBody extends StatefulWidget {
  final ThixProfile profile;
  final ProfileService profileService;
  final dynamic authUser;

  const _ProfileEditorBody({
    required this.profile,
    required this.profileService,
    required this.authUser,
  });

  @override
  State<_ProfileEditorBody> createState() => _ProfileEditorBodyState();
}

class _ProfileEditorBodyState extends State<_ProfileEditorBody> {
  final ValueNotifier<bool> _saving = ValueNotifier(false);

  // Contrôleurs (regroupés pour dispose facile)
  final List<TextEditingController> _controllers = [];
  late final TextEditingController _nameC, _competenceC, _bioC, _countryOriginC;
  late final TextEditingController _contactPhoneC, _dobC, _pobC, _nationalityC;
  late final TextEditingController _maritalC, _genderC, _occupationC, _addressC;
  late final TextEditingController _fatherNameC, _motherNameC, _thixChatC;
  late final TextEditingController _originProvinceC, _originTerritoryC, _originSectorC;
  late final TextEditingController _residenceCountryC, _residenceProvinceC, _residenceCityC;
  late final TextEditingController _residenceTerritoryC, _residenceCommuneC;
  late final TextEditingController _residenceQuarterC, _residenceAvenueC, _residenceNumberC;
  late final TextEditingController _emergencyNameC, _emergencyPhoneC, _emergencyRelationC;
  late final TextEditingController _heightC, _weightC, _bloodGroupC, _disabilityDescC;
  late final TextEditingController _nationalIdNumberC, _idDocTypeC, _idIssueDateC, _idExpiryDateC, _idIssuePlaceC;

  bool _hasDisability = false;
  PlatformFile? _idFront, _idBack, _idSelfie;
  String? _idFrontDocId, _idBackDocId, _idSelfieDocId;
  String? _idVerificationStatus;
  PlatformFile? _pickedPhoto;

  final _photos = ProfilePhotoService();
  final _docs = DocumentService();

  TextEditingController _register(String text) {
    final c = TextEditingController(text: text);
    _controllers.add(c);
    return c;
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[Editors] 📝 ProfileEditor opened for ${widget.profile.userId.substring(0, 8)}...');

    final p = widget.profile;
    final a = widget.authUser;

    _nameC = _register((p.fullName ?? p.displayName).trim().isEmpty ? p.displayName : (p.fullName ?? p.displayName));
    _competenceC = _register(p.competence ?? '');
    _bioC = _register(p.bio ?? '');
    _countryOriginC = _register(p.countryOrOrigin ?? '');
    _contactPhoneC = _register(p.contactPhone ?? a.contactPhone ?? '');
    _dobC = _register(p.dateOfBirth ?? a.dateOfBirth ?? '');
    _pobC = _register(p.placeOfBirth ?? a.placeOfBirth ?? '');
    _nationalityC = _register(p.nationality ?? a.nationality ?? '');
    _maritalC = _register(p.maritalStatus ?? a.maritalStatus ?? '');
    _genderC = _register(p.gender ?? a.gender ?? '');
    _occupationC = _register((p.profession ?? p.occupation ?? a.profession ?? a.occupation) ?? '');
    _addressC = _register(p.address ?? a.address ?? '');
    _fatherNameC = _register(p.fatherName ?? a.fatherName ?? '');
    _motherNameC = _register(p.motherName ?? a.motherName ?? '');
    _thixChatC = _register(p.thixChat ?? '');
    _originProvinceC = _register(p.originProvince ?? '');
    _originTerritoryC = _register(p.originTerritory ?? '');
    _originSectorC = _register(p.originSector ?? '');
    _residenceCountryC = _register(p.residenceCountry ?? '');
    _residenceProvinceC = _register(p.residenceProvince ?? '');
    _residenceCityC = _register(p.residenceCity ?? '');
    _residenceTerritoryC = _register(p.residenceTerritory ?? '');
    _residenceCommuneC = _register(p.residenceCommune ?? '');
    _residenceQuarterC = _register(p.residenceQuarter ?? '');
    _residenceAvenueC = _register(p.residenceAvenue ?? '');
    _residenceNumberC = _register(p.residenceNumber ?? '');
    _emergencyNameC = _register(p.emergencyContactName ?? '');
    _emergencyPhoneC = _register(p.emergencyContactPhone ?? '');
    _emergencyRelationC = _register(p.emergencyContactRelation ?? '');
    _heightC = _register(p.height ?? '');
    _weightC = _register(p.weight ?? '');
    _bloodGroupC = _register(p.bloodGroup ?? '');
    _disabilityDescC = _register(p.physicalDisabilityDescription ?? '');
    _nationalIdNumberC = _register(p.nationalIdNumber ?? '');
    _idDocTypeC = _register(p.idDocumentType ?? '');
    _idIssueDateC = _register(p.idDocumentIssueDate ?? '');
    _idExpiryDateC = _register(p.idDocumentExpiryDate ?? '');
    _idIssuePlaceC = _register(p.idDocumentIssuePlace ?? '');

    _hasDisability = p.hasPhysicalDisability ?? false;
    _idFrontDocId = p.idDocumentFrontDocId;
    _idBackDocId = p.idDocumentBackDocId;
    _idSelfieDocId = p.idDocumentSelfieDocId;
    _idVerificationStatus = p.idVerificationStatus;
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _saving.dispose();
    debugPrint('[Editors] 👋 ProfileEditor disposed (${_controllers.length} controllers)');
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    HapticFeedback.selectionClick();
    final locale = Localizations.localeOf(context).toString();
    final DateTime initialDate = DateTime.tryParse(controller.text) ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      locale: Locale(locale),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: ThixPolicy.primary,
              onPrimary: Colors.white,
              onSurface: ThixPolicy.textMain,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required List<String> options,
  }) {
    final currentVal = controller.text.trim();
    final validOptions = List<String>.from(options);
    if (currentVal.isNotEmpty && !validOptions.contains(currentVal)) {
      validOptions.add(currentVal);
    }

    return DropdownButtonFormField<String>(
      value: currentVal.isEmpty ? null : currentVal,
      decoration: _inputDecor(label, icon),
      items: validOptions
          .map((v) => DropdownMenuItem<String>(value: v, child: Text(v, style: const TextStyle(fontSize: 14))))
          .toList(),
      onChanged: (newValue) {
        if (newValue != null) {
          HapticFeedback.selectionClick();
          setState(() => controller.text = newValue);
        }
      },
      dropdownColor: ThixPolicy.card,
    );
  }

  Future<void> _pickIdFile(String kind) async {
    HapticFeedback.selectionClick();
    final files = await _pickValidatedFiles(
      context: context,
      allowMultiple: false,
      allowedExtensions: _kAllowedDocExtensions,
      withData: kIsWeb,
    );
    if (files.isEmpty || !mounted) return;

    setState(() {
      if (kind == 'front') _idFront = files.first;
      if (kind == 'back') _idBack = files.first;
      if (kind == 'selfie') _idSelfie = files.first;
    });
    debugPrint('[Editors] 📎 ID file picked: $kind (${_EdValidators.sanitizeFileName(files.first.name)})');
  }

  Future<void> _uploadIdIfNeeded({required String uid, required String kind}) async {
    final PlatformFile? f = kind == 'front' ? _idFront : (kind == 'back' ? _idBack : _idSelfie);
    if (f == null) return;

    final l10n = AppLocalizations.of(context);
    final docId = 'NATIONAL_ID_${kind.toUpperCase()}';
    final title = l10n.t('editors_national_id_${kind == 'front' ? 'front' : kind == 'back' ? 'back' : 'selfie'}');

    await _edRetry(
      () => _docs.uploadPickedFile(
        uid: uid,
        docId: docId,
        title: title,
        file: f,
        docType: 'national_id',
      ),
      label: 'uploadId[$kind]',
      timeout: _kUploadTimeout,
    );

    if (kind == 'front') _idFrontDocId = docId;
    if (kind == 'back') _idBackDocId = docId;
    if (kind == 'selfie') _idSelfieDocId = docId;
    _idVerificationStatus = 'pending';
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);

    final name = _EdValidators.sanitize(_nameC.text, maxLength: _kMaxNameLength);
    if (name.isEmpty) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('editors_name_required')), backgroundColor: ThixPolicy.warning),
      );
      return;
    }

    // Validation téléphone
    final phoneError = _EdValidators.validatePhone(_contactPhoneC.text);
    if (phoneError != null) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.t('editors_phone')}: $phoneError'), backgroundColor: ThixPolicy.warning),
      );
      return;
    }

    if (_saving.value) {
      debugPrint('[Editors] ⚠️ Save already in progress');
      return;
    }

    _saving.value = true;
    HapticFeedback.mediumImpact();
    debugPrint('[Editors] 💾 Saving profile...');

    try {
      // Upload photo
      String? newPhotoUrl;
      if (_pickedPhoto != null) {
        newPhotoUrl = await _edRetry(
          () => _photos.uploadProfilePhoto(uid: widget.profile.userId, file: _pickedPhoto!),
          label: 'uploadPhoto',
          timeout: _kUploadTimeout,
        );
      }

      // Upload ID documents
      await _uploadIdIfNeeded(uid: widget.profile.userId, kind: 'front');
      await _uploadIdIfNeeded(uid: widget.profile.userId, kind: 'back');
      await _uploadIdIfNeeded(uid: widget.profile.userId, kind: 'selfie');

      // Save profile (tous les champs sanitisés)
      await _edRetry(
        () => widget.profileService.updateProfile(
          userId: widget.profile.userId,
          displayName: name,
          fullName: name,
          competence: _EdValidators.sanitize(_competenceC.text, maxLength: _kMaxDescriptionLength),
          bio: _EdValidators.sanitize(_bioC.text, maxLength: _kMaxBioLength),
          countryOrOrigin: _EdValidators.sanitize(_countryOriginC.text, maxLength: _kMaxFieldLength),
          contactPhone: _EdValidators.sanitize(_contactPhoneC.text, maxLength: 30),
          maritalStatus: _EdValidators.sanitize(_maritalC.text, maxLength: 30),
          gender: _EdValidators.sanitize(_genderC.text, maxLength: 20),
          profession: _EdValidators.sanitize(_occupationC.text, maxLength: _kMaxFieldLength),
          occupation: _EdValidators.sanitize(_occupationC.text, maxLength: _kMaxFieldLength),
          dateOfBirth: _EdValidators.sanitize(_dobC.text, maxLength: 20),
          placeOfBirth: _EdValidators.sanitize(_pobC.text, maxLength: _kMaxFieldLength),
          nationality: _EdValidators.sanitize(_nationalityC.text, maxLength: 40),
          address: _EdValidators.sanitize(_addressC.text, maxLength: 200),
          fatherName: _EdValidators.sanitize(_fatherNameC.text, maxLength: _kMaxNameLength),
          motherName: _EdValidators.sanitize(_motherNameC.text, maxLength: _kMaxNameLength),
          originProvince: _EdValidators.sanitize(_originProvinceC.text, maxLength: 60),
          originTerritory: _EdValidators.sanitize(_originTerritoryC.text, maxLength: 60),
          originSector: _EdValidators.sanitize(_originSectorC.text, maxLength: 60),
          residenceCountry: _EdValidators.sanitize(_residenceCountryC.text, maxLength: 60),
          residenceProvince: _EdValidators.sanitize(_residenceProvinceC.text, maxLength: 60),
          residenceTerritory: _EdValidators.sanitize(_residenceTerritoryC.text, maxLength: 60),
          residenceCity: _EdValidators.sanitize(_residenceCityC.text, maxLength: 60),
          residenceCommune: _EdValidators.sanitize(_residenceCommuneC.text, maxLength: 60),
          residenceQuarter: _EdValidators.sanitize(_residenceQuarterC.text, maxLength: 60),
          residenceAvenue: _EdValidators.sanitize(_residenceAvenueC.text, maxLength: 60),
          residenceNumber: _EdValidators.sanitize(_residenceNumberC.text, maxLength: 20),
          emergencyContactName: _EdValidators.sanitize(_emergencyNameC.text, maxLength: _kMaxNameLength),
          emergencyContactPhone: _EdValidators.sanitize(_emergencyPhoneC.text, maxLength: 30),
          emergencyContactRelation: _EdValidators.sanitize(_emergencyRelationC.text, maxLength: 40),
          height: _EdValidators.sanitize(_heightC.text, maxLength: 10),
          weight: _EdValidators.sanitize(_weightC.text, maxLength: 10),
          bloodGroup: _EdValidators.sanitize(_bloodGroupC.text, maxLength: 5),
          hasPhysicalDisability: _hasDisability,
          physicalDisabilityDescription: _EdValidators.sanitize(_disabilityDescC.text, maxLength: 300),
          nationalIdNumber: _EdValidators.sanitize(_nationalIdNumberC.text, maxLength: 40),
          idDocumentType: _EdValidators.sanitize(_idDocTypeC.text, maxLength: 40),
          idDocumentIssueDate: _EdValidators.sanitize(_idIssueDateC.text, maxLength: 20),
          idDocumentExpiryDate: _EdValidators.sanitize(_idExpiryDateC.text, maxLength: 20),
          idDocumentIssuePlace: _EdValidators.sanitize(_idIssuePlaceC.text, maxLength: _kMaxFieldLength),
          idDocumentFrontDocId: _idFrontDocId,
          idDocumentBackDocId: _idBackDocId,
          idDocumentSelfieDocId: _idSelfieDocId,
          idVerificationStatus: _idVerificationStatus,
          thixChat: _EdValidators.sanitize(_thixChatC.text, maxLength: 50),
          photoUrl: newPhotoUrl,
        ),
        label: 'updateProfile',
      );

      debugPrint('[Editors] ✓ Profile saved');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.t('editors_profile_saved'))),
          ]),
          backgroundColor: ThixPolicy.success,
        ),
      );
      context.pop();
    } catch (e) {
      debugPrint('[Editors] ❌ Save profile error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_EdValidators.friendlyError(e)),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
    } finally {
      if (mounted) _saving.value = false;
    }
  }

  Widget _idSlot({
    required String kind,
    required String? docId,
    required String label,
    required IconData icon,
  }) {
    final pickedFile = kind == 'front' ? _idFront : (kind == 'back' ? _idBack : _idSelfie);

    if (pickedFile != null) {
      return Semantics(
        button: true,
        label: '$label: ${_EdValidators.sanitizeFileName(pickedFile.name)}',
        child: OutlinedButton.icon(
          onPressed: _saving.value ? null : () => _pickIdFile(kind),
          icon: const Icon(Icons.cloud_upload_rounded, color: ThixPolicy.warning),
          label: Text(
            AppLocalizations.of(context).t('editors_ready_send'),
            style: TextStyle(color: ThixPolicy.warning, fontSize: 11),
          ),
          style: OutlinedButton.styleFrom(side: BorderSide(color: ThixPolicy.warning)),
        ),
      );
    }

    if (docId == null || docId.trim().isEmpty) {
      return Semantics(
        button: true,
        label: label,
        child: OutlinedButton.icon(
          onPressed: _saving.value ? null : () => _pickIdFile(kind),
          icon: Icon(icon),
          label: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      );
    }

    return Semantics(
      button: true,
      label: '$label: ${AppLocalizations.of(context).t('editors_uploaded')}',
      child: OutlinedButton.icon(
        onPressed: _saving.value ? null : () => _pickIdFile(kind),
        icon: const Icon(Icons.check_circle_rounded, color: ThixPolicy.success),
        label: Text(
          '$label ✓',
          style: const TextStyle(color: ThixPolicy.success, fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(side: BorderSide(color: ThixPolicy.success)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: _saving,
      builder: (context, isSaving, _) => _EditorSheetScaffold(
        title: l10n.t('editors_profile_title'),
        isSaving: isSaving,
        onClose: () => context.pop(),
        children: [
          // Avatar
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: ThixPolicy.surfaceSoft,
                  backgroundImage: _pickedPhoto != null
                      ? (kIsWeb
                          ? MemoryImage(_pickedPhoto!.bytes!)
                          : FileImage(fileFromPath(_pickedPhoto!.path!) as dynamic)) as ImageProvider
                      : ((widget.profile.photoUrl ?? '').isNotEmpty
                          ? NetworkImage(widget.profile.photoUrl!)
                          : null),
                  child: _pickedPhoto == null && (widget.profile.photoUrl ?? '').isEmpty
                      ? const Icon(Icons.person, size: 40, color: ThixPolicy.textMuted)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Semantics(
                    button: true,
                    label: l10n.t('editors_change_photo'),
                    enabled: !isSaving,
                    child: InkWell(
                      onTap: isSaving
                          ? null
                          : () async {
                              HapticFeedback.selectionClick();
                              final files = await _pickValidatedFiles(
                                context: context,
                                allowMultiple: false,
                                allowedExtensions: _kAllowedImageExtensions,
                                withData: kIsWeb,
                              );
                              if (files.isNotEmpty && mounted) {
                                setState(() => _pickedPhoto = files.first);
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ThixPolicy.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // SECTION 1: Identité civile
          _EditorSectionCard(
            title: l10n.t('editors_civil_identity'),
            icon: Icons.account_circle_rounded,
            child: Column(children: [
              TextField(controller: _nameC, maxLength: _kMaxNameLength, decoration: _inputDecor(l10n.t('editors_full_name'), Icons.badge_rounded)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _selectDate(context, _dobC),
                child: IgnorePointer(
                  child: TextField(controller: _dobC, decoration: _inputDecor(l10n.t('editors_dob'), Icons.cake_rounded, hint: 'YYYY-MM-DD')),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _pobC, maxLength: _kMaxFieldLength, decoration: _inputDecor(l10n.t('editors_pob'), Icons.place_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _nationalityC, maxLength: 40, decoration: _inputDecor(l10n.t('editors_nationality'), Icons.flag_rounded)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _buildDropdown(
                    label: l10n.t('editors_gender'),
                    icon: Icons.wc_rounded,
                    controller: _genderC,
                    options: ['Homme', 'Femme', 'Autre'],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: l10n.t('editors_marital'),
                    icon: Icons.favorite_rounded,
                    controller: _maritalC,
                    options: ['Célibataire', 'Marié(e)', 'Divorcé(e)', 'Veuf/Veuve'],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _addressC, maxLength: 200, decoration: _inputDecor(l10n.t('editors_address'), Icons.home_rounded)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _fatherNameC, maxLength: _kMaxNameLength, decoration: _inputDecor(l10n.t('editors_father'), Icons.man_rounded))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _motherNameC, maxLength: _kMaxNameLength, decoration: _inputDecor(l10n.t('editors_mother'), Icons.woman_rounded))),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _contactPhoneC,
                keyboardType: TextInputType.phone,
                maxLength: 30,
                decoration: _inputDecor(l10n.t('editors_phone'), Icons.call_rounded),
              ),
            ]),
          ),

          // SECTION 2: Origine
          _EditorSectionCard(
            title: l10n.t('editors_origin'),
            icon: Icons.map_rounded,
            child: Column(children: [
              TextField(controller: _originProvinceC, maxLength: 60, decoration: _inputDecor(l10n.t('editors_origin_province'), Icons.location_on_rounded)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _originTerritoryC, maxLength: 60, decoration: _inputDecor(l10n.t('editors_territory'), Icons.terrain_rounded))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _originSectorC, maxLength: 60, decoration: _inputDecor(l10n.t('editors_sector'), Icons.account_tree_rounded))),
              ]),
            ]),
          ),

          // SECTION 3: Résidence
          _EditorSectionCard(
            title: l10n.t('editors_residence'),
            icon: Icons.home_work_rounded,
            child: Column(children: [
              TextField(controller: _residenceCountryC, maxLength: 60, decoration: _inputDecor(l10n.t('editors_country'), Icons.public_rounded)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _residenceProvinceC, maxLength: 60, decoration: _inputDecor(l10n.t('editors_province'), Icons.map_outlined))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _residenceTerritoryC, maxLength: 60, decoration: _inputDecor(l10n.t('editors_territory'), Icons.terrain_outlined))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _residenceCityC, maxLength: 60, decoration: _inputDecor(l10n.t('editors_city'), Icons.location_city_rounded))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _residenceCommuneC, maxLength: 60, decoration: _inputDecor(l10n.t('editors_commune'), Icons.apartment_rounded))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _residenceQuarterC, maxLength: 60, decoration: _inputDecor(l10n.t('editors_quarter'), Icons.streetview_rounded)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _residenceAvenueC, maxLength: 60, decoration: _inputDecor(l10n.t('editors_avenue'), Icons.route_rounded))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _residenceNumberC, maxLength: 20, decoration: _inputDecor(l10n.t('editors_number'), Icons.numbers_rounded))),
              ]),
            ]),
          ),

          // SECTION 4: Bio
          _EditorSectionCard(
            title: l10n.t('editors_biography'),
            icon: Icons.history_edu_rounded,
            child: TextField(
              controller: _bioC,
              maxLines: 5,
              maxLength: _kMaxBioLength,
              decoration: _inputDecor(l10n.t('editors_bio_hint'), Icons.edit_note_rounded),
            ),
          ),

          // SECTION 5: Professionnel
          _EditorSectionCard(
            title: l10n.t('editors_professional'),
            icon: Icons.work_outline_rounded,
            child: Column(children: [
              TextField(controller: _occupationC, maxLength: _kMaxFieldLength, decoration: _inputDecor(l10n.t('editors_occupation'), Icons.work_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _competenceC, maxLines: 3, maxLength: _kMaxDescriptionLength, decoration: _inputDecor(l10n.t('editors_competence'), Icons.psychology_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _thixChatC, maxLength: 50, decoration: _inputDecor('THIX CHAT (@handle)', Icons.alternate_email_rounded)),
            ]),
          ),

          // SECTION 6: Contact urgence
          _EditorSectionCard(
            title: l10n.t('editors_emergency'),
            icon: Icons.contact_emergency_rounded,
            child: Column(children: [
              TextField(controller: _emergencyNameC, maxLength: _kMaxNameLength, decoration: _inputDecor(l10n.t('editors_emergency_name'), Icons.person_search_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _emergencyPhoneC, keyboardType: TextInputType.phone, maxLength: 30, decoration: _inputDecor(l10n.t('editors_emergency_phone'), Icons.phone_callback_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _emergencyRelationC, maxLength: 40, decoration: _inputDecor(l10n.t('editors_emergency_relation'), Icons.family_restroom_rounded)),
            ]),
          ),

          // SECTION 7: Infos physiques
          _EditorSectionCard(
            title: l10n.t('editors_physical'),
            icon: Icons.monitor_weight_rounded,
            child: Column(children: [
              Row(children: [
                Expanded(child: TextField(controller: _heightC, keyboardType: TextInputType.number, maxLength: 10, decoration: _inputDecor(l10n.t('editors_height'), Icons.height_rounded))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _weightC, keyboardType: TextInputType.number, maxLength: 10, decoration: _inputDecor(l10n.t('editors_weight'), Icons.scale_rounded))),
              ]),
              const SizedBox(height: 12),
              _buildDropdown(
                label: l10n.t('editors_blood_group'),
                icon: Icons.bloodtype_rounded,
                controller: _bloodGroupC,
                options: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _hasDisability,
                activeColor: ThixPolicy.primary,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _hasDisability = v);
                },
                title: Text(l10n.t('editors_disability'), style: const TextStyle(fontSize: 14)),
                contentPadding: EdgeInsets.zero,
              ),
              if (_hasDisability)
                TextField(controller: _disabilityDescC, maxLines: 2, maxLength: 300, decoration: _inputDecor(l10n.t('editors_disability_desc'), Icons.accessible_forward_rounded)),
            ]),
          ),

          // SECTION 8: Identité nationale
          _EditorSectionCard(
            title: l10n.t('editors_national_id'),
            icon: Icons.admin_panel_settings_rounded,
            child: Column(children: [
              TextField(controller: _nationalIdNumberC, maxLength: 40, decoration: _inputDecor(l10n.t('editors_id_number'), Icons.numbers_rounded)),
              const SizedBox(height: 12),
              _buildDropdown(
                label: l10n.t('editors_id_type'),
                icon: Icons.credit_card_rounded,
                controller: _idDocTypeC,
                options: ['Carte d\'identité', 'Passeport', 'Permis de conduire', 'Carte d\'électeur', 'Autre'],
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, _idIssueDateC),
                    child: IgnorePointer(child: TextField(controller: _idIssueDateC, decoration: _inputDecor(l10n.t('editors_id_issue'), Icons.event_available_rounded, hint: 'YYYY-MM-DD'))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, _idExpiryDateC),
                    child: IgnorePointer(child: TextField(controller: _idExpiryDateC, decoration: _inputDecor(l10n.t('editors_id_expiry'), Icons.event_busy_rounded, hint: 'YYYY-MM-DD'))),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _idIssuePlaceC, maxLength: _kMaxFieldLength, decoration: _inputDecor(l10n.t('editors_id_place'), Icons.location_city_rounded)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
                ),
                child: Column(children: [
                  Text(l10n.t('editors_id_photos'), style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _idSlot(kind: 'front', docId: _idFrontDocId, label: l10n.t('editors_id_front'), icon: Icons.front_hand_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _idSlot(kind: 'back', docId: _idBackDocId, label: l10n.t('editors_id_back'), icon: Icons.branding_watermark_rounded)),
                  ]),
                  const SizedBox(height: 8),
                  _idSlot(kind: 'selfie', docId: _idSelfieDocId, label: l10n.t('editors_id_selfie'), icon: Icons.face_rounded),
                ]),
              ),
            ]),
          ),
        ],
        footer: SizedBox(
          width: double.infinity,
          height: 50,
          child: Semantics(
            button: true,
            label: l10n.t('common_save'),
            enabled: !isSaving,
            child: FilledButton(
              onPressed: isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(l10n.t('common_save'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MULTI-FILE UPLOAD CARD
// ============================================================================
class _MultiFileUploadCard extends StatelessWidget {
  final List<EvidenceFileRef> existingEvidences;
  final List<PlatformFile> newFiles;
  final bool isSaving;
  final VoidCallback onPickFiles;
  final Function(PlatformFile) onRemoveNew;
  final Function(EvidenceFileRef) onRemoveExisting;

  const _MultiFileUploadCard({
    required this.existingEvidences,
    required this.newFiles,
    required this.isSaving,
    required this.onPickFiles,
    required this.onRemoveNew,
    required this.onRemoveExisting,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.t('editors_evidences'),
                style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 13),
              ),
              Semantics(
                button: true,
                label: l10n.t('common_add'),
                enabled: !isSaving,
                child: OutlinedButton.icon(
                  onPressed: isSaving ? null : onPickFiles,
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: Text(l10n.t('common_add')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ThixPolicy.primary,
                    side: const BorderSide(color: ThixPolicy.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
            ],
          ),
          if (existingEvidences.isEmpty && newFiles.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.t('editors_no_documents'),
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          ...existingEvidences.map((e) => _buildFileRow(
                label: e.label ?? l10n.t('editors_document'),
                isNew: false,
                onRemove: () => onRemoveExisting(e),
              )),
          ...newFiles.map((f) => _buildFileRow(
                label: _EdValidators.sanitizeFileName(f.name),
                isNew: true,
                onRemove: () => onRemoveNew(f),
              )),
        ],
      ),
    );
  }

  Widget _buildFileRow({
    required String label,
    required bool isNew,
    required VoidCallback onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isNew ? Icons.cloud_upload_rounded : Icons.verified_rounded,
            size: 16,
            color: isNew ? ThixPolicy.warning : ThixPolicy.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: ThixPolicy.captionStyle.copyWith(fontSize: 12, fontWeight: ThixPolicy.semiBold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Semantics(
            button: true,
            label: 'Supprimer $label',
            enabled: !isSaving,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: ThixPolicy.danger, size: 16),
              onPressed: isSaving ? null : onRemove,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EDUCATION EDITOR
// ============================================================================
class EducationEditorSheet {
  static Future<void> show(
    BuildContext context, {
    required ThixProfile profile,
    required ProfileService profileService,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EducationEditorBody(profile: profile, profileService: profileService),
    );
  }
}

class _EducationEditorBody extends StatefulWidget {
  final ThixProfile profile;
  final ProfileService profileService;

  const _EducationEditorBody({required this.profile, required this.profileService});

  @override
  State<_EducationEditorBody> createState() => _EducationEditorBodyState();
}

class _EducationEditorBodyState extends State<_EducationEditorBody> {
  final ValueNotifier<bool> _saving = ValueNotifier(false);
  final _institutionC = TextEditingController();
  final _degreeC = TextEditingController();
  final _cityC = TextEditingController();
  final _startDateC = TextEditingController();
  final _endDateC = TextEditingController();
  final _descriptionC = TextEditingController();

  List<EvidenceFileRef> _existingEvidences = [];
  List<PlatformFile> _newFiles = [];
  int? _editingIndex;
  late List<Map<String, dynamic>> _localEducation;

  final _docs = DocumentService();

  @override
  void initState() {
    super.initState();
    _localEducation = List<Map<String, dynamic>>.from(widget.profile.education);
  }

  @override
  void dispose() {
    _institutionC.dispose();
    _degreeC.dispose();
    _cityC.dispose();
    _startDateC.dispose();
    _endDateC.dispose();
    _descriptionC.dispose();
    _saving.dispose();
    super.dispose();
  }

  void _load(int index, Map<String, dynamic> entry) {
    HapticFeedback.selectionClick();
    setState(() {
      _editingIndex = index;
      _institutionC.text = (entry['institution'] ?? entry['school'] ?? '') as String;
      _degreeC.text = (entry['degree'] ?? entry['title'] ?? '') as String;
      _cityC.text = (entry['city'] ?? '') as String;
      _startDateC.text = (entry['startYear'] ?? entry['start_date'] ?? '') as String;
      _endDateC.text = (entry['endYear'] ?? entry['end_date'] ?? '') as String;
      _descriptionC.text = (entry['description'] ?? '') as String;

      final rawEv = (entry['evidence'] as List?) ?? [];
      _existingEvidences = rawEv.map(EvidenceFileRef.tryParse).whereType<EvidenceFileRef>().toList();
      _newFiles = [];
    });
  }

  void _reset() {
    setState(() {
      _editingIndex = null;
      _institutionC.clear();
      _degreeC.clear();
      _cityC.clear();
      _startDateC.clear();
      _endDateC.clear();
      _descriptionC.clear();
      _existingEvidences = [];
      _newFiles = [];
    });
  }

  Future<void> _pickFiles() async {
    final files = await _pickValidatedFiles(
      context: context,
      allowMultiple: true,
      allowedExtensions: _kAllowedDocExtensions,
      withData: kIsWeb,
    );
    if (files.isNotEmpty && mounted) {
      setState(() => _newFiles.addAll(files));
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final institution = _EdValidators.sanitize(_institutionC.text, maxLength: _kMaxNameLength);

    if (institution.isEmpty) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('editors_institution_required')), backgroundColor: ThixPolicy.warning),
      );
      return;
    }

    if (_saving.value) return;
    _saving.value = true;
    HapticFeedback.mediumImpact();

    try {
      final uid = widget.profile.userId;
      final uploadedEvidences = <EvidenceFileRef>[..._existingEvidences];

      for (final f in _newFiles) {
        final safeName = _EdValidators.sanitizeFileName(f.name);
        final docId = 'EDU_${DateTime.now().millisecondsSinceEpoch}_$safeName'.toUpperCase();
        await _edRetry(
          () => _docs.uploadPickedFile(
            uid: uid,
            docId: docId,
            title: '${l10n.t('editors_edu_proof')}: $safeName',
            file: f,
            docType: 'credential_education',
          ),
          label: 'uploadEduEvidence',
          timeout: _kUploadTimeout,
        );
        uploadedEvidences.add(EvidenceFileRef(storagePathOrUrl: 'documents:$docId', label: safeName));
      }

      final patch = {
        'institution': institution,
        'degree': _EdValidators.sanitize(_degreeC.text, maxLength: _kMaxFieldLength),
        'city': _EdValidators.sanitize(_cityC.text, maxLength: 60),
        'startYear': _EdValidators.sanitize(_startDateC.text, maxLength: 20),
        'endYear': _EdValidators.sanitize(_endDateC.text, maxLength: 20),
        'description': _EdValidators.sanitize(_descriptionC.text, maxLength: _kMaxDescriptionLength),
        'evidence': uploadedEvidences.map((e) => e.toJson()).toList(),
      };

      if (_editingIndex != null) {
        _localEducation[_editingIndex!] = patch;
      } else {
        _localEducation.insert(0, patch);
      }

      await _edRetry(
        () => widget.profileService.updateProfile(userId: uid, education: _localEducation),
        label: 'updateEducation',
      );

      debugPrint('[Editors] ✓ Education saved');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('editors_edu_saved')), backgroundColor: ThixPolicy.success),
      );
      _reset();
    } catch (e) {
      debugPrint('[Editors] ❌ Save education error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_EdValidators.friendlyError(e)), backgroundColor: ThixPolicy.danger),
        );
      }
    } finally {
      if (mounted) _saving.value = false;
    }
  }

  Future<void> _delete(int index) async {
    final l10n = AppLocalizations.of(context);
    final itemName = (_localEducation[index]['institution'] ?? l10n.t('editors_education')).toString();

    final confirmed = await _confirmDelete(context, itemName);
    if (!confirmed || !mounted) return;

    _saving.value = true;
    try {
      final copy = List<Map<String, dynamic>>.from(_localEducation)..removeAt(index);
      await _edRetry(
        () => widget.profileService.updateProfile(userId: widget.profile.userId, education: copy),
        label: 'deleteEducation',
      );

      // Seulement après succès DB
      setState(() {
        _localEducation = copy;
        if (_editingIndex == index) _reset();
      });
      debugPrint('[Editors] ✓ Education deleted');
    } catch (e) {
      debugPrint('[Editors] ❌ Delete education error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_EdValidators.friendlyError(e)), backgroundColor: ThixPolicy.danger),
        );
      }
    } finally {
      if (mounted) _saving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: _saving,
      builder: (context, isSaving, _) => _EditorSheetScaffold(
        title: l10n.t('editors_education_title'),
        isSaving: isSaving,
        onClose: () => context.pop(),
        children: [
          if (_localEducation.isNotEmpty) ...[
            Text(l10n.t('editors_your_records'), style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...List.generate(_localEducation.length, (i) {
              final e = _localEducation[i];
              final isEditing = _editingIndex == i;
              final inst = _EdValidators.sanitize(e['institution']?.toString(), maxLength: _kMaxNameLength);
              final degree = _EdValidators.sanitize(e['degree']?.toString(), maxLength: _kMaxFieldLength);
              final start = _EdValidators.sanitize(e['startYear']?.toString(), maxLength: 20);

              return Card(
                elevation: 0,
                color: isEditing ? ThixPolicy.primary.withOpacity(0.05) : ThixPolicy.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isEditing ? ThixPolicy.primary : ThixPolicy.border.withOpacity(0.6)),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    inst.isEmpty ? l10n.t('editors_unknown') : inst,
                    style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '$degree - $start',
                    style: ThixPolicy.captionStyle.copyWith(fontSize: 12),
                  ),
                  trailing: Semantics(
                    button: true,
                    label: l10n.t('common_delete'),
                    enabled: !isSaving,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: ThixPolicy.danger),
                      onPressed: isSaving ? null : () => _delete(i),
                    ),
                  ),
                  onTap: isSaving ? null : () => _load(i, e),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
          _EditorSectionCard(
            title: _editingIndex == null ? l10n.t('editors_add_education') : l10n.t('editors_edit_education'),
            icon: Icons.school_rounded,
            child: Column(children: [
              TextField(controller: _institutionC, maxLength: _kMaxNameLength, decoration: _inputDecor(l10n.t('editors_institution'), Icons.account_balance_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _degreeC, maxLength: _kMaxFieldLength, decoration: _inputDecor(l10n.t('editors_degree'), Icons.workspace_premium_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _cityC, maxLength: 60, decoration: _inputDecor(l10n.t('editors_city'), Icons.location_city_rounded)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _startDateC, maxLength: 20, decoration: _inputDecor(l10n.t('editors_start'), Icons.date_range_rounded))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _endDateC, maxLength: 20, decoration: _inputDecor(l10n.t('editors_end'), Icons.event_available_rounded))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _descriptionC, maxLines: 3, maxLength: _kMaxDescriptionLength, decoration: _inputDecor(l10n.t('editors_description'), Icons.notes_rounded)),
              const SizedBox(height: 16),
              _MultiFileUploadCard(
                isSaving: isSaving,
                existingEvidences: _existingEvidences,
                newFiles: _newFiles,
                onPickFiles: _pickFiles,
                onRemoveNew: (f) => setState(() => _newFiles.remove(f)),
                onRemoveExisting: (e) => setState(() => _existingEvidences.remove(e)),
              ),
            ]),
          ),
        ],
        footer: Row(
          children: [
            if (_editingIndex != null) ...[
              OutlinedButton(
                onPressed: isSaving ? null : _reset,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(l10n.t('common_cancel')),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _editingIndex == null ? l10n.t('editors_add_record') : l10n.t('common_update'),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EXPERIENCE EDITOR
// ============================================================================
class ExperienceEditorSheet {
  static Future<void> show(
    BuildContext context, {
    required ThixProfile profile,
    required ProfileService profileService,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExperienceEditorBody(profile: profile, profileService: profileService),
    );
  }
}

class _ExperienceEditorBody extends StatefulWidget {
  final ThixProfile profile;
  final ProfileService profileService;

  const _ExperienceEditorBody({required this.profile, required this.profileService});

  @override
  State<_ExperienceEditorBody> createState() => _ExperienceEditorBodyState();
}

class _ExperienceEditorBodyState extends State<_ExperienceEditorBody> {
  final ValueNotifier<bool> _saving = ValueNotifier(false);
  final _titleC = TextEditingController();
  final _orgC = TextEditingController();
  final _dateC = TextEditingController();
  final _tasksC = TextEditingController();
  final _sectorC = TextEditingController();
  final _cityC = TextEditingController();

  List<EvidenceFileRef> _existingEvidences = [];
  List<PlatformFile> _newFiles = [];
  int? _editingIndex;
  late List<Map<String, dynamic>> _localExperience;
  final _docs = DocumentService();

  @override
  void initState() {
    super.initState();
    _localExperience = List<Map<String, dynamic>>.from(widget.profile.experience);
  }

  @override
  void dispose() {
    _titleC.dispose();
    _orgC.dispose();
    _dateC.dispose();
    _tasksC.dispose();
    _sectorC.dispose();
    _cityC.dispose();
    _saving.dispose();
    super.dispose();
  }

  void _load(int index, Map<String, dynamic> entry) {
    HapticFeedback.selectionClick();
    setState(() {
      _editingIndex = index;
      _titleC.text = (entry['title'] as String?) ?? '';
      _orgC.text = (entry['org'] as String?) ?? (entry['company'] as String?) ?? '';
      _dateC.text = (entry['date'] as String?) ?? (entry['period'] as String?) ?? '';
      _tasksC.text = (entry['tasks'] as String?) ?? (entry['missions'] as String?) ?? '';
      _sectorC.text = (entry['sector'] as String?) ?? '';
      _cityC.text = (entry['city'] as String?) ?? '';

      final rawEv = (entry['evidence'] as List?) ?? [];
      _existingEvidences = rawEv.map(EvidenceFileRef.tryParse).whereType<EvidenceFileRef>().toList();
      _newFiles = [];
    });
  }

  void _reset() {
    setState(() {
      _editingIndex = null;
      _titleC.clear();
      _orgC.clear();
      _dateC.clear();
      _tasksC.clear();
      _sectorC.clear();
      _cityC.clear();
      _existingEvidences = [];
      _newFiles = [];
    });
  }

  Future<void> _pickFiles() async {
    final files = await _pickValidatedFiles(
      context: context,
      allowMultiple: true,
      allowedExtensions: _kAllowedDocExtensions,
      withData: kIsWeb,
    );
    if (files.isNotEmpty && mounted) {
      setState(() => _newFiles.addAll(files));
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final title = _EdValidators.sanitize(_titleC.text, maxLength: _kMaxFieldLength);

    if (title.isEmpty) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('editors_title_required')), backgroundColor: ThixPolicy.warning),
      );
      return;
    }

    if (_saving.value) return;
    _saving.value = true;
    HapticFeedback.mediumImpact();

    try {
      final uid = widget.profile.userId;
      final uploadedEvidences = <EvidenceFileRef>[..._existingEvidences];

      for (final f in _newFiles) {
        final safeName = _EdValidators.sanitizeFileName(f.name);
        final docId = 'EXP_${DateTime.now().millisecondsSinceEpoch}_$safeName'.toUpperCase();
        await _edRetry(
          () => _docs.uploadPickedFile(
            uid: uid,
            docId: docId,
            title: '${l10n.t('editors_exp_proof')}: $safeName',
            file: f,
            docType: 'credential_experience',
          ),
          label: 'uploadExpEvidence',
          timeout: _kUploadTimeout,
        );
        uploadedEvidences.add(EvidenceFileRef(storagePathOrUrl: 'documents:$docId', label: safeName));
      }

      final tasks = _EdValidators.sanitize(_tasksC.text, maxLength: _kMaxDescriptionLength);
      final patch = {
        'title': title,
        'org': _EdValidators.sanitize(_orgC.text, maxLength: _kMaxNameLength),
        'date': _EdValidators.sanitize(_dateC.text, maxLength: 40),
        'sector': _EdValidators.sanitize(_sectorC.text, maxLength: 60),
        'city': _EdValidators.sanitize(_cityC.text, maxLength: 60),
        if (tasks.isNotEmpty) 'tasks': tasks,
        'evidence': uploadedEvidences.map((e) => e.toJson()).toList(),
      };

      if (_editingIndex != null) {
        _localExperience[_editingIndex!] = patch;
      } else {
        _localExperience.insert(0, patch);
      }

      await _edRetry(
        () => widget.profileService.updateProfile(userId: uid, experience: _localExperience),
        label: 'updateExperience',
      );

      debugPrint('[Editors] ✓ Experience saved');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('editors_exp_saved')), backgroundColor: ThixPolicy.success),
      );
      _reset();
    } catch (e) {
      debugPrint('[Editors] ❌ Save experience error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_EdValidators.friendlyError(e)), backgroundColor: ThixPolicy.danger),
        );
      }
    } finally {
      if (mounted) _saving.value = false;
    }
  }

  Future<void> _delete(int index) async {
    final l10n = AppLocalizations.of(context);
    final itemName = (_localExperience[index]['title'] ?? l10n.t('editors_experience')).toString();

    final confirmed = await _confirmDelete(context, itemName);
    if (!confirmed || !mounted) return;

    _saving.value = true;
    try {
      final copy = List<Map<String, dynamic>>.from(_localExperience)..removeAt(index);
      await _edRetry(
        () => widget.profileService.updateProfile(userId: widget.profile.userId, experience: copy),
        label: 'deleteExperience',
      );

      setState(() {
        _localExperience = copy;
        if (_editingIndex == index) _reset();
      });
      debugPrint('[Editors] ✓ Experience deleted');
    } catch (e) {
      debugPrint('[Editors] ❌ Delete experience error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_EdValidators.friendlyError(e)), backgroundColor: ThixPolicy.danger),
        );
      }
    } finally {
      if (mounted) _saving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: _saving,
      builder: (context, isSaving, _) => _EditorSheetScaffold(
        title: l10n.t('editors_experience_title'),
        isSaving: isSaving,
        onClose: () => context.pop(),
        children: [
          if (_localExperience.isNotEmpty) ...[
            Text(l10n.t('editors_your_records'), style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...List.generate(_localExperience.length, (i) {
              final e = _localExperience[i];
              final isEditing = _editingIndex == i;
              final title = _EdValidators.sanitize(e['title']?.toString(), maxLength: _kMaxFieldLength);
              final org = _EdValidators.sanitize(e['org']?.toString(), maxLength: _kMaxNameLength);
              final date = _EdValidators.sanitize(e['date']?.toString(), maxLength: 40);

              return Card(
                elevation: 0,
                color: isEditing ? ThixPolicy.primary.withOpacity(0.05) : ThixPolicy.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isEditing ? ThixPolicy.primary : ThixPolicy.border.withOpacity(0.6)),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    title.isEmpty ? l10n.t('editors_position') : title,
                    style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14),
                  ),
                  subtitle: Text('$org - $date', style: ThixPolicy.captionStyle.copyWith(fontSize: 12)),
                  trailing: Semantics(
                    button: true,
                    label: l10n.t('common_delete'),
                    enabled: !isSaving,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: ThixPolicy.danger),
                      onPressed: isSaving ? null : () => _delete(i),
                    ),
                  ),
                  onTap: isSaving ? null : () => _load(i, e),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
          _EditorSectionCard(
            title: _editingIndex == null ? l10n.t('editors_add_experience') : l10n.t('editors_edit_experience'),
            icon: Icons.work_history_rounded,
            child: Column(children: [
              TextField(controller: _titleC, maxLength: _kMaxFieldLength, decoration: _inputDecor(l10n.t('editors_position'), Icons.badge_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _orgC, maxLength: _kMaxNameLength, decoration: _inputDecor(l10n.t('editors_company'), Icons.business_rounded)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _sectorC, maxLength: 60, decoration: _inputDecor(l10n.t('editors_sector'), Icons.category_rounded))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _cityC, maxLength: 60, decoration: _inputDecor(l10n.t('editors_city'), Icons.location_city_rounded))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _dateC, maxLength: 40, decoration: _inputDecor(l10n.t('editors_period'), Icons.date_range_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _tasksC, maxLines: 4, maxLength: _kMaxDescriptionLength, decoration: _inputDecor(l10n.t('editors_missions'), Icons.format_list_bulleted_rounded)),
              const SizedBox(height: 16),
              _MultiFileUploadCard(
                isSaving: isSaving,
                existingEvidences: _existingEvidences,
                newFiles: _newFiles,
                onPickFiles: _pickFiles,
                onRemoveNew: (f) => setState(() => _newFiles.remove(f)),
                onRemoveExisting: (e) => setState(() => _existingEvidences.remove(e)),
              ),
            ]),
          ),
        ],
        footer: Row(
          children: [
            if (_editingIndex != null) ...[
              OutlinedButton(
                onPressed: isSaving ? null : _reset,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(l10n.t('common_cancel')),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _editingIndex == null ? l10n.t('editors_add_exp') : l10n.t('common_update'),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CONFIRM FEE SHEET
// ============================================================================
class ConfirmFeeSheet {
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String description,
    required String amountLabel,
  }) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _EdValidators.sanitize(title, maxLength: 100),
                    style: ThixPolicy.titleStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      fontSize: 18,
                      color: ThixPolicy.primaryDeep,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Semantics(
                  button: true,
                  label: l10n.t('common_close'),
                  child: IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.pop(false);
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _EdValidators.sanitize(description, maxLength: 500),
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted, height: 1.4),
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: amountLabel,
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    context.pop(true);
                  },
                  icon: const Icon(Icons.payments_rounded, color: Colors.white),
                  label: Text(
                    amountLabel,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.pop(false);
              },
              child: Text(l10n.t('common_cancel'), style: const TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SKILLS EDITOR
// ============================================================================
class SkillsEditorSheet {
  static Future<void> show(
    BuildContext context, {
    required ThixProfile profile,
    required dynamic profileService,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SkillsEditorBody(profile: profile, profileService: profileService),
    );
  }
}

class _SkillsEditorBody extends StatefulWidget {
  final ThixProfile profile;
  final dynamic profileService;

  const _SkillsEditorBody({required this.profile, required this.profileService});

  @override
  State<_SkillsEditorBody> createState() => _SkillsEditorBodyState();
}

class _SkillsEditorBodyState extends State<_SkillsEditorBody> {
  final ValueNotifier<bool> _saving = ValueNotifier(false);
  final _nameC = TextEditingController();
  final _detailsC = TextEditingController();
  String _level = 'Intermédiaire';
  int? _editingIndex;
  late List<Map<String, dynamic>> _localSkills;

  static const _levels = ['Débutant', 'Intermédiaire', 'Avancé', 'Expert'];

  @override
  void initState() {
    super.initState();
    _localSkills = List<Map<String, dynamic>>.from(widget.profile.skills);
  }

  @override
  void dispose() {
    _nameC.dispose();
    _detailsC.dispose();
    _saving.dispose();
    super.dispose();
  }

  void _load(int index, Map<String, dynamic> entry) {
    HapticFeedback.selectionClick();
    setState(() {
      _editingIndex = index;
      _nameC.text = (entry['name'] as String?) ?? '';
      _level = (entry['level'] as String?) ?? 'Intermédiaire';
      _detailsC.text = (entry['details'] as String?) ?? '';
    });
  }

  void _reset() {
    setState(() {
      _editingIndex = null;
      _nameC.clear();
      _detailsC.clear();
      _level = 'Intermédiaire';
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _EdValidators.sanitize(_nameC.text, maxLength: _kMaxNameLength);

    if (name.isEmpty) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('editors_skill_required')), backgroundColor: ThixPolicy.warning),
      );
      return;
    }

    if (_saving.value) return;
    _saving.value = true;
    HapticFeedback.mediumImpact();

    try {
      final details = _EdValidators.sanitize(_detailsC.text, maxLength: 300);
      final patch = {
        'name': name,
        'level': _level,
        if (details.isNotEmpty) 'details': details,
      };

      if (_editingIndex != null) {
        _localSkills[_editingIndex!] = patch;
      } else {
        _localSkills.insert(0, patch);
      }

      await _edRetry(
        () => widget.profileService.updateProfile(userId: widget.profile.userId, skills: _localSkills),
        label: 'updateSkills',
      );

      debugPrint('[Editors] ✓ Skill saved');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('editors_skill_saved')), backgroundColor: ThixPolicy.success),
      );
      _reset();
    } catch (e) {
      debugPrint('[Editors] ❌ Save skill error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_EdValidators.friendlyError(e)), backgroundColor: ThixPolicy.danger),
        );
      }
    } finally {
      if (mounted) _saving.value = false;
    }
  }

  Future<void> _delete(int index) async {
    final l10n = AppLocalizations.of(context);
    final itemName = (_localSkills[index]['name'] ?? l10n.t('editors_skill')).toString();

    final confirmed = await _confirmDelete(context, itemName);
    if (!confirmed || !mounted) return;

    _saving.value = true;
    try {
      final copy = List<Map<String, dynamic>>.from(_localSkills)..removeAt(index);
      await _edRetry(
        () => widget.profileService.updateProfile(userId: widget.profile.userId, skills: copy),
        label: 'deleteSkill',
      );

      setState(() {
        _localSkills = copy;
        if (_editingIndex == index) _reset();
      });
      debugPrint('[Editors] ✓ Skill deleted');
    } catch (e) {
      debugPrint('[Editors] ❌ Delete skill error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_EdValidators.friendlyError(e)), backgroundColor: ThixPolicy.danger),
        );
      }
    } finally {
      if (mounted) _saving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: _saving,
      builder: (context, isSaving, _) => _EditorSheetScaffold(
        title: l10n.t('editors_skills_title'),
        isSaving: isSaving,
        onClose: () => context.pop(),
        children: [
          if (_localSkills.isNotEmpty) ...[
            Text(l10n.t('editors_your_records'), style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...List.generate(_localSkills.length, (i) {
              final e = _localSkills[i];
              final isEditing = _editingIndex == i;
              final name = _EdValidators.sanitize(e['name']?.toString(), maxLength: _kMaxNameLength);
              final level = _EdValidators.sanitize(e['level']?.toString(), maxLength: 30);

              return Card(
                elevation: 0,
                color: isEditing ? ThixPolicy.primary.withOpacity(0.05) : ThixPolicy.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isEditing ? ThixPolicy.primary : ThixPolicy.border.withOpacity(0.6)),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    name.isEmpty ? '—' : name,
                    style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14),
                  ),
                  subtitle: Text(level.isEmpty ? '—' : level, style: ThixPolicy.captionStyle.copyWith(fontSize: 12)),
                  trailing: Semantics(
                    button: true,
                    label: l10n.t('common_delete'),
                    enabled: !isSaving,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: ThixPolicy.danger),
                      onPressed: isSaving ? null : () => _delete(i),
                    ),
                  ),
                  onTap: isSaving ? null : () => _load(i, e),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
          _EditorSectionCard(
            title: _editingIndex == null ? l10n.t('editors_add_skill') : l10n.t('editors_edit_skill'),
            icon: Icons.psychology_rounded,
            child: Column(children: [
              TextField(controller: _nameC, maxLength: _kMaxNameLength, decoration: _inputDecor(l10n.t('editors_skill'), Icons.psychology_rounded)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _levels.contains(_level) ? _level : 'Intermédiaire',
                items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _level = v ?? 'Intermédiaire');
                },
                decoration: _inputDecor(l10n.t('editors_level'), Icons.signal_cellular_alt_rounded),
              ),
              const SizedBox(height: 12),
              TextField(controller: _detailsC, maxLines: 3, maxLength: 300, decoration: _inputDecor(l10n.t('editors_details'), Icons.notes_rounded)),
            ]),
          ),
        ],
        footer: Row(
          children: [
            if (_editingIndex != null) ...[
              OutlinedButton(
                onPressed: isSaving ? null : _reset,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(l10n.t('common_cancel')),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _editingIndex == null ? l10n.t('common_add') : l10n.t('common_update'),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

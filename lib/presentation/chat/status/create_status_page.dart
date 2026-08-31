// lib/presentation/chat/status/create_status_page.dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';
import 'package:thix_id/presentation/chat/providers/status_provider.dart';
import 'package:thix_id/services/chat/status_service.dart'; // Assurez-vous que ce service existe ou utilisez chatServiceProvider

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxStatusLength = 200;
const int _kMaxImageSizeBytes = 5 * 1024 * 1024; // 5MB
const double _kColorPickerSize = 36.0;
const double _kColorPickerBorderSelected = 3.0;
const double _kColorPickerBorderDefault = 1.0;
const double _kFontSizeStatus = 26.0;
const double _kFontSizeHint = 24.0;
const double _kLoaderSize = 18.0;

// Palette de couleurs "Thix Status" (basée sur ThixPolicy mais avec variantes)
// Utilisation de couleurs prédéfinies pour garantir le contraste avec le texte blanc
final List<Color> _kStatusColors = [
  ThixPolicy.primary,          // Bleu
  const Color(0xFF0F172A),     // Noir profond (Slate 900)
  const Color(0xFF7C3AED),     // Violet
  ThixPolicy.success,          // Vert
  ThixPolicy.danger,           // Rouge
  ThixPolicy.warning,          // Orange
  const Color(0xFF0891B2),     // Cyan
  const Color(0xFFBE185D),     // Rose/Fuchsia
];

// ============================================================================
// VALIDATORS
// ============================================================================
class _StatusValidators {
  _StatusValidators._();

  /// Sanitize le texte du statut (retire HTML, caractères de contrôle)
  static String sanitizeText(String? input, {int maxLength = _kMaxStatusLength}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  /// Valide la taille de l'image
  static bool isValidImageSize(int bytes) {
    return bytes > 0 && bytes <= _kMaxImageSizeBytes;
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('file') || msg.contains('image')) return 'Format ou taille d\'image invalide.';
    return 'Une erreur est survenue lors de la publication.';
  }
}

// ============================================================================
// CREATE STATUS PAGE
// ============================================================================

/// Page de création de statut (texte ou image).
///
/// Permet de :
/// - Saisir un texte sur fond coloré
/// - Choisir une couleur de fond
/// - Ajouter une image avec légende optionnelle
class CreateStatusPage extends ConsumerStatefulWidget {
  const CreateStatusPage({super.key});

  @override
  ConsumerState<CreateStatusPage> createState() => _CreateStatusPageState();
}

class _CreateStatusPageState extends ConsumerState<CreateStatusPage> {
  final _textCtrl = TextEditingController();
  bool _sending = false;
  Color _bg = _kStatusColors.first;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _publishText() async {
    final l10n = AppLocalizations.of(context);
    final rawText = _textCtrl.text.trim();
    
    if (rawText.isEmpty || _sending) return;

    final sanitizedText = _StatusValidators.sanitizeText(rawText);
    if (sanitizedText.isEmpty) {
      _showError(l10n.t('status_empty_error'));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _sending = true);
    debugPrint('[CreateStatus] 📝 Publishing text status...');

    try {
      final hexColor = '#${_bg.value.toRadixString(16).padLeft(8, '0').substring(2)}';
      
      final ok = await ref.read(statusProvider.notifier).createText(
            sanitizedText,
            background: hexColor,
          );
      
      if (!mounted) return;
      setState(() => _sending = false);

      if (ok) {
        debugPrint('[CreateStatus] ✓ Text status published');
        Navigator.pop(context);
      } else {
        _showError(l10n.t('status_publish_error'));
      }
    } catch (e) {
      debugPrint('[CreateStatus] ❌ Publish error: $e');
      if (mounted) {
        setState(() => _sending = false);
        _showError(_StatusValidators.friendlyError(e));
      }
    }
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    if (_sending) return;

    HapticFeedback.selectionClick();
    debugPrint('[CreateStatus] ️ Picking image...');

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      debugPrint('[CreateStatus] ⚠️ No file selected');
      return;
    }

    final f = result.files.first;
    final bytes = f.bytes;

    if (bytes == null) {
      _showError(l10n.t('status_file_read_error'));
      return;
    }

    if (!_StatusValidators.isValidImageSize(bytes.length)) {
      _showError('${l10n.t('status_file_too_big')} (max 5MB)');
      return;
    }

    final sanitizedCaption = _StatusValidators.sanitizeText(
      _textCtrl.text.trim(),
      maxLength: 100, // Caption plus courte
    );

    setState(() => _sending = true);

    try {
      // Note: Utilisez le service approprié selon votre architecture
      // Ici on suppose que statusServiceProvider existe ou on utilise chatServiceProvider
      final svc = ref.read(statusServiceProvider); 
      
      debugPrint('[CreateStatus] ⬆️ Uploading image status...');
      
      final id = await svc.createImageStatus(
        bytes: Uint8List.fromList(bytes),
        extension: f.extension ?? 'jpg',
        caption: sanitizedCaption.isEmpty ? null : sanitizedCaption,
      );

      await ref.read(statusProvider.notifier).refresh();

      if (!mounted) return;

      if (id != null) {
        debugPrint('[CreateStatus] ✓ Image status published: $id');
        Navigator.pop(context);
      } else {
        _showError(l10n.t('status_publish_error'));
      }
    } catch (e) {
      debugPrint('[CreateStatus] ❌ Upload error: $e');
      if (mounted) {
        _showError(_StatusValidators.friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_close'),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
          ),
        ),
        actions: [
          Semantics(
            button: true,
            label: l10n.t('status_publish'),
            enabled: !_sending,
            child: TextButton(
              onPressed: _sending ? null : _publishText,
              child: _sending
                  ? SizedBox(
                      width: _kLoaderSize,
                      height: _kLoaderSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      l10n.t('status_publish'),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Semantics(
                    label: l10n.t('status_text_input'),
                    textField: true,
                    child: TextField(
                      controller: _textCtrl,
                      maxLines: null,
                      maxLength: _kMaxStatusLength,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _kFontSizeStatus,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        hintText: l10n.t('status_hint'),
                        hintStyle: TextStyle(
                          color: Colors.white54,
                          fontSize: _kFontSizeHint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Sélecteur de couleurs
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _kStatusColors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c = _kStatusColors[i];
                  final sel = c == _bg;
                  
                  return Semantics(
                    button: true,
                    label: '${l10n.t('status_color')} ${i + 1}',
                    selected: sel,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _bg = c);
                      },
                      child: Container(
                        width: _kColorPickerSize,
                        height: _kColorPickerSize,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: sel ? _kColorPickerBorderSelected : _kColorPickerBorderDefault,
                          ),
                          boxShadow: sel 
                              ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, spreadRadius: 1)] 
                              : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Actions (Image)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                children: [
                  _ActionChip(
                    l10n: l10n,
                    icon: Icons.image_outlined,
                    label: l10n.t('status_add_image'),
                    onTap: _sending ? null : _pickImage,
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

// ============================================================================
// ACTION CHIP
// ============================================================================

class _ActionChip extends StatelessWidget {
  final AppLocalizations l10n;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.l10n,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      child: Material(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

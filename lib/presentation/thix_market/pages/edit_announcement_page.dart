// lib/presentation/thix_market/pages/edit_announcement_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../widgets/selling/publish_announcement_form.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxTitleLength = 100;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _EditAnnouncementValidators {
  _EditAnnouncementValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }

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

  /// Extrait un message user-friendly d'une exception
  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Annonce introuvable.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = 1,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[EditAnnouncement] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[EditAnnouncement] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[EditAnnouncement] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class EditAnnouncementPage extends StatefulWidget {
  final String announcementId;

  const EditAnnouncementPage({super.key, required this.announcementId});

  @override
  State<EditAnnouncementPage> createState() => _EditAnnouncementPageState();
}

class _EditAnnouncementPageState extends State<EditAnnouncementPage> {
  Map<String, dynamic>? _announcement;
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _errorMessage;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    final isValid = _EditAnnouncementValidators.isValidId(widget.announcementId);
    debugPrint('[EditAnnouncement] ✏️ Page opened for ID ${widget.announcementId.substring(0, widget.announcementId.length > 8 ? 8 : widget.announcementId.length)}${isValid ? "" : " (INVALID)"}');

    if (!isValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleInvalidId());
    } else {
      _loadAnnouncement();
    }
  }

  @override
  void dispose() {
    debugPrint('[EditAnnouncement] 👋 Page disposed');
    super.dispose();
  }

  void _handleInvalidId() {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    _showError('Identifiant d\'annonce invalide');
    Navigator.pop(context);
  }

  Future<void> _loadAnnouncement() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Vous devez être connecté pour modifier une annonce';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await _withRetry(
        () => Supabase.instance.client
            .from('products')
            .select('*, shop:shops(id, name, owner_id)')
            .eq('id', widget.announcementId)
            .maybeSingle(),
        label: 'loadAnnouncement',
      );

      if (response == null) {
        debugPrint('[EditAnnouncement] ⚠️ Announcement not found');
        setState(() {
          _errorMessage = 'Annonce introuvable';
          _isLoading = false;
        });
        return;
      }

      // Vérification ownership
      final shop = response['shop'];
      final shopOwnerId = shop is Map ? shop['owner_id']?.toString() : null;

      if (shopOwnerId != null && shopOwnerId != user.id) {
        debugPrint('[EditAnnouncement] ⚠️ Unauthorized: user=${user.id.substring(0, 8)}, owner=${shopOwnerId.substring(0, 8)}');
        setState(() {
          _errorMessage = 'Vous n\'êtes pas autorisé à modifier cette annonce';
          _isLoading = false;
        });
        return;
      }

      debugPrint('[EditAnnouncement] ✓ Loaded: "${_EditAnnouncementValidators.sanitize(response['title']?.toString(), maxLength: 40)}"');
      setState(() {
        _announcement = response;
        _isLoading = false;
      });
    } catch (e) {
      final friendly = _EditAnnouncementValidators.friendlyError(e);
      debugPrint('[EditAnnouncement] ❌ Load error: $friendly');
      setState(() {
        _errorMessage = friendly;
        _isLoading = false;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    HapticFeedback.mediumImpact();
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: ThixPolicy.warning, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Modifications non sauvegardées',
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment quitter ? Les modifications seront perdues.',
          style: ThixPolicy.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Rester', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _EditAnnouncementValidators.isValidId(widget.announcementId);

    if (!isValid) {
      return Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          backgroundColor: ThixPolicy.card,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const _InvalidIdState(),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          title: Text(
            'Modifier l\'annonce',
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
          backgroundColor: ThixPolicy.card,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const _SkeletonEdit(),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          title: Text(
            'Modifier l\'annonce',
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
          backgroundColor: ThixPolicy.card,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _ErrorState(
          message: _errorMessage!,
          onRetry: _loadAnnouncement,
          onBack: () => Navigator.pop(context),
        ),
      );
    }

    if (_announcement == null) {
      return Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          title: Text(
            'Modifier l\'annonce',
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
          backgroundColor: ThixPolicy.card,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const _NoDataState(),
      );
    }

    final title = _EditAnnouncementValidators.sanitize(
      _announcement!['title']?.toString(),
      maxLength: _kMaxTitleLength,
    );
    final shopId = _announcement!['shop_id']?.toString();

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          title: Text(
            title.isEmpty ? 'Modifier l\'annonce' : title,
            style: ThixPolicy.h3Style.copyWith(
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: ThixPolicy.card,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Semantics(
            button: true,
            label: 'Retour${_hasUnsavedChanges ? " (modifications non sauvegardées)" : ""}',
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
              tooltip: 'Retour',
              onPressed: () async {
                final shouldPop = await _onWillPop();
                if (shouldPop && mounted) Navigator.pop(context);
              },
            ),
          ),
          actions: [
            if (_hasUnsavedChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ThixPolicy.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                      border: Border.all(color: ThixPolicy.warning.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 14, color: ThixPolicy.warning),
                        const SizedBox(width: 4),
                        Text(
                          'Non sauvegardé',
                          style: ThixPolicy.microStyle.copyWith(
                            color: ThixPolicy.warning,
                            fontWeight: ThixPolicy.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Semantics(
              button: true,
              label: 'Supprimer l\'annonce',
              child: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: ThixPolicy.danger),
                tooltip: 'Supprimer',
                onPressed: _isDeleting ? null : () => _showDeleteConfirmation(),
              ),
            ),
          ],
        ),
        body: PublishAnnouncementForm(
          shopId: shopId,
          editAnnouncement: _announcement,
          onDirty: () {
            if (mounted && !_hasUnsavedChanges) {
              setState(() => _hasUnsavedChanges = true);
            }
          },
          onSuccess: (updatedData) {
            if (!mounted) return;
            HapticFeedback.mediumImpact();
            setState(() => _hasUnsavedChanges = false);
            _showSuccess('Annonce mise à jour avec succès');
            debugPrint('[EditAnnouncement] ✅ Updated successfully');
            Navigator.pop(context, updatedData);
          },
        ),
      ),
    );
  }

  // ============================================================
  // DELETE FLOW
  // ============================================================
  Future<void> _showDeleteConfirmation() async {
    HapticFeedback.mediumImpact();
    final title = _EditAnnouncementValidators.sanitize(_announcement?['title']?.toString(), maxLength: 60);

    final confirm = await showDialog<bool>(
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
              child: const Icon(Icons.delete_forever_rounded, color: ThixPolicy.danger, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Supprimer l\'annonce',
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.danger),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Êtes-vous sûr de vouloir supprimer cette annonce ?',
              style: ThixPolicy.bodyStyle,
            ),
            if (title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ThixPolicy.danger.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ThixPolicy.danger.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: ThixPolicy.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"$title"',
                        style: ThixPolicy.labelStyle.copyWith(
                          color: ThixPolicy.danger,
                          fontWeight: ThixPolicy.semiBold,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Cette action est irréversible.',
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _deleteAnnouncement();
    }
  }

  Future<void> _deleteAnnouncement() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);
    HapticFeedback.mediumImpact();

    try {
      await _withRetry(
        () => Supabase.instance.client
            .from('products')
            .delete()
            .eq('id', widget.announcementId),
        label: 'deleteAnnouncement',
      );

      debugPrint('[EditAnnouncement] 🗑️ Deleted successfully');

      if (!mounted) return;
      _showSuccess('Annonce supprimée avec succès');
      Navigator.pop(context, {'deleted': true});
    } catch (e) {
      final friendly = _EditAnnouncementValidators.friendlyError(e);
      debugPrint('[EditAnnouncement] ❌ Delete error: $friendly');
      if (mounted) _showError(friendly);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ============================================================
  // FEEDBACK
  // ============================================================
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _SkeletonEdit extends StatelessWidget {
  const _SkeletonEdit();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            ),
          ),
          const SizedBox(height: 16),
          // Fields
          ...List.generate(
            6,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 64, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text(
              'Erreur de chargement',
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: 'Réessayer',
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onRetry();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Réessayer', style: TextStyle(fontWeight: ThixPolicy.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: 'Retour',
              child: TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onBack();
                },
                child: Text('Retour', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoDataState extends StatelessWidget {
  const _NoDataState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: ThixPolicy.textDisabled),
          const SizedBox(height: 16),
          Text(
            'Aucune donnée disponible',
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
        ],
      ),
    );
  }
}

class _InvalidIdState extends StatelessWidget {
  const _InvalidIdState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link_off_rounded, size: 64, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text(
              'Lien invalide',
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              'Cet identifiant d\'annonce n\'est pas valide.',
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

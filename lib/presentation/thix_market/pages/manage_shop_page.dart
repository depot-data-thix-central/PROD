// lib/presentation/thix_market/pages/manage_shop_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../widgets/shops/manage_shop_widget.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
class _ManageShopValidators {
  _ManageShopValidators._();

  static bool isValidShopId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    // Accepte UUID et formats ID standards (min 8 caractères, hex/uuid)
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class ManageShopPage extends StatefulWidget {
  final String shopId;

  const ManageShopPage({super.key, required this.shopId});

  @override
  State<ManageShopPage> createState() => _ManageShopPageState();
}

class _ManageShopPageState extends State<ManageShopPage> {
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    final isValid = _ManageShopValidators.isValidShopId(widget.shopId);
    debugPrint('[ManageShop] 🏪 Page opened for shop ${widget.shopId.substring(0, widget.shopId.length > 8 ? 8 : widget.shopId.length)}${isValid ? "" : " (INVALID)"}');

    if (!isValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleInvalidShopId());
    }
  }

  @override
  void dispose() {
    debugPrint('[ManageShop] 👋 Page disposed');
    super.dispose();
  }

  void _handleInvalidShopId() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text('Identifiant boutique invalide')),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
    HapticFeedback.lightImpact();
    context.pop();
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
            Text(
              'Modifications non sauvegardées',
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment quitter ? Les modifications en cours seront perdues.',
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

  void _onUpdate(Map<String, dynamic> updatedShop) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _hasUnsavedChanges = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text('Boutique mise à jour avec succès'),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    debugPrint('[ManageShop] ✅ Shop ${widget.shopId.substring(0, 8)}... updated');
  }

  void _onHasUnsavedChanges() {
    if (!mounted) return;
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  void _showHelp() {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (ctx) => const _HelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _ManageShopValidators.isValidShopId(widget.shopId);

    if (!isValid) {
      return Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          backgroundColor: ThixPolicy.card,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
            onPressed: () {
              HapticFeedback.selectionClick();
              context.pop();
            },
          ),
        ),
        body: const _InvalidShopState(),
      );
    }

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          title: Text(
            'Gérer la boutique',
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
          backgroundColor: ThixPolicy.card,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: Semantics(
            button: true,
            label: 'Retour${_hasUnsavedChanges ? " (modifications non sauvegardées)" : ""}',
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
              tooltip: 'Retour',
              onPressed: () async {
                final shouldPop = await _onWillPop();
                if (shouldPop && mounted) {
                  HapticFeedback.selectionClick();
                  context.pop();
                }
              },
            ),
          ),
          actions: [
            Semantics(
              button: true,
              label: 'Aide pour la gestion de boutique',
              child: IconButton(
                icon: const Icon(Icons.help_outline_rounded, color: ThixPolicy.textMain),
                tooltip: 'Aide',
                onPressed: _showHelp,
              ),
            ),
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
          ],
        ),
        body: ManageShopWidget(
          shopId: widget.shopId,
          onUpdate: _onUpdate,
          onDirty: _onHasUnsavedChanges,
        ),
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _HelpDialog extends StatelessWidget {
  const _HelpDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ThixPolicy.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.help_outline_rounded, color: ThixPolicy.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Gérer ma boutique',
                      style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _HelpItem(
                icon: Icons.store_rounded,
                title: 'Informations générales',
                description: 'Modifiez le nom, la description et les coordonnées de votre boutique.',
              ),
              _HelpItem(
                icon: Icons.photo_library_rounded,
                title: 'Logo & images',
                description: 'Changez le logo et la bannière pour renforcer votre identité visuelle.',
              ),
              _HelpItem(
                icon: Icons.inventory_2_rounded,
                title: 'Catalogue produits',
                description: 'Ajoutez, modifiez ou supprimez vos produits depuis la section "Mes annonces".',
              ),
              _HelpItem(
                icon: Icons.analytics_rounded,
                title: 'Statistiques',
                description: 'Consultez les performances de votre boutique dans l\'onglet "Stats".',
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 18, color: ThixPolicy.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Besoin d\'aide supplémentaire ? Contactez notre support via Paramètres → Support & Aide.',
                        style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                  ),
                  child: const Text('Compris', style: TextStyle(fontWeight: ThixPolicy.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _HelpItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: ThixPolicy.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 13, color: ThixPolicy.textMain),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvalidShopState extends StatelessWidget {
  const _InvalidShopState();

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
              'Boutique introuvable',
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              'L\'identifiant de cette boutique est invalide.\nVeuillez réessayer depuis votre liste de boutiques.',
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: 'Retour à mes boutiques',
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.pop();
                },
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                label: const Text('Retour', style: TextStyle(fontWeight: ThixPolicy.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

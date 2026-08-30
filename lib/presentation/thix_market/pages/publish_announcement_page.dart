// lib/presentation/thix_market/vendor/publish_announcement_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/shop_provider.dart';
import '../widgets/selling/publish_announcement_form.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _PublishValidators {
  _PublishValidators._();

  static String sanitize(String? input, {int maxLength = 200}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static bool isValidId(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id);
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class PublishAnnouncementPage extends ConsumerStatefulWidget {
  const PublishAnnouncementPage({super.key});

  @override
  ConsumerState<PublishAnnouncementPage> createState() => _PublishAnnouncementPageState();
}

class _PublishAnnouncementPageState extends ConsumerState<PublishAnnouncementPage> {
  String? _selectedShopId;

  @override
  void initState() {
    super.initState();
    debugPrint('[PublishAnnouncement] 📝 Page opened');
    // Invalider pour forcer le rechargement des boutiques
    Future.microtask(() => ref.invalidate(myShopsProvider));
  }

  @override
  void dispose() {
    debugPrint('[PublishAnnouncement] 👋 Page disposed');
    super.dispose();
  }

  void _onShopChanged(String? shopId) {
    if (shopId != null && _PublishValidators.isValidId(shopId)) {
      HapticFeedback.selectionClick();
      setState(() => _selectedShopId = shopId);
      debugPrint('[PublishAnnouncement] 🏪 Selected shop: ${shopId.substring(0, 8)}...');
    }
  }

  void _onPublishSuccess(dynamic response) {
    HapticFeedback.mediumImpact();
    debugPrint('[PublishAnnouncement] ✅ Published successfully');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Annonce publiée avec succès !',
                style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold),
              ),
            ),
          ],
        ),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(myShopsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          'Publier une annonce',
          style: ThixPolicy.h3Style.copyWith(
            fontWeight: ThixPolicy.bold,
            color: ThixPolicy.textMain,
            fontSize: 18,
          ),
        ),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
          tooltip: 'Retour',
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
      ),
      body: shopsAsync.when(
        loading: () => const _SkeletonLoading(),
        error: (e, _) => _ErrorState(
          message: _PublishValidators.sanitize(e.toString(), maxLength: 200),
          onRetry: () => ref.invalidate(myShopsProvider),
        ),
        data: (shops) {
          if (shops.isEmpty) return _NoShopView();

          // Initialiser _selectedShopId si null
          if (_selectedShopId == null) {
            final firstId = shops.first['id']?.toString();
            if (_PublishValidators.isValidId(firstId)) {
              _selectedShopId = firstId;
              debugPrint('[PublishAnnouncement] 🏪 Auto-selected first shop: ${firstId.substring(0, 8)}...');
            }
          }

          return Column(
            children: [
              if (shops.length > 1)
                _ShopSelector(
                  shops: shops,
                  selectedShopId: _selectedShopId,
                  onChanged: _onShopChanged,
                ),
              if (_selectedShopId != null && _PublishValidators.isValidId(_selectedShopId))
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: PublishAnnouncementForm(
                      shopId: _selectedShopId!,
                      onSuccess: _onPublishSuccess,
                    ),
                  ),
                )
              else
                const _InvalidShopState(),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _ShopSelector extends StatelessWidget {
  final List<Map<String, dynamic>> shops;
  final String? selectedShopId;
  final ValueChanged<String?> onChanged;

  const _ShopSelector({
    required this.shops,
    required this.selectedShopId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Semantics(
        label: 'Sélectionner une boutique',
        child: Container(
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.02),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: selectedShopId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Sélectionner une boutique',
                labelStyle: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: ThixPolicy.primary),
              dropdownColor: ThixPolicy.card,
              items: shops.map<DropdownMenuItem<String>>((shop) {
                final id = shop['id']?.toString() ?? '';
                final name = _PublishValidators.sanitize(shop['name']?.toString() ?? 'Boutique', maxLength: 60);
                final logoUrl = _PublishValidators.sanitizeUrl(shop['logo_url']?.toString());

                return DropdownMenuItem<String>(
                  value: id,
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: ThixPolicy.surfaceSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: logoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedNetworkImage(
                                  imageUrl: logoUrl,
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.store_rounded,
                                    size: 18,
                                    color: ThixPolicy.textMuted,
                                  ),
                                ),
                              )
                            : const Icon(Icons.store_rounded, size: 18, color: ThixPolicy.textMuted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.labelStyle.copyWith(
                            fontWeight: ThixPolicy.semiBold,
                            color: ThixPolicy.textMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoShopView extends StatelessWidget {
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
              child: const Icon(Icons.storefront_rounded, size: 64, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune boutique',
              style: ThixPolicy.h2Style.copyWith(
                fontSize: 20,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Créez une boutique pour pouvoir publier et gérer vos annonces.',
              style: ThixPolicy.bodyStyle.copyWith(
                color: ThixPolicy.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Semantics(
              button: true,
              label: 'Créer ma boutique',
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  debugPrint('[PublishAnnouncement] ➕ Navigate to create shop');
                  context.push('/market/shop/create');
                },
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(
                  'Créer ma boutique',
                  style: ThixPolicy.labelStyle.copyWith(
                    color: Colors.white,
                    fontWeight: ThixPolicy.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: 'Annuler',
              child: TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.pop();
                },
                child: Text(
                  'Annuler',
                  style: ThixPolicy.labelStyle.copyWith(
                    color: ThixPolicy.textSecondary,
                    fontWeight: ThixPolicy.semiBold,
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

class _SkeletonLoading extends StatelessWidget {
  const _SkeletonLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skeleton dropdown
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            ),
          ),
          const SizedBox(height: 24),
          // Skeleton form fields
          ...List.generate(
            5,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
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

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, size: 56, color: ThixPolicy.warning),
            ),
            const SizedBox(height: 20),
            Text(
              'Boutique invalide',
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              'Veuillez sélectionner une boutique valide.',
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

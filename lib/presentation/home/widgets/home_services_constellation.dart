// lib/presentation/home/widgets/home_services_constellation.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// DATA MODELS & ENUMS
// ============================================================================
enum ServiceCategory { all, finance, career, civic }

class _ServiceItem {
  final String key;
  final IconData icon;
  final String title;
  final int? badge;
  final Color color;
  final ServiceCategory category;

  const _ServiceItem({
    required this.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.category,
    this.badge,
  });
}

// ============================================================================
// MAIN WIDGET: DASHBOARD MODULAIRE
// ============================================================================
class HomeServicesConstellation extends StatefulWidget {
  final SectionBadgeCounts counts;
  final void Function(String key) onServiceTap;
  final VoidCallback onHomeTap;
  final VoidCallback onMiniAppsTap;
  final VoidCallback onDocumentsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;
  final String? avatarUrl;

  const HomeServicesConstellation({
    super.key,
    required this.counts,
    required this.onServiceTap,
    required this.onHomeTap,
    required this.onMiniAppsTap,
    required this.onDocumentsTap,
    required this.onProfileTap,
    required this.onScanTap,
    this.avatarUrl,
  });

  @override
  State<HomeServicesConstellation> createState() =>
      _HomeServicesConstellationState();
}

class _HomeServicesConstellationState
    extends State<HomeServicesConstellation> {
  ServiceCategory _selectedCategory = ServiceCategory.all;

  List<_ServiceItem> _getAllServices(AppLocalizations l10n) {
    final c = widget.counts;
    return [
      // Finance & Commerce
      _ServiceItem(
        key: 'thixMoney',
        icon: Icons.account_balance_wallet_rounded,
        title: 'Thix ${l10n.t('svc_money')}',
        badge: c.money,
        color: ThixPolicy.gold,
        category: ServiceCategory.finance,
      ),
      _ServiceItem(
        key: 'thixMarket',
        icon: Icons.storefront_rounded,
        title: 'Thix ${l10n.t('svc_market')}',
        badge: c.market,
        color: ThixPolicy.domainMarket,
        category: ServiceCategory.finance,
      ),
      _ServiceItem(
        key: 'thixMedia',
        icon: Icons.video_collection_rounded,
        title: 'Thix ${l10n.t('svc_media')}',
        badge: c.media,
        color: ThixPolicy.domainNetwork,
        category: ServiceCategory.finance,
      ),
      _ServiceItem(
        key: 'reservation',
        icon: Icons.confirmation_number_rounded,
        title: 'Thix ${l10n.t('svc_booking')}',
        badge: c.reservation,
        color: ThixPolicy.primary,
        category: ServiceCategory.finance,
      ),

      // Carrière & Pro
      _ServiceItem(
        key: 'emplois',
        icon: Icons.work_rounded,
        title: 'Thix ${l10n.t('svc_jobs')}',
        badge: c.jobs,
        color: ThixPolicy.primaryDeep,
        category: ServiceCategory.career,
      ),
      _ServiceItem(
        key: 'formations',
        icon: Icons.school_rounded,
        title: 'Thix ${l10n.t('svc_learning')}',
        badge: c.formations,
        color: ThixPolicy.domainLearning,
        category: ServiceCategory.career,
      ),
      _ServiceItem(
        key: 'opportunites',
        icon: Icons.lightbulb_rounded,
        title: 'Thix ${l10n.t('svc_opps')}',
        badge: c.opportunities,
        color: ThixPolicy.gold,
        category: ServiceCategory.career,
      ),
      _ServiceItem(
        key: 'reseauPro',
        icon: Icons.groups_rounded,
        title: 'Thix ${l10n.t('svc_pro')}',
        badge: c.network,
        color: ThixPolicy.domainNetwork,
        category: ServiceCategory.career,
      ),

      // Citoyen & Santé
      _ServiceItem(
        key: 'monPays',
        icon: Icons.flag_rounded,
        title: 'Thix ${l10n.t('svc_country')}',
        badge: c.monPays,
        color: ThixPolicy.primaryDeep,
        category: ServiceCategory.civic,
      ),
      _ServiceItem(
        key: 'thixInfo',
        icon: Icons.newspaper_rounded,
        title: 'Thix ${l10n.t('svc_news')}',
        badge: c.info,
        color: ThixPolicy.primary,
        category: ServiceCategory.civic,
      ),
      _ServiceItem(
        key: 'evenements',
        icon: Icons.event_rounded,
        title: 'Thix ${l10n.t('svc_event')}',
        badge: c.events,
        color: ThixPolicy.warning,
        category: ServiceCategory.civic,
      ),
      _ServiceItem(
        key: 'thixSante',
        icon: Icons.local_hospital_rounded,
        title: 'Thix ${l10n.t('svc_health')}',
        badge: c.health,
        color: ThixPolicy.danger,
        category: ServiceCategory.civic,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allServices = _getAllServices(l10n);

    final filteredServices = _selectedCategory == ServiceCategory.all
        ? allServices
        : allServices.where((s) => s.category == _selectedCategory).toList();

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(
            color: ThixPolicy.border.withOpacity(0.7),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. HEADER ENTREPRISE (Titre + Profil Hub)
            _buildEnterpriseHeader(),

            const SizedBox(height: 16),

            // 2. BARRE DE CATEGORIES / CHIPS
            _buildCategorySelector(),

            const SizedBox(height: 16),

            // 3. GRILLE DE SERVICES BENTO (4 Colonnes)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: GridView.builder(
                key: ValueKey(_selectedCategory),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredServices.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  final item = filteredServices[index];
                  return _ServiceCardTile(
                    item: item,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onServiceTap(item.key);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header Enterprise avec raccourci Profil
  Widget _buildEnterpriseHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Services & Écosystème',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: ThixPolicy.textMain,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Accès rapide à vos applications',
              style: TextStyle(
                fontSize: 11,
                color: ThixPolicy.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        // Hub Profil Élégant
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onProfileTap();
          },
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ThixPolicy.gold, width: 2),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: ThixPolicy.primaryDeep.withOpacity(0.1),
              child: (widget.avatarUrl != null &&
                      widget.avatarUrl!.trim().isNotEmpty)
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: widget.avatarUrl!.trim(),
                        fit: BoxFit.cover,
                        width: 36,
                        height: 36,
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          color: ThixPolicy.primaryDeep,
                          size: 20,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      color: ThixPolicy.primaryDeep,
                      size: 20,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // Selecteur de catégories
  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip('Tous', ServiceCategory.all),
          const SizedBox(width: 8),
          _buildChip('Finance & Market', ServiceCategory.finance),
          const SizedBox(width: 8),
          _buildChip('Carrière & Pro', ServiceCategory.career),
          const SizedBox(width: 8),
          _buildChip('Citoyen & Santé', ServiceCategory.civic),
        ],
      ),
    );
  }

  Widget _buildChip(String label, ServiceCategory category) {
    final isSelected = _selectedCategory == category;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          HapticFeedback.selectionClick();
          setState(() => _selectedCategory = category);
        }
      },
      selectedColor: ThixPolicy.primaryDeep,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        color: isSelected ? Colors.white : ThixPolicy.textMain,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: isSelected ? ThixPolicy.primaryDeep : Colors.transparent,
        ),
      ),
      showCheckmark: false,
    );
  }
}

// ============================================================================
// CARTE SERVICE BENTO INDIVIDUELLE
// ============================================================================
class _ServiceCardTile extends StatelessWidget {
  final _ServiceItem item;
  final VoidCallback onTap;

  const _ServiceCardTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        splashColor: item.color.withOpacity(0.12),
        highlightColor: item.color.withOpacity(0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA).withOpacity(0.3),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: ThixPolicy.border.withOpacity(0.3),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône avec fond doux + Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: item.color.withOpacity(0.2),
                        width: 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      item.icon,
                      color: item.color,
                      size: 22,
                    ),
                  ),

                  // Notification Badge
                  if (item.badge != null && item.badge! > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: const BoxDecoration(
                          color: ThixPolicy.danger,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            '${item.badge}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 6),

              // Libellé du service
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: ThixPolicy.textMain,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

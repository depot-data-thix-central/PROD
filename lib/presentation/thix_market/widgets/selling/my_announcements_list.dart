// lib/presentation/thix_market/widgets/my_announcements_list.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMaxTitleLength = 100;
const int _kMaxCityLength = 40;

// ============================================================================
// VALIDATORS
// ============================================================================
class _AnnValidators {
  _AnnValidators._();

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

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static int safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    return parsed < 0 || parsed.isNaN || parsed.isInfinite ? fallback : parsed;
  }

  static String formatAmount(double amount, String locale, {bool isUSD = false}) {
    try {
      if (isUSD) {
        return NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2).format(amount);
      }
      return NumberFormat.decimalPattern(locale).format(amount.toInt());
    } catch (_) {
      return isUSD ? amount.toStringAsFixed(2) : amount.toInt().toString();
    }
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Ressource introuvable.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _AnnL10n on BuildContext {
  String annT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _annRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[MyAnnouncements] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[MyAnnouncements] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[MyAnnouncements] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// FILTER CONFIGURATION
// ============================================================================
class _AnnFilter {
  final String key;
  final String labelFr;
  final String labelEn;
  final IconData icon;

  const _AnnFilter({
    required this.key,
    required this.labelFr,
    required this.labelEn,
    required this.icon,
  });

  String label(BuildContext context) => context.annT(labelFr, labelEn);
}

const List<_AnnFilter> _kFilters = [
  _AnnFilter(key: 'all', labelFr: 'Tous', labelEn: 'All', icon: Icons.filter_list_rounded),
  _AnnFilter(key: 'active', labelFr: 'En ligne', labelEn: 'Online', icon: Icons.check_circle_rounded),
  _AnnFilter(key: 'pending', labelFr: 'En attente', labelEn: 'Pending', icon: Icons.hourglass_top_rounded),
  _AnnFilter(key: 'sold_out', labelFr: 'Épuisés', labelEn: 'Sold out', icon: Icons.inventory_2_rounded),
];

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class MyAnnouncementsList extends StatefulWidget {
  final String shopId;
  final Function(Map<String, dynamic>)? onEdit;
  final Function(String)? onDelete;

  const MyAnnouncementsList({
    super.key,
    required this.shopId,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<MyAnnouncementsList> createState() => _MyAnnouncementsListState();
}

class _MyAnnouncementsListState extends State<MyAnnouncementsList> {
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'all';

  // Protection double-tap
  bool _isToggling = false;
  final Set<String> _deletingIds = <String>{};

  @override
  void initState() {
    super.initState();
    debugPrint('[MyAnnouncements] 📋 List opened for shop ${widget.shopId.substring(0, 8)}...');

    if (!_AnnValidators.isValidId(widget.shopId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = context.annT('Identifiant boutique invalide', 'Invalid shop ID');
          });
        }
      });
      return;
    }

    _loadAnnouncements();
  }

  @override
  void dispose() {
    debugPrint('[MyAnnouncements] 👋 List disposed');
    super.dispose();
  }

  // ============================================================
  // LOAD ANNOUNCEMENTS
  // ============================================================
  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      var query = Supabase.instance.client
          .from('products')
          .select()
          .eq('shop_id', widget.shopId);

      if (_filter == 'active') {
        query = query.eq('status', 'active').gt('stock', 0);
      } else if (_filter == 'pending') {
        query = query.eq('status', 'pending');
      } else if (_filter == 'sold_out') {
        query = query.eq('stock', 0);
      }

      final response = await _annRetry(
        () => query.order('created_at', ascending: false),
        label: 'loadAnnouncements[filter=$_filter]',
      );

      if (!mounted) return;

      setState(() {
        _announcements = (response as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _isLoading = false;
      });

      debugPrint('[MyAnnouncements] ✓ Loaded ${_announcements.length} announcements (filter=$_filter)');
    } catch (e) {
      debugPrint('[MyAnnouncements] ❌ Load error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _AnnValidators.friendlyError(e);
      });
    }
  }

  // ============================================================
  // CHANGE FILTER
  // ============================================================
  void _changeFilter(String value) {
    if (_filter == value) return;
    HapticFeedback.selectionClick();
    setState(() => _filter = value);
    debugPrint('[MyAnnouncements] 🔍 Filter changed to $value');
    _loadAnnouncements();
  }

  // ============================================================
  // DELETE ANNOUNCEMENT
  // ============================================================
  Future<bool> _confirmDelete(String shortId) async {
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
                context.annT('Supprimer l\'annonce ?', 'Delete announcement?'),
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          context.annT(
            'Êtes-vous sûr de vouloir supprimer cette annonce (#$shortId) ? Cette action est irréversible.',
            'Are you sure you want to delete this announcement (#$shortId)? This action is irreversible.',
          ),
          style: ThixPolicy.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.annT('Annuler', 'Cancel'),
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(context.annT('Supprimer', 'Delete')),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteAnnouncement(String id) async {
    if (!_AnnValidators.isValidId(id)) {
      _showError(context.annT('Identifiant invalide', 'Invalid ID'));
      return;
    }

    if (_deletingIds.contains(id)) {
      debugPrint('[MyAnnouncements] ⚠️ Delete already in progress for ${_shortId(id)}');
      return;
    }

    final confirmed = await _confirmDelete(_shortId(id));
    if (!confirmed || !mounted) return;

    setState(() => _deletingIds.add(id));
    HapticFeedback.mediumImpact();
    debugPrint('[MyAnnouncements] 🗑️ Deleting ${_shortId(id)}');

    try {
      await _annRetry(
        () => Supabase.instance.client.from('products').delete().eq('id', id),
        label: 'deleteAnnouncement[$id]',
      );

      widget.onDelete?.call(id);
      await _loadAnnouncements();

      if (mounted) {
        _showSuccess(context.annT('Annonce supprimée', 'Announcement deleted'));
      }
      debugPrint('[MyAnnouncements] ✓ Announcement deleted');
    } catch (e) {
      debugPrint('[MyAnnouncements] ❌ Delete error: $e');
      if (mounted) _showError(_AnnValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _deletingIds.remove(id));
    }
  }

  // ============================================================
  // TOGGLE STATUS
  // ============================================================
  Future<void> _toggleStatus(Map<String, dynamic> announcement) async {
    final id = announcement['id']?.toString();
    if (!_AnnValidators.isValidId(id)) {
      _showError(context.annT('Identifiant invalide', 'Invalid ID'));
      return;
    }

    if (_isToggling) {
      debugPrint('[MyAnnouncements] ⚠️ Toggle already in progress');
      return;
    }

    final currentStatus = announcement['status']?.toString() ?? '';
    final newStatus = currentStatus == 'active' ? 'inactive' : 'active';

    setState(() => _isToggling = true);
    HapticFeedback.selectionClick();
    debugPrint('[MyAnnouncements] 🔄 Toggle ${_shortId(id!)} → $newStatus');

    try {
      await _annRetry(
        () => Supabase.instance.client.from('products').update({'status': newStatus}).eq('id', id),
        label: 'toggleStatus[$id]',
      );

      await _loadAnnouncements();
      debugPrint('[MyAnnouncements] ✓ Status toggled to $newStatus');
    } catch (e) {
      debugPrint('[MyAnnouncements] ❌ Toggle error: $e');
      if (mounted) _showError(_AnnValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  // ============================================================
  // EDIT
  // ============================================================
  void _editAnnouncement(Map<String, dynamic> announcement) {
    final id = announcement['id']?.toString();
    if (!_AnnValidators.isValidId(id)) {
      _showError(context.annT('Identifiant invalide', 'Invalid ID'));
      return;
    }
    HapticFeedback.selectionClick();
    debugPrint('[MyAnnouncements] ✏️ Edit ${_shortId(id!)}');
    widget.onEdit?.call(announcement);
  }

  // ============================================================
  // FEEDBACK
  // ============================================================
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
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

  String _shortId(String id) => id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FilterBar(
          filters: _kFilters,
          currentFilter: _filter,
          isLoading: _isLoading,
          onFilterChanged: _changeFilter,
        ),
        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const _SkeletonCards();
    }

    if (_error != null) {
      return _ErrorState(
        message: _error!,
        retryLabel: context.annT('Réessayer', 'Retry'),
        onRetry: _loadAnnouncements,
      );
    }

    if (_announcements.isEmpty) {
      return _EmptyState(
        title: context.annT('Aucune annonce', 'No announcements'),
        subtitle: context.annT('Publiez votre première annonce', 'Publish your first announcement'),
      );
    }

    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: _loadAnnouncements,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _announcements.length,
        itemBuilder: (context, index) {
          final announcement = _announcements[index];
          final id = announcement['id']?.toString() ?? '';
          final isDeleting = _deletingIds.contains(id);

          return _AnnouncementCard(
            announcement: announcement,
            isToggling: _isToggling,
            isDeleting: isDeleting,
            onEdit: () => _editAnnouncement(announcement),
            onToggle: () => _toggleStatus(announcement),
            onDelete: () => _deleteAnnouncement(id),
          );
        },
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _FilterBar extends StatelessWidget {
  final List<_AnnFilter> filters;
  final String currentFilter;
  final bool isLoading;
  final ValueChanged<String> onFilterChanged;

  const _FilterBar({
    required this.filters,
    required this.currentFilter,
    required this.isLoading,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = currentFilter == filter.key;
            return Semantics(
              button: true,
              selected: isSelected,
              label: filter.label(context),
              enabled: !isLoading,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Icon(
                    filter.icon,
                    size: 14,
                    color: isSelected ? ThixPolicy.primary : ThixPolicy.textMuted,
                  ),
                  label: Text(
                    filter.label(context),
                    style: ThixPolicy.captionStyle.copyWith(
                      fontSize: 12.5,
                      fontWeight: isSelected ? ThixPolicy.bold : ThixPolicy.regular,
                      color: isSelected ? ThixPolicy.primary : ThixPolicy.textMuted,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: isLoading ? null : (_) => onFilterChanged(filter.key),
                  backgroundColor: ThixPolicy.surfaceSoft,
                  selectedColor: ThixPolicy.primary.withOpacity(0.1),
                  checkmarkColor: ThixPolicy.primary,
                  side: BorderSide(
                    color: isSelected ? ThixPolicy.primary.withOpacity(0.3) : ThixPolicy.border.withOpacity(0.6),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> announcement;
  final bool isToggling;
  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _AnnouncementCard({
    required this.announcement,
    required this.isToggling,
    required this.isDeleting,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = announcement['status'] == 'active';
    final stock = _AnnValidators.safeInt(announcement['stock']);
    final price = _AnnValidators.safeDouble(announcement['price']);
    final discountPrice = _AnnValidators.safeDouble(announcement['discount_price']);
    final hasDiscount = discountPrice > 0 && price > 0 && discountPrice < price;
    final rawCurrency = announcement['currency']?.toString() ?? 'FC';
    final currency = rawCurrency.toUpperCase().trim();
    final symbol = currency == 'USD' ? '\$' : 'FC';
    final isUSD = currency == 'USD';
    final city = _AnnValidators.sanitize(announcement['city']?.toString(), maxLength: _kMaxCityLength);
    final isFlash = announcement['is_flash_sale'] == true;
    final isFeatured = announcement['is_featured'] == true;
    final views = _AnnValidators.safeInt(announcement['views']);

    final images = announcement['images'];
    String? imageUrl;
    if (images is List && images.isNotEmpty) {
      imageUrl = _AnnValidators.sanitizeUrl(images.first?.toString());
    } else {
      imageUrl = _AnnValidators.sanitizeUrl(announcement['image_url']?.toString());
    }

    final title = _AnnValidators.sanitize(
      announcement['title']?.toString(),
      maxLength: _kMaxTitleLength,
    );
    final displayTitle = title.isEmpty ? context.annT('Sans titre', 'Untitled') : title;

    final finalPrice = hasDiscount ? discountPrice : price;
    final formattedPrice = _AnnValidators.formatAmount(finalPrice, context.localeCode, isUSD: isUSD);
    final formattedOldPrice = hasDiscount
        ? _AnnValidators.formatAmount(price, context.localeCode, isUSD: isUSD)
        : '';

    // Labels i18n
    final onlineLabel = context.annT('En ligne', 'Online');
    final soldOutLabel = context.annT('Épuisé', 'Sold out');
    final inactiveLabel = context.annT('Inactif', 'Inactive');
    final featuredLabel = context.annT('Mis en avant', 'Featured');
    final stockLabel = context.annT('Stock', 'Stock');
    final viewsLabel = context.annT('Vues', 'Views');
    final editLabel = context.annT('Modifier', 'Edit');
    final disableLabel = context.annT('Désactiver', 'Disable');
    final enableLabel = context.annT('Activer', 'Enable');
    final deleteLabel = context.annT('Supprimer', 'Delete');

    final statusLabel = isActive ? onlineLabel : (stock == 0 ? soldOutLabel : inactiveLabel);
    final statusColor = isActive ? ThixPolicy.success : (stock == 0 ? ThixPolicy.danger : ThixPolicy.gold);

    return Semantics(
      label: '$displayTitle, $formattedPrice $symbol, $statusLabel',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDeleting ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.05),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnnouncementImage(imageUrl: imageUrl, isFlash: isFlash),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: ThixPolicy.labelStyle.copyWith(
                            fontWeight: ThixPolicy.bold,
                            fontSize: 13.5,
                            color: ThixPolicy.textMain,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '$formattedPrice $symbol',
                              style: ThixPolicy.labelStyle.copyWith(
                                fontWeight: ThixPolicy.bold,
                                fontSize: 13,
                                color: ThixPolicy.primary,
                              ),
                            ),
                            if (hasDiscount) ...[
                              const SizedBox(width: 6),
                              Text(
                                '$formattedOldPrice $symbol',
                                style: ThixPolicy.captionStyle.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: ThixPolicy.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _Badge(label: statusLabel, color: statusColor),
                            if (isFeatured) _Badge(label: featuredLabel, color: ThixPolicy.gold),
                            _Pill(label: '$stockLabel: $stock'),
                            _Pill(label: '$viewsLabel: $views'),
                            if (city.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 11, color: ThixPolicy.textMuted),
                                  const SizedBox(width: 2),
                                  Text(
                                    city,
                                    style: ThixPolicy.microStyle.copyWith(
                                      fontSize: 11,
                                      color: ThixPolicy.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
              ),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.edit_outlined,
                      label: editLabel,
                      color: ThixPolicy.textMain,
                      isDisabled: isDeleting || isToggling,
                      onPressed: onEdit,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      label: isActive ? disableLabel : enableLabel,
                      color: ThixPolicy.textMain,
                      isDisabled: isDeleting || isToggling,
                      isLoading: isToggling,
                      onPressed: onToggle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: deleteLabel,
                      color: ThixPolicy.danger,
                      isDisabled: isDeleting || isToggling,
                      isLoading: isDeleting,
                      onPressed: onDelete,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementImage extends StatelessWidget {
  final String? imageUrl;
  final bool isFlash;

  const _AnnouncementImage({required this.imageUrl, required this.isFlash});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imageUrl == null || imageUrl.isEmpty
              ? Container(
                  width: 84,
                  height: 84,
                  color: ThixPolicy.surfaceSoft,
                  child: const Icon(Icons.image_outlined, color: ThixPolicy.textMuted, size: 26),
                )
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 84,
                    height: 84,
                    color: ThixPolicy.surfaceSoft,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 84,
                    height: 84,
                    color: ThixPolicy.surfaceSoft,
                    child: const Icon(Icons.image_not_supported_outlined, color: ThixPolicy.textMuted, size: 24),
                  ),
                ),
        ),
        if (isFlash)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: ThixPolicy.gold,
                borderRadius: BorderRadius.circular(6),
                boxShadow: ThixPolicy.shadowSoft(opacity: 0.15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flash_on_rounded, size: 10, color: Colors.white),
                  const SizedBox(width: 2),
                  Text(
                    'FLASH',
                    style: ThixPolicy.microStyle.copyWith(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: ThixPolicy.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: ThixPolicy.microStyle.copyWith(
          fontSize: 10.5,
          fontWeight: ThixPolicy.semiBold,
          color: color,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: ThixPolicy.microStyle.copyWith(
        fontSize: 11,
        color: ThixPolicy.textMuted,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDisabled;
  final bool isLoading;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.isDisabled = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: !isDisabled,
      child: OutlinedButton.icon(
        onPressed: isDisabled ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(icon, size: 17),
        label: Text(
          label,
          style: ThixPolicy.captionStyle.copyWith(
            fontSize: 12.5,
            color: isDisabled ? ThixPolicy.textDisabled : color,
            fontWeight: ThixPolicy.semiBold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: ThixPolicy.textDisabled,
          side: BorderSide(color: isDisabled ? ThixPolicy.border.withOpacity(0.3) : ThixPolicy.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}

// ============================================================================
// SKELETON & EMPTY STATES
// ============================================================================

class _SkeletonCards extends StatelessWidget {
  const _SkeletonCards();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 14, width: double.infinity, color: Colors.grey.shade200),
                      const SizedBox(height: 6),
                      Container(height: 12, width: 140, color: Colors.grey.shade200),
                      const SizedBox(height: 8),
                      Container(height: 12, width: 180, color: Colors.grey.shade200),
                      const SizedBox(height: 6),
                      Container(height: 12, width: 100, color: Colors.grey.shade200),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                3,
                (_) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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

class _ErrorState extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 48, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 16),
            Text(
              context.annT('Erreur de chargement', 'Loading error'),
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: retryLabel,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onRetry();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(retryLabel, style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

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
                color: ThixPolicy.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_outlined, size: 60, color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: ThixPolicy.h3Style.copyWith(
                fontSize: 17,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

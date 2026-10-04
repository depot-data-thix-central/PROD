// lib/presentation/thix_market/pages/supermarket_manage_page.dart
// ============================================================================
// GESTION DES RAYONS — côté vendeur (Production Enterprise v3)
// ----------------------------------------------------------------------------
//  • Sélection d'une allée → ajout / retrait de produits existants
//  • ✅ Création de produit (nom, prix, devise, stock, code-barres,
//       date d'expiration, promo, photos, **unité de mesure**)
//  • ✅ Modification d'un produit
//  • ✅ Badges stock faible / promo / expiration
// ============================================================================

import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_market/models/supermarket_models.dart';
import 'package:thix_id/presentation/thix_market/providers/market_providers.dart'
    show invalidateAllMarketProviders;
import 'package:thix_id/presentation/thix_market/providers/supermarket_providers.dart';
import 'package:thix_id/services/supermarket_service.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kDbTimeout = Duration(seconds: 20);
const Duration _kUploadTimeout = Duration(seconds: 40);
const int _kMaxImages = 5;
const int _kMaxFileSizeMB = 5;
const int _kImageMaxDim = 1280;
const int _kImageQuality = 82;
const int _kMaxNameLength = 120;
const int _kMaxDescLength = 1000;
const int _kLowStock = 5;
const int _kExpirySoonDays = 7;
const String _kBucket = 'product_images';

// ============================================================================
// UNITÉS DE MESURE (référentiel supermarché)
// ============================================================================
const List<Map<String, String>> _kUnits = [
  {'value': 'pcs', 'label': 'Pièce (pcs)'},
  {'value': 'kg', 'label': 'Kilogramme (kg)'},
  {'value': 'g', 'label': 'Gramme (g)'},
  {'value': 'L', 'label': 'Litre (L)'},
  {'value': 'mL', 'label': 'Millilitre (mL)'},
  {'value': 'sachet', 'label': 'Sachet'},
  {'value': 'paquet', 'label': 'Paquet'},
  {'value': 'boîte', 'label': 'Boîte'},
  {'value': 'bouteille', 'label': 'Bouteille'},
  {'value': 'carton', 'label': 'Carton'},
  {'value': 'douzaine', 'label': 'Douzaine'},
  {'value': 'm', 'label': 'Mètre (m)'},
  {'value': 'cm', 'label': 'Centimètre (cm)'},
];

// ============================================================================
// VALIDATEURS
// ============================================================================
class _V {
  _V._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static num? toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }

  static double? parseDouble(String? t) {
    if (t == null) return null;
    final c = t.trim().replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
    if (c.isEmpty) return null;
    final v = double.tryParse(c);
    if (v == null || v.isNaN || v.isInfinite || v < 0 || v > 999999999) return null;
    return v;
  }

  static int? parseInt(String? t) {
    if (t == null) return null;
    final c = t.replaceAll(RegExp(r'[^\d]'), '');
    if (c.isEmpty) return null;
    final v = int.tryParse(c);
    if (v == null || v < 0 || v > 999999) return null;
    return v;
  }

  static bool isValidBarcode(String code) => RegExp(r'^\d{8,14}$').hasMatch(code);

  static String fmtNum(num? v) {
    if (v == null) return '';
    return v == v.toInt() ? v.toInt().toString() : v.toString();
  }

  static String symbol(String? currency) {
    final c = (currency ?? 'CDF').toUpperCase();
    return c == 'USD' ? '\$' : 'FC';
  }

  static String ext(String filename) {
    final i = filename.lastIndexOf('.');
    if (i < 0 || i == filename.length - 1) return '';
    return filename.substring(i + 1).toLowerCase();
  }

  static String contentType(XFile f) {
    const byExt = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'heic': 'image/heic',
    };
    final e = ext(f.name.isNotEmpty ? f.name : f.path);
    if (byExt.containsKey(e)) return byExt[e]!;
    final mime = f.mimeType?.toLowerCase();
    if (mime == 'image/jpg') return 'image/jpeg';
    if (mime != null && mime.startsWith('image/')) return mime;
    return 'image/jpeg';
  }

  static String extFromContentType(String ct) {
    const map = {
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
      'image/heic': 'heic',
    };
    return map[ct] ?? 'jpg';
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('storage') || msg.contains('upload')) return 'Échec upload image. Réessayez.';
    return 'Une erreur est survenue. Réessayez.';
  }

  static String detail(dynamic e) {
    var s = e.toString().replaceAll('\n', ' ').trim();
    if (s.length > 160) s = '${s.substring(0, 160)}…';
    return s;
  }

  /// Retourne le libellé lisible d'une unité (fallback sur la valeur)
  static String unitLabel(String? value) {
    if (value == null || value.isEmpty) return '';
    final match = _kUnits.firstWhere(
      (u) => u['value'] == value,
      orElse: () => const {'value': '', 'label': ''},
    );
    final label = match['label'] ?? '';
    return label.isEmpty ? value : label;
  }
}

class _UploadFailure implements Exception {
  final Object cause;
  _UploadFailure(this.cause);
  @override
  String toString() => cause.toString();
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class SupermarketManagePage extends ConsumerStatefulWidget {
  final String supermarketId;
  const SupermarketManagePage({super.key, required this.supermarketId});

  @override
  ConsumerState<SupermarketManagePage> createState() =>
      _SupermarketManagePageState();
}

class _SupermarketManagePageState extends ConsumerState<SupermarketManagePage> {
  String? _selectedDeptId;
  final _service = SupermarketService();

  // ── Helpers ──
  void _refreshProducts() {
    ref.invalidate(supermarketAllProductsProvider(widget.supermarketId));
    invalidateAllMarketProviders(ref);
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: error ? ThixPolicy.danger : ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _tr(AppLocalizations l10n, String key, String fb) {
    final v = l10n.t(key);
    return (v.isEmpty || v == key) ? fb : v;
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deptsAsync = ref.watch(departmentsProvider(widget.supermarketId));
    final productsAsync =
        ref.watch(supermarketAllProductsProvider(widget.supermarketId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.primaryDeep,
        foregroundColor: Colors.white,
        title: Text(_tr(l10n, 'sm_manage_title', 'Gérer les rayons')),
      ),
      body: deptsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (depts) {
          if (depts.isEmpty) {
            return const Center(child: Text('Aucun rayon'));
          }
          if (_selectedDeptId == null ||
              !depts.any((d) => d.id == _selectedDeptId)) {
            _selectedDeptId = depts.first.id;
          }
          final selectedIdx = depts.indexWhere((d) => d.id == _selectedDeptId);
          final selected = depts[selectedIdx];
          final aisleNumber = selectedIdx + 1;

          final all = productsAsync.valueOrNull ?? [];
          final inDept = all
              .where((p) => p['department_id']?.toString() == selected.id)
              .toList();

          return Column(
            children: [
              // ── Chips des rayons ──
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: depts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = depts[i];
                    final sel = d.id == _selectedDeptId;
                    final count = all
                        .where((p) => p['department_id']?.toString() == d.id)
                        .length;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedDeptId = d.id);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? d.color : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: sel ? d.color : ThixPolicy.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(d.icon,
                                size: 15, color: sel ? Colors.white : d.color),
                            const SizedBox(width: 6),
                            Text(
                              '${i + 1}. ${d.name}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: sel ? Colors.white : ThixPolicy.textMain,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: sel
                                    ? Colors.white.withOpacity(0.25)
                                    : d.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('$count',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: sel ? Colors.white : d.color)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),

              // ── Produits du rayon sélectionné ──
              Expanded(
                child: productsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (_) {
                    if (inDept.isEmpty) {
                      return _buildEmpty(l10n, selected, all, aisleNumber, depts);
                    }
                    return RefreshIndicator(
                      color: ThixPolicy.primary,
                      onRefresh: () async {
                        _refreshProducts();
                        await ref.read(supermarketAllProductsProvider(
                                widget.supermarketId)
                            .future);
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: inDept.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final p = inDept[i];
                          return _ProductRow(
                            product: p,
                            accent: selected.color,
                            onEdit: () => _openProductForm(
                              dept: selected,
                              aisleNumber: aisleNumber,
                              product: p,
                            ),
                            onRemove: () => _confirmRemove(p),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ThixPolicy.primary,
        foregroundColor: Colors.white,
        onPressed: _onFabPressed,
        icon: const Icon(Icons.add_rounded),
        label: Text(_tr(l10n, 'sm_add', 'Ajouter')),
      ),
    );
  }

  // ── État vide d'un rayon ──
  Widget _buildEmpty(
    AppLocalizations l10n,
    SupermarketDepartment selected,
    List<Map<String, dynamic>> all,
    int aisleNumber,
    List<SupermarketDepartment> depts,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 52, color: selected.color.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              _tr(l10n, 'sm_dept_empty_manage',
                  'Rayon vide — ajoutez des produits'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: ThixPolicy.textSecondary,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _openProductForm(
                    dept: selected, aisleNumber: aisleNumber),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                label: const Text('Créer un produit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected.color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (all.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openPicker(selected, all, aisleNumber, depts),
                  icon: const Icon(Icons.playlist_add_rounded, size: 20),
                  label: Text(_tr(l10n, 'sm_add_products',
                      'Ajouter des produits existants')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: selected.color,
                    side: BorderSide(color: selected.color),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── FAB : menu créer / ajouter existant ──
  void _onFabPressed() {
    final depts =
        ref.read(departmentsProvider(widget.supermarketId)).valueOrNull;
    final all = ref
            .read(supermarketAllProductsProvider(widget.supermarketId))
            .valueOrNull ??
        [];
    if (depts == null || depts.isEmpty) return;
    var idx = depts.indexWhere((d) => d.id == _selectedDeptId);
    if (idx < 0) idx = 0;
    final dept = depts[idx];
    final aisle = idx + 1;

    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: ThixPolicy.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              Text('${dept.name} — Allée $aisle',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: ThixPolicy.textMain)),
              const SizedBox(height: 8),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: dept.color.withOpacity(0.12),
                  child: Icon(Icons.add_circle_outline_rounded,
                      color: dept.color),
                ),
                title: const Text('Créer un nouveau produit',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Nom, prix, photos, stock, expiration…'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openProductForm(dept: dept, aisleNumber: aisle);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: ThixPolicy.primary.withOpacity(0.12),
                  child: const Icon(Icons.playlist_add_rounded,
                      color: ThixPolicy.primary),
                ),
                title: const Text('Ajouter un produit existant',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Choisir parmi vos produits'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openPicker(dept, all, aisle, depts);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Formulaire création / modification ──
  Future<void> _openProductForm({
    required SupermarketDepartment dept,
    required int aisleNumber,
    Map<String, dynamic>? product,
  }) async {
    HapticFeedback.selectionClick();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ProductFormSheet(
        supermarketId: widget.supermarketId,
        department: dept,
        aisleNumber: aisleNumber,
        service: _service,
        product: product,
      ),
    );

    if (saved == true && mounted) {
      _refreshProducts();
      _toast(product == null ? 'Produit créé' : 'Produit mis à jour');
    }
  }

  // ── Retirer un produit du rayon ──
  Future<void> _confirmRemove(Map<String, dynamic> p) async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Retirer du rayon ?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
            '« ${_V.sanitize(p['title']?.toString(), maxLength: 60)} » ne sera plus affiché dans ce rayon. Le produit n\'est pas supprimé.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.danger,
                foregroundColor: Colors.white),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _service.unassignProduct(p['id'].toString());
      _refreshProducts();
      _toast('Produit retiré du rayon');
    } catch (e) {
      debugPrint('[SupermarketManage] ❌ unassign error: $e');
      _toast('${_V.friendlyError(e)}\nDétail : ${_V.detail(e)}', error: true);
    }
  }

  // ── Sélecteur de produits existants (bottom sheet) ──
  void _openPicker(
    SupermarketDepartment dept,
    List<Map<String, dynamic>> all,
    int aisleNumber,
    List<SupermarketDepartment> depts,
  ) {
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final filtered = query.isEmpty
              ? all
              : all
                  .where((p) => (p['title']?.toString() ?? '')
                      .toLowerCase()
                      .contains(query.toLowerCase()))
                  .toList();

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.8,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: ThixPolicy.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${dept.name} — Allée $aisleNumber',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: ThixPolicy.textMain),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openProductForm(dept: dept, aisleNumber: aisleNumber);
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          size: 20),
                      label: const Text('Créer un nouveau produit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: dept.color,
                        side: BorderSide(color: dept.color),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle:
                            const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (v) => setSheet(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un produit...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: ThixPolicy.surfaceSoft,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('Aucun produit trouvé',
                                style: TextStyle(
                                    color: ThixPolicy.textSecondary,
                                    fontWeight: FontWeight.w600)),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = filtered[i];
                              final pid = p['id'].toString();
                              final currentDept =
                                  p['department_id']?.toString();
                              final inThisDept = currentDept == dept.id;
                              final inOtherDept = currentDept != null &&
                                  currentDept.isNotEmpty &&
                                  currentDept != dept.id;
                              final otherIdx = inOtherDept
                                  ? depts.indexWhere((d) => d.id == currentDept)
                                  : -1;

                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: p['image_url'] != null
                                      ? CachedNetworkImage(
                                          imageUrl: p['image_url'].toString(),
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => _ph(),
                                        )
                                      : _ph(),
                                ),
                                title: Text(
                                  p['title']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                                subtitle: inOtherDept && otherIdx >= 0
                                    ? Text(
                                        'Déjà dans Allée ${otherIdx + 1}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: ThixPolicy.warning),
                                      )
                                    : null,
                                trailing: inThisDept
                                    ? const Icon(Icons.check_circle_rounded,
                                        color: ThixPolicy.success, size: 22)
                                    : IconButton(
                                        icon: const Icon(
                                            Icons.add_circle_outline_rounded,
                                            color: ThixPolicy.primary,
                                            size: 24),
                                        onPressed: () async {
                                          HapticFeedback.mediumImpact();
                                          try {
                                            await _service
                                                .assignProductToDepartment(
                                                    pid, dept.id, aisleNumber);
                                            _refreshProducts();
                                            if (ctx.mounted) Navigator.pop(ctx);
                                          } catch (e) {
                                            debugPrint(
                                                '[SupermarketManage] ❌ assign error: $e');
                                            _toast(
                                                '${_V.friendlyError(e)}\nDétail : ${_V.detail(e)}',
                                                error: true);
                                          }
                                        },
                                      ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ph() => Container(
        width: 44,
        height: 44,
        color: ThixPolicy.surfaceSoft,
        child: const Icon(Icons.image_outlined,
            color: ThixPolicy.textMuted, size: 18),
      );
}

// ============================================================================
// LIGNE PRODUIT
// ============================================================================
class _ProductRow extends StatelessWidget {
  final Map<String, dynamic> product;
  final Color accent;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ProductRow({
    required this.product,
    required this.accent,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final title = _V.sanitize(product['title']?.toString(), maxLength: 80);
    final price = _V.toNum(product['price'])?.toDouble() ?? 0;
    final dp = _V.toNum(product['discount_price'])?.toDouble();
    final hasPromo = dp != null && dp > 0 && dp < price;
    final symbol = _V.symbol(product['currency']?.toString());
    final stock = _V.toNum(product['stock'])?.toInt();
    final barcode = _V.sanitize(product['barcode']?.toString(), maxLength: 20);
    final imageUrl = product['image_url']?.toString();
    // ── Unité de mesure (nouveau) ──
    final unitRaw = product['unit']?.toString() ?? product['unit_of_measure']?.toString();
    final unitLabel = _V.unitLabel(unitRaw);

    final expiry = DateTime.tryParse(product['expiry_date']?.toString() ?? '');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: ThixPolicy.surfaceSoft,
                        child: const Icon(Icons.image_outlined,
                            color: ThixPolicy.textMuted, size: 20)),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: ThixPolicy.surfaceSoft,
                    child: const Icon(Icons.image_outlined,
                        color: ThixPolicy.textMuted, size: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? '—' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      hasPromo
                          ? '${dp.toInt()} $symbol'
                          : '${price.toInt()} $symbol',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: hasPromo ? ThixPolicy.danger : accent),
                    ),
                    // ── Affichage unité après le prix ──
                    if (unitLabel.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '/ $unitLabel',
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: ThixPolicy.textSecondary),
                      ),
                    ],
                    if (hasPromo) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${price.toInt()}',
                        style: const TextStyle(
                            fontSize: 10.5,
                            decoration: TextDecoration.lineThrough,
                            color: ThixPolicy.textMuted),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (stock != null) _stockChip(stock),
                    if (hasPromo)
                      _chip('PROMO', ThixPolicy.danger, Icons.local_offer_rounded),
                    if (expiry != null) _expiryChip(expiry),
                  ],
                ),
                if (barcode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.qr_code_2_rounded,
                          size: 12, color: ThixPolicy.textMuted),
                      const SizedBox(width: 3),
                      Text(barcode,
                          style: const TextStyle(
                              fontSize: 10.5, color: ThixPolicy.textMuted)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            icon: const Icon(Icons.more_vert_rounded,
                color: ThixPolicy.textSecondary, size: 22),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'remove') onRemove();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Modifier'),
                ]),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Row(children: [
                  Icon(Icons.remove_circle_outline_rounded,
                      size: 18, color: ThixPolicy.danger),
                  SizedBox(width: 10),
                  Text('Retirer du rayon',
                      style: TextStyle(color: ThixPolicy.danger)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _stockChip(int stock) {
    if (stock <= 0) {
      return _chip('Rupture', ThixPolicy.danger, Icons.remove_shopping_cart_rounded);
    }
    if (stock <= _kLowStock) {
      return _chip('Stock : $stock', ThixPolicy.warning, Icons.warning_amber_rounded);
    }
    return _chip('Stock : $stock', ThixPolicy.success, Icons.inventory_2_outlined);
  }

  Widget _expiryChip(DateTime expiry) {
    final today = DateTime.now();
    final days = DateTime(expiry.year, expiry.month, expiry.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (days < 0) {
      return _chip('Expiré', ThixPolicy.danger, Icons.event_busy_rounded);
    }
    if (days <= _kExpirySoonDays) {
      return _chip(
          days == 0 ? 'Expire aujourd\'hui' : 'Expire dans $days j',
          ThixPolicy.warning,
          Icons.schedule_rounded);
    }
    return _chip('Exp. ${DateFormat('dd/MM/yyyy').format(expiry)}',
        ThixPolicy.textSecondary, Icons.event_available_rounded);
  }
}

// ============================================================================
// FORMULAIRE PRODUIT (création / modification)
// ============================================================================
class _ProductFormSheet extends StatefulWidget {
  final String supermarketId;
  final SupermarketDepartment department;
  final int aisleNumber;
  final SupermarketService service;
  final Map<String, dynamic>? product;

  const _ProductFormSheet({
    required this.supermarketId,
    required this.department,
    required this.aisleNumber,
    required this.service,
    this.product,
  });

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _promoPrice = TextEditingController();
  final _stock = TextEditingController();
  final _barcode = TextEditingController();
  final _description = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _currency = 'CDF';
  // ── NOUVEAU : unité de mesure ──
  String _unit = 'pcs';
  bool _hasPromo = false;
  bool _perishable = false;
  DateTime? _expiry;

  List<String> _existingUrls = [];
  final List<XFile> _newImages = [];
  final Map<String, Uint8List> _bytes = {};

  bool _saving = false;
  bool _uploading = false;
  int _progress = 0;
  int _total = 0;

  bool get _isEdit => widget.product != null;
  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _name.text = p['title']?.toString() ?? '';
      _price.text = _V.fmtNum(_V.toNum(p['price']));
      _stock.text = _V.fmtNum(_V.toNum(p['stock']));
      _barcode.text = p['barcode']?.toString() ?? '';
      _description.text = p['description']?.toString() ?? '';
      _currency = (p['currency']?.toString().toUpperCase() == 'USD') ? 'USD' : 'CDF';

      // ── Restauration unité ──
      final savedUnit = (p['unit']?.toString() ?? p['unit_of_measure']?.toString() ?? '').trim();
      if (savedUnit.isNotEmpty) {
        final match = _kUnits.firstWhere(
          (u) => u['value'] == savedUnit,
          orElse: () => const {'value': '', 'label': ''},
        );
        _unit = match['value']!.isNotEmpty ? match['value']! : savedUnit;
      }

      final dp = _V.toNum(p['discount_price']);
      final price = _V.toNum(p['price']);
      if (dp != null && price != null && dp > 0 && dp < price) {
        _hasPromo = true;
        _promoPrice.text = _V.fmtNum(dp);
      }

      final exp = DateTime.tryParse(p['expiry_date']?.toString() ?? '');
      if (exp != null) {
        _perishable = true;
        _expiry = exp;
      }

      final imgs = p['images'];
      if (imgs is List) {
        _existingUrls = imgs
            .map((e) => e.toString())
            .where((e) => e.startsWith('http'))
            .toList();
      }
      if (_existingUrls.isEmpty && (p['image_url']?.toString().startsWith('http') ?? false)) {
        _existingUrls = [p['image_url'].toString()];
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _promoPrice.dispose();
    _stock.dispose();
    _barcode.dispose();
    _description.dispose();
    super.dispose();
  }

  // ── Feedback ──
  void _err(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
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

  // ── Images ──
  Future<void> _pickImages() async {
    HapticFeedback.selectionClick();
    final remaining = _kMaxImages - _existingUrls.length - _newImages.length;
    if (remaining <= 0) {
      _err('Maximum $_kMaxImages photos');
      return;
    }

    try {
      List<XFile> picked;
      if (remaining == 1) {
        final one = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: _kImageMaxDim.toDouble(),
          maxHeight: _kImageMaxDim.toDouble(),
          imageQuality: _kImageQuality,
        );
        picked = one == null ? [] : [one];
      } else {
        picked = await _picker.pickMultiImage(
          maxWidth: _kImageMaxDim.toDouble(),
          maxHeight: _kImageMaxDim.toDouble(),
          imageQuality: _kImageQuality,
          limit: remaining,
        );
      }
      if (picked.isEmpty) return;

      final accepted = <XFile>[];
      int skipped = 0;
      for (final f in picked.take(remaining)) {
        try {
          final b = await f.readAsBytes();
          if (b.length > _kMaxFileSizeMB * 1024 * 1024) {
            skipped++;
            continue;
          }
          _bytes[f.path] = b;
          accepted.add(f);
        } catch (_) {
          skipped++;
        }
      }
      if (!mounted) return;
      setState(() => _newImages.addAll(accepted));
      if (skipped > 0) {
        _err('$skipped image(s) ignorée(s) (taille > $_kMaxFileSizeMB Mo)');
      }
    } catch (e) {
      debugPrint('[ProductForm] ❌ pick error: $e');
      _err('Erreur lors de la sélection des photos');
    }
  }

  Future<List<String>> _uploadImages() async {
    if (_newImages.isEmpty) return [];
    final urls = <String>[];
    setState(() {
      _uploading = true;
      _progress = 0;
      _total = _newImages.length;
    });

    try {
      for (int i = 0; i < _newImages.length; i++) {
        final f = _newImages[i];
        final bytes = _bytes[f.path] ?? await f.readAsBytes();
        final ct = _V.contentType(f);
        final path = 'products/${const Uuid().v4()}.${_V.extFromContentType(ct)}';

        await _db.storage.from(_kBucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: ct,
                cacheControl: '31536000',
                upsert: false,
              ),
            ).timeout(_kUploadTimeout);

        urls.add(_db.storage.from(_kBucket).getPublicUrl(path));
        if (mounted) setState(() => _progress = i + 1);
      }
    } catch (e) {
      await _cleanupOrphans(urls);
      throw _UploadFailure(e);
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = 0;
          _total = 0;
        });
      }
    }
    return urls;
  }

  Future<void> _cleanupOrphans(List<String> urls) async {
    if (urls.isEmpty) return;
    try {
      final paths = urls
          .map((u) => RegExp('/$_kBucket/(.*)\$').firstMatch(u)?.group(1))
          .whereType<String>()
          .toList();
      if (paths.isNotEmpty) await _db.storage.from(_kBucket).remove(paths);
    } catch (e) {
      debugPrint('[ProductForm] ⚠️ cleanup error: $e');
    }
  }

  // ── Date d'expiration ──
  Future<void> _pickExpiry() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expiry != null && _expiry!.isAfter(now)
          ? _expiry!
          : now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 10)),
      helpText: 'Date d\'expiration',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: ThixPolicy.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) setState(() => _expiry = date);
  }

  // ── Sauvegarde ──
  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    final price = _V.parseDouble(_price.text);
    if (price == null || price <= 0) {
      _err('Prix invalide');
      return;
    }

    double? promo;
    if (_hasPromo) {
      promo = _V.parseDouble(_promoPrice.text);
      if (promo == null || promo <= 0) {
        _err('Prix promo invalide');
        return;
      }
      if (promo >= price) {
        _err('Le prix promo doit être inférieur au prix normal');
        return;
      }
    }

    final stock = _V.parseInt(_stock.text);
    if (stock == null) {
      _err('Quantité en stock invalide');
      return;
    }

    final barcode = _barcode.text.trim();
    if (barcode.isNotEmpty && !_V.isValidBarcode(barcode)) {
      _err('Code-barres invalide (8 à 14 chiffres)');
      return;
    }

    if (_perishable && _expiry == null) {
      _err('Choisissez la date d\'expiration');
      return;
    }

    if (_existingUrls.isEmpty && _newImages.isEmpty) {
      _err('Ajoutez au moins une photo');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    List<String> newUrls = [];
    bool saved = false;

    try {
      // 1. Code-barres unique
      if (barcode.isNotEmpty) {
        try {
          var q = _db
              .from('products')
              .select('id,title')
              .eq('shop_id', widget.supermarketId)
              .eq('barcode', barcode);
          if (_isEdit) q = q.neq('id', widget.product!['id']);
          final dup = await q.limit(1).timeout(_kDbTimeout);
          if ((dup as List).isNotEmpty) {
            final t = (dup.first as Map)['title'];
            _err('Ce code-barres existe déjà : ${_V.sanitize(t?.toString(), maxLength: 50)}');
            return;
          }
        } catch (e) {
          debugPrint('[ProductForm] ⚠️ barcode check skipped: $e');
        }
      }

      // 2. Upload des nouvelles photos
      newUrls = await _uploadImages();
      final allUrls = [..._existingUrls, ...newUrls];

      // 3. Données
      final payload = <String, dynamic>{
        'title': _V.sanitize(_name.text, maxLength: _kMaxNameLength),
        'description': _V.sanitize(_description.text, maxLength: _kMaxDescLength),
        'price': price,
        'discount_price': _hasPromo ? promo : null,
        'stock': stock,
        'currency': _currency,
        // ── NOUVEAU : unité de mesure ──
        'unit': _unit,
        'images': allUrls,
        'image_url': allUrls.first,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final hasExtraCols = _isEdit && widget.product!.containsKey('barcode');
      if (barcode.isNotEmpty || hasExtraCols) {
        payload['barcode'] = barcode.isEmpty ? null : barcode;
      }
      final expiryStr = (_perishable && _expiry != null)
          ? DateFormat('yyyy-MM-dd').format(_expiry!)
          : null;
      if (expiryStr != null || hasExtraCols) {
        payload['expiry_date'] = expiryStr;
      }

      String productId;
      if (_isEdit) {
        productId = widget.product!['id'].toString();
        await _db
            .from('products')
            .update(payload)
            .eq('id', productId)
            .timeout(_kDbTimeout);
        saved = true;
      } else {
        try {
          final shop = await _db
              .from('shops')
              .select()
              .eq('id', widget.supermarketId)
              .maybeSingle()
              .timeout(_kDbTimeout);
          final city = _V.sanitize(shop?['city']?.toString(), maxLength: 60);
          final country = shop?['country']?.toString().trim() ?? '';
          if (city.isNotEmpty) payload['city'] = city;
          if (country.length == 2) payload['country'] = country.toUpperCase();
        } catch (_) {}

        payload.addAll({
          'shop_id': widget.supermarketId,
          'category': 'food',
          'condition': 'new',
          'status': 'active',
          'is_service': false,
          'free_shipping': false,
          'shipping_type': 'both',
          'created_at': DateTime.now().toIso8601String(),
        });

        final res = await _db
            .from('products')
            .insert(payload)
            .select('id')
            .single()
            .timeout(_kDbTimeout);
        productId = res['id'].toString();
        saved = true;

        try {
          await widget.service.assignProductToDepartment(
              productId, widget.department.id, widget.aisleNumber);
        } catch (e) {
          debugPrint('[ProductForm] ❌ assign error: $e');
          _err('Produit créé mais non assigné au rayon. Ajoutez-le depuis "Ajouter un produit existant".\nDétail : ${_V.detail(e)}');
        }
      }

      if (mounted) Navigator.pop(context, true);
    } on _UploadFailure catch (e) {
      debugPrint('[ProductForm] ❌ upload error: ${e.cause}');
      _err('${_V.friendlyError(e.cause)}\nDétail : ${_V.detail(e.cause)}');
    } catch (e) {
      debugPrint('[ProductForm] ❌ save error: $e');
      if (!saved && newUrls.isNotEmpty) await _cleanupOrphans(newUrls);
      _err('${_V.friendlyError(e)}\nDétail : ${_V.detail(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI ──
  InputDecoration _deco(String label, {String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: ThixPolicy.card,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ThixPolicy.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ThixPolicy.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ThixPolicy.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ThixPolicy.danger),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: ThixPolicy.textMain)),
      );

  @override
  Widget build(BuildContext context) {
    final dept = widget.department;
    final busy = _saving || _uploading;
    final count = _existingUrls.length + _newImages.length;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: ThixPolicy.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'Modifier le produit' : 'Nouveau produit',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: ThixPolicy.textMain),
                    ),
                  ),
                  IconButton(
                    onPressed: busy ? null : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (!_isEdit)
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: dept.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(dept.icon, size: 14, color: dept.color),
                      const SizedBox(width: 6),
                      Text('Sera ajouté à : ${dept.name} — Allée ${widget.aisleNumber}',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: dept.color)),
                    ],
                  ),
                ),
              const SizedBox(height: 14),

              // ── Photos ──
              _label('Photos ($count/$_kMaxImages) *'),
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (int i = 0; i < _existingUrls.length; i++)
                      _thumb(
                        child: CachedNetworkImage(
                          imageUrl: _existingUrls[i],
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: ThixPolicy.textMuted),
                        ),
                        isMain: i == 0,
                        onRemove: busy
                            ? null
                            : () => setState(() => _existingUrls.removeAt(i)),
                      ),
                    for (int i = 0; i < _newImages.length; i++)
                      _thumb(
                        child: _bytes[_newImages[i].path] != null
                            ? Image.memory(_bytes[_newImages[i].path]!,
                                width: 88, height: 88, fit: BoxFit.cover)
                            : const Icon(Icons.image_outlined),
                        isMain: _existingUrls.isEmpty && i == 0,
                        onRemove: busy
                            ? null
                            : () => setState(() {
                                  final r = _newImages.removeAt(i);
                                  _bytes.remove(r.path);
                                }),
                      ),
                    if (count < _kMaxImages)
                      GestureDetector(
                        onTap: busy ? null : _pickImages,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: ThixPolicy.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: ThixPolicy.primary.withOpacity(0.3),
                                width: 1.5),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded,
                                  color: ThixPolicy.primary, size: 26),
                              SizedBox(height: 4),
                              Text('Ajouter',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: ThixPolicy.primary)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Nom ──
              TextFormField(
                controller: _name,
                maxLength: _kMaxNameLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: _deco('Nom du produit *'),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Nom obligatoire (2 caractères min.)'
                    : null,
              ),
              const SizedBox(height: 14),

              // ── Prix + devise ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                      decoration: _deco('Prix *'),
                      validator: (v) =>
                          _V.parseDouble(v) == null ? 'Prix obligatoire' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _currency,
                      isExpanded: true,
                      decoration: _deco('Devise'),
                      items: const [
                        DropdownMenuItem(value: 'CDF', child: Text('CDF (FC)')),
                        DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                      ],
                      onChanged: (v) => setState(() => _currency = v ?? 'CDF'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── NOUVEAU : Unité de mesure + Stock ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _kUnits.any((u) => u['value'] == _unit) ? _unit : 'pcs',
                      isExpanded: true,
                      decoration: _deco('Unité de mesure *'),
                      items: _kUnits
                          .map((u) => DropdownMenuItem<String>(
                                value: u['value'],
                                child: Text(u['label'] ?? '',
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: busy
                          ? null
                          : (v) => setState(() => _unit = v ?? 'pcs'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _deco('Quantité *'),
                      validator: (v) =>
                          _V.parseInt(v) == null ? 'Quantité obligatoire' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // ── Hint : le prix est par unité ──
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Le prix affiché sera par ${_V.unitLabel(_unit).toLowerCase()}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: ThixPolicy.textMuted,
                      fontStyle: FontStyle.italic),
                ),
              ),

              // ── Code-barres ──
              TextFormField(
                controller: _barcode,
                maxLength: 14,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _deco('Code-barres', hint: 'Optionnel — 8 à 14 chiffres'),
              ),
              const SizedBox(height: 8),

              // ── Périssable + expiration ──
              _switchCard(
                icon: Icons.event_busy_rounded,
                title: 'Produit périssable',
                subtitle: 'Définir une date d\'expiration',
                value: _perishable,
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                          _perishable = v;
                          if (!v) _expiry = null;
                        }),
              ),
              if (_perishable) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: busy ? null : _pickExpiry,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: ThixPolicy.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ThixPolicy.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 20, color: ThixPolicy.primary),
                        const SizedBox(width: 10),
                        Text(
                          _expiry == null
                              ? 'Choisir la date d\'expiration *'
                              : DateFormat('dd MMMM yyyy', 'fr').format(_expiry!),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _expiry == null
                                ? ThixPolicy.textMuted
                                : ThixPolicy.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // ── Promo ──
              _switchCard(
                icon: Icons.local_offer_rounded,
                title: 'Promotion',
                subtitle: 'Afficher un prix réduit',
                value: _hasPromo,
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                          _hasPromo = v;
                          if (!v) _promoPrice.clear();
                        }),
              ),
              if (_hasPromo) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _promoPrice,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  decoration: _deco('Prix promo *'),
                  validator: (v) {
                    if (!_hasPromo) return null;
                    final p = _V.parseDouble(v);
                    if (p == null || p <= 0) return 'Prix promo obligatoire';
                    final normal = _V.parseDouble(_price.text);
                    if (normal != null && p >= normal) {
                      return 'Doit être inférieur au prix normal';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 14),

              // ── Description ──
              TextFormField(
                controller: _description,
                maxLines: 3,
                maxLength: _kMaxDescLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: _deco('Description', hint: 'Optionnel'),
              ),
              const SizedBox(height: 12),

              if (_uploading) ...[
                LinearProgressIndicator(
                  value: _total > 0 ? _progress / _total : null,
                  backgroundColor: ThixPolicy.border,
                  color: ThixPolicy.primary,
                ),
                const SizedBox(height: 6),
                Text('Upload des photos… $_progress/$_total',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ThixPolicy.primary)),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: busy ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ThixPolicy.primary.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          _isEdit ? 'Enregistrer' : 'Créer le produit',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb({
    required Widget child,
    required bool isMain,
    required VoidCallback? onRemove,
  }) {
    return Container(
      width: 88,
      height: 88,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
          if (isMain)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text('Principale',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          if (onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.black87, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _switchCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: ThixPolicy.primary, size: 22),
        title: Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5)),
        value: value,
        onChanged: onChanged,
        activeColor: ThixPolicy.primary,
      ),
    );
  }
}

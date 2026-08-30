// lib/presentation/thix_market/widgets/boost_promotion_card.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 20);
const Duration _kPaymentTimeout = Duration(seconds: 45);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMaxTitleLength = 100;
const int _kMaxPackageNameLength = 60;

// ============================================================================
// VALIDATORS
// ============================================================================
class _BoostValidators {
  _BoostValidators._();

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

  static String formatDuration(int days, BuildContext context) {
    final l10n = _BoostL10nExt(context);
    if (days <= 0) return l10n.bstT('0 jour', '0 day');
    if (days == 1) return l10n.bstT('1 jour', '1 day');
    if (days == 7) return l10n.bstT('1 semaine', '1 week');
    if (days == 14) return l10n.bstT('2 semaines', '2 weeks');
    if (days == 30) return l10n.bstT('1 mois', '1 month');
    if (days == 60) return l10n.bstT('2 mois', '2 months');
    if (days == 90) return l10n.bstT('3 mois', '3 months');
    if (days % 7 == 0) {
      final weeks = days ~/ 7;
      return l10n.bstT('$weeks semaines', '$weeks weeks');
    }
    if (days % 30 == 0) {
      final months = days ~/ 30;
      return l10n.bstT('$months mois', '$months months');
    }
    return l10n.bstT('$days jours', '$days days');
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Ressource introuvable.';
    if (msg.contains('insufficient') || msg.contains('balance')) return 'Solde insuffisant.';
    if (msg.contains('already') || msg.contains('duplicate')) return 'Boost déjà actif pour cette annonce.';
    return 'Une erreur est survenue. Réessayez.';
  }

  static IconData packageIcon(int days) {
    if (days <= 3) return Icons.bolt_rounded;
    if (days <= 7) return Icons.rocket_launch_rounded;
    if (days <= 30) return Icons.local_fire_department_rounded;
    return Icons.workspace_premium_rounded;
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
class _BoostL10nExt {
  final BuildContext context;
  _BoostL10nExt(this.context);

  String bstT(String fr, String en) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(context).languageCode;
}

extension _BoostL10n on BuildContext {
  _BoostL10nExt get l10n => _BoostL10nExt(this);
  String bstT(String fr, String en) => l10n.bstT(fr, en);
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _boostRetry<T>(
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
        debugPrint('[BoostCard] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[BoostCard] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[BoostCard] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class BoostPromotionCard extends StatefulWidget {
  final String announcementId;
  final String announcementTitle;

  const BoostPromotionCard({
    super.key,
    required this.announcementId,
    required this.announcementTitle,
  });

  @override
  State<BoostPromotionCard> createState() => _BoostPromotionCardState();
}

class _BoostPromotionCardState extends State<BoostPromotionCard> {
  List<Map<String, dynamic>> _packages = [];
  bool _isLoading = true;
  String? _selectedPackageId;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    debugPrint('[BoostCard] 🚀 Opened for ${_shortId(widget.announcementId)}');

    if (!_BoostValidators.isValidId(widget.announcementId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = context.bstT('Identifiant d\'annonce invalide', 'Invalid announcement ID');
          });
        }
      });
      return;
    }

    _loadPackages();
  }

  @override
  void dispose() {
    debugPrint('[BoostCard] 👋 Disposed');
    super.dispose();
  }

  String _shortId(String id) => id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  // ============================================================
  // LOAD PACKAGES
  // ============================================================
  Future<void> _loadPackages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _boostRetry(
        () => Supabase.instance.client
            .from('boost_packages')
            .select()
            .eq('is_active', true)
            .order('price', ascending: true),
        label: 'loadPackages',
      );

      if (!mounted) return;

      final packages = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _packages = packages;
        _isLoading = false;
        // Auto-sélection du premier package si disponible
        if (packages.isNotEmpty && _selectedPackageId == null) {
          _selectedPackageId = packages.first['id']?.toString();
        }
      });

      debugPrint('[BoostCard] ✓ Loaded ${packages.length} packages');
    } catch (e) {
      debugPrint('[BoostCard] ❌ Load packages error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _BoostValidators.friendlyError(e);
      });
    }
  }

  // ============================================================
  // SELECT PACKAGE
  // ============================================================
  void _selectPackage(String? id) {
    if (id == null || _isProcessing) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedPackageId = id);
  }

  // ============================================================
  // VALIDATE SELECTED PACKAGE
  // ============================================================
  Map<String, dynamic>? _findSelectedPackage() {
    if (_selectedPackageId == null) return null;
    try {
      return _packages.firstWhere(
        (p) => p['id']?.toString() == _selectedPackageId,
      );
    } catch (_) {
      return null; // Package supprimé entre-temps
    }
  }

  // ============================================================
  // PURCHASE BOOST
  // ============================================================
  Future<void> _purchaseBoost() async {
    if (_isProcessing) {
      debugPrint('[BoostCard] ⚠️ Purchase already in progress');
      return;
    }

    final selectedPackage = _findSelectedPackage();
    if (selectedPackage == null) {
      HapticFeedback.lightImpact();
      _showInfo(context.bstT('Sélectionnez une formule', 'Select a plan'));
      return;
    }

    final packageId = selectedPackage['id']?.toString();
    final price = _BoostValidators.safeDouble(selectedPackage['price']);
    final durationDays = _BoostValidators.safeInt(selectedPackage['duration_days'], fallback: 1);
    final packageName = _BoostValidators.sanitize(
      selectedPackage['name']?.toString(),
      maxLength: _kMaxPackageNameLength,
    );

    if (!_BoostValidators.isValidId(packageId)) {
      _showError(context.bstT('Formule invalide', 'Invalid plan'));
      return;
    }

    // Confirmation premium
    final confirmed = await _showConfirmDialog(
      packageName: packageName,
      price: price,
      durationDays: durationDays,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    debugPrint('[BoostCard] 💳 Processing boost for ${_shortId(widget.announcementId)} (pkg=${_shortId(packageId!)}, price=$price)');

    String? boostOrderId;
    bool paymentSuccessful = false;

    try {
      // 1. Créer le boost order
      final order = await _boostRetry(
        () => Supabase.instance.client.from('boost_orders').insert({
          'product_id': widget.announcementId,
          'package_id': packageId,
          'price': price,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        }).select().maybeSingle(),
        label: 'createBoostOrder',
      );

      if (order == null) {
        throw Exception('Échec de création de la commande boost');
      }

      boostOrderId = order['id']?.toString();
      if (!_BoostValidators.isValidId(boostOrderId)) {
        throw Exception('ID de commande invalide');
      }

      // 2. Process paiement (via Edge Function)
      paymentSuccessful = await _processPayment(
        boostOrderId: boostOrderId!,
        amount: price,
        packageId: packageId,
      );

      if (!paymentSuccessful) {
        // Paiement échoué → order reste 'pending', rien à rollback
        if (mounted) {
          _showError(context.bstT('Paiement échoué. Réessayez.', 'Payment failed. Please try again.'));
        }
        return;
      }

      // 3. Activer le boost sur le produit
      final expiryDate = DateTime.now().add(Duration(days: durationDays));
      await _boostRetry(
        () => Supabase.instance.client.from('products').update({
          'is_boosted': true,
          'boost_expires_at': expiryDate.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.announcementId),
        label: 'activateBoost',
      );

      debugPrint('[BoostCard] ✓ Boost activated until ${DateFormat('yyyy-MM-dd').format(expiryDate)}');

      if (mounted) {
        _showSuccess(
          '${context.bstT('Boost activé jusqu\'au', 'Boost active until')} '
          '${DateFormat('dd MMM yyyy', context.l10n.localeCode).format(expiryDate)}',
        );
        // Pop après succès si dans un modal
        try {
          Navigator.pop(context);
        } catch (_) {
          // Pas dans un modal, ignoré
        }
      }
    } catch (e) {
      debugPrint('[BoostCard] ❌ Purchase error: $e');

      // ROLLBACK : si paiement OK mais activate échoue → remboursement
      if (paymentSuccessful && boostOrderId != null) {
        debugPrint('[BoostCard] 🔄 Rolling back: refunding boost order $boostOrderId');
        await _rollbackPayment(boostOrderId);
      }

      if (mounted) _showError(_BoostValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ============================================================
  // PROCESS PAYMENT (via Edge Function)
  // ============================================================
  Future<bool> _processPayment({
    required String boostOrderId,
    required double amount,
    required String packageId,
  }) async {
    try {
      // TODO : Remplacer par votre vraie Edge Function de paiement
      // (Stripe, Flutterwave, CinetPay, Mobile Money, THIX Money, etc.)
      final response = await _boostRetry(
        () => Supabase.instance.client.functions.invoke(
          'process-boost-payment',
          body: {
            'boost_order_id': boostOrderId,
            'package_id': packageId,
            'amount': amount,
            'currency': 'XOF',
          },
        ),
        label: 'processBoostPayment[$boostOrderId]',
        timeout: _kPaymentTimeout,
        maxRetries: 0, // Pas de retry sur paiement (double charge)
      );

      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      return data['success'] == true;
    } catch (e) {
      debugPrint('[BoostCard] ❌ Payment function error: $e');
      return false;
    }
  }

  // ============================================================
  // ROLLBACK PAYMENT
  // ============================================================
  Future<void> _rollbackPayment(String boostOrderId) async {
    try {
      await _boostRetry(
        () => Supabase.instance.client.from('boost_orders').update({
          'status': 'refunded',
          'refunded_at': DateTime.now().toIso8601String(),
        }).eq('id', boostOrderId),
        label: 'rollbackBoostOrder[$boostOrderId]',
      );

      // TODO : Appeler Edge Function pour remboursement PSP si applicable
      try {
        await Supabase.instance.client.functions.invoke(
          'refund-boost-payment',
          body: {'boost_order_id': boostOrderId},
        );
      } catch (_) {
        // Non-bloquant
      }

      debugPrint('[BoostCard] ✓ Rollback successful for $boostOrderId');
    } catch (e) {
      debugPrint('[BoostCard] ⚠️ Rollback failed (MANUAL INTERVENTION NEEDED): $e');
      // Log critique : intervention manuelle requise
    }
  }

  // ============================================================
  // CONFIRM DIALOG
  // ============================================================
  Future<bool> _showConfirmDialog({
    required String packageName,
    required double price,
    required int durationDays,
  }) async {
    HapticFeedback.mediumImpact();
    final currency = 'FC';
    final formattedPrice = _BoostValidators.formatAmount(price, context.l10n.localeCode);
    final durationStr = _BoostValidators.formatDuration(durationDays, context);
    final sanitizedTitle = _BoostValidators.sanitize(
      widget.announcementTitle,
      maxLength: _kMaxTitleLength,
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.rocket_launch_rounded, color: ThixPolicy.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.bstT('Confirmer le boost', 'Confirm boost'),
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(
              icon: Icons.article_outlined,
              label: context.bstT('Produit', 'Product'),
              value: sanitizedTitle.isEmpty ? context.bstT('Sans titre', 'Untitled') : sanitizedTitle,
            ),
            const SizedBox(height: 6),
            _ConfirmRow(
              icon: Icons.workspace_premium_rounded,
              label: context.bstT('Formule', 'Plan'),
              value: packageName,
            ),
            const SizedBox(height: 6),
            _ConfirmRow(
              icon: Icons.calendar_today_rounded,
              label: context.bstT('Durée', 'Duration'),
              value: durationStr,
            ),
            const SizedBox(height: 6),
            _ConfirmRow(
              icon: Icons.payments_rounded,
              label: context.bstT('Prix', 'Price'),
              value: '$formattedPrice $currency',
              isBold: true,
              valueColor: ThixPolicy.primary,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.bstT('Annuler', 'Cancel'),
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(context.bstT('Confirmer', 'Confirm')),
          ),
        ],
      ),
    );
    return result ?? false;
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

  void _showInfo(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final sanitizedTitle = _BoostValidators.sanitize(
      widget.announcementTitle,
      maxLength: _kMaxTitleLength,
    );

    if (_isLoading) {
      return const _SkeletonPackages();
    }

    if (_error != null) {
      return _ErrorState(
        message: _error!,
        retryLabel: context.bstT('Réessayer', 'Retry'),
        onRetry: _loadPackages,
      );
    }

    if (_packages.isEmpty) {
      return _EmptyPackages(
        title: context.bstT('Aucune formule disponible', 'No plans available'),
        subtitle: context.bstT(
          'Les formules de boost seront bientôt disponibles',
          'Boost plans will be available soon',
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ThixPolicy.primary.withOpacity(0.1), ThixPolicy.primary.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: ThixPolicy.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.bstT('Boostez votre annonce', 'Boost your listing'),
                      style: ThixPolicy.h3Style.copyWith(
                        fontSize: 18,
                        fontWeight: ThixPolicy.bold,
                        color: ThixPolicy.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.bstT(
                        'Augmentez la visibilité',
                        'Increase visibility',
                      ),
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sanitizedTitle.isEmpty
                ? context.bstT('Votre annonce', 'Your listing')
                : '"$sanitizedTitle"',
            style: ThixPolicy.captionStyle.copyWith(
              color: ThixPolicy.textSecondary,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),

          // Packages
          ..._packages.map((pkg) => _PackageCard(
                package: pkg,
                isSelected: _selectedPackageId == pkg['id']?.toString(),
                isDisabled: _isProcessing,
                onSelect: (id) => _selectPackage(id),
              )),

          const SizedBox(height: 20),

          // Purchase button
          Semantics(
            button: true,
            label: context.bstT('Booster maintenant', 'Boost now'),
            enabled: !_isProcessing,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _purchaseBoost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ThixPolicy.primary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.bstT('Traitement...', 'Processing...'),
                            style: ThixPolicy.labelStyle.copyWith(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: ThixPolicy.bold,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            context.bstT('Booster maintenant', 'Boost now'),
                            style: ThixPolicy.labelStyle.copyWith(
                              fontSize: 15,
                              color: Colors.white,
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
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _ConfirmRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: ThixPolicy.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: ThixPolicy.captionStyle.copyWith(
              fontWeight: isBold ? ThixPolicy.bold : ThixPolicy.semiBold,
              color: valueColor ?? ThixPolicy.textMain,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> package;
  final bool isSelected;
  final bool isDisabled;
  final ValueChanged<String?> onSelect;

  const _PackageCard({
    required this.package,
    required this.isSelected,
    required this.isDisabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final id = package['id']?.toString();
    final name = _BoostValidators.sanitize(
      package['name']?.toString(),
      maxLength: _kMaxPackageNameLength,
    );
    final durationDays = _BoostValidators.safeInt(package['duration_days'], fallback: 1);
    final price = _BoostValidators.safeDouble(package['price']);
    final originalPrice = _BoostValidators.safeDouble(package['original_price']);
    final estimatedViews = _BoostValidators.safeInt(package['estimated_views']);

    final hasDiscount = originalPrice > price && price > 0;
    final discountPercent = hasDiscount
        ? (((originalPrice - price) / originalPrice) * 100).round()
        : 0;

    final currency = 'FC';
    final formattedPrice = _BoostValidators.formatAmount(price, context.l10n.localeCode);
    final formattedOriginal = hasDiscount
        ? _BoostValidators.formatAmount(originalPrice, context.l10n.localeCode)
        : '';
    final formattedViews = _BoostValidators.formatAmount(estimatedViews.toDouble(), context.l10n.localeCode);
    final durationStr = _BoostValidators.formatDuration(durationDays, context);
    final icon = _BoostValidators.packageIcon(durationDays);

    final viewsLabel = context.bstT('vues garanties', 'guaranteed views');
    final displayName = name.isEmpty ? durationStr : name;

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: !isDisabled,
      label: '$displayName, $formattedPrice $currency, $durationStr',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? ThixPolicy.primary : ThixPolicy.border.withOpacity(0.6),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? ThixPolicy.shadowSoft(opacity: 0.1)
              : ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: RadioListTile<String>(
          value: id ?? '',
          groupValue: isDisabled ? null : (isSelected ? id : null),
          onChanged: isDisabled ? null : onSelect,
          activeColor: ThixPolicy.primary,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? ThixPolicy.primary.withOpacity(0.15) : ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? ThixPolicy.primary : ThixPolicy.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayName,
                  style: ThixPolicy.labelStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 14,
                    color: ThixPolicy.textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasDiscount)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ThixPolicy.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '-$discountPercent%',
                    style: ThixPolicy.microStyle.copyWith(
                      fontSize: 10,
                      fontWeight: ThixPolicy.bold,
                      color: ThixPolicy.danger,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: ThixPolicy.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      durationStr,
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.visibility_rounded, size: 12, color: ThixPolicy.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '$formattedViews $viewsLabel',
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          secondary: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$formattedPrice $currency',
                style: ThixPolicy.labelStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  fontSize: 14,
                  color: ThixPolicy.primary,
                ),
              ),
              if (hasDiscount)
                Text(
                  '$formattedOriginal $currency',
                  style: ThixPolicy.microStyle.copyWith(
                    decoration: TextDecoration.lineThrough,
                    fontSize: 10,
                    color: ThixPolicy.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SKELETON / EMPTY / ERROR STATES
// ============================================================================

class _SkeletonPackages extends StatelessWidget {
  const _SkeletonPackages();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
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
                    Container(height: 16, width: 200, color: Colors.grey.shade200),
                    const SizedBox(height: 6),
                    Container(height: 10, width: 140, color: Colors.grey.shade200),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(
            3,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 14, width: 140, color: Colors.grey.shade200),
                        const SizedBox(height: 6),
                        Container(height: 10, width: 200, color: Colors.grey.shade200),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(height: 18, width: 60, color: Colors.grey.shade200),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPackages extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyPackages({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ThixPolicy.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rocket_launch_outlined, size: 48, color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
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
    return Padding(
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
            child: const Icon(Icons.error_outline_rounded, size: 48, color: ThixPolicy.danger),
          ),
          const SizedBox(height: 16),
          Text(
            context.bstT('Erreur de chargement', 'Loading error'),
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
    );
  }
}

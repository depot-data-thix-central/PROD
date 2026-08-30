// lib/presentation/thix_market/pages/auction_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../widgets/live/live_auction_widget.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _AuctionValidators {
  _AuctionValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class AuctionPage extends StatefulWidget {
  final String auctionId;

  const AuctionPage({super.key, required this.auctionId});

  @override
  State<AuctionPage> createState() => _AuctionPageState();
}

class _AuctionPageState extends State<AuctionPage> {
  /// Clé utilisée pour forcer un rebuild complet du widget enfant au refresh.
  Key _widgetKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    final isValid = _AuctionValidators.isValidId(widget.auctionId);
    debugPrint('[Auction] 🎯 Page opened for ${_shortId(widget.auctionId)}${isValid ? "" : " (INVALID)"}');

    if (!isValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleInvalidId());
    }
  }

  @override
  void dispose() {
    debugPrint('[Auction] 👋 Page disposed');
    super.dispose();
  }

  String _shortId(String id) {
    final len = id.length > 8 ? 8 : id.length;
    return id.substring(0, len);
  }

  void _handleInvalidId() {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    _showError('Identifiant d\'enchère invalide');
    context.pop();
  }

  /// Force un rebuild complet du widget enfant (équivalent à un vrai refresh)
  void _forceRefresh() {
    HapticFeedback.mediumImpact();
    setState(() => _widgetKey = UniqueKey());
    debugPrint('[Auction] 🔄 Forced refresh via UniqueKey');
  }

  /// Callback appelé par LiveAuctionWidget quand une enchère est placée
  void _onBidPlaced(num bidAmount) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _showSuccess('Enchère de $bidAmount FCFA placée !');
    debugPrint('[Auction] 💰 Bid placed: $bidAmount FCFA');
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _AuctionValidators.isValidId(widget.auctionId);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          'Enchère en direct',
          style: ThixPolicy.h3Style.copyWith(
            fontWeight: ThixPolicy.bold,
            color: ThixPolicy.textMain,
          ),
        ),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Semantics(
          button: true,
          label: 'Retour',
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
            tooltip: 'Retour',
            onPressed: () {
              HapticFeedback.selectionClick();
              context.pop();
            },
          ),
        ),
        actions: [
          if (isValid)
            Semantics(
              button: true,
              label: 'Actualiser l\'enchère',
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, color: ThixPolicy.textMain),
                tooltip: 'Actualiser',
                onPressed: _forceRefresh,
              ),
            ),
        ],
      ),
      body: isValid
          ? LiveAuctionWidget(
              key: _widgetKey,
              auctionId: widget.auctionId,
              onBidPlaced: _onBidPlaced,
            )
          : const _InvalidIdState(),
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

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
              style: ThixPolicy.h3Style.copyWith(
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cet identifiant d\'enchère n\'est pas valide.\nRetour aux enchères disponibles.',
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: ThixPolicy.textMuted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

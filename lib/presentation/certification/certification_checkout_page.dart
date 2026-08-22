// lib/presentation/certification/certification_checkout_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/providers/certification_provider.dart';
import 'package:thix_id/services/bcc_exchange_rate_service.dart';
import 'package:thix_id/services/certification_payment_service.dart';
import 'package:thix_id/services/certification_service.dart';

class CertificationCheckoutPage extends ConsumerStatefulWidget {
  final CertificationTier tier;
  final String? requestId;

  const CertificationCheckoutPage({
    super.key,
    required this.tier,
    this.requestId,
  });

  @override
  ConsumerState<CertificationCheckoutPage> createState() =>
      _CertificationCheckoutPageState();
}

class _CertificationCheckoutPageState
    extends ConsumerState<CertificationCheckoutPage> {
  final _phoneCtrl = TextEditingController();
  String _method = 'mpesa';
  bool _paying = false;

  static const _methods = <_PayMethod>[
    _PayMethod(
      id: 'mpesa',
      name: 'M-Pesa',
      brand: 'Vodacom',
      color: Color(0xFF00A651),
      needsPhone: true,
    ),
    _PayMethod(
      id: 'airtel',
      name: 'Airtel Money',
      brand: 'Airtel',
      color: Color(0xFFE60000),
      needsPhone: true,
    ),
    _PayMethod(
      id: 'orange_money',
      name: 'Orange Money',
      brand: 'Orange',
      color: Color(0xFFFF6600),
      needsPhone: true,
    ),
    _PayMethod(
      id: 'card',
      name: 'Carte bancaire',
      brand: 'Visa / Mastercard',
      color: Color(0xFF1A56DB),
      needsPhone: false,
    ),
    _PayMethod(
      id: 'thix_money',
      name: 'THIX Money',
      brand: 'Portefeuille THIX',
      color: Color(0xFFD4A017), // Or THIX
      needsPhone: false,
    ),
  ];

  _PayMethod get _selected =>
      _methods.firstWhere((m) => m.id == _method, orElse: () => _methods.first);

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── LOGIQUE DE SECOURS POUR ANNULER LA DEMANDE ──
  Future<void> _cancelRequestFallback() async {
    try {
      await ref.read(certificationServiceProvider).cancelUpgradeRequest();
      ref.invalidate(myCertificationProvider);
    } catch (e) {
      debugPrint("Erreur lors du nettoyage de la requête : $e");
    }
  }

  Future<void> _pay(ExchangeRateQuote? quote) async {
    if (_paying) return;
    if (widget.tier.isInviteOnly || widget.tier.priceUsd == null) {
      _toast('Ce niveau n\'est pas payable', error: true);
      return;
    }
    if (_selected.needsPhone && _phoneCtrl.text.trim().length < 9) {
      _toast('Numéro de téléphone requis', error: true);
      return;
    }

    setState(() => _paying = true);
    HapticFeedback.mediumImpact();

    try {
      // 1. Créer / lier la demande si besoin (Passe le statut à "pending")
      String? requestId = widget.requestId;
      if (requestId == null) {
        try {
          await ref.read(certificationServiceProvider).requestUpgrade(
                requestedTier: widget.tier,
                reason: 'Checkout certification',
              );
        } catch (_) {
          // déjà une demande pending → on continue le paiement
        }
      }

      // 2. Initier le paiement
      final result =
          await ref.read(certificationPaymentServiceProvider).initiate(
                tier: widget.tier,
                paymentMethod: _method,
                phoneNumber:
                    _selected.needsPhone ? _phoneCtrl.text.trim() : null,
                requestId: requestId,
              );

      if (!mounted) return;

      // 🚨 CAS D'ÉCHEC IMMÉDIAT
      if (!result.success) {
        _toast(result.error ?? 'Paiement échoué', error: true);
        await _cancelRequestFallback(); // On annule la requête
        return;
      }

      // ✅ CAS SUCCÈS IMMÉDIAT (ex: Wallet THIX)
      if (result.status == 'paid') {
        ref.invalidate(myCertificationProvider);
        _toast('Paiement réussi — certification en cours');
        Navigator.of(context).pop(true);
        return;
      }

      // ⏳ CAS EN ATTENTE (ex: Mobile Money Push)
      if (result.needsWaiting && result.paymentId != null) {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => CertificationPaymentWaitingPage(
              paymentId: result.paymentId!,
              tier: widget.tier,
            ),
          ),
        );
        
        if (mounted) {
          if (ok != true) {
            // L'utilisateur a quitté la page d'attente sans payer ou échec
            await _cancelRequestFallback();
          } else {
            // Succès
            ref.invalidate(myCertificationProvider);
          }
          Navigator.of(context).pop(ok);
        }
        return;
      }

      _toast('Paiement initié');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
      // 🚨 CAS CRASH / ERREUR RÉSEAU
      await _cancelRequestFallback();
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    final color = tier.badgeColor;
    final rateAsync = ref.watch(usdCdfRateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA), // Uniformisé avec la page Tiers
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628), // Bleu Marine THIX
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Paiement',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: rateAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ThixPolicy.primary),
        ),
        error: (e, _) => Center(child: Text('Erreur taux: $e')),
        data: (quote) {
          final usd = tier.priceUsd ?? 0;
          final cdf = quote.cdfForUsd(usd);
          final cdfStr = NumberFormat('#,##0', 'fr_FR').format(cdf);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // ── Récap tier (Design Premium) ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF06101D),
                            Color(0xFF0A1628),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0A1628).withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                            color: color.withOpacity(0.4), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withOpacity(0.15),
                              border: Border.all(color: color, width: 2),
                            ),
                            child: Icon(tier.icon, color: color, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Souscription',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tier.labelFr,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tier.descriptionFr,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Montant (Carte claire et épurée) ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0A1628).withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Montant à payer',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${usd.toStringAsFixed(0)} USD',
                            style: TextStyle(
                              color: color,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '≈ $cdfStr CDF',
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Taux : 1 USD = ${NumberFormat('#,##0.##', 'fr_FR').format(quote.usdToCdf)} CDF'
                            ' (${quote.isOfficialBcc ? 'BCC' : quote.source})',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      'Moyen de paiement',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0A1628),
                      ),
                    ),
                    const SizedBox(height: 12),

                    ..._methods.map((m) {
                      final sel = _method == m.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => setState(() => _method = m.id),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: sel ? m.color : const Color(0xFFE2E8F0),
                                  width: sel ? 2.0 : 1.0,
                                ),
                                boxShadow: sel
                                    ? [
                                        BoxShadow(
                                          color: m.color.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: m.color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      m.id == 'card'
                                          ? Icons.credit_card_rounded
                                          : m.id == 'thix_money'
                                              ? Icons.account_balance_wallet_rounded
                                              : Icons.phone_android_rounded,
                                      color: m.color,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            color: sel 
                                                ? m.color 
                                                : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          m.brand,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    sel
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: sel ? m.color : const Color(0xFFCBD5E1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    if (_selected.needsPhone) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Numéro Mobile Money',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A1628),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                        ],
                        decoration: InputDecoration(
                          hintText: 'ex: 0991234567',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          prefixIcon: Icon(Icons.phone_rounded, color: _selected.color),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: _selected.color, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── CTA (Bouton d'action) ──
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  20 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(
                    top: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A1628).withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _paying ? null : () => _pay(quote),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _paying
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Payer $cdfStr CDF',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PayMethod {
  final String id;
  final String name;
  final String brand;
  final Color color;
  final bool needsPhone;

  const _PayMethod({
    required this.id,
    required this.name,
    required this.brand,
    required this.color,
    required this.needsPhone,
  });
}

// ─────────────────────────────────────────────────────────────
// PAGE D'ATTENTE PAIEMENT (Mise au propre avec le Bleu Marine)
// ─────────────────────────────────────────────────────────────

class CertificationPaymentWaitingPage extends ConsumerStatefulWidget {
  final String paymentId;
  final CertificationTier tier;

  const CertificationPaymentWaitingPage({
    super.key,
    required this.paymentId,
    required this.tier,
  });

  @override
  ConsumerState<CertificationPaymentWaitingPage> createState() =>
      _CertificationPaymentWaitingPageState();
}

class _CertificationPaymentWaitingPageState
    extends ConsumerState<CertificationPaymentWaitingPage> {
  Timer? _timer;
  String _status = 'awaiting_payment';
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    _ticks++;
    if (_ticks > 40) {
      // \~2 min
      _timer?.cancel();
      if (mounted) setState(() => _status = 'expired');
      return;
    }
    try {
      final s = await ref
          .read(certificationPaymentServiceProvider)
          .getPaymentStatus(widget.paymentId);
      if (s == null || !mounted) return;
      setState(() => _status = s);
      if (s == 'paid' || s == 'failed' || s == 'cancelled') {
        _timer?.cancel();
        if (s == 'paid') {
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) Navigator.of(context).pop(true);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.tier.badgeColor;
    final waiting = _status == 'awaiting_payment' || _status == 'pending';

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF06101D),
              Color(0xFF0A1628), // THIX Navy Blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context, false), // Renvoie false par défaut
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (waiting)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withOpacity(0.1),
                            ),
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                color: color,
                                strokeWidth: 4,
                              ),
                            ),
                          )
                        else if (_status == 'paid')
                          Icon(Icons.check_circle_rounded, size: 84, color: color)
                        else
                          const Icon(Icons.error_outline_rounded,
                              size: 84, color: Color(0xFFEF4444)),
                        const SizedBox(height: 32),
                        Text(
                          waiting
                              ? 'Validation en cours...'
                              : _status == 'paid'
                                  ? 'Paiement confirmé !'
                                  : 'Paiement non finalisé',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          waiting
                              ? 'Veuillez valider la demande sur votre téléphone (Mobile Money).\nNe fermez pas cette page.'
                              : _status == 'paid'
                                  ? 'Votre demande de certification a été enregistrée avec succès.'
                                  : 'Le paiement a expiré ou a été annulé. Veuillez réessayer.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!waiting && _status != 'paid') ...[
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.1),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Retourner aux options',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 60), // Espace pour centrer un peu plus haut
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

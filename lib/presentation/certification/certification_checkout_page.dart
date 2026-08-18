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
      color: Color(0xFFD4A017),
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
      // Créer / lier la demande si besoin
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

      final result =
          await ref.read(certificationPaymentServiceProvider).initiate(
                tier: widget.tier,
                paymentMethod: _method,
                phoneNumber:
                    _selected.needsPhone ? _phoneCtrl.text.trim() : null,
                requestId: requestId,
              );

      if (!mounted) return;

      if (!result.success) {
        _toast(result.error ?? 'Paiement échoué', error: true);
        return;
      }

      if (result.status == 'paid') {
        ref.invalidate(myCertificationProvider);
        _toast('Paiement réussi — certification en cours');
        Navigator.of(context).pop(true);
        return;
      }

      if (result.needsWaiting && result.paymentId != null) {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => CertificationPaymentWaitingPage(
              paymentId: result.paymentId!,
              tier: widget.tier,
            ),
          ),
        );
        if (ok == true && mounted) {
          ref.invalidate(myCertificationProvider);
          Navigator.of(context).pop(true);
        }
        return;
      }

      _toast('Paiement initié');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? ThixPolicy.danger : ThixPolicy.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    final color = tier.badgeColor;
    final rateAsync = ref.watch(usdCdfRateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1B3A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Paiement certification',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    // ── Récap tier ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withOpacity(0.2),
                              border: Border.all(color: color, width: 2),
                            ),
                            child: Icon(tier.icon, color: color, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tier.labelFr,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tier.descriptionFr,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Montant ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ThixPolicy.border),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Montant à payer',
                            style: TextStyle(
                              color: ThixPolicy.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${usd.toStringAsFixed(0)} USD',
                            style: TextStyle(
                              color: color,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '≈ $cdfStr CDF',
                            style: const TextStyle(
                              color: ThixPolicy.textMain,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '1 USD = ${NumberFormat('#,##0.##', 'fr_FR').format(quote.usdToCdf)} CDF'
                            ' · ${quote.isOfficialBcc ? 'BCC' : quote.source}',
                            style: const TextStyle(
                              color: ThixPolicy.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Moyen de paiement',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: ThixPolicy.textMain,
                      ),
                    ),
                    const SizedBox(height: 10),

                    ..._methods.map((m) {
                      final sel = _method == m.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () => setState(() => _method = m.id),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: sel ? m.color : ThixPolicy.border,
                                  width: sel ? 1.8 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: m.color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      m.id == 'card'
                                          ? Icons.credit_card_rounded
                                          : m.id == 'thix_money'
                                              ? Icons.account_balance_wallet_rounded
                                              : Icons.phone_android_rounded,
                                      color: m.color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: ThixPolicy.textMain,
                                          ),
                                        ),
                                        Text(
                                          m.brand,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: ThixPolicy.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    sel
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: sel ? m.color : ThixPolicy.border,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    if (_selected.needsPhone) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Numéro Mobile Money',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ThixPolicy.textMain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                        ],
                        decoration: InputDecoration(
                          hintText: 'ex: 0991234567',
                          prefixIcon: const Icon(Icons.phone_rounded),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: ThixPolicy.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: ThixPolicy.border),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── CTA ──
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _paying ? null : () => _pay(quote),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _paying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Payer $cdfStr CDF',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
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
// PAGE D'ATTENTE PAIEMENT
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
      backgroundColor: const Color(0xFF0B1B3A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Validation du paiement'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (waiting)
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    color: color,
                    strokeWidth: 3,
                  ),
                )
              else if (_status == 'paid')
                Icon(Icons.check_circle_rounded, size: 72, color: color)
              else
                const Icon(Icons.error_outline_rounded,
                    size: 72, color: Color(0xFFEF4444)),
              const SizedBox(height: 24),
              Text(
                waiting
                    ? 'Confirmez sur votre téléphone'
                    : _status == 'paid'
                        ? 'Paiement confirmé'
                        : 'Paiement non finalisé',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                waiting
                    ? 'Validez la demande Mobile Money ou carte.\nCette page se met à jour automatiquement.'
                    : _status == 'paid'
                        ? 'Votre demande de certification est enregistrée.'
                        : 'Réessayez ou choisissez un autre moyen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (!waiting && _status != 'paid') ...[
                const SizedBox(height: 28),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Retour', style: TextStyle(color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

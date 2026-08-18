import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/profile_service.dart';

import '../../theme.dart';

class PaymentMethodCard extends StatelessWidget {
  final String name;
  final String description;
  final String providerLogo;
  final bool selected;

  const PaymentMethodCard({
    super.key,
    required this.name,
    required this.description,
    required this.providerLogo,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: selected
              ? LightModeColors.accent
              : theme.dividerColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 40,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: theme.dividerColor),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.payment,
              color: LightModeColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(
                    color:
                        LightModeColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(
              color:
                  LightModeColors.secondaryText,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentGatewayPage extends StatefulWidget {
  final String? returnTo;

  const PaymentGatewayPage({
    super.key,
    this.returnTo,
  });

  @override
  State<PaymentGatewayPage> createState() =>
      _PaymentGatewayPageState();
}

class _PaymentGatewayPageState
    extends State<PaymentGatewayPage> {
  final _mobileMoneyPhoneC =
      TextEditingController();

  String _method = 'mobile_money';

  bool _isPaying = false;

  @override
  void dispose() {
    _mobileMoneyPhoneC.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _txRef() {
    final rnd = Random();

    final suffix = List.generate(
      6,
      (_) => rnd.nextInt(10),
    ).join();

    return 'TX-ID-$suffix-GOV';
  }

  Future<void> _confirmPayment() async {
    if (_isPaying) return;

    final auth = context.read<AuthController>();

    final me = auth.currentUser;

    if (me == null) {
      _snack('Veuillez vous connecter.');
      return;
    }

    setState(() {
      _isPaying = true;
    });

    try {
      await Future.delayed(
        const Duration(seconds: 2),
      );

      final txRef = _txRef();

      if (!mounted) return;

      context.go(
        Uri(
          path: AppRoutes.activationReceipt,
          queryParameters: {
            'txRef': txRef,
            'method': _method,
          },
        ).toString(),
      );
    } catch (e) {
      debugPrint('$e');

      _snack('Paiement impossible.');
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A2F5C),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      context.go(
                        AppRoutes.home,
                      );
                    },
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Paiement Institutionnel',
                      style: theme
                          .textTheme.titleLarge
                          ?.copyWith(
                        color: Colors.white,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(
                  AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color:
                      theme.scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.only(
                    topLeft:
                        Radius.circular(30),
                    topRight:
                        Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.all(
                          AppSpacing.lg,
                        ),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme
                                  .surface,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            AppRadius.lg,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'TOTAL À PAYER',
                              style: theme
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                color:
                                    LightModeColors
                                        .accent,
                              ),
                            ),
                            const SizedBox(
                              height:
                                  AppSpacing.sm,
                            ),
                            Text(
                              '5.00 USD',
                              style: theme
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: AppSpacing.lg,
                      ),

                      Text(
                        'Méthode de paiement',
                        style: theme
                            .textTheme.titleMedium
                            ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: AppSpacing.md,
                      ),

                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _method =
                                'mobile_money';
                          });
                        },
                        child: PaymentMethodCard(
                          name: 'Mobile Money',
                          description:
                              'M-Pesa, Airtel, Orange',
                          providerLogo:
                              'mobile_money',
                          selected: _method ==
                              'mobile_money',
                        ),
                      ),

                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _method = 'card';
                          });
                        },
                        child: PaymentMethodCard(
                          name:
                              'Carte Bancaire',
                          description:
                              'Visa, Mastercard',
                          providerLogo:
                              'card',
                          selected:
                              _method == 'card',
                        ),
                      ),

                      const SizedBox(
                        height: AppSpacing.lg,
                      ),

                      Text(
                        'Numéro Mobile Money',
                        style: theme
                            .textTheme.labelLarge
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),

                      const SizedBox(
                        height: AppSpacing.sm,
                      ),

                      TextField(
                        controller:
                            _mobileMoneyPhoneC,
                        keyboardType:
                            TextInputType.phone,
                        enabled:
                            _method ==
                                'mobile_money',
                        decoration:
                            InputDecoration(
                          hintText:
                              '812 345 678',
                          prefixIcon:
                              const Icon(
                            Icons.phone,
                          ),
                          filled: true,
                          fillColor: theme
                              .colorScheme
                              .surface,
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              AppRadius.md,
                            ),
                            borderSide:
                                BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: AppSpacing.xl,
                      ),

                      Container(
                        padding:
                            const EdgeInsets.all(
                          AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(
                            0xFF0A3D62,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            AppRadius.lg,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons
                                  .verified_user_rounded,
                              color:
                                  LightModeColors
                                      .accent,
                            ),
                            const SizedBox(
                              width:
                                  AppSpacing.md,
                            ),
                            Expanded(
                              child: Text(
                                'Transaction sécurisée AES-256',
                                style: theme
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color:
                                      Colors
                                          .white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: AppSpacing.xl,
                      ),

                      GestureDetector(
                        onTap: _isPaying
                            ? null
                            : _confirmPayment,
                        child:
                            AnimatedOpacity(
                          duration:
                              const Duration(
                            milliseconds:
                                180,
                          ),
                          opacity:
                              _isPaying
                                  ? 0.7
                                  : 1,
                          child: Container(
                            height: 58,
                            decoration:
                                BoxDecoration(
                              color:
                                  LightModeColors
                                      .accent,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                AppRadius.lg,
                              ),
                            ),
                            alignment:
                                Alignment
                                    .center,
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              children: [
                                if (_isPaying)
                                  ...[
                                    const SizedBox(
                                      width:
                                          18,
                                      height:
                                          18,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            2.2,
                                        color:
                                            Color(
                                          0xFF0A2F5C,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width:
                                          AppSpacing
                                              .md,
                                    ),
                                  ]
                                else ...[
                                  const Icon(
                                    Icons
                                        .lock_rounded,
                                    color:
                                        Color(
                                      0xFF0A2F5C,
                                    ),
                                  ),
                                  const SizedBox(
                                    width:
                                        AppSpacing
                                            .md,
                                  ),
                                ],
                                Text(
                                  _isPaying
                                      ? 'CONFIRMATION…'
                                      : 'CONFIRMER LE PAIEMENT',
                                  style: theme
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                    color:
                                        const Color(
                                      0xFF0A2F5C,
                                    ),
                                    fontWeight:
                                        FontWeight
                                            .w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: AppSpacing.lg,
                      ),

                      Center(
                        child: Text(
                          'THIX ID Secure Gateway',
                          style: theme
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                            color:
                                LightModeColors
                                    .secondaryText,
                          ),
                        ),
                      ),
                    ],
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

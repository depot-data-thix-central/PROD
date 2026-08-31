// lib/presentation/certification/providers/certification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/services/certification_service.dart';
import 'package:thix_id/services/bcc_exchange_rate_service.dart';
import 'package:thix_id/services/certification_payment_service.dart';


final certificationServiceProvider = Provider<CertificationService>((ref) {
  return CertificationService(Supabase.instance.client);
});

final myCertificationProvider = FutureProvider<CertificationInfo>((ref) async {
  return ref.watch(certificationServiceProvider).getMyCertification();
});

final bccRateServiceProvider = Provider<BccExchangeRateService>((ref) {
  return BccExchangeRateService(Supabase.instance.client);
});

final usdCdfRateProvider = FutureProvider<ExchangeRateQuote>((ref) {
  return ref.watch(bccRateServiceProvider).getUsdToCdf();
});

final certificationPaymentServiceProvider = Provider<CertificationPaymentService>((ref) {
  return CertificationPaymentService(Supabase.instance.client);
});

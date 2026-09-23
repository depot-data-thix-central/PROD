// lib/services/serdipay_service.dart
// Service Flutter pour les paiements SerdiPay (mobile money RDC)
// Tous les paiements passent par l'Edge Function Supabase (jamais en direct)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/serdipay_transaction.dart';

/// Résultat d'une initiation de paiement
class SerdipayPaymentResult {
  final bool success;
  final String status; // 'awaiting_payment' | 'paid' | 'failed'
  final String? transactionId;
  final String? serdiSessionId;
  final String? serdiTransactionId;
  final String? error;
  final Map<String, dynamic>? data;

  const SerdipayPaymentResult({
    required this.success,
    required this.status,
    this.transactionId,
    this.serdiSessionId,
    this.serdiTransactionId,
    this.error,
    this.data,
  });

  bool get needsWaiting => status == 'awaiting_payment';
  bool get isPaid => status == 'paid';
  bool get isFailed => status == 'failed';
}

class SerdiPayService {
  final SupabaseClient _client;

  SerDiPayService(this._client);

  /// Lance un paiement SerdiPay (mobile money)
  ///
  /// [type] : certification, market, ou event
  /// [referenceId] : ID de la ligne métier (certification_payments, market_orders, event_bookings)
  /// [amount] : montant à payer
  /// [currency] : CDF ou USD
  /// [telecom] : opérateur (AM, OM, MP, AF)
  /// [phoneNumber] : numéro du client
  Future<SerdipayPaymentResult> initiate({
    required SerdipayPaymentType type,
    required String referenceId,
    required double amount,
    required String currency,
    required SerdipayTelecom telecom,
    required String phoneNumber,
  }) async {
    try {
      // Validation côté client
      if (referenceId.isEmpty) {
        return const SerdipayPaymentResult(
          success: false,
          status: 'failed',
          error: 'Référence manquante',
        );
      }
      if (amount <= 0) {
        return const SerdipayPaymentResult(
          success: false,
          status: 'failed',
          error: 'Montant invalide',
        );
      }
      if (phoneNumber.length < 10) {
        return const SerdipayPaymentResult(
          success: false,
          status: 'failed',
          error: 'Numéro de téléphone invalide',
        );
      }

      debugPrint(
          '[SerdiPay] Initiating: type=${type.value}, ref=$referenceId, amount=$amount $currency, telecom=${telecom.value}');

      final response = await _client.functions.invoke(
        'serdipay-pay',
        body: {
          'type': type.value,
          'reference_id': referenceId,
          'amount': amount,
          'currency': currency,
          'telecom': telecom.value,
          'phone_number': phoneNumber,
        },
      );

      debugPrint('[SerdiPay] Response status: ${response.status}');
      debugPrint('[SerdiPay] Response data: ${response.data}');

      final data = response.data;
      final ok = response.status == 200 &&
          data != null &&
          data is Map &&
          data['success'] == true;

      if (ok) {
        return SerdipayPaymentResult(
          success: true,
          status: data['status']?.toString() ?? 'awaiting_payment',
          transactionId: data['transaction_id']?.toString(),
          serdiSessionId: data['serdi_session_id']?.toString(),
          serdiTransactionId: data['serdi_transaction_id']?.toString(),
          data: Map<String, dynamic>.from(data as Map),
        );
      }

      final err = (data is Map ? data['error']?.toString() : null) ??
          'Échec initiation paiement SerdiPay';

      return SerdipayPaymentResult(
        success: false,
        status: 'failed',
        error: err,
      );
    } catch (e) {
      debugPrint('❌ SerdiPayService.initiate: $e');
      return SerdipayPaymentResult(
        success: false,
        status: 'failed',
        error: e.toString(),
      );
    }
  }

  /// Récupère le statut actuel d'une transaction
  Future<SerdipayStatus> getStatus(String transactionId) async {
    try {
      final row = await _client
          .from('serdipay_transactions')
          .select('status')
          .eq('id', transactionId)
          .maybeSingle();

      final statusStr = row?['status']?.toString() ?? 'pending';
      return SerdipayStatus.fromString(statusStr);
    } catch (e) {
      debugPrint('❌ SerdiPayService.getStatus: $e');
      return SerdipayStatus.pending;
    }
  }

  /// Polling intelligent — attend la confirmation (timeout 2 min selon doc SerdiPay)
  Future<SerdipayStatus> waitForCompletion(
    String transactionId, {
    Duration timeout = const Duration(minutes: 2),
    Duration pollInterval = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final status = await getStatus(transactionId);

      if (status == SerdipayStatus.paid || status == SerdipayStatus.failed) {
        debugPrint('[SerdiPay] Transaction completed: $status');
        return status;
      }

      debugPrint('[SerdiPay] Still waiting... status=$status');
      await Future.delayed(pollInterval);
    }

    debugPrint('[SerdiPay] Timeout reached, returning processing');
    return SerdipayStatus.processing; // timeout
  }

  /// Historique des transactions d'un utilisateur
  Future<List<SerdipayTransaction>> getHistory({
    SerdipayPaymentType? type,
    SerdipayStatus? status,
    int limit = 50,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      var query = _client
          .from('serdipay_transactions')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      if (type != null) query = query.eq('type', type.value);
      if (status != null) query = query.eq('status', status.value);

      final rows = await query;
      return (rows as List).map((r) => SerdipayTransaction.fromJson(r)).toList();
    } catch (e) {
      debugPrint('❌ SerdiPayService.getHistory: $e');
      return [];
    }
  }

  /// Récupère une transaction par ID
  Future<SerdipayTransaction?> getById(String transactionId) async {
    try {
      final row = await _client
          .from('serdipay_transactions')
          .select('*')
          .eq('id', transactionId)
          .maybeSingle();

      if (row == null) return null;
      return SerdipayTransaction.fromJson(row);
    } catch (e) {
      debugPrint('❌ SerdiPayService.getById: $e');
      return null;
    }
  }
}

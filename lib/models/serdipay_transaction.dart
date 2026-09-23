// lib/models/serdipay_transaction.dart
// Modèle pour les transactions SerdiPay (mobile money DRC)

class SerdipayTransaction {
  final String id;
  final String userId;
  final SerdipayPaymentType type;
  final String referenceId;
  final double amount;
  final String currency;
  final SerdipayTelecom telecom;
  final String phoneNumber;
  final SerdipayStatus status;
  final String? serdiSessionId;
  final String? serdiTransactionId;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SerdipayTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.referenceId,
    required this.amount,
    required this.currency,
    required this.telecom,
    required this.phoneNumber,
    required this.status,
    this.serdiSessionId,
    this.serdiTransactionId,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  /// En attente de confirmation
  bool get isPending =>
      status == SerdipayStatus.pending || status == SerdipayStatus.processing;

  /// Paiement confirmé
  bool get isPaid => status == SerdipayStatus.paid;

  /// Paiement échoué
  bool get isFailed => status == SerdipayStatus.failed;

  factory SerdipayTransaction.fromJson(Map<String, dynamic> json) {
    return SerdipayTransaction(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      type: SerdipayPaymentType.fromString(json['type']?.toString() ?? 'market'),
      referenceId: json['reference_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'CDF',
      telecom: SerdipayTelecom.fromString(json['telecom']?.toString() ?? 'MP'),
      phoneNumber: json['phone_number']?.toString() ?? '',
      status: SerdipayStatus.fromString(json['status']?.toString() ?? 'pending'),
      serdiSessionId: json['serdi_session_id']?.toString(),
      serdiTransactionId: json['serdi_transaction_id']?.toString(),
      errorMessage: json['error_message']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.value,
      'reference_id': referenceId,
      'amount': amount,
      'currency': currency,
      'telecom': telecom.value,
      'phone_number': phoneNumber,
      'status': status.value,
      'serdi_session_id': serdiSessionId,
      'serdi_transaction_id': serdiTransactionId,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Type de paiement (certification, market, event)
enum SerdipayPaymentType {
  certification('certification'),
  market('market'),
  event('event');

  final String value;
  const SerdipayPaymentType(this.value);

  static SerdipayPaymentType fromString(String value) {
    return SerdipayPaymentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SerdipayPaymentType.market,
    );
  }

  String get displayName {
    switch (this) {
      case SerdipayPaymentType.certification:
        return 'Certification';
      case SerdipayPaymentType.market:
        return 'Achat Market';
      case SerdipayPaymentType.event:
        return 'Billet Événement';
    }
  }
}

/// Opérateur mobile money (RDC)
enum SerdipayTelecom {
  airtel('AM'),
  orange('OM'),
  mpesa('MP'),
  afrimoney('AF');

  final String value;
  const SerdipayTelecom(this.value);

  static SerdipayTelecom fromString(String value) {
    return SerdipayTelecom.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SerdipayTelecom.mpesa,
    );
  }

  String get displayName {
    switch (this) {
      case SerdipayTelecom.airtel:
        return 'Airtel Money';
      case SerdipayTelecom.orange:
        return 'Orange Money';
      case SerdipayTelecom.mpesa:
        return 'M-Pesa';
      case SerdipayTelecom.afrimoney:
        return 'Afrimoney';
    }
  }

  /// Méthodes UI courantes → telecom
  static SerdipayTelecom fromPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'airtel':
      case 'airtel_money':
        return SerdipayTelecom.airtel;
      case 'orange_money':
      case 'orange':
        return SerdipayTelecom.orange;
      case 'afrimoney':
      case 'afrimomo':
        return SerdipayTelecom.afrimoney;
      case 'mpesa':
      default:
        return SerdipayTelecom.mpesa;
    }
  }
}

/// Statut de la transaction
enum SerdipayStatus {
  pending('pending'),
  processing('processing'),
  paid('paid'),
  failed('failed');

  final String value;
  const SerdipayStatus(this.value);

  static SerdipayStatus fromString(String value) {
    return SerdipayStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SerdipayStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case SerdipayStatus.pending:
        return 'En attente';
      case SerdipayStatus.processing:
        return 'En cours';
      case SerdipayStatus.paid:
        return 'Payé';
      case SerdipayStatus.failed:
        return 'Échoué';
    }
  }
}

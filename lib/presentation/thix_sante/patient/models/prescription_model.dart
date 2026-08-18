// lib/presentation/thix_sante/patient/models/prescription_model.dart
// =============================================================================
// Model: PrescriptionModel + PrescriptionItem
// Role: Ordonnance digitale verifiable par QR code, envoyable a la pharmacie
// Fonctionnalite moderne: QR hash, suivi statut, items detailles
// =============================================================================

import 'package:flutter/foundation.dart';

enum PrescriptionStatus {
  prescrite,
  envoyee,
  preparee,
  delivree,
  expiree;

  static PrescriptionStatus fromString(String? v) {
    switch (v) {
      case 'envoyee':
        return PrescriptionStatus.envoyee;
      case 'preparee':
        return PrescriptionStatus.preparee;
      case 'delivree':
        return PrescriptionStatus.delivree;
      case 'expiree':
        return PrescriptionStatus.expiree;
      default:
        return PrescriptionStatus.prescrite;
    }
  }

  String get label {
    switch (this) {
      case PrescriptionStatus.prescrite:
        return 'Prescrite';
      case PrescriptionStatus.envoyee:
        return 'Envoyee pharmacie';
      case PrescriptionStatus.preparee:
        return 'Prete';
      case PrescriptionStatus.delivree:
        return 'Delivree';
      case PrescriptionStatus.expiree:
        return 'Expiree';
    }
  }
}

/// Item medicament dans une ordonnance.
@immutable
class PrescriptionItem {
  final String medicament;
  final String posologie;
  final String duree;
  final String? quantite;
  final String? instructions;

  const PrescriptionItem({
    required this.medicament,
    required this.posologie,
    required this.duree,
    this.quantite,
    this.instructions,
  });

  factory PrescriptionItem.fromJson(Map<String, dynamic> json) {
    return PrescriptionItem(
      medicament: json['medicament'] as String,
      posologie: json['posologie'] as String,
      duree: json['duree'] as String,
      quantite: json['quantite'] as String?,
      instructions: json['instructions'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'medicament': medicament,
        'posologie': posologie,
        'duree': duree,
        'quantite': quantite,
        'instructions': instructions,
      };
}

/// Ordonnance complete, verifiable par QR.
@immutable
class PrescriptionModel {
  final String id;
  final String patientUid;
  final String patientThixId;
  final String doctorUid;
  final String doctorThixId;
  final String? pharmacyUid;
  final String consultationId;
  final List<PrescriptionItem> items;
  final PrescriptionStatus status;
  final String qrHash;
  final String? doctorSignatureUrl;
  final String? doctorName;
  final DateTime createdAt;
  final DateTime? expiryDate;
  final String? notes;

  const PrescriptionModel({
    required this.id,
    required this.patientUid,
    required this.patientThixId,
    required this.doctorUid,
    required this.doctorThixId,
    this.pharmacyUid,
    required this.consultationId,
    required this.items,
    required this.status,
    required this.qrHash,
    this.doctorSignatureUrl,
    this.doctorName,
    required this.createdAt,
    this.expiryDate,
    this.notes,
  });

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawItems = json['items'] as List<dynamic>? ?? [];
    return PrescriptionModel(
      id: json['id'] as String,
      patientUid: json['patient_uid'] as String,
      patientThixId: json['patient_thix_id'] as String,
      doctorUid: json['doctor_uid'] as String,
      doctorThixId: json['doctor_thix_id'] as String,
      pharmacyUid: json['pharmacy_uid'] as String?,
      consultationId: json['consultation_id'] as String,
      items: rawItems
         .map((e) => PrescriptionItem.fromJson(e as Map<String, dynamic>))
         .toList(),
      status: PrescriptionStatus.fromString(json['status'] as String?),
      qrHash: json['qr_hash'] as String? ?? '',
      doctorSignatureUrl: json['doctor_signature_url'] as String?,
      doctorName: json['doctor_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiryDate: json['expiry_date']!= null
         ? DateTime.tryParse(json['expiry_date'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'patient_uid': patientUid,
        'patient_thix_id': patientThixId,
        'doctor_uid': doctorUid,
        'doctor_thix_id': doctorThixId,
        'pharmacy_uid': pharmacyUid,
        'consultation_id': consultationId,
        'items': items.map((e) => e.toJson()).toList(),
        'status': status.name,
        'qr_hash': qrHash,
        'notes': notes,
        'expiry_date': expiryDate?.toIso8601String(),
      };

  bool get isExpired =>
      expiryDate!= null && DateTime.now().isAfter(expiryDate!);
  bool get canSendToPharmacy => status == PrescriptionStatus.prescrite;
  int get medicamentCount => items.length;

  String get qrVerificationUrl => 'https://thix.id/verify/prescription/$qrHash';
}

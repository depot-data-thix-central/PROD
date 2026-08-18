import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prescription_model.dart';

class PrescriptionService {
  PrescriptionService({SupabaseClient? client}) : _db = client ?? Supabase.instance.client;
  final SupabaseClient _db;
  static const String _table = 'prescriptions';

  String _generateQrHash(String patientThixId, String doctorThixId) {
    final raw = '$patientThixId-$doctorThixId-${DateTime.now().millisecondsSinceEpoch}-${Random.secure().nextInt(999999)}';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 16).toUpperCase();
  }

  Future<List<PrescriptionModel>> getMyPrescriptions() async {
    final uid = _db.auth.currentUser!.id;
    // CORRECTION: patient_uid -> patient_id
    final List data = await _db.from(_table).select().eq('patient_id', uid).order('created_at', ascending: false);
    return data.map((e) => PrescriptionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Stream<List<PrescriptionModel>> watchActivePrescriptions() {
    final uid = _db.auth.currentUser!.id;
    // CORRECTION: patient_uid -> patient_id
    return _db.from(_table).stream(primaryKey: ['id']).eq('patient_id', uid).map((rows) => rows
       .map((e) => PrescriptionModel.fromJson(e as Map<String, dynamic>))
       .where((p) => p.status != PrescriptionStatus.delivree && p.status != PrescriptionStatus.expiree)
       .toList());
  }

  Future<PrescriptionModel> createPrescription({
    required String patientUid, // Ceci est la valeur (le GUID), le nom de la colonne est patient_id
    required String patientThixId,
    required String consultationId,
    required List<PrescriptionItem> items,
    String? notes,
    DateTime? expiryDate,
  }) async {
    final user = _db.auth.currentUser!;
    final myProfile = await _db.from('profiles').select('thix_id, full_name').eq('uid', user.id).single();
    final qrHash = _generateQrHash(patientThixId, myProfile['thix_id'] as String);
    
    final payload = {
      'patient_id': patientUid, // CORRECTION: patient_uid -> patient_id
      'patient_thix_id': patientThixId,
      'doctor_uid': user.id,
      'doctor_thix_id': myProfile['thix_id'],
      'doctor_name': myProfile['full_name'],
      'consultation_id': consultationId,
      'items': items.map((e) => e.toJson()).toList(),
      'status': PrescriptionStatus.prescrite.name,
      'qr_hash': qrHash,
      'notes': notes,
      'expiry_date': expiryDate?.toIso8601String() ?? DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    };
    final inserted = await _db.from(_table).insert(payload).select().single();
    return PrescriptionModel.fromJson(inserted);
  }

  Future<void> sendToPharmacy({required String prescriptionId, required String pharmacyThixId}) async {
    final String clean = pharmacyThixId.trim().toUpperCase();
    final pharmacy = await _db.from('profiles').select('uid').eq('thix_id', clean).eq('role', 'pharmacy').maybeSingle();
    if (pharmacy == null) throw Exception('Pharmacie introuvable avec THIX ID: $pharmacyThixId');
    
    // CORRECTION: patient_uid -> patient_id
    await _db.from(_table)
      .update({'pharmacy_uid': pharmacy['uid'], 'status': PrescriptionStatus.envoyee.name})
      .eq('id', prescriptionId)
      .eq('patient_id', _db.auth.currentUser!.id);
  }

  Future<PrescriptionModel?> verifyByQrHash(String qrHash) async {
    final data = await _db.from(_table).select().eq('qr_hash', qrHash.toUpperCase()).maybeSingle();
    if (data == null) return null;
    return PrescriptionModel.fromJson(data);
  }

  Future<int> countActive() async {
    final uid = _db.auth.currentUser!.id;
    // CORRECTION: patient_uid -> patient_id
    final List res = await _db.from(_table).select('id').eq('patient_id', uid).neq('status', 'delivree');
    return res.length;
  }
}

// lib/presentation/education/services/certificate_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/education/models/certificate.dart';

class CertificateService {
  CertificateService._();
  static final instance = CertificateService._();

  final _db = Supabase.instance.client;

  /// Émet un certificat si la formation est certifiante et pas déjà délivré.
  Future<Certificate?> issueIfNeeded({
    required String userId,
    required String formationId,
    String? enrollmentId,
  }) async {
    // Déjà émis ?
    final existing = await _db
        .from('certificates')
        .select()
        .eq('user_id', userId)
        .eq('formation_id', formationId)
        .maybeSingle();
    if (existing != null) return Certificate.fromJson(existing);

    // Formation
    final formation = await _db.from('formations').select('''
          id, title, is_certifying, instructor_id, created_by, user_id,
          instructor_name, organized_by, provider,
          certificate_template_id, certificate_header, certificate_body,
          certificate_footer, certificate_logo_url, certificate_signature_url,
          certificate_signatory_name, certificate_signatory_title
        ''').eq('id', formationId).maybeSingle();

    if (formation == null || formation['is_certifying'] != true) {
      return null; // pas certifiant
    }

    // Nom apprenant (compte)
    final learner = await _db
        .from('profiles')
        .select('full_name, first_name, last_name, email')
        .eq('id', userId)
        .maybeSingle();

    final learnerName = _resolvePersonName(learner) ??
        (learner?['email'] as String?)?.split('@').first ??
        'Apprenant';

    // Académie = formateur
    final instructorId = formation['instructor_id'] as String? ??
        formation['created_by'] as String? ??
        formation['user_id'] as String?;

    Map<String, dynamic>? academy;
    if (instructorId != null) {
      academy = await _db
          .from('profiles')
          .select(
            'full_name, academy_name, academy_logo_url, signature_url, signatory_title',
          )
          .eq('id', instructorId)
          .maybeSingle();
    }

    final academyName = (academy?['academy_name'] as String?)?.trim().isNotEmpty == true
        ? academy!['academy_name'] as String
        : (formation['instructor_name'] as String?)?.trim().isNotEmpty == true
            ? formation['instructor_name'] as String
            : (formation['organized_by'] as String?)?.trim().isNotEmpty == true
                ? formation['organized_by'] as String
                : (formation['provider'] as String?)?.trim().isNotEmpty == true
                    ? formation['provider'] as String
                    : (academy?['full_name'] as String?) ?? 'THIX Academy';

    final serial = _genSerial();
    final issuedAt = DateTime.now().toUtc();
    final hash = _secureHash(
      '$userId|$formationId|\( serial| \){issuedAt.toIso8601String()}|$learnerName|$academyName',
    );

    final row = await _db.from('certificates').insert({
      'user_id': userId,
      'formation_id': formationId,
      if (enrollmentId != null) 'enrollment_id': enrollmentId,
      'issued_at': issuedAt.toIso8601String(),
      'verification_hash': hash,
      'serial_number': serial,
      'issued_to_name': learnerName,
      'template_id':
          formation['certificate_template_id'] ?? 'classic_navy',
    }).select().single();

    return Certificate.fromJson(row);
  }

  String? _resolvePersonName(Map<String, dynamic>? p) {
    if (p == null) return null;
    final full = (p['full_name'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;
    final parts = [
      p['first_name'],
      p['last_name'],
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty);
    final joined = parts.join(' ');
    return joined.isEmpty ? null : joined;
  }

  String _genSerial() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    final code =
        List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
    final year = DateTime.now().year;
    return 'THIX-CERT-$year-$code';
  }

  String _secureHash(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}

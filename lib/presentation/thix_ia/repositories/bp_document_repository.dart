import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/thix_bp_document.dart';
import '../services/bp_post_process_service.dart';

abstract class BpDocumentRepository {
  Future<ThixBpDocument?> getLatestDocument(String projectCode);
  Future<ThixBpDocument> updateSections(
      String docId, Map<String, dynamic> sections);
  Future<ThixBpDocument> recompileAndUploadPdf(
    String projectCode,
    String docId,
    Map<String, dynamic> sections,
  );
}

final bpDocumentRepositoryProvider = Provider<BpDocumentRepository>((ref) {
  return BpDocumentRepositoryImpl(Supabase.instance.client);
});

class BpDocumentRepositoryImpl implements BpDocumentRepository {
  BpDocumentRepositoryImpl(this._supabase);
  final SupabaseClient _supabase;

  static const _bucket = 'thix-documents';

  @override
  Future<ThixBpDocument?> getLatestDocument(String projectCode) async {
    final res = await _supabase
        .from('thix_bp_documents')
        .select()
        .eq('project_code', projectCode)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return ThixBpDocument.fromJson(Map<String, dynamic>.from(res));
  }

  @override
  Future<ThixBpDocument> updateSections(
    String docId,
    Map<String, dynamic> sections,
  ) async {
    final res = await _supabase
        .from('thix_bp_documents')
        .update({
          'sections': sections,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', docId)
        .select()
        .single();
    return ThixBpDocument.fromJson(Map<String, dynamic>.from(res));
  }

  @override
  Future<ThixBpDocument> recompileAndUploadPdf(
    String projectCode,
    String docId,
    Map<String, dynamic> sections,
  ) async {
    final Uint8List pdfBytes = await BpPostProcessService().buildA4Pdf(
      projectCode: projectCode,
      title: sections['title']?.toString() ?? 'Business Plan',
      sections: sections,
    );

    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$projectCode/business_plans/BP_$ts.pdf';

    await _supabase.storage.from(_bucket).uploadBinary(
          path,
          pdfBytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );

    final publicUrl = _supabase.storage.from(_bucket).getPublicUrl(path);

    final res = await _supabase
        .from('thix_bp_documents')
        .update({
          'pdf_path': path,
          'pdf_url': publicUrl,
          'pdf_size': pdfBytes.length,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', docId)
        .select()
        .single();

    try {
      await _supabase.from('project_documents').insert({
        'project_code': projectCode,
        'file_name': 'Business_Plan_A4.pdf',
        'file_path': path,
        'file_type': 'pdf',
        'file_size': pdfBytes.length,
        'mime_type': 'application/pdf',
        'status': 'indexed',
        'summary': 'Business Plan A4 (recompilé)',
      });
    } catch (_) {}

    return ThixBpDocument.fromJson(Map<String, dynamic>.from(res));
  }
}

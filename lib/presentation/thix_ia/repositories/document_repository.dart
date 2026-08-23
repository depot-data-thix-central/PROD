// lib/presentation/thix_ia/repositories/document_repository.dart
import '../datasources/thix_ia_remote_datasource.dart';
import '../models/document.dart';
import '../core/errors/thix_ia_exception.dart';

/// ============================================================================
/// DOCUMENT REPOSITORY - Upload S3 + Indexation RAG
/// ============================================================================

abstract class DocumentRepository {
  Future<List<ProjectDocument>> getDocuments(String projectCode);
  Future<ProjectDocument> uploadDocument({required String projectCode, required String fileName, required List<int> bytes, required String mimeType});
  Future<void> deleteDocument(String documentId);
}

class DocumentRepositoryImpl implements DocumentRepository {
  DocumentRepositoryImpl(this.remote);

  final ThixIaRemoteDatasource remote;

  @override
  Future<List<ProjectDocument>> getDocuments(String projectCode) async {
    return remote.getDocuments(projectCode);
  }

  @override
  Future<ProjectDocument> uploadDocument({required String projectCode, required String fileName, required List<int> bytes, required String mimeType}) async {
    if (bytes.length > 25 * 1024 * 1024) {
      throw const ThixIADocumentException(message: 'Fichier trop volumineux (max 25MB)');
    }

    // 1. Upload vers Supabase Storage
    final fileUrl = await remote.uploadFile(projectCode, fileName, bytes, mimeType);

    // 2. Crée l'entrée DB
    final doc = await remote.createDocument({
      'project_code': projectCode,
      'file_name': fileName,
      'file_path': fileUrl,
      'file_type': fileName.split('.').last.toLowerCase(),
      'file_size': bytes.length,
      'mime_type': mimeType,
      'status': 'processing',
    });

    return doc;
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    // Implémenté Phase 2 avec RLS + storage delete
    throw UnimplementedError();
  }
}

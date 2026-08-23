// lib/presentation/thix_ia/services/document_service.dart
import 'dart:typed_data';
import '../datasources/thix_ia_remote_datasource.dart';
import '../models/document.dart';

class DocumentService {
  DocumentService(this._remote);
  final ThixIaRemoteDatasource _remote;

  // GET ALL DOCUMENTS FOR PROJECT
  Future<List<ProjectDocument>> getDocuments(String projectCode) async {
    try {
      final rows = await _remote.getDocuments(projectCode);
      return rows.map((e) => ProjectDocument.fromJson(e)).toList()
        ..sort((a, b) => (b.createdAt?? DateTime.now()).compareTo(a.createdAt?? DateTime.now()));
    } catch (e) {
      throw Exception('getDocuments failed: $e');
    }
  }

  // GET SINGLE DOCUMENT
  Future<ProjectDocument?> getDocument(String docId) async {
    try {
      final row = await _remote.getDocument(docId);
      if (row == null) return null;
      return ProjectDocument.fromJson(row);
    } catch (e) {
      throw Exception('getDocument $docId failed: $e');
    }
  }

  // UPLOAD DOCUMENT + SUPABASE STORAGE + RAG INDEXATION
  Future<ProjectDocument> upload({
    required String projectCode,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? description,
  }) async {
    try {
      // 1. Upload to Supabase Storage via datasource
      final storagePath = await _remote.uploadDocumentFile(
        projectCode: projectCode,
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
      );

      // 2. Insert row thix_documents
      final row = await _remote.insertDocument({
        'project_code': projectCode,
        'file_name': fileName,
        'file_type': fileName.split('.').last.toLowerCase(),
        'file_size': bytes.length,
        'mime_type': mimeType,
        'storage_path': storagePath,
        'status': 'processing',
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 3. Trigger RAG indexing Edge Function (async)
      await _remote.triggerDocumentIndexing(
        documentId: row['id'],
        projectCode: projectCode,
        storagePath: storagePath,
      );

      return ProjectDocument.fromJson(row);
    } catch (e) {
      throw Exception('upload $fileName failed: $e');
    }
  }

  // DELETE DOCUMENT + STORAGE + CHUNKS
  Future<void> delete(String docId) async {
    try {
      await _remote.deleteDocument(docId);
    } catch (e) {
      throw Exception('delete $docId failed: $e');
    }
  }

  // GET CHUNKS FOR RAG
  Future<List<DocumentChunk>> getChunks(String docId) async {
    try {
      final rows = await _remote.getDocumentChunks(docId);
      return rows.map((e) => DocumentChunk.fromJson(e)).toList();
    } catch (e) {
      throw Exception('getChunks $docId failed: $e');
    }
  }

  // SEARCH CHUNKS (RAG QUERY)
  Future<List<DocumentChunk>> searchChunks({
    required String projectCode,
    required String query,
    int limit = 10,
  }) async {
    try {
      final rows = await _remote.searchDocumentChunks(
        projectCode: projectCode,
        query: query,
        limit: limit,
      );
      return rows.map((e) => DocumentChunk.fromJson(e)).toList();
    } catch (e) {
      throw Exception('searchChunks failed: $e');
    }
  }

  // GET DOCUMENTS STATUS STATS
  Future<Map<String, int>> getStats(String projectCode) async {
    final docs = await getDocuments(projectCode);
    return {
      'total': docs.length,
      'indexed': docs.where((d) => d.isIndexed).length,
      'processing': docs.where((d) => d.status == DocumentStatus.processing).length,
      'failed': docs.where((d) => d.status == DocumentStatus.failed).length,
      'totalChunks': docs.fold(0, (sum, d) => sum + d.chunksCount),
    };
  }

  // RETRY FAILED INDEXING
  Future<void> retryIndexing(String docId) async {
    try {
      await _remote.retryDocumentIndexing(docId);
    } catch (e) {
      throw Exception('retryIndexing $docId failed: $e');
    }
  }
}

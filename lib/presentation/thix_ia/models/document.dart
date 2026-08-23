// lib/presentation/thix_ia/models/document.dart
import 'package:equatable/equatable.dart';
import '../core/utils/json_utils.dart';

/// ============================================================================
/// DOCUMENTS - Tables: project_documents + document_chunks + S3 Storage
/// ============================================================================

enum DocumentStatus { uploading, processing, indexed, failed }

extension DocumentStatusParser on String {
  DocumentStatus toDocStatus() {
    switch (toLowerCase()) {
      case 'uploading': return DocumentStatus.uploading;
      case 'processing': return DocumentStatus.processing;
      case 'indexed': return DocumentStatus.indexed;
      case 'failed': return DocumentStatus.failed;
      default: return DocumentStatus.uploading;
    }
  }
}

class ProjectDocument extends Equatable {
  const ProjectDocument({
    required this.id,
    required this.projectCode,
    required this.fileName,
    required this.filePath, // Supabase Storage path
    required this.fileType, // pdf, docx, xlsx, image
    this.fileSize = 0,
    this.mimeType,
    this.status = DocumentStatus.uploading,
    this.extractedText,
    this.summary,
    this.chunksCount = 0,
    this.uploadedBy,
    this.createdAt,
    this.indexedAt,
  });

  final String id; // uuid
  final String projectCode;
  final String fileName;
  final String filePath; // bucket/project_code/filename
  final String fileType;
  final int fileSize;
  final String? mimeType;
  final DocumentStatus status;
  final String? extractedText;
  final String? summary;
  final int chunksCount;
  final String? uploadedBy;
  final DateTime? createdAt;
  final DateTime? indexedAt;

  bool get isIndexed => status == DocumentStatus.indexed;
  bool get isPdf => fileType.toLowerCase() == 'pdf';
  bool get isSpreadsheet => ['xlsx', 'xls', 'csv'].contains(fileType.toLowerCase());

  factory ProjectDocument.fromJson(Map<String, dynamic> json) => ProjectDocument(
        id: JsonUtils.stringValue(json, 'id'),
        projectCode: JsonUtils.stringValue(json, 'project_code'),
        fileName: JsonUtils.stringValue(json, 'file_name'),
        filePath: JsonUtils.stringValue(json, 'file_path'),
        fileType: JsonUtils.stringValue(json, 'file_type', fallback: 'pdf'),
        fileSize: JsonUtils.intValue(json, 'file_size'),
        mimeType: JsonUtils.stringValue(json, 'mime_type'),
        status: JsonUtils.stringValue(json, 'status', fallback: 'uploading').toDocStatus(),
        extractedText: JsonUtils.stringValue(json, 'extracted_text'),
        summary: JsonUtils.stringValue(json, 'summary'),
        chunksCount: JsonUtils.intValue(json, 'chunks_count'),
        uploadedBy: JsonUtils.stringValue(json, 'uploaded_by'),
        createdAt: JsonUtils.dateTimeValue(json, 'created_at'),
        indexedAt: JsonUtils.dateTimeValue(json, 'indexed_at'),
      );

  Map<String, dynamic> toSupabase() => JsonUtils.cleanNulls({
        'project_code': projectCode,
        'file_name': fileName,
        'file_path': filePath,
        'file_type': fileType,
        'file_size': fileSize,
        'mime_type': mimeType,
        'status': status.name,
        'extracted_text': extractedText,
        'summary': summary,
        'chunks_count': chunksCount,
        'uploaded_by': uploadedBy,
      });

  ProjectDocument copyWith({DocumentStatus? status, int? chunksCount, String? summary}) {
    return ProjectDocument(
      id: id,
      projectCode: projectCode,
      fileName: fileName,
      filePath: filePath,
      fileType: fileType,
      fileSize: fileSize,
      mimeType: mimeType,
      status: status?? this.status,
      extractedText: extractedText,
      summary: summary?? this.summary,
      chunksCount: chunksCount?? this.chunksCount,
      uploadedBy: uploadedBy,
      createdAt: createdAt,
      indexedAt: indexedAt,
    );
  }

  @override
  List<Object?> get props => [id, projectCode, status, filePath];
}

class DocumentChunk extends Equatable {
  const DocumentChunk({
    required this.id,
    required this.documentId,
    required this.projectCode,
    required this.chunkIndex,
    required this.content,
    this.embedding, // pgvector - pas stocké côté Flutter
    this.tokenCount = 0,
    this.metadata = const {},
  });

  final String id;
  final String documentId;
  final String projectCode;
  final int chunkIndex;
  final String content;
  final List<double>? embedding;
  final int tokenCount;
  final Map<String, dynamic> metadata;

  factory DocumentChunk.fromJson(Map<String, dynamic> json) => DocumentChunk(
        id: JsonUtils.stringValue(json, 'id'),
        documentId: JsonUtils.stringValue(json, 'document_id'),
        projectCode: JsonUtils.stringValue(json, 'project_code'),
        chunkIndex: JsonUtils.intValue(json, 'chunk_index'),
        content: JsonUtils.stringValue(json, 'content'),
        tokenCount: JsonUtils.intValue(json, 'token_count'),
        metadata: JsonUtils.asMap(json['metadata']),
      );

  Map<String, dynamic> toSupabase() => {
        'document_id': documentId,
        'project_code': projectCode,
        'chunk_index': chunkIndex,
        'content': content,
        'token_count': tokenCount,
        'metadata': metadata,
      };

  @override
  List<Object?> get props => [id, documentId, chunkIndex];
}

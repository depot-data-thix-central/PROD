import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/services/document_service.dart';
import 'vault_state.dart';

// Services
final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService();
});

// User
final currentUserProvider = Provider<String?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth.currentUser?.id;
});

final currentUserThixIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth.currentUser?.thixId;
});

// State
final vaultStateProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  return VaultNotifier(ref);
});

class VaultNotifier extends StateNotifier<VaultState> {
  final Ref ref;
  
  VaultNotifier(this.ref) : super(const VaultState()) {
    _init();
  }

  DocumentService get _docs => ref.read(documentServiceProvider);
  String? get _uid => ref.read(currentUserProvider);
  String? get _thixId => ref.read(currentUserThixIdProvider);

  void _init() {
    if (_uid == null) return;
    
    // Stream documents
    _docs.streamDocuments(_uid!).listen((docs) {
      state = state.copyWith(documents: docs);
    });

    // Stream folders
    _docs.streamFolders(_uid!).listen((folders) {
      state = state.copyWith(folders: folders);
    });

    // Stream sent shares
    _docs.streamSentShares(_uid!).listen((shares) {
      state = state.copyWith(sentShares: shares);
    });

    // Stream received shares
    if (_thixId != null) {
      _docs.streamReceivedShares(_uid!, _thixId!).listen((shares) {
        state = state.copyWith(receivedShares: shares);
      });
    }

    // Stream audit log
    _docs.streamTransactions(_uid!).listen((log) {
      state = state.copyWith(auditLog: log);
    });
  }

  void setFolderFilter(String? folderId) {
    state = state.copyWith(folderFilter: folderId);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.toLowerCase());
  }

  List<Map<String, dynamic>> get filteredDocuments {
    var docs = state.documents;
    
    if (state.folderFilter != null) {
      docs = docs.where((d) => d['folder_id'] == state.folderFilter).toList();
    }
    
    if (state.searchQuery.isNotEmpty) {
      docs = docs.where((d) {
        final title = (d['title'] ?? '').toString().toLowerCase();
        final docType = (d['doc_type'] ?? '').toString().toLowerCase();
        final docId = (d['generated_doc_id'] ?? '').toString().toLowerCase();
        return title.contains(state.searchQuery) || 
               docType.contains(state.searchQuery) ||
               docId.contains(state.searchQuery);
      }).toList();
    }
    
    return docs;
  }

  Future<void> createFolder(String name) async {
    if (_uid == null) return;
    await _docs.createFolder(uid: _uid!, name: name);
  }

  Future<String> uploadDocument({
    required dynamic file,
    required String docType,
    String? title,
    DateTime? expiresAt,
    String? folderId,
  }) async {
    if (_uid == null) throw Exception('Non connecté');
    
    state = state.copyWith(isUploading: true, error: null);
    try {
      final id = await _docs.uploadPickedFileSimple(
        uid: _uid!,
        file: file,
        docType: docType,
        expiresAt: expiresAt,
        title: title,
        folderId: folderId,
        isPublic: false,
      );
      state = state.copyWith(isUploading: false);
      return id;
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> sendDocument({
    required String documentId,
    required String docIdLabel,
    required List<String> recipients,
    String? subject,
    String? body,
    String? password,
    DateTime? availableFrom,
    Duration? autoDestructIn,
  }) async {
    if (_uid == null) throw Exception('Non connecté');
    
    state = state.copyWith(isSending: true, error: null);
    try {
      await _docs.shareDocument(
        senderId: _uid!,
        documentId: documentId,
        docId: docIdLabel,
        recipientThixIds: recipients,
        subject: subject,
        body: body,
        password: password,
        availableFrom: availableFrom,
        autoDestructIn: autoDestructIn,
      );
      state = state.copyWith(isSending: false);
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteDocument({
    required String documentId,
    required String storagePath,
    required String docId,
  }) async {
    if (_uid == null) return;
    await _docs.deleteDocument(
      uid: _uid!,
      documentId: documentId,
      storagePath: storagePath,
      docId: docId,
    );
  }

  Future<void> togglePublic({
    required String documentId,
    required String docId,
    required bool isPublic,
  }) async {
    if (_uid == null) return;
    await _docs.togglePublic(
      uid: _uid!,
      documentId: documentId,
      docId: docId,
      isPublic: isPublic,
    );
  }

  Future<Map<String, dynamic>?> searchPublicDocument(String query) async {
    return await _docs.searchPublicDocument(query);
  }

  Future<String?> resolveDownloadUrl(Map<String, dynamic> row) async {
    try {
      return await _docs.resolveRowDownloadUrl(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> openShare(Map<String, dynamic> share) async {
    final shareId = share['id']?.toString();
    final documentId = share['document_id']?.toString();
    
    if (shareId == null || documentId == null) return;

    try {
      final docRow = await _docs.fetchDocumentById(documentId);
      if (docRow == null) throw Exception('Document introuvable');
      
      await _docs.markShareOpened(
        shareId,
        uid: docRow['user_id']?.toString(),
        docId: docRow['generated_doc_id']?.toString(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> verifySharePassword(String password, String hash) async {
    return await _docs.verifyPassword(password: password, hash: hash);
  }

  Future<void> markShareDestroyed(String shareId) async {
    await _docs.markShareDestroyed(shareId);
  }

  Future<Map<String, dynamic>?> verifyThixId(String thixId) async {
    return await _docs.verifyThixId(thixId);
  }
}

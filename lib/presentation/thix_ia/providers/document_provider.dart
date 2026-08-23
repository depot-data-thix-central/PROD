// lib/presentation/thix_ia/providers/document_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document.dart';
import '../repositories/document_repository.dart';
import 'thix_ia_provider.dart';
import 'active_project_provider.dart';

/// ============================================================================
/// DOCUMENT PROVIDER - Upload + Liste + RAG ready
/// ============================================================================

class DocumentsNotifier extends AsyncNotifier<List<ProjectDocument>> {
  @override
  Future<List<ProjectDocument>> build() async {
    final code = ref.watch(activeProjectCodeProvider);
    if (code == null) return [];
    final repo = ref.watch(documentRepositoryProvider);
    return repo.getDocuments(code);
  }

  Future<void> refresh() async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(documentRepositoryProvider);
      return repo.getDocuments(code);
    });
  }

  Future<ProjectDocument> upload({required String fileName, required List<int> bytes, required String mimeType}) async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) throw Exception('Aucun projet actif');

    // Optimistic loading
    final repo = ref.read(documentRepositoryProvider);
    final doc = await repo.uploadDocument(projectCode: code, fileName: fileName, bytes: bytes, mimeType: mimeType);

    final current = state.value?? [];
    state = AsyncData([doc,...current]);
    return doc;
  }

  List<ProjectDocument> get pdfs => (state.value?? []).where((d) => d.isPdf).toList();
  List<ProjectDocument> get indexed => (state.value?? []).where((d) => d.isIndexed).toList();
}

final documentsProvider = AsyncNotifierProvider<DocumentsNotifier, List<ProjectDocument>>(() {
  return DocumentsNotifier();
});

final documentsCountProvider = Provider<int>((ref) {
  return ref.watch(documentsProvider).value?.length?? 0;
});

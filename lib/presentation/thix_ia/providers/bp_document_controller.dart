import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/thix_bp_document.dart';
import '../repositories/bp_document_repository.dart';

class BpDocumentController
    extends AutoDisposeFamilyAsyncNotifier<ThixBpDocument?, String> {
  late String _projectCode;

  @override
  Future<ThixBpDocument?> build(String projectCode) async {
    _projectCode = projectCode;
    return ref.read(bpDocumentRepositoryProvider).getLatestDocument(projectCode);
  }

  /// Sauvegarde texte seulement (rapide)
  Future<void> saveSections(Map<String, dynamic> sections) async {
    final current = state.value;
    if (current == null) return;

    final updated = await ref
        .read(bpDocumentRepositoryProvider)
        .updateSections(current.id, sections);

    state = AsyncData(updated);
  }

  /// Sauvegarde + recompile PDF (bouton explicite)
  Future<void> saveAndRecompile(Map<String, dynamic> sections) async {
    final current = state.value;
    if (current == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final saved = await ref
          .read(bpDocumentRepositoryProvider)
          .updateSections(current.id, sections);
      return ref.read(bpDocumentRepositoryProvider).recompileAndUploadPdf(
            _projectCode,
            saved.id,
            saved.sections,
          );
    });
  }
}

final bpDocumentControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    BpDocumentController, ThixBpDocument?, String>(BpDocumentController.new);

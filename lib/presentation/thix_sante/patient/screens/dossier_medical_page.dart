// lib/presentation/thix_sante/patient/screens/dossier_medical_page.dart
// =============================================================================
// Screen: DossierMedicalPage - Service Rapide 2
// Role: Dossier medical complet avec upload photo, PDF, radio, ordonnance
// Fonctionnalites modernes: Upload image/camera, preview PDF, filtre type
// =============================================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/thix_id_validator.dart';
import '../../core/thix_sante_colors.dart';
import '../providers/patient_dashboard_provider.dart';
import '../models/health_record_model.dart';
import '../services/health_record_service.dart';

class DossierMedicalPage extends ConsumerStatefulWidget {
  const DossierMedicalPage({super.key});
  @override
  ConsumerState<DossierMedicalPage> createState() => _DossierMedicalPageState();
}

class _DossierMedicalPageState extends ConsumerState<DossierMedicalPage> {
  RecordType? _filter;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    await _upload(
      title: 'Radio ${DateTime.now().day}/${DateTime.now().month}',
      type: RecordType.radiologie,
      fileName: file.name,
      bytes: bytes,
      mime: 'image/jpeg',
    );
  }

  Future<void> _pickPdf() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.first.bytes == null) return;
    final f = result.files.first;
    await _upload(
      title: f.name.replaceAll('.pdf', ''),
      type: RecordType.ordonnance,
      fileName: f.name,
      bytes: f.bytes!,
      mime: 'application/pdf',
    );
  }

  Future<void> _upload({
    required String title,
    required RecordType type,
    required String fileName,
    required Uint8List bytes,
    required String mime,
  }) async {
    setState(() => _isUploading = true);
    try {
      await ref.read(healthRecordServiceProvider).createRecord(
            title: title,
            type: type,
            description: 'Ajoute depuis mobile',
            fileName: fileName,
            fileBytes: bytes,
            mimeType: mime,
            examDate: DateTime.now(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document ajoute'), backgroundColor: ThixSanteColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: ThixSanteColors.danger),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<HealthRecordModel>> recordsAsync = ref.watch(recentRecordsProvider);

    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Dossier Medical', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list_rounded, color: ThixSanteColors.ink), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip('Tous', _filter == null, () => setState(() => _filter = null)),
                  ...RecordType.values.map((t) => _chip(t.label, _filter == t, () => setState(() => _filter = t))),
                ].map((w) => Padding(padding: const EdgeInsets.only(right: 8), child: w)).toList(),
              ),
            ),
          ),
          Expanded(
            child: recordsAsync.when(
              data: (records) {
                final filtered = _filter == null ? records : records.where((r) => r.type == _filter).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 64, color: ThixSanteColors.mutedLight.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text('Aucun document', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Text('Ajoutez photo radio ou PDF ordonnance',
                            style: TextStyle(fontSize: 12, color: ThixSanteColors.muted)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (c, i) {
                    final r = filtered[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ThixSanteColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: r.typeLightColor, borderRadius: BorderRadius.circular(12)),
                            child: Icon(r.typeIcon, color: r.typeColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('${r.type.label} • ${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
                                    style: const TextStyle(fontSize: 11, color: ThixSanteColors.muted)),
                                if (r.hasFile)
                                  Row(
                                    children: [
                                      Icon(r.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded, size: 12, color: ThixSanteColors.muted),
                                      const SizedBox(width: 4),
                                      Text('${r.fileName ?? ''} ${r.fileSizeLabel}',
                                          style: const TextStyle(fontSize: 10, color: ThixSanteColors.mutedLight),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.more_vert_rounded, size: 18), onPressed: () => _showActions(r)),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: _isUploading
          ? const FloatingActionButton(
              onPressed: null,
              backgroundColor: ThixSanteColors.mutedLight,
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          : FloatingActionButton.extended(
              onPressed: () => _showUploadSheet(),
              backgroundColor: ThixSanteColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : ThixSanteColors.ink)),
        selected: selected,
        selectedColor: ThixSanteColors.primary,
        backgroundColor: ThixSanteColors.borderLight,
        onSelected: (_) => onTap(),
      );

  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixSanteColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Ajouter un document', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: ThixSanteColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_camera_rounded, color: ThixSanteColors.primary)),
              title: const Text('Photo radio / analyse', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Depuis galerie ou camera', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage();
              },
            ),
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: ThixSanteColors.dangerLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: ThixSanteColors.danger)),
              title: const Text('Ordonnance PDF', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Televerser PDF depuis fichiers', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _pickPdf();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showActions(HealthRecordModel r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.visibility_rounded), title: const Text('Voir'), onTap: () => Navigator.pop(ctx)),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: ThixSanteColors.danger),
              title: const Text('Supprimer', style: TextStyle(color: ThixSanteColors.danger)),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(healthRecordServiceProvider).deleteRecord(r.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// lib/presentation/vault/document_vault_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/document_service.dart';
import '../../core/theme/thix_design_policy.dart';

// =============================================================
// COULEURS DU COFFRE-FORT (DARK ENTERPRISE)
// =============================================================
class _VaultColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF111118);
  static const surfaceLight = Color(0xFF1C1C26);
  static const primary = Color(0xFF3B82F6); // Bleu Tech
  static const primaryLight = Color(0xFF60A5FA);
  static const gold = Color(0xFFF59E0B); // Accent premium
  static const border = Color(0x1AFFFFFF);
  static const textMain = Colors.white;
  static const textSecondary = Color(0x99FFFFFF);
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
}

class DocumentVaultPage extends StatefulWidget {
  const DocumentVaultPage({super.key});

  @override
  State<DocumentVaultPage> createState() => _DocumentVaultPageState();
}

class _DocumentVaultPageState extends State<DocumentVaultPage> with SingleTickerProviderStateMixin {
  final _docs = DocumentService();
  late TabController _tabController;

  String? _folderFilter; // null = "Tout"
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    // 🟢 SUPPRESSION DU VÉROUILLAGE : Accès direct au coffre
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication, webOnlyWindowName: kIsWeb ? '_blank' : null);
      if (!ok) throw Exception('launch failed');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ouverture impossible.', style: TextStyle(color: Colors.white)), backgroundColor: _VaultColors.danger));
    }
  }

  Future<void> _openDoc(Map<String, dynamic> row) async {
    try {
      final url = await _docs.resolveRowDownloadUrl(row);
      if (url.trim().isEmpty) throw Exception('URL vide');
      await _openUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Téléchargement impossible.', style: TextStyle(color: Colors.white)), backgroundColor: _VaultColors.danger));
    }
  }

  String _formatDate(dynamic createdAt) {
    final date = createdAt is DateTime ? createdAt : (createdAt is String) ? DateTime.tryParse(createdAt) : null;
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatSize(int sizeBytes) {
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _createFolder(String uid) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: _GlassModalContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nouveau dossier', style: TextStyle(color: _VaultColors.textMain, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              _GlassTextField(controller: ctrl, label: 'Nom du dossier'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _VaultColors.textSecondary, fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _VaultColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: const Text('Créer', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (name == null || name.isEmpty) return;
    await _docs.createFolder(uid: uid, name: name);
  }

  Future<void> _pickAndUpload() async {
    final me = context.read<AuthController>().currentUser;
    if (me == null) return;

    final picked = await FilePicker.platform.pickFiles(withData: kIsWeb);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;

    if (!mounted) return;
    final folders = await _docs.fetchFolders(me.id);
    if (!mounted) return;

    final res = await showModalBottomSheet<_UploadDocPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UploadDocumentSheet(
        fileName: file.name,
        folders: folders,
        preselectedFolderId: _folderFilter,
        onCreateFolder: (name) => _docs.createFolder(uid: me.id, name: name),
      ),
    );
    if (res == null) return;

    try {
      final generatedId = await _docs.uploadPickedFileSimple(
        uid: me.id,
        file: file,
        docType: res.docType,
        expiresAt: res.expiresAt,
        title: res.title,
        folderId: res.folderId,
        isPublic: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Document sécurisé • $generatedId', style: const TextStyle(color: Colors.white)), backgroundColor: _VaultColors.success));
    } catch (e) {
      if (!mounted) return;
      final msg = DocumentService.isBucketNotFound(e) ? 'Erreur stockage : bucket introuvable.' : 'Échec du dépôt.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white)), backgroundColor: _VaultColors.danger));
    }
  }

  Future<void> _openSendSheet() async {
    final me = context.read<AuthController>().currentUser;
    if (me == null) return;

    final docs = await _docs.fetchDocuments(me.id, limit: 50);
    if (!mounted) return;

    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun document disponible pour le partage.', style: TextStyle(color: Colors.white)), backgroundColor: _VaultColors.gold));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SendDocumentSheet(
        documents: docs,
        docsService: _docs,
        onSend: (payload) async {
          try {
            await _docs.shareDocument(
              senderId: me.id,
              documentId: payload.documentId,
              docId: payload.docIdLabel,
              recipientThixIds: payload.recipients,
              subject: payload.subject,
              body: payload.body,
              password: payload.password,
              availableFrom: payload.availableFrom,
              autoDestructIn: payload.autoDestructIn,
            );
            if (!mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transmission sécurisée effectuée.', style: TextStyle(color: Colors.white)), backgroundColor: _VaultColors.success));
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec transmission: $e', style: const TextStyle(color: Colors.white)), backgroundColor: _VaultColors.danger));
          }
        },
      ),
    );
  }

  // 🟢 RECHERCHE PUBLIQUE AVEC AFFICHAGE IMAGE EN GRAND
  Future<void> _searchById() async {
    final ctrl = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: _GlassModalContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Vérifier un document', style: TextStyle(color: _VaultColors.textMain, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text('Entrez l\'identifiant unique de certification (ex: THIX-DOC-...)', style: TextStyle(fontSize: 12, color: _VaultColors.textSecondary)),
              const SizedBox(height: 20),
              _GlassTextField(controller: ctrl, label: 'Identifiant THIX-DOC'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _VaultColors.textSecondary, fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _VaultColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: const Text('Rechercher', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (query == null || query.isEmpty) return;

    final res = await _docs.searchPublicDocument(query);
    if (!mounted) return;

    if (res == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun document certifié trouvé.', style: TextStyle(color: Colors.white)), backgroundColor: _VaultColors.danger));
      return;
    }

    final storagePath = (res['storage_path'] as String?) ?? '';
    final mime = (res['mime_type'] as String?) ?? '';
    final avatarUrl = (res['owner_avatar_url'] as String?) ?? '';
    final isImage = mime.toLowerCase().contains('image');
    final accent = _typeAccentColor(mime, res['doc_type'] as String?);

    Future<String>? downloadFuture;
    if (storagePath.isNotEmpty) {
      downloadFuture = _docs.createDownloadUrl(storagePath: storagePath);
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: _GlassModalContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty ? Text(((res['owner_name'] as String?)?.isNotEmpty == true ? (res['owner_name'] as String).substring(0, 1) : '?').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((res['owner_name'] as String?) ?? 'Émetteur certifié', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _VaultColors.textMain)),
                        Text((res['owner_thix_id'] as String?) ?? '—', style: const TextStyle(fontSize: 11, color: _VaultColors.textSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _VaultColors.success.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Row(children: [Icon(Icons.verified_rounded, size: 12, color: _VaultColors.success), SizedBox(width: 4), Text('CERTIFIÉ', style: TextStyle(color: _VaultColors.success, fontSize: 9, fontWeight: FontWeight.w900))]),
                  )
                ],
              ),
              const SizedBox(height: 20),
              
              // 🟢 AFFICHAGE EN GRAND DE L'IMAGE
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: downloadFuture == null ? null : () async {
                  try {
                    final url = await downloadFuture!;
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    await _openUrl(url);
                  } catch (_) {}
                },
                child: Container(
                  height: isImage ? 300 : 150, // Beaucoup plus grand si c'est une image
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(16), border: Border.all(color: accent.withOpacity(0.4))),
                  clipBehavior: Clip.antiAlias,
                  child: isImage && downloadFuture != null
                      ? FutureBuilder<String>(
                          future: downloadFuture,
                          builder: (context, snap) {
                            if (!snap.hasData) return Center(child: CircularProgressIndicator(color: accent));
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(snap.data!, fit: BoxFit.cover),
                                Positioned(
                                  bottom: 8, right: 8,
                                  child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle), child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18)),
                                )
                              ],
                            );
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_typeIcon(mime, res['doc_type'] as String?), color: accent, size: 48),
                              const SizedBox(height: 12),
                              Text('Ouvrir le fichier', style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Text(res['title'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _VaultColors.textMain, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text('${res['doc_type'] ?? '—'} • ${res['generated_doc_id'] ?? '—'}', style: const TextStyle(fontSize: 12, color: _VaultColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.1), foregroundColor: _VaultColors.textMain, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDocMenu({required Map<String, dynamic> row}) async {
    final title = (row['title'] as String?) ?? 'Document';
    final storagePath = (row['storage_path'] as String?) ?? '';
    final docId = (row['generated_doc_id'] as String?) ?? (row['doc_id'] as String?) ?? '';
    final me = context.read<AuthController>().currentUser;
    bool isPublic = (row['is_public'] as bool?) ?? false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => _GlassModalContainer(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(color: _VaultColors.textMain, fontWeight: FontWeight.w900, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded, color: _VaultColors.textSecondary, size: 22)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () { context.pop(); _openDoc(row); },
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                    label: const Text('Ouvrir l\'archive', style: TextStyle(fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(backgroundColor: _VaultColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showQrDialog(context, title: title, value: docId.isNotEmpty ? docId : title),
                          icon: const Icon(Icons.qr_code_2_rounded, size: 18, color: Colors.white),
                          label: const Text('QR Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: Colors.white.withOpacity(0.2)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showDocIdDialog(context, docId: docId.isNotEmpty ? docId : '—', title: title),
                          icon: const Icon(Icons.badge_outlined, size: 18, color: Colors.white),
                          label: const Text('Identifiant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: Colors.white.withOpacity(0.2)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(isPublic ? 'Archive Publique' : 'Archive Privée', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _VaultColors.textMain)),
                      subtitle: Text(isPublic ? 'Accessible via le moteur de recherche global' : 'Strictement confidentiel dans votre coffre', style: const TextStyle(fontSize: 11, color: _VaultColors.textSecondary)),
                      value: isPublic,
                      activeColor: _VaultColors.gold,
                      onChanged: me == null ? null : (v) async {
                        setSheet(() => isPublic = v);
                        await _docs.togglePublic(uid: me.id, documentId: row['id'].toString(), docId: docId, isPublic: v);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: me == null ? null : () async {
                      try {
                        final docRowId = (row['id'] ?? '').toString();
                        if (docRowId.trim().isEmpty) throw Exception('id manquant');
                        await _docs.deleteDocument(uid: me.id, documentId: docRowId, storagePath: storagePath, docId: docId);
                        if (!mounted) return;
                        context.pop();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archive supprimée définitivement.', style: TextStyle(color: Colors.white)), backgroundColor: _VaultColors.success));
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suppression impossible.', style: TextStyle(color: Colors.white)), backgroundColor: _VaultColors.danger));
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: _VaultColors.danger, size: 20),
                    label: const Text('Supprimer définitivement', style: TextStyle(color: _VaultColors.danger, fontWeight: FontWeight.w900)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: _VaultColors.danger.withOpacity(0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().currentUser;

    return Scaffold(
      backgroundColor: _VaultColors.bg,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // LUEUR DE FOND
          Positioned(
            top: -100, right: -50,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_VaultColors.primary.withOpacity(0.15), Colors.transparent]))),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== ENTERPRISE TOP BAR (Glassmorphism) =====
                ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: _VaultColors.surface.withOpacity(0.8),
                        border: const Border(bottom: BorderSide(color: _VaultColors.border)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _VaultColors.textMain, size: 20),
                                    onPressed: () {
                                      final auth = context.read<AuthController>();
                                      if (auth.isAuthenticated) {
                                        final t = auth.currentUser?.accountType;
                                        context.go(t == AccountType.enterprise ? AppRoutes.enterpriseDashboard : AppRoutes.userDashboard);
                                        return;
                                      }
                                      context.go(AppRoutes.home);
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('THIX VAULT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5)),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: _VaultColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: _VaultColors.success.withOpacity(0.3))),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.shield_rounded, color: _VaultColors.success, size: 14),
                                        SizedBox(width: 6),
                                        Text('SÉCURISÉ', style: TextStyle(color: _VaultColors.success, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.search_rounded, color: _VaultColors.textMain, size: 24),
                                    onPressed: _searchById,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // SEARCH FILTER BAR
                          _GlassTextField(
                            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                            label: 'Filtrer vos archives...',
                            icon: Icons.filter_list_rounded,
                          ),
                          const SizedBox(height: 20),
                          Container(
                            height: 44,
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(22), border: Border.all(color: _VaultColors.border)),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(color: _VaultColors.primary, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: _VaultColors.primary.withOpacity(0.4), blurRadius: 8)]),
                              labelColor: Colors.white,
                              unselectedLabelColor: _VaultColors.textSecondary,
                              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              tabs: const [
                                Tab(text: 'Coffre'),
                                Tab(text: 'Transmettre'),
                                Tab(text: 'Reçus'),
                                Tab(text: 'Audit'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _DepotTab(
                        me: me,
                        docsService: _docs,
                        formatDate: _formatDate,
                        formatSize: _formatSize,
                        onOpenDoc: _openDoc,
                        onMore: (row) => _showDocMenu(row: row),
                        onDeposit: _pickAndUpload,
                        folderFilter: _folderFilter,
                        onFolderSelected: (id) => setState(() => _folderFilter = id),
                        onCreateFolder: _createFolder,
                        searchQuery: _searchQuery,
                      ),
                      _EnvoyerTab(me: me, docsService: _docs, formatDate: _formatDate, onOpenSend: _openSendSheet),
                      _RecuTab(me: me, docsService: _docs, onOpenDoc: _openDoc, formatDate: _formatDate),
                      _HistoriqueTab(me: me, docsService: _docs, formatDate: _formatDate),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _pickAndUpload,
              icon: const Icon(Icons.add_moderator_rounded, color: Colors.white, size: 20),
              label: const Text("SÉCURISER", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              backgroundColor: _VaultColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
            )
          : null,
    );
  }
}

// =============================================================
// REUSABLE GLASS COMPONENTS
// =============================================================
class _GlassModalContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry? borderRadius;

  const _GlassModalContainer({required this.child, this.padding = const EdgeInsets.all(24), this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _VaultColors.surfaceLight.withOpacity(0.75),
            borderRadius: borderRadius ?? BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final IconData? icon;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  const _GlassTextField({this.controller, required this.label, this.icon, this.obscureText = false, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        onChanged: onChanged,
        style: const TextStyle(color: _VaultColors.textMain, fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(color: _VaultColors.textSecondary, fontSize: 14),
          prefixIcon: icon != null ? Icon(icon, size: 20, color: _VaultColors.textSecondary) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// =============================================================
// HELPERS DE TYPE DE FICHIER
// =============================================================
Color _typeAccentColor(String? mime, String? docType) {
  final m = (mime ?? '').toLowerCase();
  final t = (docType ?? '').toLowerCase();
  if (m.contains('image')) return const Color(0xFF8B5CF6);
  if (m.contains('pdf')) return _VaultColors.danger;
  if (t.contains('diplome') || t.contains('diplôme') || t.contains('attestation')) return _VaultColors.success;
  if (t == 'cin' || t == 'passeport' || t == 'permis') return _VaultColors.primaryLight;
  return _VaultColors.gold;
}

IconData _typeIcon(String? mime, String? docType) {
  final m = (mime ?? '').toLowerCase();
  if (m.contains('pdf')) return Icons.picture_as_pdf_rounded;
  if (m.contains('image')) return Icons.image_rounded;
  final t = (docType ?? '').toLowerCase();
  if (t.contains('diplome') || t.contains('diplôme')) return Icons.school_rounded;
  if (t == 'cin' || t == 'passeport' || t == 'permis') return Icons.badge_rounded;
  return Icons.description_rounded;
}

// =============================================================
// DIALOGUES UTILITAIRES : QR CODE & IDENTIFIANT
// =============================================================

void showQrDialog(BuildContext context, {required String title, required String value}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: _GlassModalContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _VaultColors.textMain, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(
                data: value,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _VaultColors.bg),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _VaultColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _VaultColors.textSecondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: _VaultColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showDocIdDialog(BuildContext context, {required String docId, required String title}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: _GlassModalContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(color: _VaultColors.textMain, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: SelectableText(docId, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _VaultColors.primaryLight, letterSpacing: 1.0)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer', style: TextStyle(color: _VaultColors.textSecondary, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// =============================================================
// COMPOSANTS UI ENTERPRISE VAULT
// =============================================================
class FolderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const FolderChip({super.key, required this.icon, required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _VaultColors.primary : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _VaultColors.primaryLight : Colors.white.withOpacity(0.1)),
          boxShadow: selected ? [BoxShadow(color: _VaultColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : _VaultColors.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: selected ? Colors.white : _VaultColors.textMain, fontWeight: selected ? FontWeight.w900 : FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class DocSquareCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String docId;
  final String subtitle;
  final bool isPublic;
  final Future<String>? previewUrlFuture;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final VoidCallback? onShowQr;
  final VoidCallback? onShowId;

  const DocSquareCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.docId,
    required this.subtitle,
    required this.isPublic,
    this.previewUrlFuture,
    this.onTap,
    this.onMore,
    this.onShowQr,
    this.onShowId,
  });

  Widget _buildPreview() {
    if (previewUrlFuture == null) {
      return Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: accentColor.withOpacity(0.1)),
        alignment: Alignment.center,
        child: Icon(icon, color: accentColor, size: 42),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FutureBuilder<String>(
        future: previewUrlFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done || !snap.hasData || snap.data!.isEmpty) {
            return Container(color: accentColor.withOpacity(0.1), alignment: Alignment.center, child: Icon(icon, color: accentColor, size: 42));
          }
          return Image.network(snap.data!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => Container(color: accentColor.withOpacity(0.1), alignment: Alignment.center, child: Icon(icon, color: accentColor, size: 42)));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onMore,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: _VaultColors.surfaceLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildPreview()),
                  if (isPublic)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _VaultColors.gold, borderRadius: BorderRadius.circular(8)),
                        child: const Text('PUBLIC', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _VaultColors.bg)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _VaultColors.textMain)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _VaultColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                GestureDetector(
                  onTap: onMore,
                  child: const Icon(Icons.more_horiz_rounded, size: 18, color: _VaultColors.textSecondary),
                )
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                      onTap: onShowQr,
                      child: const Center(child: Icon(Icons.qr_code_2_rounded, size: 16, color: _VaultColors.primaryLight)),
                    ),
                  ),
                  Container(width: 1, height: 16, color: Colors.white.withOpacity(0.1)),
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                      onTap: onShowId,
                      child: const Center(child: Icon(Icons.badge_outlined, size: 16, color: _VaultColors.primaryLight)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DocItem extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final String? trailing;
  final bool hasPassword;
  final VoidCallback? onTap;
  final Widget? progress;

  const DocItem({
    super.key,
    required this.icon,
    this.accentColor = _VaultColors.primary,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.hasPassword = false,
    this.onTap,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _VaultColors.surfaceLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: accentColor.withOpacity(0.15)),
                      alignment: Alignment.center,
                      child: Icon(icon, color: accentColor, size: 24),
                    ),
                    if (hasPassword)
                      Positioned(
                        right: -4, bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: _VaultColors.bg, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                          child: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _VaultColors.textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: _VaultColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (trailing != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                    child: Text(trailing!, style: const TextStyle(color: _VaultColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
            if (progress != null) ...[const SizedBox(height: 16), progress!],
          ],
        ),
      ),
    );
  }
}

class CountdownBar extends StatefulWidget {
  final DateTime start;
  final DateTime target;
  final String label;
  final Color color;

  const CountdownBar({super.key, required this.start, required this.target, required this.label, this.color = _VaultColors.primary});

  @override
  State<CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<CountdownBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final total = widget.target.difference(widget.start).inMilliseconds;
    final elapsed = now.difference(widget.start).inMilliseconds;
    final progress = total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0);
    final remaining = widget.target.difference(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label, style: const TextStyle(fontSize: 11, color: _VaultColors.textSecondary, fontWeight: FontWeight.w700)),
            Text(_fmt(remaining), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: widget.color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: widget.color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation(widget.color)),
        ),
      ],
    );
  }
}

// =============================================================
// ONGLET COFFRE (_DepotTab)
// =============================================================
class _DepotTab extends StatelessWidget {
  final AppUser? me;
  final DocumentService docsService;
  final String Function(dynamic) formatDate;
  final String Function(int) formatSize;
  final Future<void> Function(Map<String, dynamic>) onOpenDoc;
  final void Function(Map<String, dynamic>) onMore;
  final VoidCallback onDeposit;
  final String? folderFilter;
  final void Function(String?) onFolderSelected;
  final Future<void> Function(String uid) onCreateFolder;
  final String searchQuery;

  const _DepotTab({
    required this.me,
    required this.docsService,
    required this.formatDate,
    required this.formatSize,
    required this.onOpenDoc,
    required this.onMore,
    required this.onDeposit,
    required this.folderFilter,
    required this.onFolderSelected,
    required this.onCreateFolder,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (me == null) return const Center(child: Text('Veuillez vous connecter.'));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Dossiers sécurisés", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _VaultColors.textMain, letterSpacing: -0.5)),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: docsService.streamFolders(me!.id),
            builder: (context, snap) {
              final folders = snap.data ?? const [];
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    FolderChip(icon: Icons.grid_view_rounded, label: "Toutes les archives", selected: folderFilter == null, onTap: () => onFolderSelected(null)),
                    ...folders.map((f) => FolderChip(
                          icon: Icons.folder_rounded,
                          label: f['name'] as String? ?? 'Dossier',
                          selected: folderFilter == f['id'],
                          onTap: () => onFolderSelected(f['id'] as String),
                        )),
                    FolderChip(icon: Icons.create_new_folder_rounded, label: "Nouveau", selected: false, onTap: () => onCreateFolder(me!.id)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text("Documents & Certificats", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _VaultColors.textMain, letterSpacing: -0.5)),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: docsService.streamDocuments(me!.id),
            builder: (context, snap) {
              var docs = snap.data ?? const <Map<String, dynamic>>[];
              if (folderFilter != null) {
                docs = docs.where((d) => d['folder_id'] == folderFilter).toList();
              }
              if (searchQuery.isNotEmpty) {
                docs = docs.where((d) {
                  final t = (d['title'] ?? '').toString().toLowerCase();
                  final dt = (d['doc_type'] ?? '').toString().toLowerCase();
                  return t.contains(searchQuery) || dt.contains(searchQuery);
                }).toList();
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: _VaultColors.primary)));
              }
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Icon(Icons.shield_outlined, size: 60, color: Colors.white.withOpacity(0.1)),
                      const SizedBox(height: 16),
                      const Text('Le coffre est vide.', style: TextStyle(color: _VaultColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: onDeposit, 
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Sécuriser un document', style: TextStyle(fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(backgroundColor: _VaultColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
                      ),
                    ],
                  ),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
                itemBuilder: (context, i) {
                  final data = docs[i];
                  final title = (data['title'] as String?) ?? (data['generated_doc_id'] as String?) ?? 'Document';
                  final mime = (data['mime_type'] as String?) ?? (data['mimeType'] as String?);
                  final docType = data['doc_type'] as String?;
                  final sizeBytes = (data['size_bytes'] as num?)?.toInt() ?? 0;
                  final dateStr = formatDate(data['created_at']);
                  final sizeStr = formatSize(sizeBytes);
                  final docId = (data['generated_doc_id'] as String?) ?? '';
                  final isPublic = (data['is_public'] as bool?) ?? false;
                  final isImage = (mime ?? '').toLowerCase().contains('image');

                  return DocSquareCard(
                    icon: _typeIcon(mime, docType),
                    accentColor: _typeAccentColor(mime, docType),
                    title: title,
                    docId: docId,
                    subtitle: '$dateStr • $sizeStr',
                    isPublic: isPublic,
                    previewUrlFuture: isImage ? docsService.resolveRowDownloadUrl(data) : null,
                    onTap: () => onOpenDoc(data),
                    onMore: () => onMore(data),
                    onShowQr: () => showQrDialog(context, title: title, value: docId.isNotEmpty ? docId : title),
                    onShowId: () => showDocIdDialog(context, docId: docId.isNotEmpty ? docId : '—', title: title),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

// =============================================================
// ONGLET TRANSMETTRE (_EnvoyerTab)
// =============================================================
class _EnvoyerTab extends StatefulWidget {
  final AppUser? me;
  final DocumentService docsService;
  final String Function(dynamic) formatDate;
  final VoidCallback onOpenSend;

  const _EnvoyerTab({required this.me, required this.docsService, required this.formatDate, required this.onOpenSend});

  @override
  State<_EnvoyerTab> createState() => _EnvoyerTabState();
}

class _EnvoyerTabState extends State<_EnvoyerTab> {
  final Set<String> _autoDestroyed = {};

  String _statusLabel(String status) {
    switch (status) {
      case 'available': return 'Transmis';
      case 'opened': return 'Consulté';
      case 'pending': return 'En attente';
      case 'expired': return 'Expiré';
      case 'destroyed': return 'Détruit';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.me == null) return const Center(child: Text('Veuillez vous connecter.'));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _VaultColors.surfaceLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _VaultColors.primary.withOpacity(0.3), width: 1.5),
              boxShadow: [BoxShadow(color: _VaultColors.primary.withOpacity(0.1), blurRadius: 20)],
            ),
            child: Column(
              children: [
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _VaultColors.primary.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.admin_panel_settings_rounded, size: 40, color: _VaultColors.primaryLight)),
                const SizedBox(height: 16),
                const Text('Transmission Sécurisée', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                const Text('Partagez vos documents avec chiffrement E2E, auto-destruction et traçabilité absolue.', textAlign: TextAlign.center, style: TextStyle(color: _VaultColors.textSecondary, fontSize: 12, height: 1.4, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: widget.onOpenSend,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('NOUVEL ENVOI SÉCURISÉ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _VaultColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text("Suivi des transmissions", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _VaultColors.textMain, letterSpacing: -0.5)),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.docsService.streamSentShares(widget.me!.id),
            builder: (context, snap) {
              final shares = snap.data ?? const [];
              final now = DateTime.now();
              final visible = <Map<String, dynamic>>[];

              for (final s in shares) {
                final status = (s['status'] as String?) ?? 'pending';
                final shareId = s['id']?.toString();
                final autoDestructAt = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());

                if (status == 'destroyed' || status == 'expired') continue;
                if (autoDestructAt != null && autoDestructAt.isBefore(now)) {
                  if (shareId != null && _autoDestroyed.add(shareId)) {
                    widget.docsService.markShareDestroyed(shareId);
                  }
                  continue;
                }
                visible.add(s);
              }

              if (visible.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('Aucune transmission active.', style: TextStyle(color: _VaultColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600))),
                );
              }
              return Column(
                children: visible.map((s) {
                  final status = (s['status'] as String?) ?? 'pending';
                  final hasPassword = (s['password_hash'] as String?)?.isNotEmpty == true;
                  final autoDestructAt = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
                  final createdAt = DateTime.tryParse((s['created_at'] ?? '').toString()) ?? DateTime.now();
                  Widget? progress;
                  if (autoDestructAt != null) {
                    progress = CountdownBar(start: createdAt, target: autoDestructAt, label: 'Auto-destruction', color: _VaultColors.danger);
                  }
                  return DocItem(
                    icon: status == 'opened' ? Icons.mark_email_read_rounded : Icons.mail_outline_rounded,
                    accentColor: status == 'opened' ? _VaultColors.success : _VaultColors.primary,
                    title: (s['recipient_thix_id'] as String?) ?? 'Destinataire',
                    subtitle: (s['subject'] as String?)?.isNotEmpty == true ? s['subject'] as String : 'Transmission confidentielle',
                    trailing: _statusLabel(status),
                    hasPassword: hasPassword,
                    progress: progress,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================
// ONGLET RÉCEPTIONS (_RecuTab)
// =============================================================
class _RecuTab extends StatefulWidget {
  final AppUser? me;
  final DocumentService docsService;
  final Future<void> Function(Map<String, dynamic>) onOpenDoc;
  final String Function(dynamic) formatDate;

  const _RecuTab({required this.me, required this.docsService, required this.onOpenDoc, required this.formatDate});

  @override
  State<_RecuTab> createState() => _RecuTabState();
}

class _RecuTabState extends State<_RecuTab> {
  final Set<String> _autoDestroyed = {};

  Future<void> _handleOpenShare(BuildContext context, Map<String, dynamic> share) async {
    final status = (share['status'] as String?) ?? 'pending';
    final availableFromRaw = share['available_from'];
    final autoDestructRaw = share['auto_destruct_at'];
    final hasPassword = (share['password_hash'] as String?)?.isNotEmpty == true;
    final shareId = share['id']?.toString();
    final documentId = share['document_id']?.toString();

    if (shareId == null || documentId == null) return;

    if (autoDestructRaw != null) {
      final autoAt = DateTime.tryParse(autoDestructRaw.toString());
      if (autoAt != null && autoAt.isBefore(DateTime.now())) {
        await widget.docsService.markShareDestroyed(shareId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce document a expiré et a été détruit.', style: TextStyle(color: Colors.white)), backgroundColor: _VaultColors.danger));
        return;
      }
    }

    if (hasPassword) {
      final stored = share['password_hash'] as String?;
      final ctrl = TextEditingController();
      String? error;
      final entered = await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDlg) => Dialog(
            backgroundColor: Colors.transparent,
            child: _GlassModalContainer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Mot de passe requis', style: TextStyle(color: _VaultColors.textMain, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  _GlassTextField(controller: ctrl, label: 'Mot de passe', obscureText: true),
                  if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: _VaultColors.danger, fontSize: 12))),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _VaultColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      if (stored == null) { Navigator.pop(ctx, ctrl.text); return; }
                      final valid = await widget.docsService.verifyPassword(password: ctrl.text, hash: stored);
                      if (valid) Navigator.pop(ctx, ctrl.text); else setDlg(() => error = 'Mot de passe incorrect');
                    },
                    child: const Text('Déchiffrer et Ouvrir', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (entered == null) return;
    }

    try {
      final docRow = await widget.docsService.fetchDocumentById(documentId);
      if (docRow == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archive introuvable.', style: TextStyle(color: Colors.white)), backgroundColor: _VaultColors.danger));
        return;
      }
      await widget.docsService.markShareOpened(shareId, uid: docRow['user_id']?.toString(), docId: docRow['generated_doc_id']?.toString());
      await widget.onOpenDoc(docRow);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ouverture impossible.', style: TextStyle(color: Colors.white)), backgroundColor: _VaultColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.me == null) return const Center(child: Text('Veuillez vous connecter.'));

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.docsService.streamReceivedShares(widget.me!.id, widget.me!.thixId),
      builder: (context, snap) {
        final shares = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _VaultColors.primary));
        }

        final now = DateTime.now();
        final visible = <Map<String, dynamic>>[];
        for (final s in shares) {
          final status = (s['status'] as String?) ?? 'pending';
          final shareId = s['id']?.toString();
          final autoDestructAt = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());

          if (status == 'destroyed' || status == 'expired') continue;
          if (autoDestructAt != null && autoDestructAt.isBefore(now)) {
            if (shareId != null && _autoDestroyed.add(shareId)) {
              widget.docsService.markShareDestroyed(shareId);
            }
            continue;
          }
          visible.add(s);
        }

        if (visible.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded, size: 60, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 16),
                const Text('Boîte de réception vide.', style: TextStyle(color: _VaultColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            )
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemCount: visible.length,
          itemBuilder: (context, i) {
            final s = visible[i];
            final subject = (s['subject'] as String?)?.trim().isNotEmpty == true ? s['subject'] as String : 'Archive partagée';
            final status = (s['status'] as String?) ?? 'pending';
            final hasPassword = (s['password_hash'] as String?)?.isNotEmpty == true;
            final screenshotCount = (s['screenshot_count'] as num?)?.toInt() ?? 0;
            final createdAt = DateTime.tryParse((s['created_at'] ?? '').toString()) ?? DateTime.now();
            final autoDestructAt = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
            final availableFrom = DateTime.tryParse((s['available_from'] ?? '').toString());

            String statusLabel;
            switch (status) {
              case 'available': statusLabel = 'Disponible'; break;
              case 'opened': statusLabel = 'Consulté'; break;
              case 'pending': statusLabel = 'Verrouillé'; break;
              default: statusLabel = status;
            }

            Widget? progress;
            if (status == 'pending' && availableFrom != null && availableFrom.isAfter(DateTime.now())) {
              progress = CountdownBar(start: createdAt, target: availableFrom, label: 'Déverrouillage dans', color: _VaultColors.primaryLight);
            } else if (autoDestructAt != null) {
              progress = CountdownBar(start: createdAt, target: autoDestructAt, label: 'Auto-destruction', color: _VaultColors.danger);
            }

            return DocItem(
              icon: Icons.mark_email_unread_rounded,
              accentColor: _VaultColors.gold,
              title: subject,
              subtitle: '${widget.formatDate(s['created_at'])}${screenshotCount > 0 ? ' • 📸 $screenshotCount' : ''}',
              trailing: statusLabel,
              hasPassword: hasPassword,
              onTap: () => _handleOpenShare(context, s),
              progress: progress,
            );
          },
        );
      },
    );
  }
}

// =============================================================
// ONGLET AUDIT (_HistoriqueTab)
// =============================================================
class _HistoriqueTab extends StatelessWidget {
  final AppUser? me;
  final DocumentService docsService;
  final String Function(dynamic) formatDate;

  const _HistoriqueTab({required this.me, required this.docsService, required this.formatDate});

  IconData _iconForAction(String action) {
    switch (action) {
      case 'upload': return Icons.cloud_upload_rounded;
      case 'send': return Icons.send_rounded;
      case 'open': return Icons.visibility_rounded;
      case 'delete': return Icons.delete_outline_rounded;
      case 'screenshot': return Icons.camera_alt_rounded;
      case 'public_toggle': return Icons.public_rounded;
      case 'folder_create': return Icons.create_new_folder_rounded;
      default: return Icons.history_rounded;
    }
  }

  String _labelForAction(String action) {
    switch (action) {
      case 'upload': return 'Archivage';
      case 'send': return 'Transmission';
      case 'open': return 'Consultation';
      case 'delete': return 'Suppression';
      case 'screenshot': return 'Capture d\'écran détectée';
      case 'public_toggle': return 'Modification visibilité';
      case 'folder_create': return 'Création dossier';
      default: return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (me == null) return const Center(child: Text('Veuillez vous connecter.'));

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: docsService.streamTransactions(me!.id),
      builder: (context, snap) {
        final tx = snap.data ?? const [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _VaultColors.primary));
        }
        if (tx.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 60, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 16),
                const Text('Aucun journal d\'audit.', style: TextStyle(color: _VaultColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            )
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemCount: tx.length,
          itemBuilder: (context, i) {
            final t = tx[i];
            final action = (t['action'] as String?) ?? '';
            return DocItem(
              icon: _iconForAction(action),
              accentColor: action == 'delete' ? _VaultColors.danger : (action == 'screenshot' ? _VaultColors.gold : _VaultColors.primaryLight),
              title: _labelForAction(action),
              subtitle: '${(t['detail'] as String?) ?? (t['doc_id'] as String?) ?? ''}',
              trailing: formatDate(t['created_at']),
            );
          },
        );
      },
    );
  }
}

// =============================================================
// SHEET : DÉPÔT D'ARCHIVE
// =============================================================
class _UploadDocPayload {
  final String docType;
  final String? title;
  final DateTime? expiresAt;
  final String? folderId;
  const _UploadDocPayload({required this.docType, this.title, this.expiresAt, this.folderId});
}

class _UploadDocumentSheet extends StatefulWidget {
  final String fileName;
  final List<Map<String, dynamic>> folders;
  final String? preselectedFolderId;
  final Future<void> Function(String name) onCreateFolder;

  const _UploadDocumentSheet({required this.fileName, required this.folders, this.preselectedFolderId, required this.onCreateFolder});

  @override
  State<_UploadDocumentSheet> createState() => _UploadDocumentSheetState();
}

class _UploadDocumentSheetState extends State<_UploadDocumentSheet> {
  String _type = 'Autre';
  DateTime? _expiresAt;
  String? _folderId;
  final _titleC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _folderId = widget.preselectedFolderId;
  }

  @override
  void dispose() {
    _titleC.dispose();
    super.dispose();
  }

  bool get _needsExpiry => _type == 'CIN' || _type == 'Passeport' || _type == 'Permis';

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 20)),
      lastDate: now.add(const Duration(days: 365 * 50)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _VaultColors.primary, surface: _VaultColors.surface)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiresAt = DateTime(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final expiryLabel = _expiresAt == null ? 'Sélectionner une date' : '${_expiresAt!.year.toString().padLeft(4, '0')}-${_expiresAt!.month.toString().padLeft(2, '0')}-${_expiresAt!.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: _GlassModalContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nouvelle Archive', style: TextStyle(color: _VaultColors.textMain, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded, color: _VaultColors.textSecondary, size: 22)),
                ],
              ),
              const SizedBox(height: 8),
              Text(widget.fileName, style: const TextStyle(color: _VaultColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Identifiant unique généré automatiquement (THIX-DOC...)', style: TextStyle(color: _VaultColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              DropdownButtonFormField<String?>(
                value: _folderId,
                dropdownColor: _VaultColors.surface,
                style: const TextStyle(color: _VaultColors.textMain, fontWeight: FontWeight.w600),
                decoration: InputDecoration(labelText: 'Dossier de destination', labelStyle: const TextStyle(color: _VaultColors.textSecondary), filled: true, fillColor: Colors.black.withOpacity(0.2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1)))),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Racine principale')),
                  ...widget.folders.map((f) => DropdownMenuItem(value: f['id'] as String, child: Text(f['name'] as String? ?? 'Dossier'))),
                ],
                onChanged: (v) => setState(() => _folderId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                dropdownColor: _VaultColors.surface,
                style: const TextStyle(color: _VaultColors.textMain, fontWeight: FontWeight.w600),
                items: const [
                  DropdownMenuItem(value: 'CIN', child: Text('Pièce d\'identité — CIN')),
                  DropdownMenuItem(value: 'Passeport', child: Text('Passeport')),
                  DropdownMenuItem(value: 'Permis', child: Text('Permis de conduire')),
                  DropdownMenuItem(value: 'Diplôme', child: Text('Diplôme & Certification')),
                  DropdownMenuItem(value: 'PreuveAdresse', child: Text('Justificatif de domicile')),
                  DropdownMenuItem(value: 'Autre', child: Text('Document Général')),
                ],
                onChanged: (v) => setState(() { _type = v ?? 'Autre'; if (!_needsExpiry) _expiresAt = null; }),
                decoration: InputDecoration(labelText: 'Classification', labelStyle: const TextStyle(color: _VaultColors.textSecondary), filled: true, fillColor: Colors.black.withOpacity(0.2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1)))),
              ),
              const SizedBox(height: 16),
              _GlassTextField(controller: _titleC, label: 'Libellé (Optionnel, ex: Master 2025)'),
              if (_needsExpiry) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickExpiry,
                  icon: const Icon(Icons.event_available_rounded, size: 18, color: _VaultColors.primaryLight),
                  label: Text('Expiration : $expiryLabel', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: Colors.white.withOpacity(0.2)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  if (_needsExpiry && _expiresAt == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date d\'expiration requise.', style: TextStyle(color: Colors.white)), backgroundColor: _VaultColors.danger));
                    return;
                  }
                  context.pop(_UploadDocPayload(
                    docType: _type,
                    title: _titleC.text.trim().isEmpty ? null : _titleC.text.trim(),
                    expiresAt: _expiresAt,
                    folderId: _folderId,
                  ));
                },
                icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
                label: const Text('FINALISER L\'ARCHIVAGE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(backgroundColor: _VaultColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// SHEET : ENVOI SÉCURISÉ (_SendDocumentSheet)
// =============================================================
class _SendPayload {
  final String documentId;
  final String? docIdLabel;
  final List<String> recipients;
  final String? subject;
  final String? body;
  final String? password;
  final DateTime? availableFrom;
  final Duration? autoDestructIn;

  const _SendPayload({required this.documentId, this.docIdLabel, required this.recipients, this.subject, this.body, this.password, this.availableFrom, this.autoDestructIn});
}

class _SendDocumentSheet extends StatefulWidget {
  final List<Map<String, dynamic>> documents;
  final DocumentService docsService;
  final Future<void> Function(_SendPayload) onSend;

  const _SendDocumentSheet({required this.documents, required this.docsService, required this.onSend});

  @override
  State<_SendDocumentSheet> createState() => _SendDocumentSheetState();
}

class _SendDocumentSheetState extends State<_SendDocumentSheet> {
  String? _selectedDocId;
  final _recipientsC = TextEditingController();
  final _subjectC = TextEditingController();
  final _bodyC = TextEditingController();
  final _passwordC = TextEditingController();
  final _durationValueC = TextEditingController(text: '10');
  String _durationUnit = 'minutes';
  bool _autoDestructEnabled = false;
  DateTime? _availableFrom;
  bool _sending = false;

  Timer? _debounce;
  String? _verifiedName;
  bool _verifying = false;

  @override
  void dispose() {
    _recipientsC.dispose(); _subjectC.dispose(); _bodyC.dispose(); _passwordC.dispose(); _durationValueC.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onRecipientsChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final ids = value.split(RegExp(r'[,;\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty);
      if (ids.isEmpty) { setState(() => _verifiedName = null); return; }
      setState(() => _verifying = true);
      final profile = await widget.docsService.verifyThixId(ids.last);
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verifiedName = profile == null ? 'Introuvable' : (profile['full_name'] as String? ?? 'Vérifié');
      });
    });
  }

  Duration? _computeDuration() {
    if (!_autoDestructEnabled) return null;
    final v = int.tryParse(_durationValueC.text.trim());
    if (v == null || v <= 0) return null;
    switch (_durationUnit) {
      case 'secondes': return Duration(seconds: v);
      case 'heures': return Duration(hours: v);
      case 'jours': return Duration(days: v);
      case 'minutes': default: return Duration(minutes: v);
    }
  }

  Future<void> _pickAvailableDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context, 
      initialDate: now, 
      firstDate: now, 
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _VaultColors.primary, surface: _VaultColors.surface)), child: child!),
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    setState(() {
      _availableFrom = DateTime(picked.year, picked.month, picked.day, time?.hour ?? 0, time?.minute ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: _GlassModalContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Transmission Sécurisée', style: TextStyle(color: _VaultColors.textMain, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: _VaultColors.textSecondary, size: 22)),
                ],
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedDocId,
                dropdownColor: _VaultColors.surface,
                style: const TextStyle(color: _VaultColors.textMain, fontWeight: FontWeight.w600),
                decoration: InputDecoration(labelText: 'Archive à transmettre', labelStyle: const TextStyle(color: _VaultColors.textSecondary), filled: true, fillColor: Colors.black.withOpacity(0.2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1)))),
                items: widget.documents.map((d) {
                  final id = d['id'].toString();
                  final title = (d['title'] as String?) ?? (d['generated_doc_id'] as String?) ?? 'Document';
                  return DropdownMenuItem(value: id, child: Text(title, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (v) => setState(() => _selectedDocId = v),
              ),
              const SizedBox(height: 16),
              _GlassTextField(controller: _recipientsC, onChanged: _onRecipientsChanged, label: 'THIX ID du destinataire (ex: THIX-882-091)'),
              if (_verifying)
                const Padding(padding: EdgeInsets.only(top: 6, left: 4), child: Text('Vérification...', style: TextStyle(fontSize: 12, color: _VaultColors.textSecondary)))
              else if (_verifiedName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Row(
                    children: [
                      Icon(_verifiedName == 'Introuvable' ? Icons.error_rounded : Icons.check_circle_rounded, size: 16, color: _verifiedName == 'Introuvable' ? _VaultColors.danger : _VaultColors.success),
                      const SizedBox(width: 6),
                      Text(_verifiedName!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _verifiedName == 'Introuvable' ? _VaultColors.danger : _VaultColors.success)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              _GlassTextField(controller: _subjectC, label: 'Objet de la transmission'),
              const SizedBox(height: 16),
              Container(
                height: 100,
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
                child: TextField(controller: _bodyC, maxLines: 4, style: const TextStyle(color: _VaultColors.textMain, fontWeight: FontWeight.w600), decoration: const InputDecoration(hintText: 'Message confidentiel', hintStyle: TextStyle(color: _VaultColors.textSecondary), border: InputBorder.none, contentPadding: EdgeInsets.all(16))),
              ),
              const SizedBox(height: 16),
              _GlassTextField(controller: _passwordC, label: 'Mot de passe optionnel', obscureText: true),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: const Text('Auto-destruction', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _VaultColors.textMain)),
                  subtitle: const Text('Supprime l\'accès après lecture', style: TextStyle(fontSize: 12, color: _VaultColors.textSecondary)),
                  value: _autoDestructEnabled,
                  activeColor: _VaultColors.danger,
                  onChanged: (v) => setState(() => _autoDestructEnabled = v),
                ),
              ),
              if (_autoDestructEnabled) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(flex: 2, child: _GlassTextField(controller: _durationValueC, label: 'Délai')),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _durationUnit,
                        dropdownColor: _VaultColors.surface,
                        style: const TextStyle(color: _VaultColors.textMain, fontWeight: FontWeight.w800),
                        items: const [DropdownMenuItem(value: 'secondes', child: Text('Secondes')), DropdownMenuItem(value: 'minutes', child: Text('Minutes')), DropdownMenuItem(value: 'heures', child: Text('Heures')), DropdownMenuItem(value: 'jours', child: Text('Jours'))],
                        onChanged: (v) => setState(() => _durationUnit = v ?? 'minutes'),
                        decoration: InputDecoration(filled: true, fillColor: Colors.black.withOpacity(0.2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1)))),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickAvailableDate,
                icon: const Icon(Icons.schedule_rounded, size: 18, color: _VaultColors.primaryLight),
                label: Text(
                  _availableFrom == null
                      ? 'Disponibilité immédiate (Modifier)'
                      : 'Prévu le ${_availableFrom!.day}/${_availableFrom!.month}/${_availableFrom!.year} à ${_availableFrom!.hour.toString().padLeft(2, '0')}:${_availableFrom!.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: Colors.white.withOpacity(0.2)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _sending ? null : () async {
                  if (_selectedDocId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner une archive.', style: TextStyle(color: Colors.white)), backgroundColor: _VaultColors.danger));
                    return;
                  }
                  final recipients = _recipientsC.text.split(RegExp(r'[,;\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  if (recipients.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indiquez au moins un destinataire.', style: TextStyle(color: Colors.white)), backgroundColor: _VaultColors.danger));
                    return;
                  }

                  setState(() => _sending = true);
                  final selectedDoc = widget.documents.firstWhere((d) => d['id'].toString() == _selectedDocId);
                  await widget.onSend(_SendPayload(
                    documentId: _selectedDocId!,
                    docIdLabel: (selectedDoc['generated_doc_id'] as String?) ?? (selectedDoc['doc_id'] as String?),
                    recipients: recipients,
                    subject: _subjectC.text.trim().isEmpty ? null : _subjectC.text.trim(),
                    body: _bodyC.text.trim().isEmpty ? null : _bodyC.text.trim(),
                    password: _passwordC.text.trim().isEmpty ? null : _passwordC.text.trim(),
                    availableFrom: _availableFrom,
                    autoDestructIn: _computeDuration(),
                  ));
                  if (mounted) setState(() => _sending = false);
                },
                icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, size: 20),
                label: Text(_sending ? 'Transmission...' : 'TRANSMETTRE LE DOCUMENT', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(backgroundColor: _VaultColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

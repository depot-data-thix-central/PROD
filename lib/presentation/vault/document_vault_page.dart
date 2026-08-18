// lib/presentation/vault/document_vault_page.dart
import 'dart:async';
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
// THIX VAULT — Design System Enterprise v1 (Dark / Neumorphic Glass)
// =============================================================

class DocumentVaultPage extends StatefulWidget {
  const DocumentVaultPage({super.key});

  @override
  State<DocumentVaultPage> createState() => _DocumentVaultPageState();
}

class _DocumentVaultPageState extends State<DocumentVaultPage>
    with SingleTickerProviderStateMixin {
  final _docs = DocumentService();
  late TabController _tabController;

  bool _checkingLock = true;
  bool _unlocked = false;
  String? _folderFilter; // null = "Tout"
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLock());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkLock() async {
    final me = context.read<AuthController>().currentUser;
    if (me == null) {
      setState(() {
        _checkingLock = false;
        _unlocked = true;
      });
      return;
    }
    final has = await _docs.hasVaultLock(me.id);
    if (!mounted) return;
    if (!has) {
      final pin = await _promptSetPin(context);
      if (pin != null) {
        await _docs.setVaultPin(uid: me.id, pin: pin);
        setState(() {
          _checkingLock = false;
          _unlocked = true;
        });
      } else {
        setState(() {
          _checkingLock = false;
          _unlocked = false;
        });
      }
      return;
    }
    setState(() {
      _checkingLock = false;
      _unlocked = false;
    });
  }

  Future<String?> _promptSetPin(BuildContext context) async {
    final ctrl = TextEditingController();
    final ctrl2 = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        child: Padding(
          padding: const EdgeInsets.all(ThixPolicy.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Sécuriser THIX VAULT', style: TextStyle(color: ThixPolicy.textMain, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: ThixPolicy.s12),
              const Text('Définissez un code d\'accès chiffré pour protéger votre coffre-fort numérique.', style: TextStyle(fontSize: 13, color: ThixPolicy.textSecondary)),
              const SizedBox(height: ThixPolicy.s20),
              TextField(
                controller: ctrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: ThixPolicy.textMain),
                decoration: InputDecoration(
                  labelText: 'Code (4 à 6 chiffres)',
                  filled: true,
                  fillColor: ThixPolicy.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius)),
                ),
              ),
              const SizedBox(height: ThixPolicy.s12),
              TextField(
                controller: ctrl2,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: ThixPolicy.textMain),
                decoration: InputDecoration(
                  labelText: 'Confirmer le code',
                  filled: true,
                  fillColor: ThixPolicy.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius)),
                ),
              ),
              const SizedBox(height: ThixPolicy.s24),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Plus tard', style: TextStyle(color: ThixPolicy.textSecondary)))),
                  const SizedBox(width: ThixPolicy.s12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                      onPressed: () {
                        if (ctrl.text.trim().length < 4 || ctrl.text.trim() != ctrl2.text.trim()) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Les codes ne correspondent pas.'), backgroundColor: ThixPolicy.danger));
                          return;
                        }
                        Navigator.pop(ctx, ctrl.text.trim());
                      },
                      child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    final me = context.read<AuthController>().currentUser;
    if (me == null) return;
    final ctrl = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          backgroundColor: ThixPolicy.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
          child: Padding(
            padding: const EdgeInsets.all(ThixPolicy.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Déverrouiller THIX VAULT', style: TextStyle(color: ThixPolicy.textMain, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: ThixPolicy.s16),
                TextField(
                  controller: ctrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(color: ThixPolicy.textMain),
                  decoration: InputDecoration(
                    labelText: 'Code PIN',
                    errorText: error,
                    filled: true,
                    fillColor: ThixPolicy.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius)),
                  ),
                ),
                const SizedBox(height: ThixPolicy.s24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                  onPressed: () async {
                    final valid = await _docs.verifyVaultPin(uid: me.id, pin: ctrl.text.trim());
                    if (valid) {
                      Navigator.pop(ctx, true);
                    } else {
                      setDlg(() => error = 'Code incorrect');
                    }
                  },
                  child: const Text('Accéder au coffre', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok == true) setState(() => _unlocked = true);
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication, webOnlyWindowName: kIsWeb ? '_blank' : null);
      if (!ok) throw Exception('launch failed');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ouverture impossible.'), backgroundColor: ThixPolicy.danger));
    }
  }

  Future<void> _openDoc(Map<String, dynamic> row) async {
    try {
      final url = await _docs.resolveRowDownloadUrl(row);
      if (url.trim().isEmpty) throw Exception('URL vide');
      await _openUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Téléchargement impossible.'), backgroundColor: ThixPolicy.danger));
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
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        child: Padding(
          padding: const EdgeInsets.all(ThixPolicy.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nouveau dossier', style: TextStyle(color: ThixPolicy.textMain, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: ThixPolicy.s16),
              TextField(
                controller: ctrl,
                style: const TextStyle(color: ThixPolicy.textMain),
                decoration: InputDecoration(
                  labelText: 'Nom du dossier',
                  filled: true,
                  fillColor: ThixPolicy.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius)),
                ),
              ),
              const SizedBox(height: ThixPolicy.s24),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: ThixPolicy.textSecondary)))),
                  const SizedBox(width: ThixPolicy.s12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: const Text('Créer', style: TextStyle(fontWeight: FontWeight.bold)),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Document sécurisé • $generatedId'), backgroundColor: ThixPolicy.success));
    } catch (e) {
      if (!mounted) return;
      final msg = DocumentService.isBucketNotFound(e) ? 'Erreur stockage : bucket introuvable.' : 'Échec du dépôt.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: ThixPolicy.danger));
    }
  }

  Future<void> _openSendSheet() async {
    final me = context.read<AuthController>().currentUser;
    if (me == null) return;

    final docs = await _docs.fetchDocuments(me.id, limit: 50);
    if (!mounted) return;

    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun document disponible pour le partage.'), backgroundColor: ThixPolicy.warning));
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transmission sécurisée effectuée.'), backgroundColor: ThixPolicy.success));
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec transmission: $e'), backgroundColor: ThixPolicy.danger));
          }
        },
      ),
    );
  }

  Future<void> _searchById() async {
    final ctrl = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        child: Padding(
          padding: const EdgeInsets.all(ThixPolicy.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Vérifier un document', style: TextStyle(color: ThixPolicy.textMain, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: ThixPolicy.s12),
              const Text('Entrez l\'identifiant unique de certification (ex: THIX-DOC-...)', style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary)),
              const SizedBox(height: ThixPolicy.s20),
              TextField(
                controller: ctrl,
                style: const TextStyle(color: ThixPolicy.textMain),
                decoration: InputDecoration(
                  labelText: 'Identifiant THIX-DOC',
                  filled: true,
                  fillColor: ThixPolicy.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius)),
                ),
              ),
              const SizedBox(height: ThixPolicy.s24),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: ThixPolicy.textSecondary)))),
                  const SizedBox(width: ThixPolicy.s12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: const Text('Rechercher', style: TextStyle(fontWeight: FontWeight.bold)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun document certifié trouvé.'), backgroundColor: ThixPolicy.danger));
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
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        child: Padding(
          padding: const EdgeInsets.all(ThixPolicy.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: ThixPolicy.tint,
                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty ? Text(((res['owner_name'] as String?)?.isNotEmpty == true ? (res['owner_name'] as String).substring(0, 1) : '?').toUpperCase(), style: const TextStyle(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.bold)) : null,
                  ),
                  const SizedBox(width: ThixPolicy.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((res['owner_name'] as String?) ?? 'Émetteur certifié', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ThixPolicy.textMain)),
                        Text((res['owner_thix_id'] as String?) ?? '—', style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ThixPolicy.s16),
              InkWell(
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                onTap: downloadFuture == null ? null : () async {
                  try {
                    final url = await downloadFuture!;
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    await _openUrl(url);
                  } catch (_) {}
                },
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: accent.withValues(alpha: 0.3))),
                    clipBehavior: Clip.antiAlias,
                    child: isImage && downloadFuture != null
                        ? FutureBuilder<String>(
                            future: downloadFuture,
                            builder: (context, snap) {
                              if (!snap.hasData) return Center(child: CircularProgressIndicator(color: accent));
                              return Image.network(snap.data!, fit: BoxFit.cover);
                            },
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_typeIcon(mime, res['doc_type'] as String?), color: accent, size: 40),
                                const SizedBox(height: 8),
                                Text('Consulter l\'archive', style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: ThixPolicy.s16),
              Text(res['title'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain)),
              const SizedBox(height: 4),
              Text('${res['doc_type'] ?? '—'} • ${res['generated_doc_id'] ?? '—'}', style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary)),
              const SizedBox(height: 2),
              Text('Certification officielle du ${_formatDate(res['created_at'])}', style: const TextStyle(fontSize: 11, color: ThixPolicy.success, fontWeight: FontWeight.w700)),
              const SizedBox(height: ThixPolicy.s24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.surface, foregroundColor: ThixPolicy.textMain, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer'),
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
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => Container(
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
              border: Border.all(color: ThixPolicy.border),
            ),
            padding: const EdgeInsets.all(ThixPolicy.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w800, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded, color: ThixPolicy.textSecondary, size: 20)),
                  ],
                ),
                const SizedBox(height: ThixPolicy.s16),
                ElevatedButton.icon(
                  onPressed: () { context.pop(); _openDoc(row); },
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                  label: const Text('Ouvrir l\'archive', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                ),
                const SizedBox(height: ThixPolicy.s12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showQrDialog(context, title: title, value: docId.isNotEmpty ? docId : title),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: ThixPolicy.primary),
                        label: const Text('QR Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: ThixPolicy.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                      ),
                    ),
                    const SizedBox(width: ThixPolicy.s12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showDocIdDialog(context, docId: docId.isNotEmpty ? docId : '—', title: title),
                        icon: const Icon(Icons.badge_outlined, size: 16, color: ThixPolicy.primary),
                        label: const Text('Identifiant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: ThixPolicy.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ThixPolicy.s12),
                Container(
                  decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border)),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12),
                    title: Text(isPublic ? 'Archive Publique' : 'Archive Privée', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                    subtitle: Text(isPublic ? 'Accessible via le moteur de recherche global' : 'Strictement confidentiel dans votre coffre', style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
                    value: isPublic,
                    activeColor: ThixPolicy.gold,
                    onChanged: me == null ? null : (v) async {
                      setSheet(() => isPublic = v);
                      await _docs.togglePublic(uid: me.id, documentId: row['id'].toString(), docId: docId, isPublic: v);
                    },
                  ),
                ),
                const SizedBox(height: ThixPolicy.s12),
                OutlinedButton.icon(
                  onPressed: me == null ? null : () async {
                    try {
                      final docRowId = (row['id'] ?? '').toString();
                      if (docRowId.trim().isEmpty) throw Exception('id manquant');
                      await _docs.deleteDocument(uid: me.id, documentId: docRowId, storagePath: storagePath, docId: docId);
                      if (!mounted) return;
                      context.pop();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archive supprimée définitivement.'), backgroundColor: ThixPolicy.success));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suppression impossible.'), backgroundColor: ThixPolicy.danger));
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: ThixPolicy.danger, size: 18),
                  label: const Text('Supprimer du coffre', style: TextStyle(color: ThixPolicy.danger, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: ThixPolicy.danger.withOpacity(0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingLock) {
      return const Scaffold(backgroundColor: ThixPolicy.inkDeep, body: Center(child: CircularProgressIndicator(color: ThixPolicy.gold)));
    }
    if (!_unlocked) {
      return _LockScreen(onUnlock: _unlock);
    }

    final me = context.watch<AuthController>().currentUser;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== ENTERPRISE TOP BAR =====
            Container(
              padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s12),
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                boxShadow: ThixPolicy.shadowSoft(),
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
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 18),
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
                          const SizedBox(width: ThixPolicy.s12),
                          ShaderMask(
                            shaderCallback: (bounds) => ThixPolicy.brandGradient.createShader(bounds),
                            child: const Text('THIX VAULT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: ThixPolicy.success.withOpacity(0.1), borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                            child: Row(
                              children: const [
                                Icon(Icons.shield_rounded, color: ThixPolicy.success, size: 14),
                                SizedBox(width: 4),
                                Text('AES-256', style: TextStyle(color: ThixPolicy.success, fontSize: 10, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                          const SizedBox(width: ThixPolicy.s8),
                          IconButton(
                            icon: const Icon(Icons.search_rounded, color: ThixPolicy.textMain, size: 22),
                            onPressed: _searchById,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: ThixPolicy.s16),
                  // SEARCH FILTER BAR IN VAULT
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: ThixPolicy.surface,
                      borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
                      border: Border.all(color: ThixPolicy.border),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                      style: const TextStyle(color: ThixPolicy.textMain, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Filtrer vos archives...',
                        hintStyle: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13),
                        prefixIcon: Icon(Icons.filter_list_rounded, size: 18, color: ThixPolicy.textSecondary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: ThixPolicy.s16),
                  Container(
                    height: 42,
                    decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(ThixPolicy.rFull), border: Border.all(color: ThixPolicy.border)),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(color: ThixPolicy.primary, borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                      labelColor: Colors.white,
                      unselectedLabelColor: ThixPolicy.textSecondary,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Coffre'),
                        Tab(text: 'Transmettre'),
                        Tab(text: 'Réceptions'),
                        Tab(text: 'Audit'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
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
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _pickAndUpload,
              icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
              label: const Text("NOUVELLE ARCHIVE", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              backgroundColor: ThixPolicy.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
              elevation: 4,
            )
          : null,
    );
  }
}

// =============================================================
// ÉCRAN DE VERROUILLAGE ENTERPRISE
// =============================================================
class _LockScreen extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockScreen({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ThixPolicy.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: ThixPolicy.surface, shape: BoxShape.circle, border: Border.all(color: ThixPolicy.gold.withOpacity(0.3), width: 2)),
                alignment: Alignment.center,
                child: const Icon(Icons.lock_rounded, color: ThixPolicy.gold, size: 42),
              ),
              const SizedBox(height: ThixPolicy.s24),
              const Text('Coffre-Fort Chiffré', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
              const SizedBox(height: ThixPolicy.s8),
              const Text('Vos documents institutionnels sont protégés par un chiffrement de niveau bancaire.', textAlign: TextAlign.center, style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13, height: 1.4)),
              const SizedBox(height: ThixPolicy.s32),
              ElevatedButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Déverrouiller le coffre', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.gold,
                  foregroundColor: ThixPolicy.inkDeep,
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s24, vertical: ThixPolicy.s16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                ),
              ),
            ],
          ),
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
  if (m.contains('image')) return ThixPolicy.domainMarket;
  if (m.contains('pdf')) return ThixPolicy.danger;
  if (t.contains('diplome') || t.contains('diplôme') || t.contains('attestation')) return ThixPolicy.success;
  if (t == 'cin' || t == 'passeport' || t == 'permis') return ThixPolicy.primary;
  return ThixPolicy.domainNetwork;
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
// DIALOGUES UTILITAIRES : QR CODE & IDENTIFIANT (restaurés)
// =============================================================

void showQrDialog(BuildContext context, {required String title, required String value}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: ThixPolicy.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
      child: Padding(
        padding: const EdgeInsets.all(ThixPolicy.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: ThixPolicy.s16),
            Container(
              padding: const EdgeInsets.all(ThixPolicy.s12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              ),
              child: QrImageView(
                data: value,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ThixPolicy.inkDeep),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: ThixPolicy.primary),
              ),
            ),
            const SizedBox(height: ThixPolicy.s12),
            SelectableText(value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
            const SizedBox(height: ThixPolicy.s20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor: ThixPolicy.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
      child: Padding(
        padding: const EdgeInsets.all(ThixPolicy.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: ThixPolicy.s12),
            Container(
              padding: const EdgeInsets.all(ThixPolicy.s12),
              decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border)),
              child: SelectableText(docId, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ThixPolicy.primary)),
            ),
            const SizedBox(height: ThixPolicy.s20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer', style: TextStyle(color: ThixPolicy.textSecondary)),
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
        margin: const EdgeInsets.only(right: ThixPolicy.s8),
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ThixPolicy.primary : ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
          border: Border.all(color: selected ? Colors.transparent : ThixPolicy.border),
          boxShadow: selected ? ThixPolicy.shadowSoft() : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : ThixPolicy.textSecondary),
            const SizedBox(width: ThixPolicy.s8),
            Text(label, style: TextStyle(color: selected ? Colors.white : ThixPolicy.textMain, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, fontSize: 12)),
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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(ThixPolicy.rSm), color: accentColor.withOpacity(0.1)),
        alignment: Alignment.center,
        child: Icon(icon, color: accentColor, size: 36),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
      child: FutureBuilder<String>(
        future: previewUrlFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done || !snap.hasData || snap.data!.isEmpty) {
            return Container(color: accentColor.withOpacity(0.1), alignment: Alignment.center, child: Icon(icon, color: accentColor, size: 36));
          }
          return Image.network(snap.data!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => Container(color: accentColor.withOpacity(0.1), alignment: Alignment.center, child: Icon(icon, color: accentColor, size: 36)));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onMore,
      borderRadius: BorderRadius.circular(ThixPolicy.rLg),
      child: Container(
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: ThixPolicy.shadowSoft(),
        ),
        padding: const EdgeInsets.all(ThixPolicy.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildPreview()),
                  if (isPublic)
                    Positioned(
                      top: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: ThixPolicy.gold, borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                        child: const Text('PUBLIC', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: ThixPolicy.inkDeep)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: ThixPolicy.s8),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textMain)),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 10))),
                GestureDetector(
                  onTap: onMore,
                  child: const Icon(Icons.more_vert_rounded, size: 16, color: ThixPolicy.textSecondary),
                )
              ],
            ),
            const SizedBox(height: ThixPolicy.s8),
            // Barre QR + Identifiant (restaurée depuis l'ancienne version)
            Container(
              decoration: BoxDecoration(
                color: ThixPolicy.surface,
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                border: Border.all(color: ThixPolicy.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(ThixPolicy.rSm)),
                      onTap: onShowQr,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Icon(Icons.qr_code_2_rounded, size: 16, color: ThixPolicy.primary),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 14, color: ThixPolicy.border),
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(ThixPolicy.rSm)),
                      onTap: onShowId,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Icon(Icons.badge_outlined, size: 16, color: ThixPolicy.primary),
                      ),
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
    this.accentColor = ThixPolicy.primary,
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
      borderRadius: BorderRadius.circular(ThixPolicy.rLg),
      child: Container(
        margin: const EdgeInsets.only(bottom: ThixPolicy.s12),
        padding: const EdgeInsets.all(ThixPolicy.s16),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: ThixPolicy.shadowSoft(),
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
                      width: 44, height: 44,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(ThixPolicy.rSm), color: accentColor.withOpacity(0.12)),
                      alignment: Alignment.center,
                      child: Icon(icon, color: accentColor, size: 22),
                    ),
                    if (hasPassword)
                      Positioned(
                        right: -4, bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: ThixPolicy.inkDeep, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                          child: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: ThixPolicy.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ThixPolicy.textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (trailing != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
                    child: Text(trailing!, style: const TextStyle(color: ThixPolicy.primary, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
            if (progress != null) ...[const SizedBox(height: ThixPolicy.s12), progress!],
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

  const CountdownBar({super.key, required this.start, required this.target, required this.label, this.color = ThixPolicy.primary});

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
            Text(widget.label, style: const TextStyle(fontSize: 10, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
            Text(_fmt(remaining), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: widget.color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
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
      padding: const EdgeInsets.all(ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Dossiers sécurisés", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain)),
          const SizedBox(height: ThixPolicy.s12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: docsService.streamFolders(me!.id),
            builder: (context, snap) {
              final folders = snap.data ?? const [];
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FolderChip(icon: Icons.grid_view_rounded, label: "Toutes les archives", selected: folderFilter == null, onTap: () => onFolderSelected(null)),
                    ...folders.map((f) => FolderChip(
                          icon: Icons.folder_rounded,
                          label: f['name'] as String? ?? 'Dossier',
                          selected: folderFilter == f['id'],
                          onTap: () => onFolderSelected(f['id'] as String),
                        )),
                    FolderChip(icon: Icons.add_rounded, label: "Nouveau dossier", selected: false, onTap: () => onCreateFolder(me!.id)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: ThixPolicy.s24),
          const Text("Documents & Certificats", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain)),
          const SizedBox(height: ThixPolicy.s12),
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
                return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)));
              }
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      const Icon(Icons.folder_open_rounded, size: 48, color: ThixPolicy.textSecondary),
                      const SizedBox(height: ThixPolicy.s12),
                      const Text('Aucune archive disponible.', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: ThixPolicy.s16),
                      ElevatedButton(onPressed: onDeposit, style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white), child: const Text('Déposer un document')),
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
                  crossAxisSpacing: ThixPolicy.s12,
                  mainAxisSpacing: ThixPolicy.s12,
                  childAspectRatio: 0.82,
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
          const SizedBox(height: 100),
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
      case 'pending': return 'Sécurisé';
      case 'expired': return 'Expiré';
      case 'destroyed': return 'Détruit';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.me == null) return const Center(child: Text('Veuillez vous connecter.'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(ThixPolicy.s24),
            decoration: BoxDecoration(
              gradient: ThixPolicy.brandGradient,
              borderRadius: BorderRadius.circular(ThixPolicy.rXl),
              boxShadow: ThixPolicy.shadowCard(),
            ),
            child: Column(
              children: [
                const Icon(Icons.admin_panel_settings_rounded, size: 48, color: Colors.white),
                const SizedBox(height: ThixPolicy.s16),
                const Text('Transmission Sécurisée', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: ThixPolicy.s8),
                const Text('Partagez vos documents avec un chiffrement de bout en bout, auto-destruction et traçabilité.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
                const SizedBox(height: ThixPolicy.s24),
                ElevatedButton.icon(
                  onPressed: widget.onOpenSend,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('NOUVEL ENVOI SÉCURISÉ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.gold,
                    foregroundColor: ThixPolicy.inkDeep,
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s24, vertical: ThixPolicy.s16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ThixPolicy.s32),
          const Text("Suivi des transmissions", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain)),
          const SizedBox(height: ThixPolicy.s12),
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
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Aucune transmission active.', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13))),
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
                    progress = CountdownBar(start: createdAt, target: autoDestructAt, label: 'Auto-destruction', color: ThixPolicy.danger);
                  }
                  return DocItem(
                    icon: status == 'opened' ? Icons.mark_email_read_rounded : Icons.mail_outline_rounded,
                    accentColor: status == 'opened' ? ThixPolicy.success : ThixPolicy.primary,
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce document a expiré et a été détruit.'), backgroundColor: ThixPolicy.danger));
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
            backgroundColor: ThixPolicy.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
            child: Padding(
              padding: const EdgeInsets.all(ThixPolicy.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Mot de passe requis', style: TextStyle(color: ThixPolicy.textMain, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: ThixPolicy.s16),
                  TextField(
                    controller: ctrl,
                    obscureText: true,
                    style: const TextStyle(color: ThixPolicy.textMain),
                    decoration: InputDecoration(labelText: 'Mot de passe', errorText: error, filled: true, fillColor: ThixPolicy.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius))),
                    autofocus: true,
                  ),
                  const SizedBox(height: ThixPolicy.s24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                    onPressed: () async {
                      if (stored == null) { Navigator.pop(ctx, ctrl.text); return; }
                      final valid = await widget.docsService.verifyPassword(password: ctrl.text, hash: stored);
                      if (valid) Navigator.pop(ctx, ctrl.text); else setDlg(() => error = 'Mot de passe incorrect');
                    },
                    child: const Text('Déchiffrer et Ouvrir', style: TextStyle(fontWeight: FontWeight.bold)),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archive introuvable.'), backgroundColor: ThixPolicy.danger));
        return;
      }
      await widget.docsService.markShareOpened(shareId, uid: docRow['user_id']?.toString(), docId: docRow['generated_doc_id']?.toString());
      await widget.onOpenDoc(docRow);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ouverture impossible.'), backgroundColor: ThixPolicy.danger));
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
          return const Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
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
          return const Center(child: Text('Aucune archive reçue.', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(ThixPolicy.s16),
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
              progress = CountdownBar(start: createdAt, target: availableFrom, label: 'Disponible dans', color: ThixPolicy.primary);
            } else if (autoDestructAt != null) {
              progress = CountdownBar(start: createdAt, target: autoDestructAt, label: 'Auto-destruction', color: ThixPolicy.danger);
            }

            return DocItem(
              icon: Icons.mark_email_unread_rounded,
              accentColor: ThixPolicy.primary,
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
          return const Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
        }
        if (tx.isEmpty) {
          return const Center(child: Text('Aucun journal d\'audit.', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(ThixPolicy.s16),
          itemCount: tx.length,
          itemBuilder: (context, i) {
            final t = tx[i];
            final action = (t['action'] as String?) ?? '';
            return DocItem(
              icon: _iconForAction(action),
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
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: ThixPolicy.primary)),
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
      child: Container(
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
          border: Border.all(color: ThixPolicy.border),
        ),
        padding: const EdgeInsets.all(ThixPolicy.s24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nouvelle Archive', style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w900, fontSize: 18)),
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded, color: ThixPolicy.textSecondary, size: 20)),
                ],
              ),
              Text(widget.fileName, style: const TextStyle(color: ThixPolicy.primary, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Identifiant unique généré automatiquement (THIX-DOC-MMAAAA-XXXXXX-XXX/CC)',
                style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.lock_outline_rounded, size: 12, color: ThixPolicy.textSecondary),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Déposé en privé par défaut — rendez-le public plus tard depuis le menu du document.',
                      style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ThixPolicy.s16),
              DropdownButtonFormField<String?>(
                value: _folderId,
                dropdownColor: ThixPolicy.card,
                style: const TextStyle(color: ThixPolicy.textMain),
                decoration: InputDecoration(labelText: 'Dossier de destination', filled: true, fillColor: ThixPolicy.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius))),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Racine principale')),
                  ...widget.folders.map((f) => DropdownMenuItem(value: f['id'] as String, child: Text(f['name'] as String? ?? 'Dossier'))),
                ],
                onChanged: (v) => setState(() => _folderId = v),
              ),
              const SizedBox(height: ThixPolicy.s16),
              DropdownButtonFormField<String>(
                value: _type,
                dropdownColor: ThixPolicy.card,
                style: const TextStyle(color: ThixPolicy.textMain),
                items: const [
                  DropdownMenuItem(value: 'CIN', child: Text('Pièce d\'identité — CIN')),
                  DropdownMenuItem(value: 'Passeport', child: Text('Passeport')),
                  DropdownMenuItem(value: 'Permis', child: Text('Permis de conduire')),
                  DropdownMenuItem(value: 'Diplôme', child: Text('Diplôme & Certification')),
                  DropdownMenuItem(value: 'PreuveAdresse', child: Text('Justificatif de domicile')),
                  DropdownMenuItem(value: 'Autre', child: Text('Document Général')),
                ],
                onChanged: (v) => setState(() { _type = v ?? 'Autre'; if (!_needsExpiry) _expiresAt = null; }),
                decoration: InputDecoration(labelText: 'Classification', filled: true, fillColor: ThixPolicy.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius))),
              ),
              const SizedBox(height: ThixPolicy.s16),
              TextField(
                controller: _titleC,
                style: const TextStyle(color: ThixPolicy.textMain),
                decoration: InputDecoration(labelText: 'Libellé (Optionnel)', hintText: 'ex: Diplôme Master 2025', filled: true, fillColor: ThixPolicy.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius))),
              ),
              if (_needsExpiry) ...[
                const SizedBox(height: ThixPolicy.s16),
                OutlinedButton.icon(
                  onPressed: _pickExpiry,
                  icon: const Icon(Icons.event_available_rounded, size: 18),
                  label: Text('Date d\'expiration : $expiryLabel'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius))),
                ),
              ],
              const SizedBox(height: ThixPolicy.s24),
              ElevatedButton.icon(
                onPressed: () {
                  if (_needsExpiry && _expiresAt == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date d\'expiration requise.'), backgroundColor: ThixPolicy.danger));
                    return;
                  }
                  context.pop(_UploadDocPayload(
                    docType: _type,
                    title: _titleC.text.trim().isEmpty ? null : _titleC.text.trim(),
                    expiresAt: _expiresAt,
                    folderId: _folderId,
                  ));
                },
                icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                label: const Text('FINALISER L\'ARCHIVAGE', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius))),
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
    final picked = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 365 * 2)));
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
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ThixPolicy.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Transmission Sécurisée', style: TextStyle(color: ThixPolicy.textMain, fontSize: 18, fontWeight: FontWeight.w900)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: ThixPolicy.textSecondary, size: 20)),
                ],
              ),
              const SizedBox(height: ThixPolicy.s16),
              DropdownButtonFormField<String>(
                value: _selectedDocId,
                dropdownColor: ThixPolicy.card,
                style: const TextStyle(color: ThixPolicy.textMain),
                decoration: InputDecoration(labelText: 'Archive à transmettre', filled: true, fillColor: ThixPolicy.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius))),
                items: widget.documents.map((d) {
                  final id = d['id'].toString();
                  final title = (d['title'] as String?) ?? (d['generated_doc_id'] as String?) ?? 'Document';
                  return DropdownMenuItem(value: id, child: Text(title, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (v) => setState(() => _selectedDocId = v),
              ),
              const SizedBox(height: ThixPolicy.s16),
              TextField(
                controller: _recipientsC,
                onChanged: _onRecipientsChanged,
                style: const TextStyle(color: ThixPolicy.textMain),
                decoration: InputDecoration(labelText: 'THIX ID du destinataire', hintText: 'ex: THIX-882-091', filled: true, fillColor: ThixPolicy.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius))),
              ),
              if (_verifying)
                const Padding(padding: EdgeInsets.only(top: 6), child: Text('Vérification...', style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)))
              else if (_verifiedName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(_verifiedName == 'Introuvable' ? Icons.error_outline : Icons.check_circle, size: 14, color: _verifiedName == 'Introuvable' ? ThixPolicy.danger : ThixPolicy.success),
                      const SizedBox(width: 4),
                      Text(_verifiedName!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _verifiedName == 'Introuvable' ? ThixPolicy.danger : ThixPolicy.success)),
                    ],
                  ),
                ),
              const SizedBox(height: ThixPolicy.s16),
              TextField(controller: _subjectC, style: const TextStyle(color: ThixPolicy.textMain), decoration: InputDecoration(labelText: 'Objet de la transmission', filled: true, fillColor: ThixPolicy.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius)))),
              const SizedBox(height: ThixPolicy.s16),
              TextField(controller: _bodyC, maxLines: 3, style: const TextStyle(color: ThixPolicy.textMain), decoration: InputDecoration(labelText: 'Message confidentiel', filled: true, fillColor: ThixPolicy.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius)))),
              const SizedBox(height: ThixPolicy.s16),
              TextField(controller: _passwordC, obscureText: true, style: const TextStyle(color: ThixPolicy.textMain), decoration: InputDecoration(labelText: 'Mot de passe optionnel', filled: true, fillColor: ThixPolicy.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius)))),
              const SizedBox(height: ThixPolicy.s16),
              Container(
                decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border)),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12),
                  title: const Text('Auto-destruction activée', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                  subtitle: const Text('Supprime l\'accès automatiquement après lecture', style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
                  value: _autoDestructEnabled,
                  activeColor: ThixPolicy.danger,
                  onChanged: (v) => setState(() => _autoDestructEnabled = v),
                ),
              ),
              if (_autoDestructEnabled) ...[
                const SizedBox(height: ThixPolicy.s12),
                Row(
                  children: [
                    Expanded(flex: 2, child: TextField(controller: _durationValueC, keyboardType: TextInputType.number, style: const TextStyle(color: ThixPolicy.textMain), decoration: InputDecoration(labelText: 'Délai', filled: true, fillColor: ThixPolicy.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius))))),
                    const SizedBox(width: ThixPolicy.s12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _durationUnit,
                        dropdownColor: ThixPolicy.card,
                        style: const TextStyle(color: ThixPolicy.textMain),
                        items: const [DropdownMenuItem(value: 'secondes', child: Text('Secondes')), DropdownMenuItem(value: 'minutes', child: Text('Minutes')), DropdownMenuItem(value: 'heures', child: Text('Heures')), DropdownMenuItem(value: 'jours', child: Text('Jours'))],
                        onChanged: (v) => setState(() => _durationUnit = v ?? 'minutes'),
                        decoration: InputDecoration(filled: true, fillColor: ThixPolicy.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius))),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: ThixPolicy.s12),
              OutlinedButton.icon(
                onPressed: _pickAvailableDate,
                icon: const Icon(Icons.schedule, size: 16),
                label: Text(
                  _availableFrom == null
                      ? 'Disponible dès maintenant (choisir une date/heure différée)'
                      : 'Disponible à partir du ${_availableFrom!.day}/${_availableFrom!.month}/${_availableFrom!.year} ${_availableFrom!.hour.toString().padLeft(2, '0')}:${_availableFrom!.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius)),
                ),
              ),
              const SizedBox(height: ThixPolicy.s24),
              ElevatedButton.icon(
                onPressed: _sending ? null : () async {
                  if (_selectedDocId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner une archive.'), backgroundColor: ThixPolicy.danger));
                    return;
                  }
                  final recipients = _recipientsC.text.split(RegExp(r'[,;\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  if (recipients.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indiquez au moins un destinataire.'), backgroundColor: ThixPolicy.danger));
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
                icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, size: 18),
                label: Text(_sending ? 'Transmission...' : 'TRANSMETTRE', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

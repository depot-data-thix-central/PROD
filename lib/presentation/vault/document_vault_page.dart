import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'providers/vault_providers.dart';
import 'providers/vault_state.dart';
import 'widgets/vault_app_bar.dart';
import 'widgets/vault_tab_bar.dart';
import 'widgets/folder_chip.dart';
import 'widgets/document_card.dart';
import 'widgets/document_item.dart';
import 'widgets/countdown_bar.dart';
import 'widgets/empty_state.dart';
import 'widgets/sheets/upload_document_sheet.dart';
import 'widgets/sheets/send_document_sheet.dart';
import 'widgets/sheets/document_details_sheet.dart';
import '../core/theme/thix_design_policy.dart';

class DocumentVaultPage extends ConsumerStatefulWidget {
  const DocumentVaultPage({super.key});

  @override
  ConsumerState<DocumentVaultPage> createState() => _DocumentVaultPageState();
}

class _DocumentVaultPageState extends ConsumerState<DocumentVaultPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_blank' : null,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ouverture impossible'),
          backgroundColor: ThixPolicy.danger,
        ),
      );
    }
  }

  Future<void> _openDoc(Map<String, dynamic> row) async {
    final notifier = ref.read(vaultStateProvider.notifier);
    final url = await notifier.resolveDownloadUrl(row);
    if (url == null || url.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Téléchargement impossible'),
          backgroundColor: ThixPolicy.danger,
        ),
      );
      return;
    }
    await _openUrl(url);
  }

  String _formatDate(dynamic createdAt) {
    final date = createdAt is DateTime
        ? createdAt
        : (createdAt is String ? DateTime.tryParse(createdAt) : null);
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatSize(int sizeBytes) {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nouveau dossier',
                style: TextStyle(
                  color: ThixPolicy.textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: TextField(
                  controller: ctrl,
                  style: TextStyle(
                    color: ThixPolicy.textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nom du dossier',
                    hintStyle: TextStyle(
                      color: ThixPolicy.textSecondary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Annuler',
                        style: TextStyle(
                          color: ThixPolicy.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThixPolicy.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: const Text(
                        'Créer',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
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
    await ref.read(vaultStateProvider.notifier).createFolder(name);
  }

  Future<void> _pickAndUpload() async {
    final uid = ref.read(currentUserProvider);
    if (uid == null) return;

    final picked = await FilePicker.platform.pickFiles(withData: kIsWeb);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;

    if (!mounted) return;
    final state = ref.read(vaultStateProvider);

    final result = await showModalBottomSheet<UploadDocPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UploadDocumentSheet(
        fileName: file.name,
        folders: state.folders,
        preselectedFolderId: state.folderFilter,
      ),
    );

    if (result == null) return;

    try {
      final generatedId = await ref.read(vaultStateProvider.notifier).uploadDocument(
            file: file,
            docType: result.docType,
            expiresAt: result.expiresAt,
            title: result.title,
            folderId: result.folderId,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document sécurisé • $generatedId'),
          backgroundColor: ThixPolicy.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = DocumentService.isBucketNotFound(e)
          ? 'Erreur stockage : bucket introuvable.'
          : 'Échec du dépôt.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: ThixPolicy.danger),
      );
    }
  }

  Future<void> _openSendSheet() async {
    final state = ref.read(vaultStateProvider);
    final docs = state.documents;

    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aucun document disponible pour le partage'),
          backgroundColor: ThixPolicy.gold,
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendDocumentSheet(
        documents: docs,
        onSend: (payload) async {
          try {
            await ref.read(vaultStateProvider.notifier).sendDocument(
                  documentId: payload.documentId,
                  docIdLabel: payload.docIdLabel ?? '',
                  recipients: payload.recipients,
                  subject: payload.subject,
                  body: payload.body,
                  password: payload.password,
                  availableFrom: payload.availableFrom,
                  autoDestructIn: payload.autoDestructIn,
                );

            if (!mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Transmission sécurisée effectuée'),
                backgroundColor: ThixPolicy.success,
              ),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Échec transmission: $e'),
                backgroundColor: ThixPolicy.danger,
              ),
            );
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Vérifier un document',
                style: TextStyle(
                  color: ThixPolicy.textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Entrez l\'identifiant unique de certification',
                style: TextStyle(
                  fontSize: 12,
                  color: ThixPolicy.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: TextField(
                  controller: ctrl,
                  style: TextStyle(
                    color: ThixPolicy.textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'THIX-DOC-...',
                    hintStyle: TextStyle(
                      color: ThixPolicy.textSecondary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Annuler',
                        style: TextStyle(
                          color: ThixPolicy.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThixPolicy.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: const Text(
                        'Rechercher',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
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

    final notifier = ref.read(vaultStateProvider.notifier);
    final res = await notifier.searchPublicDocument(query);
    if (!mounted) return;

    if (res == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aucun document certifié trouvé'),
          backgroundColor: ThixPolicy.danger,
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DocumentDetailsSheet(
        document: res,
        docsService: ref.read(documentServiceProvider),
        onOpen: (url) => _openUrl(url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultStateProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VaultAppBar(
              onSearch: _searchById,
              onSearchChanged: (v) {
                ref.read(vaultStateProvider.notifier).setSearchQuery(v);
              },
              searchQuery: state.searchQuery,
            ),
            VaultTabBar(controller: _tabController),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _DepotTab(
                    state: state,
                    onOpenDoc: _openDoc,
                    onDeposit: _pickAndUpload,
                    onCreateFolder: _createFolder,
                    formatDate: _formatDate,
                    formatSize: _formatSize,
                  ),
                  _EnvoyerTab(
                    state: state,
                    onOpenSend: _openSendSheet,
                    formatDate: _formatDate,
                  ),
                  _RecuTab(
                    state: state,
                    onOpenDoc: _openDoc,
                    formatDate: _formatDate,
                  ),
                  _AuditTab(
                    state: state,
                    formatDate: _formatDate,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _pickAndUpload,
              icon: const Icon(
                Icons.add_moderator_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'SÉCURISER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              backgroundColor: ThixPolicy.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 6,
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TABS
// ─────────────────────────────────────────────────────────────

class _DepotTab extends ConsumerWidget {
  final VaultState state;
  final Future<void> Function(Map<String, dynamic>) onOpenDoc;
  final VoidCallback onDeposit;
  final VoidCallback onCreateFolder;
  final String Function(dynamic) formatDate;
  final String Function(int) formatSize;

  const _DepotTab({
    required this.state,
    required this.onOpenDoc,
    required this.onDeposit,
    required this.onCreateFolder,
    required this.formatDate,
    required this.formatSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(vaultStateProvider.notifier).filteredDocuments;
    final folders = state.folders;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Folders section
          Text(
            'Dossiers sécurisés',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: ThixPolicy.textMain,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                FolderChip(
                  icon: Icons.grid_view_rounded,
                  label: 'Toutes',
                  selected: state.folderFilter == null,
                  count: state.documents.length,
                  onTap: () => ref
                      .read(vaultStateProvider.notifier)
                      .setFolderFilter(null),
                ),
                ...folders.map((f) {
                  final folderDocs = state.documents
                      .where((d) => d['folder_id'] == f['id'])
                      .length;
                  return FolderChip(
                    icon: Icons.folder_rounded,
                    label: f['name'] as String? ?? 'Dossier',
                    selected: state.folderFilter == f['id'],
                    count: folderDocs,
                    onTap: () => ref
                        .read(vaultStateProvider.notifier)
                        .setFolderFilter(f['id'] as String),
                  );
                }),
                FolderChip(
                  icon: Icons.create_new_folder_rounded,
                  label: 'Nouveau',
                  selected: false,
                  onTap: onCreateFolder,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Documents section
          Text(
            'Documents & Certificats',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: ThixPolicy.textMain,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          if (docs.isEmpty)
            EmptyState(
              icon: Icons.shield_outlined,
              title: 'Le coffre est vide',
              subtitle: 'Sécurisez votre premier document',
              buttonText: 'Ajouter un document',
              onButtonPressed: onDeposit,
            )
          else
            GridView.builder(
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
                final title = (data['title'] as String?) ??
                    (data['generated_doc_id'] as String?) ??
                    'Document';
                final mime = (data['mime_type'] as String?) ??
                    (data['mimeType'] as String?);
                final docType = data['doc_type'] as String?;
                final sizeBytes = (data['size_bytes'] as num?)?.toInt() ?? 0;
                final dateStr = formatDate(data['created_at']);
                final sizeStr = formatSize(sizeBytes);
                final docId = (data['generated_doc_id'] as String?) ?? '';
                final isPublic = (data['is_public'] as bool?) ?? false;
                final isImage =
                    (mime ?? '').toLowerCase().contains('image');

                return DocumentCard(
                  icon: _typeIcon(mime, docType),
                  accentColor: _typeAccentColor(mime, docType),
                  title: title,
                  docId: docId,
                  subtitle: '$dateStr • $sizeStr',
                  isPublic: isPublic,
                  previewUrlFuture: isImage
                      ? ref
                          .read(documentServiceProvider)
                          .resolveRowDownloadUrl(data)
                      : null,
                  onTap: () => onOpenDoc(data),
                  onMore: () => _showDocMenu(
                    context: context,
                    ref: ref,
                    row: data,
                    onOpenDoc: onOpenDoc,
                  ),
                  onShowQr: () => _showQrDialog(
                    context,
                    title: title,
                    value: docId.isNotEmpty ? docId : title,
                  ),
                  onShowId: () => _showDocIdDialog(
                    context,
                    docId: docId.isNotEmpty ? docId : '—',
                    title: title,
                  ),
                );
              },
            ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

class _EnvoyerTab extends ConsumerWidget {
  final VaultState state;
  final VoidCallback onOpenSend;
  final String Function(dynamic) formatDate;

  const _EnvoyerTab({
    required this.state,
    required this.onOpenSend,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shares = state.sentShares;
    final now = DateTime.now();

    final visible = shares.where((s) {
      final status = (s['status'] as String?) ?? 'pending';
      final autoDestructAt =
          DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());

      if (status == 'destroyed' || status == 'expired') return false;
      if (autoDestructAt != null && autoDestructAt.isBefore(now)) return false;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ThixPolicy.primary,
                  ThixPolicy.primaryDeep,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: ThixPolicy.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Transmission Sécurisée',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Partagez vos documents avec chiffrement E2E, auto-destruction et traçabilité absolue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onOpenSend,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    'NOUVEL ENVOI SÉCURISÉ',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ThixPolicy.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Sent shares
          Text(
            'Suivi des transmissions',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: ThixPolicy.textMain,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            const EmptyState(
              icon: Icons.send_outlined,
              title: 'Aucune transmission',
              subtitle: 'Vos envois sécurisés apparaîtront ici',
            )
          else
            Column(
              children: visible.map((s) {
                final status = (s['status'] as String?) ?? 'pending';
                final hasPassword =
                    (s['password_hash'] as String?)?.isNotEmpty == true;
                final autoDestructAt = DateTime.tryParse(
                    (s['auto_destruct_at'] ?? '').toString());
                final createdAt = DateTime.tryParse(
                        (s['created_at'] ?? '').toString()) ??
                    DateTime.now();

                String statusLabel;
                Color statusColor;
                switch (status) {
                  case 'opened':
                    statusLabel = 'Consulté';
                    statusColor = ThixPolicy.success;
                    break;
                  case 'available':
                    statusLabel = 'Transmis';
                    statusColor = ThixPolicy.primary;
                    break;
                  case 'pending':
                    statusLabel = 'En attente';
                    statusColor = ThixPolicy.gold;
                    break;
                  default:
                    statusLabel = status;
                    statusColor = ThixPolicy.textSecondary;
                }

                Widget? progress;
                if (autoDestructAt != null) {
                  progress = CountdownBar(
                    start: createdAt,
                    target: autoDestructAt,
                    label: 'Auto-destruction',
                    color: ThixPolicy.danger,
                  );
                }

                return DocumentItem(
                  icon: status == 'opened'
                      ? Icons.mark_email_read_rounded
                      : Icons.mail_outline_rounded,
                  accentColor: statusColor,
                  title: (s['recipient_thix_id'] as String?) ?? 'Destinataire',
                  subtitle: (s['subject'] as String?)?.isNotEmpty == true
                      ? s['subject'] as String
                      : 'Transmission confidentielle',
                  trailing: statusLabel,
                  hasPassword: hasPassword,
                  progress: progress,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _RecuTab extends ConsumerWidget {
  final VaultState state;
  final Future<void> Function(Map<String, dynamic>) onOpenDoc;
  final String Function(dynamic) formatDate;

  const _RecuTab({
    required this.state,
    required this.onOpenDoc,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shares = state.receivedShares;
    final now = DateTime.now();

    final visible = shares.where((s) {
      final status = (s['status'] as String?) ?? 'pending';
      final autoDestructAt =
          DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());

      if (status == 'destroyed' || status == 'expired') return false;
      if (autoDestructAt != null && autoDestructAt.isBefore(now)) return false;
      return true;
    }).toList();

    if (visible.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_rounded,
        title: 'Boîte de réception vide',
        subtitle: 'Les documents reçus apparaîtront ici',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final s = visible[i];
        final subject = (s['subject'] as String?)?.trim().isNotEmpty == true
            ? s['subject'] as String
            : 'Archive partagée';
        final status = (s['status'] as String?) ?? 'pending';
        final hasPassword = (s['password_hash'] as String?)?.isNotEmpty == true;
        final screenshotCount = (s['screenshot_count'] as num?)?.toInt() ?? 0;
        final createdAt =
            DateTime.tryParse((s['created_at'] ?? '').toString()) ??
                DateTime.now();
        final autoDestructAt =
            DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
        final availableFrom =
            DateTime.tryParse((s['available_from'] ?? '').toString());

        String statusLabel;
        Color statusColor;
        switch (status) {
          case 'available':
            statusLabel = 'Disponible';
            statusColor = ThixPolicy.success;
            break;
          case 'opened':
            statusLabel = 'Consulté';
            statusColor = ThixPolicy.primary;
            break;
          case 'pending':
            statusLabel = 'Verrouillé';
            statusColor = ThixPolicy.gold;
            break;
          default:
            statusLabel = status;
            statusColor = ThixPolicy.textSecondary;
        }

        Widget? progress;
        if (status == 'pending' &&
            availableFrom != null &&
            availableFrom.isAfter(DateTime.now())) {
          progress = CountdownBar(
            start: createdAt,
            target: availableFrom,
            label: 'Déverrouillage dans',
            color: ThixPolicy.primary,
          );
        } else if (autoDestructAt != null) {
          progress = CountdownBar(
            start: createdAt,
            target: autoDestructAt,
            label: 'Auto-destruction',
            color: ThixPolicy.danger,
          );
        }

        return DocumentItem(
          icon: Icons.mark_email_unread_rounded,
          accentColor: statusColor,
          title: subject,
          subtitle:
              '${formatDate(s['created_at'])}${screenshotCount > 0 ? ' • 📸 $screenshotCount' : ''}',
          trailing: statusLabel,
          hasPassword: hasPassword,
          onTap: () => _handleOpenShare(
            context: context,
            ref: ref,
            share: s,
            onOpenDoc: onOpenDoc,
          ),
          progress: progress,
        );
      },
    );
  }
}

class _AuditTab extends ConsumerWidget {
  final VaultState state;
  final String Function(dynamic) formatDate;

  const _AuditTab({
    required this.state,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = state.auditLog;

    if (tx.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'Aucun journal d\'audit',
        subtitle: 'Vos actions apparaîtront ici',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: tx.length,
      itemBuilder: (context, i) {
        final t = tx[i];
        final action = (t['action'] as String?) ?? '';

        return DocumentItem(
          icon: _iconForAction(action),
          accentColor: action == 'delete'
              ? ThixPolicy.danger
              : (action == 'screenshot' ? ThixPolicy.gold : ThixPolicy.primary),
          title: _labelForAction(action),
          subtitle: (t['detail'] as String?) ?? (t['doc_id'] as String?) ?? '',
          trailing: formatDate(t['created_at']),
        );
      },
    );
  }

  IconData _iconForAction(String action) {
    switch (action) {
      case 'upload':
        return Icons.cloud_upload_rounded;
      case 'send':
        return Icons.send_rounded;
      case 'open':
        return Icons.visibility_rounded;
      case 'delete':
        return Icons.delete_outline_rounded;
      case 'screenshot':
        return Icons.camera_alt_rounded;
      case 'public_toggle':
        return Icons.public_rounded;
      case 'folder_create':
        return Icons.create_new_folder_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  String _labelForAction(String action) {
    switch (action) {
      case 'upload':
        return 'Archivage';
      case 'send':
        return 'Transmission';
      case 'open':
        return 'Consultation';
      case 'delete':
        return 'Suppression';
      case 'screenshot':
        return 'Capture d\'écran détectée';
      case 'public_toggle':
        return 'Modification visibilité';
      case 'folder_create':
        return 'Création dossier';
      default:
        return action;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────

Color _typeAccentColor(String? mime, String? docType) {
  final m = (mime ?? '').toLowerCase();
  final t = (docType ?? '').toLowerCase();
  if (m.contains('image')) return const Color(0xFF8B5CF6);
  if (m.contains('pdf')) return ThixPolicy.danger;
  if (t.contains('diplome') ||
      t.contains('diplôme') ||
      t.contains('attestation')) return ThixPolicy.success;
  if (t == 'cin' || t == 'passeport' || t == 'permis') {
    return ThixPolicy.primary;
  }
  return ThixPolicy.gold;
}

IconData _typeIcon(String? mime, String? docType) {
  final m = (mime ?? '').toLowerCase();
  if (m.contains('pdf')) return Icons.picture_as_pdf_rounded;
  if (m.contains('image')) return Icons.image_rounded;
  final t = (docType ?? '').toLowerCase();
  if (t.contains('diplome') || t.contains('diplôme')) {
    return Icons.school_rounded;
  }
  if (t == 'cin' || t == 'passeport' || t == 'permis') {
    return Icons.badge_rounded;
  }
  return Icons.description_rounded;
}

Future<void> _handleOpenShare({
  required BuildContext context,
  required WidgetRef ref,
  required Map<String, dynamic> share,
  required Future<void> Function(Map<String, dynamic>) onOpenDoc,
}) async {
  final notifier = ref.read(vaultStateProvider.notifier);
  final docsService = ref.read(documentServiceProvider);

  final status = (share['status'] as String?) ?? 'pending';
  final hasPassword = (share['password_hash'] as String?)?.isNotEmpty == true;
  final shareId = share['id']?.toString();
  final documentId = share['document_id']?.toString();

  if (shareId == null || documentId == null) return;

  // Check auto-destruct
  final autoDestructRaw = share['auto_destruct_at'];
  if (autoDestructRaw != null) {
    final autoAt = DateTime.tryParse(autoDestructRaw.toString());
    if (autoAt != null && autoAt.isBefore(DateTime.now())) {
      await notifier.markShareDestroyed(shareId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ce document a expiré et a été détruit'),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
      return;
    }
  }

  // Password verification
  if (hasPassword) {
    final stored = share['password_hash'] as String?;
    final ctrl = TextEditingController();
    String? error;

    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ThixPolicy.danger.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        color: ThixPolicy.danger,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Document protégé',
                            style: TextStyle(
                              color: ThixPolicy.textMain,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Mot de passe requis pour accéder',
                            style: TextStyle(
                              color: ThixPolicy.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThixPolicy.border),
                  ),
                  child: TextField(
                    controller: ctrl,
                    obscureText: true,
                    style: TextStyle(
                      color: ThixPolicy.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Mot de passe',
                      hintStyle: TextStyle(
                        color: ThixPolicy.textSecondary,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: ThixPolicy.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    if (stored == null) {
                      Navigator.pop(ctx, ctrl.text);
                      return;
                    }
                    final valid = await docsService.verifyPassword(
                      password: ctrl.text,
                      hash: stored,
                    );
                    if (valid) {
                      Navigator.pop(ctx, ctrl.text);
                    } else {
                      setDlg(() => error = 'Mot de passe incorrect');
                    }
                  },
                  child: const Text(
                    'Déchiffrer et Ouvrir',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (entered == null) return;
  }

  // Open document
  try {
    await notifier.openShare(share);
    final docRow = await docsService.fetchDocumentById(documentId);
    if (docRow == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Archive introuvable'),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
      return;
    }
    await onOpenDoc(docRow);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ouverture impossible'),
          backgroundColor: ThixPolicy.danger,
        ),
      );
    }
  }
}

Future<void> _showDocMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Map<String, dynamic> row,
  required Future<void> Function(Map<String, dynamic>) onOpenDoc,
}) async {
  final notifier = ref.read(vaultStateProvider.notifier);
  final title = (row['title'] as String?) ?? 'Document';
  final storagePath = (row['storage_path'] as String?) ?? '';
  final docId = (row['generated_doc_id'] as String?) ??
      (row['doc_id'] as String?) ??
      '';
  bool isPublic = (row['is_public'] as bool?) ?? false;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) {
      return StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: ThixPolicy.textMain,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: ThixPolicy.textSecondary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onOpenDoc(row);
                  },
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Ouvrir l\'archive',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showQrDialog(
                          context,
                          title: title,
                          value: docId.isNotEmpty ? docId : title,
                        ),
                        icon: Icon(
                          Icons.qr_code_2_rounded,
                          size: 18,
                          color: ThixPolicy.primary,
                        ),
                        label: Text(
                          'QR Code',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ThixPolicy.textMain,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: ThixPolicy.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDocIdDialog(
                          context,
                          docId: docId.isNotEmpty ? docId : '—',
                          title: title,
                        ),
                        icon: Icon(
                          Icons.badge_outlined,
                          size: 18,
                          color: ThixPolicy.primary,
                        ),
                        label: Text(
                          'Identifiant',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ThixPolicy.textMain,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: ThixPolicy.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ThixPolicy.border),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      isPublic ? 'Archive Publique' : 'Archive Privée',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: ThixPolicy.textMain,
                      ),
                    ),
                    subtitle: Text(
                      isPublic
                          ? 'Accessible via le moteur de recherche global'
                          : 'Strictement confidentiel dans votre coffre',
                      style: TextStyle(
                        fontSize: 11,
                        color: ThixPolicy.textSecondary,
                      ),
                    ),
                    value: isPublic,
                    activeColor: ThixPolicy.gold,
                    onChanged: (v) async {
                      setSheet(() => isPublic = v);
                      await notifier.togglePublic(
                        documentId: row['id'].toString(),
                        docId: docId,
                        isPublic: v,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final docRowId = (row['id'] ?? '').toString();
                      if (docRowId.trim().isEmpty) {
                        throw Exception('id manquant');
                      }
                      await notifier.deleteDocument(
                        documentId: docRowId,
                        storagePath: storagePath,
                        docId: docId,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Archive supprimée définitivement'),
                            backgroundColor: ThixPolicy.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Suppression impossible'),
                            backgroundColor: ThixPolicy.danger,
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: ThixPolicy.danger,
                    size: 20,
                  ),
                  label: Text(
                    'Supprimer définitivement',
                    style: TextStyle(
                      color: ThixPolicy.danger,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: ThixPolicy.danger.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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

void _showQrDialog(BuildContext context,
    {required String title, required String value}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThixPolicy.textMain,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ThixPolicy.border),
              ),
              child: QrImageView(
                data: value,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: ThixPolicy.surfaceSoft,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: ThixPolicy.textMain,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: ThixPolicy.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: ThixPolicy.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Fermer',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showDocIdDialog(BuildContext context,
    {required String docId, required String title}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: ThixPolicy.textMain,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThixPolicy.border),
              ),
              child: SelectableText(
                docId,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: ThixPolicy.primary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Fermer',
                  style: TextStyle(
                    color: ThixPolicy.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

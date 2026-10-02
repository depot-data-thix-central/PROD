// lib/presentation/vault/document_vault_page.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/document_service.dart';

// =============================================================
// PALETTE VAULT v3 — graphite & or (compact)
// =============================================================
class _V {
  static const bg = Color(0xFF0B1017);
  static const surface = Color(0xFF10161D);
  static const card = Color(0xFF171F29);
  static const cardSoft = Color(0xFF1D2733);
  static const border = Color(0xFF2A3644);
  static const gold = Color(0xFFE3B23C);
  static const text = Color(0xFFF2F6FA);
  static const textSec = Color(0xFF9AA7B4);
  static const textMut = Color(0xFF6B7885);
  static const ok = Color(0xFF34D399);
  static const warn = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
  static const dangerBright = Color(0xFFFF453A);
  static const info = Color(0xFF60A5FA);
}

// =============================================================
// PAGE PRINCIPALE
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
  final _searchCtrl = TextEditingController();
  String? _folderFilter;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    // Cache images Flutter agrandi (évite les re-téléchargements)
    PaintingBinding.instance.imageCache
      ..maximumSize = 500
      ..maximumSizeBytes = 200 * 1024 * 1024;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 12)),
      backgroundColor: error ? _V.dangerBright : _V.ok,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(
        Uri.parse(url),
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_blank' : null,
      );
    } catch (_) {
      _snack(AppLocalizations.of(context).t('vault_open_failed'), error: true);
    }
  }

  Future<void> _openDoc(Map<String, dynamic> row) async {
    try {
      final url = await _docs.resolveRowDownloadUrl(row);
      if (url.trim().isEmpty) throw Exception('empty');
      await _openUrl(url);
    } catch (_) {
      _snack(AppLocalizations.of(context).t('vault_download_failed'),
          error: true);
    }
  }

  String _fmtDate(dynamic v) {
    final d = v is DateTime ? v : DateTime.tryParse((v ?? '').toString());
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';
  }

  String _fmtSize(int b) => b < 1024 * 1024
      ? '${(b / 1024).toStringAsFixed(0)} KB'
      : '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';

  Future<void> _createFolder(String uid) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _V.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(l10n.t('vault_new_folder'),
            style: const TextStyle(
                color: _V.text, fontSize: 14, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: _V.text, fontSize: 13),
          decoration: InputDecoration(
            hintText: l10n.t('vault_folder_name'),
            hintStyle: const TextStyle(color: _V.textMut, fontSize: 12),
            filled: true,
            fillColor: _V.cardSoft,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _V.border)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.t('common_cancel'),
                  style: const TextStyle(color: _V.textSec, fontSize: 12))),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _V.gold,
                  foregroundColor: _V.bg,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(l10n.t('vault_create'),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _docs.createFolder(uid: uid, name: name);
  }

  Future<void> _pickAndUpload() async {
    final l10n = AppLocalizations.of(context);
    final me = context.read<AuthController>().currentUser;
    if (me == null) return;
    final picked = await FilePicker.platform.pickFiles(withData: kIsWeb);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (!mounted) return;
    final folders = await _docs.fetchFolders(me.id);
    if (!mounted) return;
    final res = await showModalBottomSheet<_UploadPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UploadSheet(
        fileName: file.name,
        folders: folders,
        preselectedFolderId: _folderFilter,
      ),
    );
    if (res == null) return;
    try {
      final id = await _docs.uploadPickedFileSimple(
        uid: me.id,
        file: file,
        docType: res.docType,
        expiresAt: res.expiresAt,
        title: res.title,
        folderId: res.folderId,
        isPublic: false,
      );
      _snack(l10n.t('vault_upload_ok', args: [id]));
    } catch (e) {
      _snack(l10n.t('vault_upload_failed'), error: true);
    }
  }

  Future<void> _openSendSheet({Map<String, dynamic>? singleDoc}) async {
    final l10n = AppLocalizations.of(context);
    final me = context.read<AuthController>().currentUser;
    if (me == null) return;
    final docs = singleDoc != null
        ? [singleDoc]
        : await _docs.fetchDocuments(me.id, limit: 50);
    if (!mounted) return;
    if (docs.isEmpty) {
      _snack(l10n.t('vault_select_archive'), error: true);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SendSheet(
        documents: docs,
        docsService: _docs,
        initialDocId: singleDoc?['id']?.toString(),
        onDone: (ok) {
          if (!mounted) return;
          Navigator.of(context).pop();
          _snack(l10n.t(ok ? 'vault_send_ok' : 'vault_send_failed'),
              error: !ok);
        },
      ),
    );
  }

  Future<void> _verifyById() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _V.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(l10n.t('vault_verify_title'),
            style: const TextStyle(
                color: _V.text, fontSize: 14, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('vault_verify_hint'),
                style: const TextStyle(color: _V.textSec, fontSize: 11)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: _V.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'THIX-DOC-…',
                hintStyle: const TextStyle(color: _V.textMut, fontSize: 12),
                filled: true,
                fillColor: _V.cardSoft,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _V.border)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.t('common_cancel'),
                  style: const TextStyle(color: _V.textSec, fontSize: 12))),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _V.gold,
                  foregroundColor: _V.bg,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(l10n.t('common_search'),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (query == null || query.isEmpty) return;
    final res = await _docs.searchPublicDocument(query);
    if (!mounted) return;
    if (res == null) {
      _snack(l10n.t('vault_verify_none'), error: true);
      return;
    }
    await showDialog(
      context: context,
      builder: (ctx) => _CertifiedDocDialog(
        res: res,
        docs: _docs,
        onOpen: _openUrl,
        me: context.read<AuthController>().currentUser,
        onSaved: () => _snack(l10n.t('vault_saved_ok')),
        onSaveFailed: () => _snack(l10n.t('vault_save_failed'), error: true),
      ),
    );
  }

  Future<void> _docMenu(Map<String, dynamic> row) async {
    final l10n = AppLocalizations.of(context);
    final me = context.read<AuthController>().currentUser;
    final docId = (row['generated_doc_id'] as String?) ?? '';
    bool isPublic = (row['is_public'] as bool?) ?? false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          margin: const EdgeInsets.all(10),
          decoration:
              BoxDecoration(color: _V.card, borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.all(14),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text((row['title'] as String?) ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _V.text, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                _MenuTile(
                    icon: Icons.open_in_new_rounded,
                    label: l10n.t('vault_open_archive'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openDoc(row);
                    }),
                _MenuTile(
                    icon: Icons.qr_code_2_rounded,
                    label: l10n.t('vault_menu_qr'),
                    onTap: () => showQrDialog(context,
                        title: (row['title'] as String?) ?? '',
                        value: docId.isNotEmpty ? docId : (row['title'] ?? ''))),
                _MenuTile(
                    icon: Icons.badge_outlined,
                    label: l10n.t('vault_menu_id'),
                    onTap: () => showDocIdDialog(context,
                        docId: docId.isNotEmpty ? docId : '—',
                        title: (row['title'] as String?) ?? '')),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: _V.gold,
                  title: Text(
                      isPublic ? l10n.t('vault_public') : l10n.t('vault_private'),
                      style: const TextStyle(
                          color: _V.text, fontSize: 12, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      isPublic
                          ? l10n.t('vault_public_sub')
                          : l10n.t('vault_private_sub'),
                      style: const TextStyle(color: _V.textMut, fontSize: 10)),
                  value: isPublic,
                  onChanged: me == null
                      ? null
                      : (v) async {
                          setSheet(() => isPublic = v);
                          await _docs.togglePublic(
                              uid: me.id,
                              documentId: row['id'].toString(),
                              docId: docId,
                              isPublic: v);
                        },
                ),
                _MenuTile(
                    icon: Icons.delete_outline_rounded,
                    label: l10n.t('common_delete'),
                    color: _V.dangerBright,
                    onTap: () async {
                      if (me == null) return;
                      try {
                        await _docs.deleteDocument(
                            uid: me.id,
                            documentId: (row['id'] ?? '').toString(),
                            storagePath: (row['storage_path'] as String?) ?? '',
                            docId: docId);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _snack(l10n.t('vault_deleted'));
                      } catch (_) {
                        _snack(l10n.t('vault_delete_failed'), error: true);
                      }
                    }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = context.watch<AuthController>().currentUser;

    return Scaffold(
      backgroundColor: _V.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: _V.surface,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  _IconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () {
                        final auth = context.read<AuthController>();
                        if (auth.isAuthenticated) {
                          final t = auth.currentUser?.accountType;
                          context.go(t == AccountType.enterprise
                              ? AppRoutes.enterpriseDashboard
                              : AppRoutes.userDashboard);
                          return;
                        }
                        context.go(AppRoutes.home);
                      }),
                  const SizedBox(width: 8),
                  const Icon(Icons.lock_rounded, color: _V.gold, size: 16),
                  const SizedBox(width: 6),
                  Text(l10n.t('vault_title'),
                      style: const TextStyle(
                          color: _V.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: _V.ok.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _V.ok.withOpacity(0.3))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_rounded,
                            color: _V.ok, size: 10),
                        const SizedBox(width: 4),
                        Text(l10n.t('vault_secure'),
                            style: const TextStyle(
                                color: _V.ok,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _IconBtn(icon: Icons.search_rounded, onTap: _verifyById),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                    color: _V.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _V.border)),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: _V.text, fontSize: 12),
                  onChanged: (v) {
                    setState(() => _query = v.trim().toLowerCase());
                    if (_query.isNotEmpty && _tabController.index != 0) {
                      _tabController.animateTo(0);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: l10n.t('vault_search_hint'),
                    hintStyle: const TextStyle(color: _V.textMut, fontSize: 11.5),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 15, color: _V.textSec),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 13, color: _V.textSec),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
            ),
            Container(
              height: 34,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                  color: _V.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _V.border)),
              child: TabBar(
                controller: _tabController,
                indicator:
                    BoxDecoration(color: _V.gold, borderRadius: BorderRadius.circular(8)),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: _V.bg,
                unselectedLabelColor: _V.textSec,
                labelStyle:
                    const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: l10n.t('vault_tab_vault')),
                  Tab(text: l10n.t('vault_tab_send')),
                  Tab(text: l10n.t('vault_tab_received')),
                  Tab(text: l10n.t('vault_tab_audit')),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _VaultTab(
                    me: me,
                    docs: _docs,
                    query: _query,
                    folderFilter: _folderFilter,
                    onFolder: (id) => setState(() => _folderFilter = id),
                    onCreateFolder: _createFolder,
                    onOpen: _openDoc,
                    onMenu: _docMenu,
                    fmtDate: _fmtDate,
                    fmtSize: _fmtSize,
                  ),
                  _SendTab(
                      me: me, docs: _docs, onSend: () => _openSendSheet(), fmtDate: _fmtDate),
                  _InboxTab(me: me, docs: _docs, onOpen: _openDoc, fmtDate: _fmtDate),
                  _AuditTab(me: me, docs: _docs, fmtDate: _fmtDate),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.small(
              backgroundColor: _V.gold,
              foregroundColor: _V.bg,
              onPressed: _pickAndUpload,
              child: const Icon(Icons.add_moderator_rounded, size: 18),
            )
          : null,
    );
  }
}

// =============================================================
// WIDGETS COMPACTS
// =============================================================
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            color: _V.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _V.border)),
        child: Icon(icon, size: 14, color: _V.textSec),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _MenuTile(
      {required this.icon, required this.label, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color ?? _V.textSec),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: color ?? _V.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Image mise en cache (bytes en mémoire) — évite les appels réseau répétés.
class _CachedImg extends StatefulWidget {
  final String url;
  final double size;
  final BorderRadius? radius;
  final Widget fallback;
  const _CachedImg(
      {required this.url,
      required this.size,
      this.radius,
      required this.fallback});
  @override
  State<_CachedImg> createState() => _CachedImgState();
}

class _CachedImgState extends State<_CachedImg> {
  static final Map<String, Future<Uint8List>> _cache = {};
  @override
  Widget build(BuildContext context) {
    final fut = _cache.putIfAbsent(widget.url,
        () => http.get(Uri.parse(widget.url)).then((r) => r.bodyBytes));
    return FutureBuilder<Uint8List>(
      future: fut,
      builder: (context, snap) {
        if (!snap.hasData) return widget.fallback;
        return ClipRRect(
          borderRadius: widget.radius ?? BorderRadius.zero,
          child: Image.memory(
            snap.data!,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => widget.fallback,
          ),
        );
      },
    );
  }
}

/// Countdown ROUGE CLAIR (visible, lumineux)
class _Count extends StatefulWidget {
  final DateTime start;
  final DateTime target;
  final String label;
  final Color color;
  const _Count(
      {required this.start,
      required this.target,
      required this.label,
      this.color = _V.dangerBright});
  @override
  State<_Count> createState() => _CountState();
}

class _CountState extends State<_Count> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rem = widget.target.difference(DateTime.now());
    final total = widget.target.difference(widget.start).inMilliseconds;
    final elapsed = DateTime.now().difference(widget.start).inMilliseconds;
    final p = total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0);
    String f(Duration d) {
      if (d.isNegative) return '00:00:00';
      return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label,
                style: TextStyle(
                    fontSize: 9,
                    color: widget.color.withOpacity(0.85),
                    fontWeight: FontWeight.w800)),
            Text(f(rem),
                style: TextStyle(
                    fontSize: 10.5,
                    color: widget.color,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: widget.color.withOpacity(0.6), blurRadius: 6)
                    ])),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p,
            minHeight: 5,
            backgroundColor: widget.color.withOpacity(0.25),
            valueColor: AlwaysStoppedAnimation(widget.color),
          ),
        ),
      ],
    );
  }
}

Color _typeColor(String? mime, String? docType) {
  final m = (mime ?? '').toLowerCase();
  final t = (docType ?? '').toLowerCase();
  if (m.contains('image')) return _V.info;
  if (m.contains('pdf')) return _V.danger;
  if (t.contains('diplome') || t.contains('diplôme') || t.contains('attestation')) {
    return _V.ok;
  }
  if (t == 'cin' || t == 'passeport' || t == 'permis') return _V.gold;
  return _V.textSec;
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

bool _isImageMime(String? mime, String? fileName) {
  final m = (mime ?? '').toLowerCase();
  final n = (fileName ?? '').toLowerCase();
  return m.startsWith('image/') ||
      n.endsWith('.jpg') ||
      n.endsWith('.jpeg') ||
      n.endsWith('.png') ||
      n.endsWith('.webp');
}

void showQrDialog(BuildContext context,
    {required String title, required String value}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: _V.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _V.text, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: QrImageView(
                data: value,
                version: QrVersions.auto,
                size: 160,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(value,
                style: const TextStyle(
                    color: _V.textSec, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _V.gold, foregroundColor: _V.bg),
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context).t('common_close'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showDocIdDialog(BuildContext context,
    {required String docId, required String title}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: _V.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    color: _V.text, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _V.cardSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _V.border)),
              child: SelectableText(docId,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _V.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 32,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context).t('common_close'),
                    style: const TextStyle(color: _V.textSec, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Demande de mot de passe (partage chiffré) — fonction globale
Future<bool> askVaultPassword(
    BuildContext context, DocumentService docs, String stored) async {
  final l10n = AppLocalizations.of(context);
  final ctrl = TextEditingController();
  String? err;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: _V.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          const Icon(Icons.lock_rounded, color: _V.gold, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(l10n.t('vault_password_required'),
                  style: const TextStyle(
                      color: _V.text, fontSize: 13, fontWeight: FontWeight.w800))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            obscureText: true,
            style: const TextStyle(color: _V.text, fontSize: 13),
            decoration: InputDecoration(
              hintText: l10n.t('vault_password'),
              hintStyle: const TextStyle(color: _V.textMut, fontSize: 12),
              filled: true,
              fillColor: _V.cardSoft,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _V.border)),
            ),
          ),
          if (err != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(err!,
                    style: const TextStyle(
                        color: _V.dangerBright, fontSize: 10.5))),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.t('common_cancel'),
                  style: const TextStyle(color: _V.textSec, fontSize: 12))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _V.gold,
                foregroundColor: _V.bg,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            onPressed: () async {
              final valid =
                  await docs.verifyPassword(password: ctrl.text, hash: stored);
              if (valid) {
                Navigator.pop(ctx, true);
              } else {
                setDlg(() => err = l10n.t('vault_wrong_password'));
              }
            },
            child: Text(l10n.t('vault_decrypt_open'),
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}

// =============================================================
// ONGLET COFFRE
// =============================================================
class _VaultTab extends StatelessWidget {
  final AppUser? me;
  final DocumentService docs;
  final String query;
  final String? folderFilter;
  final void Function(String?) onFolder;
  final Future<void> Function(String) onCreateFolder;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  final Future<void> Function(Map<String, dynamic>) onMenu;
  final String Function(dynamic) fmtDate;
  final String Function(int) fmtSize;

  const _VaultTab({
    required this.me,
    required this.docs,
    required this.query,
    required this.folderFilter,
    required this.onFolder,
    required this.onCreateFolder,
    required this.onOpen,
    required this.onMenu,
    required this.fmtDate,
    required this.fmtSize,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (me == null) {
      return Center(
          child: Text(l10n.t('vault_connect'),
              style: const TextStyle(color: _V.textSec, fontSize: 12)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
      children: [
        SizedBox(
          height: 28,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: docs.streamFolders(me!.id),
            builder: (context, snap) {
              final folders = snap.data ?? const [];
              return ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FolderChip(
                      label: l10n.t('vault_all'),
                      selected: folderFilter == null,
                      onTap: () => onFolder(null)),
                  ...folders.map((f) => _FolderChip(
                      label: (f['name'] as String?) ?? '—',
                      selected: folderFilter == f['id'],
                      onTap: () => onFolder(f['id'] as String))),
                  _FolderChip(
                      label: '+ ${l10n.t('vault_new_folder')}',
                      selected: false,
                      onTap: () => onCreateFolder(me!.id)),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: docs.streamDocuments(me!.id),
          builder: (context, snap) {
            var list = snap.data ?? const <Map<String, dynamic>>[];
            if (folderFilter != null) {
              list = list.where((d) => d['folder_id'] == folderFilter).toList();
            }
            if (query.isNotEmpty) {
              list = list.where((d) {
                final hay =
                    '${d['title'] ?? ''} ${d['generated_doc_id'] ?? ''} ${d['doc_type'] ?? ''} ${d['file_name'] ?? ''}'
                        .toLowerCase();
                return hay.contains(query);
              }).toList();
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _V.gold))));
            }
            if (query.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l10n.t('vault_results', args: ['${list.length}']),
                    style: const TextStyle(
                        color: _V.gold, fontSize: 10, fontWeight: FontWeight.w800)),
              );
            }
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 50),
                child: Column(
                  children: [
                    const Icon(Icons.shield_outlined, size: 40, color: _V.border),
                    const SizedBox(height: 10),
                    Text(l10n.t('vault_empty'),
                        style: const TextStyle(
                            color: _V.textSec,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(l10n.t('vault_empty_hint'),
                        style: const TextStyle(color: _V.textMut, fontSize: 10.5)),
                  ],
                ),
              );
            }
            return Column(
              children: list
                  .map((d) => _DocRow(
                        data: d,
                        docs: docs,
                        onOpen: () => onOpen(d),
                        onMenu: () => onMenu(d),
                        fmtDate: fmtDate,
                        fmtSize: fmtSize,
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _FolderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FolderChip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: selected ? _V.gold : _V.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? _V.gold : _V.border)),
        child: Text(label,
            style: TextStyle(
                color: selected ? _V.bg : _V.textSec,
                fontSize: 10,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final DocumentService docs;
  final VoidCallback onOpen;
  final VoidCallback onMenu;
  final String Function(dynamic) fmtDate;
  final String Function(int) fmtSize;
  const _DocRow({
    required this.data,
    required this.docs,
    required this.onOpen,
    required this.onMenu,
    required this.fmtDate,
    required this.fmtSize,
  });

  @override
  Widget build(BuildContext context) {
    final mime = (data['mime_type'] as String?) ?? '';
    final docType = data['doc_type'] as String?;
    final color = _typeColor(mime, docType);
    final isPublic = (data['is_public'] as bool?) ?? false;
    final isImage = _isImageMime(mime, data['file_name'] as String?);
    return GestureDetector(
      onTap: onOpen,
      onLongPress: onMenu,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
            color: _V.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _V.border)),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9)),
              child: isImage
                  ? FutureBuilder<String>(
                      future: docs.resolveRowDownloadUrl(data),
                      builder: (c, sn) => sn.hasData
                          ? _CachedImg(
                              url: sn.data!,
                              size: 38,
                              radius: BorderRadius.circular(9),
                              fallback:
                                  Icon(_typeIcon(mime, docType), color: color, size: 17))
                          : Icon(_typeIcon(mime, docType), color: color, size: 17),
                    )
                  : Icon(_typeIcon(mime, docType), color: color, size: 17),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((data['title'] as String?) ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _V.text, fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                      '${fmtDate(data['created_at'])} • ${fmtSize((data['size_bytes'] as num?)?.toInt() ?? 0)} • ${(data['generated_doc_id'] as String?) ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _V.textMut, fontSize: 9.5)),
                ],
              ),
            ),
            if (isPublic)
              const Icon(Icons.public_rounded, size: 12, color: _V.gold),
            const SizedBox(width: 4),
            GestureDetector(
                onTap: onMenu,
                child:
                    const Icon(Icons.more_vert_rounded, size: 14, color: _V.textSec)),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// ONGLET ENVOIS
// =============================================================
class _SendTab extends StatefulWidget {
  final AppUser? me;
  final DocumentService docs;
  final VoidCallback onSend;
  final String Function(dynamic) fmtDate;
  const _SendTab(
      {required this.me,
      required this.docs,
      required this.onSend,
      required this.fmtDate});
  @override
  State<_SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<_SendTab> {
  final Set<String> _destroyed = {};

  String _stLabel(AppLocalizations l10n, String st) {
    switch (st) {
      case 'opened':
        return l10n.t('vault_st_opened');
      case 'available':
        return l10n.t('vault_st_sent');
      case 'pending':
        return l10n.t('vault_st_pending');
      case 'expired':
        return l10n.t('vault_st_expired');
      case 'destroyed':
        return l10n.t('vault_st_destroyed');
      default:
        return st;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (widget.me == null) {
      return Center(
          child: Text(l10n.t('vault_connect'),
              style: const TextStyle(color: _V.textSec, fontSize: 12)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _V.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _V.gold.withOpacity(0.35))),
          child: Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _V.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.shield_rounded, color: _V.gold, size: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l10n.t('vault_send_subtitle'),
                    style: const TextStyle(
                        color: _V.textSec, fontSize: 10.5, height: 1.35)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _V.gold,
                    foregroundColor: _V.bg,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9)),
                onPressed: widget.onSend,
                child: Text(l10n.t('vault_new_send'),
                    style: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: widget.docs.streamSentShares(widget.me!.id),
          builder: (context, snap) {
            final shares = snap.data ?? const [];
            final now = DateTime.now();
            final visible = shares.where((s) {
              final st = (s['status'] as String?) ?? 'pending';
              final ad =
                  DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
              if (st == 'destroyed' || st == 'expired') return false;
              if (ad != null && ad.isBefore(now)) {
                final id = s['id']?.toString();
                if (id != null && _destroyed.add(id)) {
                  widget.docs.markShareDestroyed(id);
                }
                return false;
              }
              return true;
            }).toList();
            if (visible.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: Text(l10n.t('vault_no_sent'),
                        style: const TextStyle(
                            color: _V.textMut, fontSize: 11.5))),
              );
            }
            return Column(
              children: visible.map((s) {
                final st = (s['status'] as String?) ?? 'pending';
                final hasPw = (s['password_hash'] as String?)?.isNotEmpty == true;
                final ad =
                    DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
                final cd = DateTime.tryParse((s['created_at'] ?? '').toString()) ??
                    now;
                final c = st == 'opened'
                    ? _V.ok
                    : (st == 'pending' ? _V.warn : _V.info);
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: _V.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _V.border)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                              st == 'opened'
                                  ? Icons.mark_email_read_rounded
                                  : Icons.send_rounded,
                              size: 14,
                              color: c),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((s['recipient_thix_id'] as String?) ?? '—',
                                    style: const TextStyle(
                                        color: _V.text,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800)),
                                Text(
                                    (s['subject'] as String?)?.isNotEmpty == true
                                        ? s['subject'] as String
                                        : l10n.t('vault_send_subtitle'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _V.textMut, fontSize: 9.5)),
                              ],
                            ),
                          ),
                          if (hasPw)
                            const Icon(Icons.lock_rounded, size: 11, color: _V.gold),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                                color: c.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(_stLabel(l10n, st),
                                style: TextStyle(
                                    color: c,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      if (ad != null) ...[
                        const SizedBox(height: 7),
                        _Count(
                            start: cd,
                            target: ad,
                            label: l10n.t('vault_destruct_in'),
                            color: _V.dangerBright),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// =============================================================
// ONGLET REÇUS (boîte mail + détail "Voir plus")
// =============================================================
class _InboxTab extends StatefulWidget {
  final AppUser? me;
  final DocumentService docs;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  final String Function(dynamic) fmtDate;
  const _InboxTab(
      {required this.me,
      required this.docs,
      required this.onOpen,
      required this.fmtDate});
  @override
  State<_InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<_InboxTab> {
  final Set<String> _destroyed = {};

  void _showDetail(Map<String, dynamic> s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InboxDetailSheet(
        share: s,
        docs: widget.docs,
        me: widget.me,
        fmtDate: widget.fmtDate,
        onOpenDoc: widget.onOpen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (widget.me == null) {
      return Center(
          child: Text(l10n.t('vault_connect'),
              style: const TextStyle(color: _V.textSec, fontSize: 12)));
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream:
          widget.docs.streamReceivedShares(widget.me!.id, widget.me!.thixId),
      builder: (context, snap) {
        final shares = snap.data ?? const [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _V.gold)));
        }
        final now = DateTime.now();
        final visible = shares.where((s) {
          final st = (s['status'] as String?) ?? 'pending';
          final ad = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
          if (st == 'destroyed' || st == 'expired') return false;
          if (ad != null && ad.isBefore(now)) {
            final id = s['id']?.toString();
            if (id != null && _destroyed.add(id)) {
              widget.docs.markShareDestroyed(id);
            }
            return false;
          }
          return true;
        }).toList();
        if (visible.isEmpty) {
          return Center(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_rounded, size: 40, color: _V.border),
              const SizedBox(height: 10),
              Text(l10n.t('vault_received_empty'),
                  style: const TextStyle(
                      color: _V.textSec, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
          children: visible.map((s) {
            final st = (s['status'] as String?) ?? 'pending';
            final hasPw = (s['password_hash'] as String?)?.isNotEmpty == true;
            final shots = (s['screenshot_count'] as num?)?.toInt() ?? 0;
            final af = DateTime.tryParse((s['available_from'] ?? '').toString());
            final ad = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
            final cd =
                DateTime.tryParse((s['created_at'] ?? '').toString()) ?? now;
            final locked = st == 'pending' && af != null && af.isAfter(now);
            final senderThix = s['sender_thix_id'] as String?;
            final senderId = (s['sender_id'] as String?) ?? '';
            final sender = senderThix ??
                (senderId.length >= 8 ? senderId.substring(0, 8) : '—');
            return GestureDetector(
              onTap: () => _showDetail(s),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _V.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: locked ? _V.warn.withOpacity(0.4) : _V.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: _V.gold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8)),
                          child: Icon(
                              locked
                                  ? Icons.lock_clock_rounded
                                  : Icons.mark_email_unread_rounded,
                              size: 15,
                              color: locked ? _V.warn : _V.gold),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                        (s['subject'] as String?)?.isNotEmpty == true
                                            ? s['subject'] as String
                                            : l10n.t('vault_attachment'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: _V.text,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  if (hasPw)
                                    const Icon(Icons.lock_rounded,
                                        size: 11, color: _V.gold),
                                  if (shots > 0) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.camera_alt_rounded,
                                        size: 11, color: _V.warn),
                                  ],
                                ],
                              ),
                              Text(
                                  (s['body'] as String?)?.isNotEmpty == true
                                      ? s['body'] as String
                                      : l10n.t('vault_no_message'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: _V.textSec, fontSize: 10)),
                            ],
                          ),
                        ),
                        Text(widget.fmtDate(s['created_at']),
                            style: const TextStyle(
                                color: _V.textMut, fontSize: 9)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('${l10n.t('vault_from')} $sender',
                            style: const TextStyle(
                                color: _V.textMut,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                              color: (locked
                                      ? _V.warn
                                      : (st == 'opened' ? _V.ok : _V.info))
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(
                              locked
                                  ? l10n.t('vault_st_pending')
                                  : (st == 'opened'
                                      ? l10n.t('vault_st_opened')
                                      : l10n.t('vault_st_available')),
                              style: TextStyle(
                                  color: locked
                                      ? _V.warn
                                      : (st == 'opened' ? _V.ok : _V.info),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded,
                            size: 14, color: _V.textMut),
                      ],
                    ),
                    if (locked && af != null) ...[
                      const SizedBox(height: 7),
                      _Count(
                          start: cd,
                          target: af,
                          label: l10n.t('vault_unlock_in'),
                          color: _V.warn),
                    ] else if (ad != null) ...[
                      const SizedBox(height: 7),
                      _Count(
                          start: cd,
                          target: ad,
                          label: l10n.t('vault_destruct_in'),
                          color: _V.dangerBright),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// =============================================================
// SHEET DÉTAIL REÇU (type mail + actions)
// =============================================================
class _InboxDetailSheet extends StatefulWidget {
  final Map<String, dynamic> share;
  final DocumentService docs;
  final AppUser? me;
  final String Function(dynamic) fmtDate;
  final Future<void> Function(Map<String, dynamic>) onOpenDoc;
  const _InboxDetailSheet({
    required this.share,
    required this.docs,
    required this.me,
    required this.fmtDate,
    required this.onOpenDoc,
  });
  @override
  State<_InboxDetailSheet> createState() => _InboxDetailSheetState();
}

class _InboxDetailSheetState extends State<_InboxDetailSheet> {
  Map<String, dynamic>? _doc;
  Map<String, dynamic>? _sender;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final docId = widget.share['document_id']?.toString();
    final senderId = widget.share['sender_id']?.toString();
    try {
      final res = await Future.wait<dynamic>([
        docId != null
            ? widget.docs.fetchDocumentById(docId)
            : Future.value(null),
        senderId != null
            ? Supabase.instance.client
                .from('profiles')
                .select('full_name, thix_id, avatar_url')
                .eq('id', senderId)
                .maybeSingle()
            : Future.value(null),
      ]);
      if (!mounted) return;
      setState(() {
        _doc = (res[0] as Map?)?.cast<String, dynamic>();
        _sender = (res[1] as Map?)?.cast<String, dynamic>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontSize: 11)),
        backgroundColor: error ? _V.dangerBright : _V.ok,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2)));
  }

  Future<void> _open() async {
    if (_doc == null) return;
    final hasPw = (widget.share['password_hash'] as String?)?.isNotEmpty == true;
    if (hasPw) {
      final ok = await askVaultPassword(
          context, widget.docs, widget.share['password_hash'] as String);
      if (!ok) return;
    }
    await widget.docs.markShareOpened(widget.share['id'].toString(),
        uid: _doc!['user_id']?.toString(),
        docId: _doc!['generated_doc_id']?.toString());
    if (mounted) Navigator.pop(context);
    await widget.onOpenDoc(_doc!);
  }

  Future<void> _saveToVault() async {
    final l10n = AppLocalizations.of(context);
    if (_doc == null || widget.me == null) return;
    setState(() => _busy = true);
    try {
      final url = await widget.docs.resolveRowDownloadUrl(_doc!);
      final resp = await http.get(Uri.parse(url));
      final name = (_doc!['file_name'] as String?) ??
          (_doc!['title'] as String?) ??
          'document';
      final file =
          PlatformFile(name: name, bytes: resp.bodyBytes, size: resp.bodyBytes.length);
      await widget.docs.uploadPickedFileSimple(
        uid: widget.me!.id,
        file: file,
        docType: (_doc!['doc_type'] as String?) ?? 'Autre',
        title: _doc!['title'] as String?,
        isPublic: false,
      );
      _snack(l10n.t('vault_saved_ok'));
    } catch (_) {
      _snack(l10n.t('vault_save_failed'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forward() async {
    if (_doc == null) return;
    Navigator.pop(context);
    final me = widget.me;
    if (me == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SendSheet(
        documents: [_doc!],
        docsService: widget.docs,
        initialDocId: _doc!['id'].toString(),
        onDone: (ok) {
          if (!mounted) return;
          Navigator.pop(context);
          _snack(AppLocalizations.of(context)
              .t(ok ? 'vault_send_ok' : 'vault_send_failed'), error: !ok);
        },
      ),
    );
  }

  Future<void> _download() async {
    if (_doc == null) return;
    try {
      final url = await widget.docs.resolveRowDownloadUrl(_doc!);
      await launchUrl(Uri.parse(url),
          mode: kIsWeb
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication);
    } catch (_) {
      _snack(AppLocalizations.of(context).t('vault_download_failed'), error: true);
    }
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration:
            BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(t,
            style: TextStyle(color: c, fontSize: 8.5, fontWeight: FontWeight.w900)),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = widget.share;
    final st = (s['status'] as String?) ?? 'pending';
    final hasPw = (s['password_hash'] as String?)?.isNotEmpty == true;
    final shots = (s['screenshot_count'] as num?)?.toInt() ?? 0;
    final af = DateTime.tryParse((s['available_from'] ?? '').toString());
    final ad = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
    final cd = DateTime.tryParse((s['created_at'] ?? '').toString()) ?? DateTime.now();
    final locked = st == 'pending' && af != null && af.isAfter(DateTime.now());
    final name = (_sender?['full_name'] as String?) ?? l10n.t('vault_anonymous');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final mime = (_doc?['mime_type'] as String?) ?? '';
    final isImage = _isImageMime(mime, _doc?['file_name'] as String?);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: const BoxDecoration(
            color: _V.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _V.gold)))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: _V.gold.withOpacity(0.15),
                              shape: BoxShape.circle),
                          child: Center(
                              child: Text(initial,
                                  style: const TextStyle(
                                      color: _V.gold,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      color: _V.text,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800)),
                              Text(
                                  (_sender?['thix_id'] as String?) ??
                                      '${l10n.t('vault_from')} ${(s['sender_id'] as String? ?? '').length >= 8 ? (s['sender_id'] as String).substring(0, 8) : '—'}',
                                  style: const TextStyle(
                                      color: _V.textMut, fontSize: 9.5)),
                            ],
                          ),
                        ),
                        Text(widget.fmtDate(s['created_at']),
                            style:
                                const TextStyle(color: _V.textMut, fontSize: 9)),
                        const SizedBox(width: 6),
                        GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: _V.textSec)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                        (s['subject'] as String?)?.isNotEmpty == true
                            ? s['subject'] as String
                            : l10n.t('vault_attachment'),
                        style: const TextStyle(
                            color: _V.text, fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _chip(
                            locked
                                ? l10n.t('vault_st_pending')
                                : (st == 'opened'
                                    ? l10n.t('vault_st_opened')
                                    : l10n.t('vault_st_available')),
                            locked ? _V.warn : (st == 'opened' ? _V.ok : _V.info)),
                        if (hasPw) _chip(l10n.t('vault_password'), _V.gold),
                        if (shots > 0) _chip('📸 $shots', _V.warn),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: _V.cardSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _V.border)),
                      child: SelectableText(
                          (s['body'] as String?)?.isNotEmpty == true
                              ? s['body'] as String
                              : l10n.t('vault_no_message'),
                          style: const TextStyle(
                              color: _V.textSec, fontSize: 11.5, height: 1.5)),
                    ),
                    const SizedBox(height: 12),
                    if (_doc != null)
                      GestureDetector(
                        onTap: _open,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                              color: _V.cardSoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _V.gold.withOpacity(0.35))),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                    color: _typeColor(mime,
                                            _doc!['doc_type'] as String?)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(9)),
                                child: isImage
                                    ? FutureBuilder<String>(
                                        future: widget.docs
                                            .resolveRowDownloadUrl(_doc!),
                                        builder: (c, sn) => sn.hasData
                                            ? _CachedImg(
                                                url: sn.data!,
                                                size: 44,
                                                radius: BorderRadius.circular(9),
                                                fallback: Icon(
                                                    _typeIcon(mime,
                                                        _doc!['doc_type'] as String?),
                                                    color: _typeColor(mime,
                                                        _doc!['doc_type'] as String?),
                                                    size: 18))
                                            : Icon(
                                                _typeIcon(mime,
                                                    _doc!['doc_type'] as String?),
                                                color: _typeColor(mime,
                                                    _doc!['doc_type'] as String?),
                                                size: 18))
                                    : Icon(
                                        _typeIcon(mime, _doc!['doc_type'] as String?),
                                        color: _typeColor(
                                            mime, _doc!['doc_type'] as String?),
                                        size: 18),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text((_doc!['title'] as String?) ?? '—',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: _V.text,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800)),
                                    Text(
                                        '${_doc!['doc_type'] ?? '—'} • ${(_doc!['generated_doc_id'] as String?) ?? ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: _V.textMut, fontSize: 9)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  size: 15, color: _V.gold),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (locked && af != null) ...[
                      _Count(
                          start: cd,
                          target: af,
                          label: l10n.t('vault_unlock_in'),
                          color: _V.warn),
                      const SizedBox(height: 10),
                    ],
                    if (ad != null) ...[
                      _Count(
                          start: cd,
                          target: ad,
                          label: l10n.t('vault_destruct_in'),
                          color: _V.dangerBright),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                            child: _ActBtn(
                                icon: Icons.open_in_new_rounded,
                                label: l10n.t('vault_open'),
                                color: _V.gold,
                                busy: _busy,
                                onTap: _open)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _ActBtn(
                                icon: Icons.download_rounded,
                                label: l10n.t('vault_download'),
                                color: _V.info,
                                busy: _busy,
                                onTap: _download)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: _ActBtn(
                                icon: Icons.save_rounded,
                                label: l10n.t('vault_save_vault'),
                                color: _V.ok,
                                busy: _busy,
                                onTap: _saveToVault)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _ActBtn(
                                icon: Icons.forward_rounded,
                                label: l10n.t('vault_forward'),
                                color: _V.warn,
                                busy: _busy,
                                onTap: _forward)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ActBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool busy;
  final VoidCallback onTap;
  const _ActBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.busy,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withOpacity(0.5)),
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 8)),
        onPressed: busy ? null : onTap,
        icon: Icon(icon, size: 13),
        label: Text(label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// =============================================================
// ONGLET AUDIT
// =============================================================
class _AuditTab extends StatelessWidget {
  final AppUser? me;
  final DocumentService docs;
  final String Function(dynamic) fmtDate;
  const _AuditTab({required this.me, required this.docs, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (me == null) {
      return Center(
          child: Text(l10n.t('vault_connect'),
              style: const TextStyle(color: _V.textSec, fontSize: 12)));
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: docs.streamTransactions(me!.id),
      builder: (context, snap) {
        final tx = snap.data ?? const [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _V.gold)));
        }
        if (tx.isEmpty) {
          return Center(
              child: Text(l10n.t('vault_audit_empty'),
                  style: const TextStyle(color: _V.textMut, fontSize: 11.5)));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
          children: tx.map((t) {
            final a = (t['action'] as String?) ?? '';
            IconData ic;
            Color c;
            String lb;
            switch (a) {
              case 'upload':
                ic = Icons.cloud_upload_rounded;
                c = _V.info;
                lb = l10n.t('vault_act_upload');
                break;
              case 'send':
                ic = Icons.send_rounded;
                c = _V.gold;
                lb = l10n.t('vault_act_send');
                break;
              case 'open':
                ic = Icons.visibility_rounded;
                c = _V.ok;
                lb = l10n.t('vault_act_open');
                break;
              case 'delete':
                ic = Icons.delete_outline_rounded;
                c = _V.dangerBright;
                lb = l10n.t('vault_act_delete');
                break;
              case 'screenshot':
                ic = Icons.camera_alt_rounded;
                c = _V.warn;
                lb = l10n.t('vault_act_screenshot');
                break;
              case 'public_toggle':
                ic = Icons.public_rounded;
                c = _V.gold;
                lb = l10n.t('vault_act_public');
                break;
              case 'folder_create':
                ic = Icons.create_new_folder_rounded;
                c = _V.info;
                lb = l10n.t('vault_act_folder');
                break;
              default:
                ic = Icons.history_rounded;
                c = _V.textSec;
                lb = a;
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              decoration: BoxDecoration(
                  color: _V.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _V.border)),
              child: Row(
                children: [
                  Icon(ic, size: 13, color: c),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lb,
                            style: const TextStyle(
                                color: _V.text,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                        Text((t['detail'] as String?) ?? (t['doc_id'] as String?) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _V.textMut, fontSize: 9)),
                      ],
                    ),
                  ),
                  Text(fmtDate(t['created_at']),
                      style: const TextStyle(color: _V.textMut, fontSize: 9)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// =============================================================
// DIALOG DOCUMENT CERTIFIÉ (recherche publique → affiche le doc)
// =============================================================
class _CertifiedDocDialog extends StatelessWidget {
  final Map<String, dynamic> res;
  final DocumentService docs;
  final Future<void> Function(String) onOpen;
  final AppUser? me;
  final VoidCallback onSaved;
  final VoidCallback onSaveFailed;
  const _CertifiedDocDialog({
    required this.res,
    required this.docs,
    required this.onOpen,
    required this.me,
    required this.onSaved,
    required this.onSaveFailed,
  });

  Future<void> _saveToVault(BuildContext context) async {
    final path = (res['storage_path'] as String?) ?? '';
    if (path.isEmpty || me == null) return;
    try {
      final url = await docs.createDownloadUrl(storagePath: path);
      final resp = await http.get(Uri.parse(url));
      final name = (res['file_name'] as String?) ?? (res['title'] as String?) ?? 'doc';
      final file =
          PlatformFile(name: name, bytes: resp.bodyBytes, size: resp.bodyBytes.length);
      await docs.uploadPickedFileSimple(
        uid: me!.id,
        file: file,
        docType: (res['doc_type'] as String?) ?? 'Autre',
        title: res['title'] as String?,
        isPublic: false,
      );
      onSaved();
    } catch (_) {
      onSaveFailed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final path = (res['storage_path'] as String?) ?? '';
    final color = _typeColor(res['mime_type'] as String?, res['doc_type'] as String?);
    final img = _isImageMime(res['mime_type'] as String?, res['file_name'] as String?);
    return Dialog(
      backgroundColor: _V.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((res['owner_name'] as String?) ?? l10n.t('vault_from'),
                            style: const TextStyle(
                                color: _V.text,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800)),
                        Text((res['owner_thix_id'] as String?) ?? '—',
                            style:
                                const TextStyle(color: _V.textMut, fontSize: 9.5)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: _V.ok.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, size: 9, color: _V.ok),
                        const SizedBox(width: 3),
                        Text(l10n.t('vault_certified'),
                            style: const TextStyle(
                                color: _V.ok,
                                fontSize: 8,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: img ? 200 : 90,
                decoration: BoxDecoration(
                    color: _V.cardSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.35))),
                clipBehavior: Clip.antiAlias,
                child: img && path.isNotEmpty
                    ? FutureBuilder<String>(
                        future: docs.createDownloadUrl(storagePath: path),
                        builder: (context, snap) => snap.hasData
                            ? _CachedImg(
                                url: snap.data!,
                                size: 200,
                                fallback: Icon(
                                    _typeIcon(res['mime_type'] as String?,
                                        res['doc_type'] as String?),
                                    color: color,
                                    size: 30))
                            : const Center(
                                child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: _V.gold))))
                    : Center(
                        child: Icon(
                            _typeIcon(res['mime_type'] as String?,
                                res['doc_type'] as String?),
                            color: color,
                            size: 30)),
              ),
              const SizedBox(height: 12),
              Text((res['title'] as String?) ?? '—',
                  style: const TextStyle(
                      color: _V.text, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('${res['doc_type'] ?? '—'} • ${res['generated_doc_id'] ?? '—'}',
                  style: const TextStyle(color: _V.textMut, fontSize: 9.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (res['size_bytes'] != null)
                    Text(
                        '${l10n.t('vault_size')}: ${(((res['size_bytes'] as num).toInt()) / 1024).toStringAsFixed(0)} KB',
                        style: const TextStyle(color: _V.textSec, fontSize: 9.5)),
                  const SizedBox(width: 10),
                  Text('${l10n.t('vault_date')}: ${widget_date(res['created_at'])}',
                      style: const TextStyle(color: _V.textSec, fontSize: 9.5)),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 36,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: _V.gold, foregroundColor: _V.bg),
                  onPressed: path.isEmpty
                      ? null
                      : () async {
                          final url =
                              await docs.createDownloadUrl(storagePath: path);
                          if (context.mounted) Navigator.pop(context);
                          await onOpen(url);
                        },
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(l10n.t('vault_open_file'),
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w900)),
                ),
              ),
              if (me != null) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _V.ok.withOpacity(0.5)),
                        foregroundColor: _V.ok),
                    onPressed: () => _saveToVault(context),
                    icon: const Icon(Icons.save_rounded, size: 13),
                    label: Text(l10n.t('vault_save_vault'),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              SizedBox(
                height: 32,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.t('common_close'),
                      style: const TextStyle(color: _V.textSec, fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String widget_date(dynamic v) {
    final d = DateTime.tryParse((v ?? '').toString());
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

// =============================================================
// SHEET UPLOAD
// =============================================================
class _UploadPayload {
  final String docType;
  final String? title;
  final DateTime? expiresAt;
  final String? folderId;
  const _UploadPayload(
      {required this.docType, this.title, this.expiresAt, this.folderId});
}

class _UploadSheet extends StatefulWidget {
  final String fileName;
  final List<Map<String, dynamic>> folders;
  final String? preselectedFolderId;
  const _UploadSheet(
      {required this.fileName,
      required this.folders,
      this.preselectedFolderId});
  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
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

  bool get _needsExpiry =>
      _type == 'CIN' || _type == 'Passeport' || _type == 'Permis';

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _V.textMut, fontSize: 10.5),
        filled: true,
        fillColor: _V.cardSoft,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _V.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _V.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _V.gold)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
            color: _V.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(l10n.t('vault_new_archive'),
                          style: const TextStyle(
                              color: _V.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w900))),
                  GestureDetector(
                      onTap: () => context.pop(),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: _V.textSec)),
                ],
              ),
              const SizedBox(height: 4),
              Text(widget.fileName,
                  style: const TextStyle(
                      color: _V.gold, fontSize: 10.5, fontWeight: FontWeight.w700)),
              Text(l10n.t('vault_auto_id'),
                  style: const TextStyle(color: _V.textMut, fontSize: 9)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _folderId,
                dropdownColor: _V.cardSoft,
                style: const TextStyle(color: _V.text, fontSize: 12),
                decoration: _dec(l10n.t('vault_dest_folder')),
                items: [
                  DropdownMenuItem<String?>(
                      value: null, child: Text(l10n.t('vault_root'))),
                  ...widget.folders.map((f) => DropdownMenuItem<String?>(
                      value: f['id'] as String,
                      child: Text((f['name'] as String?) ?? '—'))),
                ],
                onChanged: (v) => setState(() => _folderId = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _type,
                dropdownColor: _V.cardSoft,
                style: const TextStyle(color: _V.text, fontSize: 12),
                decoration: _dec(l10n.t('vault_class')),
                items: [
                  DropdownMenuItem(
                      value: 'CIN', child: Text(l10n.t('vault_class_cin'))),
                  DropdownMenuItem(
                      value: 'Passeport', child: Text(l10n.t('vault_class_passport'))),
                  DropdownMenuItem(
                      value: 'Permis', child: Text(l10n.t('vault_class_license'))),
                  DropdownMenuItem(
                      value: 'Diplôme', child: Text(l10n.t('vault_class_diploma'))),
                  DropdownMenuItem(
                      value: 'PreuveAdresse',
                      child: Text(l10n.t('vault_class_address'))),
                  DropdownMenuItem(
                      value: 'Autre', child: Text(l10n.t('vault_class_other'))),
                ],
                onChanged: (v) => setState(() {
                  _type = v ?? 'Autre';
                  if (!_needsExpiry) _expiresAt = null;
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titleC,
                style: const TextStyle(color: _V.text, fontSize: 12),
                decoration: _dec(l10n.t('vault_label_opt')),
              ),
              if (_needsExpiry) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _V.border),
                      padding: const EdgeInsets.symmetric(vertical: 10)),
                  onPressed: () async {
                    final now = DateTime.now();
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _expiresAt ?? now,
                      firstDate: now.subtract(const Duration(days: 365 * 20)),
                      lastDate: now.add(const Duration(days: 365 * 50)),
                      builder: (c, ch) => Theme(
                          data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                  primary: _V.gold, surface: _V.card)),
                          child: ch!),
                    );
                    if (p != null) setState(() => _expiresAt = p);
                  },
                  icon: const Icon(Icons.event_available_rounded,
                      size: 14, color: _V.gold),
                  label: Text(
                      _expiresAt == null
                          ? l10n.t('vault_pick_date')
                          : '${l10n.t('vault_expiry')} : ${_expiresAt!.day.toString().padLeft(2, '0')}/${_expiresAt!.month.toString().padLeft(2, '0')}/${_expiresAt!.year}',
                      style: const TextStyle(
                          color: _V.text, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: _V.gold, foregroundColor: _V.bg),
                  onPressed: () {
                    if (_needsExpiry && _expiresAt == null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(l10n.t('vault_expiry_required'),
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor: _V.dangerBright));
                      return;
                    }
                    context.pop(_UploadPayload(
                      docType: _type,
                      title:
                          _titleC.text.trim().isEmpty ? null : _titleC.text.trim(),
                      expiresAt: _expiresAt,
                      folderId: _folderId,
                    ));
                  },
                  icon: const Icon(Icons.cloud_upload_rounded, size: 15),
                  label: Text(l10n.t('vault_finalize'),
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w900)),
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
// SHEET ENVOI
// =============================================================
class _SendSheet extends StatefulWidget {
  final List<Map<String, dynamic>> documents;
  final DocumentService docsService;
  final String? initialDocId;
  final void Function(bool ok) onDone;
  const _SendSheet({
    required this.documents,
    required this.docsService,
    required this.onDone,
    this.initialDocId,
  });
  @override
  State<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<_SendSheet> {
  String? _docId;
  final _recipC = TextEditingController();
  final _subjectC = TextEditingController();
  final _bodyC = TextEditingController();
  final _pwC = TextEditingController();
  final _durC = TextEditingController(text: '10');
  String _unit = 'minutes';
  bool _autoDestruct = false;
  bool _sending = false;
  Timer? _deb;
  String? _verified;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _docId = widget.initialDocId;
  }

  @override
  void dispose() {
    _recipC.dispose();
    _subjectC.dispose();
    _bodyC.dispose();
    _pwC.dispose();
    _durC.dispose();
    _deb?.cancel();
    super.dispose();
  }

  void _onRecip(String v) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 500), () async {
      final ids =
          v.split(RegExp(r'[,;\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty);
      if (ids.isEmpty) {
        setState(() => _verified = null);
        return;
      }
      setState(() => _verifying = true);
      final p = await widget.docsService.verifyThixId(ids.last);
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verified = p == null ? 'KO' : (p['full_name'] as String? ?? 'OK');
      });
    });
  }

  Duration? _dur() {
    if (!_autoDestruct) return null;
    final v = int.tryParse(_durC.text.trim());
    if (v == null || v <= 0) return null;
    switch (_unit) {
      case 's':
        return Duration(seconds: v);
      case 'h':
        return Duration(hours: v);
      case 'd':
        return Duration(days: v);
      default:
        return Duration(minutes: v);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _V.textMut, fontSize: 10.5),
        filled: true,
        fillColor: _V.cardSoft,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _V.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _V.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _V.gold)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(
            color: _V.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(l10n.t('vault_send_title'),
                          style: const TextStyle(
                              color: _V.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w900))),
                  GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: _V.textSec)),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _docId,
                dropdownColor: _V.cardSoft,
                style: const TextStyle(color: _V.text, fontSize: 12),
                decoration: _dec(l10n.t('vault_choose_archive')),
                items: widget.documents.map((d) {
                  final id = d['id'].toString();
                  final t = (d['title'] as String?) ?? '—';
                  return DropdownMenuItem(
                      value: id,
                      child: Text(t,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5)));
                }).toList(),
                onChanged: (v) => setState(() => _docId = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _recipC,
                onChanged: _onRecip,
                style: const TextStyle(color: _V.text, fontSize: 12),
                decoration: _dec(l10n.t('vault_recipient')),
              ),
              if (_verifying)
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l10n.t('vault_verifying'),
                        style: const TextStyle(color: _V.textMut, fontSize: 9.5)))
              else if (_verified != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                          _verified == 'KO'
                              ? Icons.error_rounded
                              : Icons.check_circle_rounded,
                          size: 12,
                          color: _verified == 'KO' ? _V.dangerBright : _V.ok),
                      const SizedBox(width: 5),
                      Text(
                          _verified == 'KO'
                              ? l10n.t('vault_not_found')
                              : _verified!,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _verified == 'KO' ? _V.dangerBright : _V.ok)),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _subjectC,
                style: const TextStyle(color: _V.text, fontSize: 12),
                decoration: _dec(l10n.t('vault_subject')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bodyC,
                maxLines: 3,
                style: const TextStyle(color: _V.text, fontSize: 12),
                decoration: _dec(l10n.t('vault_message')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pwC,
                obscureText: true,
                style: const TextStyle(color: _V.text, fontSize: 12),
                decoration: _dec(l10n.t('vault_password_opt')),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: _V.dangerBright,
                title: Text(l10n.t('vault_autodestruct'),
                    style: const TextStyle(
                        color: _V.text, fontSize: 11.5, fontWeight: FontWeight.w800)),
                subtitle: Text(l10n.t('vault_autodestruct_sub'),
                    style: const TextStyle(color: _V.textMut, fontSize: 9.5)),
                value: _autoDestruct,
                onChanged: (v) => setState(() => _autoDestruct = v),
              ),
              if (_autoDestruct)
                Row(
                  children: [
                    Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _durC,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: _V.text, fontSize: 12),
                          decoration: _dec(l10n.t('vault_delay')),
                        )),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _unit,
                        dropdownColor: _V.cardSoft,
                        style: const TextStyle(color: _V.text, fontSize: 12),
                        decoration: _dec(''),
                        items: [
                          DropdownMenuItem(
                              value: 's', child: Text(l10n.t('vault_seconds'))),
                          DropdownMenuItem(
                              value: 'minutes', child: Text(l10n.t('vault_minutes'))),
                          DropdownMenuItem(
                              value: 'h', child: Text(l10n.t('vault_hours'))),
                          DropdownMenuItem(
                              value: 'd', child: Text(l10n.t('vault_days'))),
                        ],
                        onChanged: (v) => setState(() => _unit = v ?? 'minutes'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: _V.gold, foregroundColor: _V.bg),
                  onPressed: _sending
                      ? null
                      : () async {
                          if (_docId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(l10n.t('vault_select_archive'),
                                    style: const TextStyle(fontSize: 11)),
                                backgroundColor: _V.dangerBright));
                            return;
                          }
                          final recips = _recipC.text
                              .split(RegExp(r'[,;\s]+'))
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();
                          if (recips.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(l10n.t('vault_need_recipient'),
                                    style: const TextStyle(fontSize: 11)),
                                backgroundColor: _V.dangerBright));
                            return;
                          }
                          setState(() => _sending = true);
                          final sel = widget.documents
                              .firstWhere((d) => d['id'].toString() == _docId);
                          try {
                            final me =
                                context.read<AuthController>().currentUser;
                            await widget.docsService.shareDocument(
                              senderId: me!.id,
                              documentId: _docId!,
                              docId: (sel['generated_doc_id'] as String?) ??
                                  (sel['doc_id'] as String?),
                              recipientThixIds: recips,
                              subject: _subjectC.text.trim().isEmpty
                                  ? null
                                  : _subjectC.text.trim(),
                              body: _bodyC.text.trim().isEmpty
                                  ? null
                                  : _bodyC.text.trim(),
                              password: _pwC.text.trim().isEmpty
                                  ? null
                                  : _pwC.text.trim(),
                              autoDestructIn: _dur(),
                            );
                            widget.onDone(true);
                          } catch (_) {
                            setState(() => _sending = false);
                            widget.onDone(false);
                          }
                        },
                  icon: _sending
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _V.bg))
                      : const Icon(Icons.send_rounded, size: 14),
                  label: Text(
                      _sending ? l10n.t('vault_sending') : l10n.t('vault_send_btn'),
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

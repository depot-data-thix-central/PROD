import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/document_service.dart';

// =============================================================
// PALETTE VAULT v2 — graphite & or (compact)
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
  static const info = Color(0xFF60A5FA);
}

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
      backgroundColor: error ? _V.danger : _V.ok,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(
        Uri.parse(url),
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
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
      _snack(AppLocalizations.of(context).t('vault_download_failed'), error: true);
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
            style: const TextStyle(color: _V.text, fontSize: 14, fontWeight: FontWeight.w800)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(l10n.t('vault_create'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
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
      _snack(DocumentService.isBucketNotFound(e)
          ? l10n.t('vault_upload_failed')
          : l10n.t('vault_upload_failed'), error: true);
    }
  }

  Future<void> _openSendSheet() async {
    final l10n = AppLocalizations.of(context);
    final me = context.read<AuthController>().currentUser;
    if (me == null) return;
    final docs = await _docs.fetchDocuments(me.id, limit: 50);
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
        onDone: (ok) {
          if (!mounted) return;
          Navigator.of(context).pop();
          _snack(ok ? l10n.t('vault_send_ok') : l10n.t('vault_send_failed'), error: !ok);
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
            style: const TextStyle(color: _V.text, fontSize: 14, fontWeight: FontWeight.w800)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(l10n.t('common_search'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
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
      builder: (ctx) => _CertifiedDocDialog(res: res, docs: _docs, onOpen: _openUrl),
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
          decoration: BoxDecoration(
              color: _V.card, borderRadius: BorderRadius.circular(16)),
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
                  },
                ),
                _MenuTile(
                  icon: Icons.qr_code_2_rounded,
                  label: l10n.t('vault_menu_qr'),
                  onTap: () => showQrDialog(context,
                      title: (row['title'] as String?) ?? '',
                      value: docId.isNotEmpty ? docId : (row['title'] as String? ?? '')),
                ),
                _MenuTile(
                  icon: Icons.badge_outlined,
                  label: l10n.t('vault_menu_id'),
                  onTap: () => showDocIdDialog(context,
                      docId: docId.isNotEmpty ? docId : '—',
                      title: (row['title'] as String?) ?? ''),
                ),
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
                  color: _V.danger,
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
                  },
                ),
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
            // ── HEADER compact ──
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
                    },
                  ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: _V.ok.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _V.ok.withOpacity(0.3))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_rounded, color: _V.ok, size: 10),
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
            // ── SEARCH inline compact ──
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
                    prefixIcon:
                        const Icon(Icons.search_rounded, size: 15, color: _V.textSec),
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
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
            ),
            // ── TABS compact ──
            Container(
              height: 34,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                  color: _V.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _V.border)),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                    color: _V.gold, borderRadius: BorderRadius.circular(8)),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: _V.bg,
                unselectedLabelColor: _V.textSec,
                labelStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
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
                  _SendTab(me: me, docs: _docs, onSend: _openSendSheet, fmtDate: _fmtDate),
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

class _Count extends StatefulWidget {
  final DateTime start;
  final DateTime target;
  final String label;
  final Color color;
  const _Count(
      {required this.start,
      required this.target,
      required this.label,
      this.color = _V.danger});
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
                style: const TextStyle(
                    fontSize: 9, color: _V.textMut, fontWeight: FontWeight.w700)),
            Text(f(rem),
                style: TextStyle(
                    fontSize: 9.5, color: widget.color, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
              value: p,
              minHeight: 3,
              backgroundColor: widget.color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(widget.color)),
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
              height: 36,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context).t('common_close'),
                    style: const TextStyle(color: _V.textSec, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
        // Dossiers
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
    final isImage = mime.toLowerCase().contains('image');
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
                      builder: (context, snap) => snap.hasData
                          ? Image.network(snap.data!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Icon(_typeIcon(mime, docType),
                                      color: color, size: 17))
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
                          color: _V.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
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
                child: const Icon(Icons.more_vert_rounded,
                    size: 14, color: _V.textSec)),
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
                child: const Icon(Icons.shield_rounded, color: _V.gold, size: 18),
              ),
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
                final ad =
                    DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
                final cd =
                    DateTime.tryParse((s['created_at'] ?? '').toString()) ?? now;
                final hasPw = (s['password_hash'] as String?)?.isNotEmpty == true;
                Color c = st == 'opened'
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
                                Text(
                                    (s['recipient_thix_id'] as String?) ?? '—',
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
                            const Icon(Icons.lock_rounded,
                                size: 11, color: _V.gold),
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
                            color: _V.danger),
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
}

// =============================================================
// ONGLET REÇUS (boîte mail)
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

  Future<void> _openShare(Map<String, dynamic> s) async {
    final l10n = AppLocalizations.of(context);
    final shareId = s['id']?.toString();
    final docId = s['document_id']?.toString();
    if (shareId == null || docId == null) return;
    final ad = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
    if (ad != null && ad.isBefore(DateTime.now())) {
      await widget.docs.markShareDestroyed(shareId);
      if (mounted) _snackLocal(l10n.t('vault_expired_destroyed'));
      return;
    }
    final hasPw = (s['password_hash'] as String?)?.isNotEmpty == true;
    if (hasPw) {
      final ok = await _askPassword(s['password_hash'] as String);
      if (!ok) return;
    }
    final doc = await widget.docs.fetchDocumentById(docId);
    if (doc == null) {
      if (mounted) _snackLocal(l10n.t('vault_archive_missing'));
      return;
    }
    await widget.docs.markShareOpened(shareId,
        uid: doc['user_id']?.toString(),
        docId: doc['generated_doc_id']?.toString());
    await widget.onOpen(doc);
  }

  void _snackLocal(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontSize: 12)),
        backgroundColor: _V.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2)));
  }

  Future<bool> _askPassword(String stored) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _V.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.lock_rounded, color: _V.gold, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.t('vault_password_required'),
                    style: const TextStyle(
                        color: _V.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                      style: const TextStyle(color: _V.danger, fontSize: 10.5)),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.t('common_cancel'),
                    style: const TextStyle(color: _V.textSec, fontSize: 12))),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _V.gold,
                  foregroundColor: _V.bg,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              onPressed: () async {
                final valid = await widget.docs.verifyPassword(
                    password: ctrl.text, hash: stored);
                if (valid) {
                  Navigator.pop(ctx, true);
                } else {
                  setDlg(() => err = l10n.t('vault_wrong_password'));
                }
              },
              child: Text(l10n.t('vault_decrypt_open'),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    return ok == true;
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
      stream: widget.docs
          .streamReceivedShares(widget.me!.id, widget.me!.thixId),
      builder: (context, snap) {
        final shares = snap.data ?? const [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _V.gold)));
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
                      color: _V.textSec,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
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
            final cd = DateTime.tryParse((s['created_at'] ?? '').toString()) ?? now;
            final locked = st == 'pending' && af != null && af.isAfter(now);
            final senderThix = s['sender_thix_id'] as String?;
            final senderId = (s['sender_id'] as String?) ?? '';
            final sender = senderThix ?? (senderId.length >= 8 ? senderId.substring(0, 8) : '—');
            return GestureDetector(
              onTap: () => _openShare(s),
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
                                        (s['subject'] as String?)?.isNotEmpty ==
                                                true
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
                                      : (st == 'opened'
                                          ? _V.ok
                                          : _V.info))
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
                          color: _V.danger),
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
// ONGLET AUDIT
// =============================================================
class _AuditTab extends StatelessWidget {
  final AppUser? me;
  final DocumentService docs;
  final String Function(dynamic) fmtDate;
  const _AuditTab(
      {required this.me, required this.docs, required this.fmtDate});

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
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _V.gold)));
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
                c = _V.danger;
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
                            style: const TextStyle(
                                color: _V.textMut, fontSize: 9)),
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
// DIALOG DOCUMENT CERTIFIÉ (recherche par ID)
// =============================================================
class _CertifiedDocDialog extends StatelessWidget {
  final Map<String, dynamic> res;
  final DocumentService docs;
  final Future<void> Function(String) onOpen;
  const _CertifiedDocDialog(
      {required this.res, required this.docs, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mime = (res['mime_type'] as String?) ?? '';
    final path = (res['storage_path'] as String?) ?? '';
    final isImage = mime.toLowerCase().contains('image');
    final color = _typeColor(mime, res['doc_type'] as String?);
    return Dialog(
      backgroundColor: _V.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                          style: const TextStyle(
                              color: _V.textMut, fontSize: 9.5)),
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
                      const Icon(Icons.verified_rounded,
                          size: 9, color: _V.ok),
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
              height: isImage ? 180 : 90,
              decoration: BoxDecoration(
                  color: _V.cardSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.35))),
              clipBehavior: Clip.antiAlias,
              child: isImage && path.isNotEmpty
                  ? FutureBuilder<String>(
                      future: docs.createDownloadUrl(storagePath: path),
                      builder: (context, snap) => snap.hasData
                          ? Image.network(snap.data!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Icon(_typeIcon(mime, res['doc_type'] as String?),
                                      color: color, size: 30))
                          : const Center(
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: _V.gold))))
                  : Center(
                      child: Icon(
                          _typeIcon(mime, res['doc_type'] as String?),
                          color: color,
                          size: 30)),
            ),
            const SizedBox(height: 12),
            Text((res['title'] as String?) ?? '—',
                style: const TextStyle(
                    color: _V.text, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(
                '${res['doc_type'] ?? '—'} • ${res['generated_doc_id'] ?? '—'}',
                style: const TextStyle(color: _V.textMut, fontSize: 9.5)),
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
    );
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                            fontWeight: FontWeight.w900)),
                  ),
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
                      value: 'Passeport',
                      child: Text(l10n.t('vault_class_passport'))),
                  DropdownMenuItem(
                      value: 'Permis',
                      child: Text(l10n.t('vault_class_license'))),
                  DropdownMenuItem(
                      value: 'Diplôme',
                      child: Text(l10n.t('vault_class_diploma'))),
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
                    if (p != null) {
                      setState(() => _expiresAt = p);
                    }
                  },
                  icon: const Icon(Icons.event_available_rounded,
                      size: 14, color: _V.gold),
                  label: Text(
                      _expiresAt == null
                          ? l10n.t('vault_pick_date')
                          : '${l10n.t('vault_expiry')} : ${_expiresAt!.day.toString().padLeft(2, '0')}/${_expiresAt!.month.toString().padLeft(2, '0')}/${_expiresAt!.year}',
                      style: const TextStyle(
                          color: _V.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
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
                          backgroundColor: _V.danger));
                      return;
                    }
                    context.pop(_UploadPayload(
                      docType: _type,
                      title: _titleC.text.trim().isEmpty
                          ? null
                          : _titleC.text.trim(),
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
  final void Function(bool ok) onDone;
  const _SendSheet(
      {required this.documents,
      required this.docsService,
      required this.onDone});
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
      final ids = v
          .split(RegExp(r'[,;\s]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      if (ids.isEmpty) {
        setState(() => _verified = null);
        return;
      }
      setState(() => _verifying = true);
      final p = await widget.docsService.verifyThixId(ids.last);
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verified = p == null
            ? 'KO'
            : (p['full_name'] as String? ?? 'OK');
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                            fontWeight: FontWeight.w900)),
                  ),
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
                  return DropdownMenuItem(value: id, child: Text(t,
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
                      style: const TextStyle(
                          color: _V.textMut, fontSize: 9.5)),
                )
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
                          color: _verified == 'KO' ? _V.danger : _V.ok),
                      const SizedBox(width: 5),
                      Text(
                          _verified == 'KO'
                              ? l10n.t('vault_not_found')
                              : _verified!,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _verified == 'KO' ? _V.danger : _V.ok)),
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
                activeColor: _V.danger,
                title: Text(l10n.t('vault_autodestruct'),
                    style: const TextStyle(
                        color: _V.text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800)),
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
                              value: 'minutes',
                              child: Text(l10n.t('vault_minutes'))),
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
                                backgroundColor: _V.danger));
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
                                backgroundColor: _V.danger));
                            return;
                          }
                          setState(() => _sending = true);
                          final sel = widget.documents.firstWhere(
                              (d) => d['id'].toString() == _docId);
                          try {
                            final me = context
                                .read<AuthController>()
                                .currentUser;
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
                      _sending
                          ? l10n.t('vault_sending')
                          : l10n.t('vault_send_btn'),
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

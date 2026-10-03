// lib/presentation/vault/document_vault_page.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;
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
// PALETTE VAULT — clair & verre dépoli
// =============================================================
class _V {
  static const bg = Color(0xFFF4F7FB);
  static const card = Color(0xFFFFFFFF);
  static const cardSoft = Color(0xFFF1F5F9);
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF2563EB);
  static const gold = Color(0xFFD97706);
  static const text = Color(0xFF0F172A);
  static const textSec = Color(0xFF475569);
  static const textMut = Color(0xFF94A3B8);
  static const ok = Color(0xFF059669);
  static const warn = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const dangerBright = Color(0xFFEF4444);
  static const info = Color(0xFF0EA5E9);
  static const violet = Color(0xFF8B5CF6);
}

// =============================================================
// HELPERS GLOBAUX
// =============================================================
String _fmtDT(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

Widget _spinner() => const Center(
    child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: _V.primary)));

bool _isLocked(Map<String, dynamic> s) {
  final st = (s['status'] as String?) ?? 'pending';
  final af = DateTime.tryParse((s['available_from'] ?? '').toString());
  return af != null &&
      af.isAfter(DateTime.now()) &&
      st != 'opened' &&
      st != 'destroyed' &&
      st != 'expired';
}

Widget? _progressFor(AppLocalizations l10n, Map<String, dynamic> s) {
  final now = DateTime.now();
  final af = DateTime.tryParse((s['available_from'] ?? '').toString());
  final ad = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
  final cd = DateTime.tryParse((s['created_at'] ?? '').toString()) ?? now;
  if (_isLocked(s) && af != null) {
    return _Count(
        start: cd,
        target: af,
        label: l10n.t('vault_unlock_in'),
        color: _V.primary);
  }
  if (ad != null) {
    return _Count(
        start: cd,
        target: ad,
        label: l10n.t('vault_destruct_in'),
        color: _V.dangerBright);
  }
  return null;
}

InputDecoration _dec(String label) => InputDecoration(
      labelText: label.isEmpty ? null : label,
      labelStyle: const TextStyle(color: _V.textSec, fontSize: 11),
      filled: true,
      fillColor: Colors.white.withOpacity(0.7),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _V.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _V.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _V.primary)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    );

Widget _lightPicker(BuildContext c, Widget? ch) => Theme(
    data: ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(
            primary: _V.primary, surface: Colors.white)),
    child: ch!);

Color _typeColor(String? mime, String? docType) {
  final m = (mime ?? '').toLowerCase();
  final t = (docType ?? '').toLowerCase();
  if (m.contains('image')) return _V.violet;
  if (m.contains('pdf')) return _V.danger;
  if (t.contains('diplome') ||
      t.contains('diplôme') ||
      t.contains('attestation')) {
    return _V.ok;
  }
  if (t == 'cin' || t == 'passeport' || t == 'permis') return _V.primary;
  return _V.gold;
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

bool _isImageMime(String? mime, String? fileName) {
  final m = (mime ?? '').toLowerCase();
  final n = (fileName ?? '').toLowerCase();
  return m.startsWith('image/') ||
      n.endsWith('.jpg') ||
      n.endsWith('.jpeg') ||
      n.endsWith('.png') ||
      n.endsWith('.webp');
}

// =============================================================
// VERRE DÉPOLI : fond, carte, dialogue, feuille
// =============================================================
class _GlassBg extends StatelessWidget {
  final Widget child;
  const _GlassBg({required this.child});

  Widget _blob(double s, Color c) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c, c.withOpacity(0)])),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE6EEFE), Color(0xFFF6F8FC), Color(0xFFFFF3DF)],
            ),
          ),
        ),
        Positioned(
            top: -80, right: -70, child: _blob(280, _V.primary.withOpacity(0.25))),
        Positioned(
            bottom: 140, left: -100, child: _blob(300, _V.gold.withOpacity(0.2))),
        Positioned(
            top: 300, right: -120, child: _blob(240, _V.violet.withOpacity(0.14))),
        child,
      ],
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double opacity;
  final double blur;
  final Color? borderColor;
  const _Glass({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.radius = 16,
    this.opacity = 0.62,
    this.blur = 14,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1E293B).withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                  color: borderColor ?? Colors.white.withOpacity(0.9)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GlassDialog extends StatelessWidget {
  final Widget child;
  const _GlassDialog({required this.child});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: _Glass(
          radius: 22,
          opacity: 0.88,
          blur: 20,
          padding: const EdgeInsets.all(18),
          child: child),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final Widget child;
  final double maxFactor;
  const _SheetShell({required this.child, this.maxFactor = 0.9});
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * maxFactor),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.88),
                border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.95))),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                              color: _V.border,
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 10),
                      Flexible(child: child),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      content: Text(msg,
          style: const TextStyle(fontSize: 12, color: Colors.white)),
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
      builder: (ctx) => _GlassDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.t('vault_new_folder'),
                style: const TextStyle(
                    color: _V.text, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: _V.text, fontSize: 13),
              decoration: _dec(l10n.t('vault_folder_name')),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.t('common_cancel'),
                          style: const TextStyle(
                              color: _V.textSec, fontSize: 12))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: _V.primary,
                          foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: Text(l10n.t('vault_create'),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800))),
                ),
              ],
            ),
          ],
        ),
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
      builder: (sheetCtx) => _SendSheet(
        documents: docs,
        docsService: _docs,
        initialDocId: singleDoc?['id']?.toString(),
        onDone: (ok) {
          if (!mounted) return;
          if (ok) Navigator.of(sheetCtx).pop();
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
      builder: (ctx) => _GlassDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.t('vault_verify_title'),
                style: const TextStyle(
                    color: _V.text, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(l10n.t('vault_verify_hint'),
                style: const TextStyle(color: _V.textSec, fontSize: 11)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: _V.text, fontSize: 13),
              decoration: _dec('THIX-DOC-…'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.t('common_cancel'),
                          style: const TextStyle(
                              color: _V.textSec, fontSize: 12))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: _V.primary,
                          foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: Text(l10n.t('common_search'),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800))),
                ),
              ],
            ),
          ],
        ),
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
    final title = (row['title'] as String?) ?? '';
    bool isPublic = (row['is_public'] as bool?) ?? false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => _SheetShell(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title.isEmpty ? '—' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _V.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
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
                        title: title,
                        value: docId.isNotEmpty ? docId : title)),
                _MenuTile(
                    icon: Icons.badge_outlined,
                    label: l10n.t('vault_menu_id'),
                    onTap: () => showDocIdDialog(context,
                        docId: docId.isNotEmpty ? docId : '—', title: title)),
                _MenuTile(
                    icon: Icons.forward_rounded,
                    label: l10n.t('vault_forward'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openSendSheet(singleDoc: row);
                    }),
                const SizedBox(height: 4),
                _Glass(
                  radius: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: _V.gold,
                    title: Text(
                        isPublic
                            ? l10n.t('vault_public')
                            : l10n.t('vault_private'),
                        style: const TextStyle(
                            color: _V.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                    subtitle: Text(
                        isPublic
                            ? l10n.t('vault_public_sub')
                            : l10n.t('vault_private_sub'),
                        style:
                            const TextStyle(color: _V.textMut, fontSize: 10)),
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
                ),
                const SizedBox(height: 4),
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
      body: _GlassBg(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _Glass(
                  radius: 16,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      const Icon(Icons.lock_rounded,
                          color: _V.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(l10n.t('vault_title'),
                          style: const TextStyle(
                              color: _V.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                            color: _V.ok.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border:
                                Border.all(color: _V.ok.withOpacity(0.3))),
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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _Glass(
                  radius: 12,
                  child: SizedBox(
                    height: 38,
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
                        hintStyle:
                            const TextStyle(color: _V.textMut, fontSize: 11.5),
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
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: _Glass(
                  radius: 12,
                  padding: const EdgeInsets.all(3),
                  child: SizedBox(
                    height: 32,
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                          color: _V.primary,
                          borderRadius: BorderRadius.circular(9)),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: _V.textSec,
                      labelStyle: const TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w900),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w600),
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(text: l10n.t('vault_tab_vault')),
                        Tab(text: l10n.t('vault_tab_send')),
                        Tab(text: l10n.t('vault_tab_received')),
                        Tab(text: l10n.t('vault_tab_audit')),
                      ],
                    ),
                  ),
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
                        me: me,
                        docs: _docs,
                        onSend: () => _openSendSheet(),
                        fmtDate: _fmtDate),
                    _InboxTab(
                        me: me,
                        docs: _docs,
                        onOpen: _openDoc,
                        fmtDate: _fmtDate),
                    _AuditTab(me: me, docs: _docs, fmtDate: _fmtDate),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.small(
              backgroundColor: _V.primary,
              foregroundColor: Colors.white,
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
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(9),
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
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color ?? _V.primary),
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

/// Image en cache mémoire (évite les appels réseau répétés).
class _CachedImg extends StatefulWidget {
  final String url;
  final double? size;
  final BorderRadius? radius;
  final Widget fallback;
  const _CachedImg(
      {required this.url, this.size, this.radius, required this.fallback});
  @override
  State<_CachedImg> createState() => _CachedImgState();
}

class _CachedImgState extends State<_CachedImg> {
  static final Map<String, Future<Uint8List>> _cache = {};

  static Future<Uint8List> _fetch(String url) async {
    try {
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200) throw Exception('http ${r.statusCode}');
      return r.bodyBytes;
    } catch (e) {
      _cache.remove(url);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fut = _cache.putIfAbsent(widget.url, () => _fetch(widget.url));
    return FutureBuilder<Uint8List>(
      future: fut,
      builder: (context, snap) {
        if (!snap.hasData) return widget.fallback;
        return ClipRRect(
          borderRadius: widget.radius ?? BorderRadius.zero,
          child: Image.memory(
            snap.data!,
            width: widget.size ?? double.infinity,
            height: widget.size ?? double.infinity,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => widget.fallback,
          ),
        );
      },
    );
  }
}

/// Compte à rebours avec barre de progression
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
                    fontSize: 9.5,
                    color: widget.color.withOpacity(0.9),
                    fontWeight: FontWeight.w800)),
            Text(f(rem),
                style: TextStyle(
                    fontSize: 10.5,
                    color: widget.color,
                    fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p,
            minHeight: 5,
            backgroundColor: widget.color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(widget.color),
          ),
        ),
      ],
    );
  }
}

/// Carte "liste" (forme de l'ancien DocItem) — envoi / reçus / audit
class _DocItem extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String? trailing;
  final bool hasPassword;
  final VoidCallback? onTap;
  final Widget? progress;
  final Color? borderColor;
  const _DocItem({
    required this.icon,
    this.accent = _V.primary,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.hasPassword = false,
    this.onTap,
    this.progress,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _Glass(
          radius: 16,
          padding: const EdgeInsets.all(10),
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: accent.withOpacity(0.13)),
                        alignment: Alignment.center,
                        child: Icon(icon, color: accent, size: 19),
                      ),
                      if (hasPassword)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                                color: _V.text,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.5)),
                            child: const Icon(Icons.lock_rounded,
                                size: 8, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _V.text,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _V.textSec,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(trailing!,
                          style: TextStyle(
                              color: accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: 10),
                progress!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// DIALOGUES UTILITAIRES
// =============================================================
void showQrDialog(BuildContext context,
    {required String title, required String value}) {
  showDialog(
    context: context,
    builder: (ctx) => _GlassDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _V.text, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _V.border)),
              child: QrImageView(
                data: value,
                version: QrVersions.auto,
                size: 160,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _V.textSec, fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _V.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).t('common_close'),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    ),
  );
}

void showDocIdDialog(BuildContext context,
    {required String docId, required String title}) {
  showDialog(
    context: context,
    builder: (ctx) => _GlassDialog(
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
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _V.border)),
            child: SelectableText(docId,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _V.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
          ),
          const SizedBox(height: 12),
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
  );
}

/// Demande de mot de passe (partage chiffré)
Future<bool> askVaultPassword(
    BuildContext context, DocumentService docs, String stored) async {
  final l10n = AppLocalizations.of(context);
  final ctrl = TextEditingController();
  String? err;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => _GlassDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.lock_rounded, color: _V.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(l10n.t('vault_password_required'),
                      style: const TextStyle(
                          color: _V.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              style: const TextStyle(color: _V.text, fontSize: 13),
              decoration: _dec(l10n.t('vault_password')),
            ),
            if (err != null)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(err!,
                      style: const TextStyle(
                          color: _V.dangerBright, fontSize: 10.5))),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.t('common_cancel'),
                          style: const TextStyle(
                              color: _V.textSec, fontSize: 12))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: _V.primary,
                        foregroundColor: Colors.white),
                    onPressed: () async {
                      final valid = await docs.verifyPassword(
                          password: ctrl.text, hash: stored);
                      if (valid) {
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } else {
                        setDlg(() => err = l10n.t('vault_wrong_password'));
                      }
                    },
                    child: Text(l10n.t('vault_decrypt_open'),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return ok == true;
}

// =============================================================
// ONGLET COFFRE (grille de cartes)
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
          height: 34,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: docs.streamFolders(me!.id),
            builder: (context, snap) {
              final folders = snap.data ?? const [];
              return ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FolderChip(
                      icon: Icons.grid_view_rounded,
                      label: l10n.t('vault_all'),
                      selected: folderFilter == null,
                      onTap: () => onFolder(null)),
                  ...folders.map((f) => _FolderChip(
                      icon: Icons.folder_rounded,
                      label: (f['name'] as String?) ?? '—',
                      selected: folderFilter == f['id'],
                      onTap: () => onFolder(f['id'] as String))),
                  _FolderChip(
                      icon: Icons.create_new_folder_rounded,
                      label: l10n.t('vault_new_folder'),
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
              return Padding(
                  padding: const EdgeInsets.all(30), child: _spinner());
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        l10n.t('vault_results', args: ['${list.length}']),
                        style: const TextStyle(
                            color: _V.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50),
                    child: Column(
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 40, color: _V.textMut),
                        const SizedBox(height: 10),
                        Text(l10n.t('vault_empty'),
                            style: const TextStyle(
                                color: _V.textSec,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(l10n.t('vault_empty_hint'),
                            style: const TextStyle(
                                color: _V.textMut, fontSize: 10.5)),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    itemBuilder: (context, i) {
                      final d = list[i];
                      return _DocSquareCard(
                        key: ValueKey(d['id']?.toString() ?? '$i'),
                        data: d,
                        docs: docs,
                        onOpen: () => onOpen(d),
                        onMenu: () => onMenu(d),
                        fmtDate: fmtDate,
                        fmtSize: fmtSize,
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FolderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FolderChip(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
            color: selected ? _V.primary : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? _V.primary : _V.border)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: selected ? Colors.white : _V.textSec),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : _V.text,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _DocSquareCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final DocumentService docs;
  final VoidCallback onOpen;
  final VoidCallback onMenu;
  final String Function(dynamic) fmtDate;
  final String Function(int) fmtSize;
  const _DocSquareCard({
    super.key,
    required this.data,
    required this.docs,
    required this.onOpen,
    required this.onMenu,
    required this.fmtDate,
    required this.fmtSize,
  });
  @override
  State<_DocSquareCard> createState() => _DocSquareCardState();
}

class _DocSquareCardState extends State<_DocSquareCard> {
  Future<String>? _url;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    if (_isImageMime(d['mime_type'] as String?, d['file_name'] as String?)) {
      _url = widget.docs.resolveRowDownloadUrl(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final mime = (d['mime_type'] as String?) ?? '';
    final docType = d['doc_type'] as String?;
    final color = _typeColor(mime, docType);
    final icon = _typeIcon(mime, docType);
    final isPublic = (d['is_public'] as bool?) ?? false;
    final docId = (d['generated_doc_id'] as String?) ?? '';
    final title = (d['title'] as String?) ?? (docId.isNotEmpty ? docId : '—');
    final sub =
        '${widget.fmtDate(d['created_at'])} • ${widget.fmtSize((d['size_bytes'] as num?)?.toInt() ?? 0)}';

    final fallback = Container(
        color: color.withOpacity(0.1),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 34));

    return GestureDetector(
      onTap: widget.onOpen,
      onLongPress: widget.onMenu,
      child: _Glass(
        radius: 18,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: _url == null
                          ? fallback
                          : FutureBuilder<String>(
                              future: _url,
                              builder: (c, sn) => sn.hasData
                                  ? _CachedImg(
                                      url: sn.data!, fallback: fallback)
                                  : fallback),
                    ),
                  ),
                  if (isPublic)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                            color: _V.gold,
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('PUBLIC',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _V.text, fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _V.textSec,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600)),
                ),
                GestureDetector(
                  onTap: widget.onMenu,
                  child: const Icon(Icons.more_horiz_rounded,
                      size: 16, color: _V.textSec),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 28,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _V.border)),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(10)),
                      onTap: () => showQrDialog(context,
                          title: title, value: docId.isNotEmpty ? docId : title),
                      child: const Center(
                          child: Icon(Icons.qr_code_2_rounded,
                              size: 15, color: _V.primary)),
                    ),
                  ),
                  Container(width: 1, height: 14, color: _V.border),
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(10)),
                      onTap: () => showDocIdDialog(context,
                          docId: docId.isNotEmpty ? docId : '—', title: title),
                      child: const Center(
                          child: Icon(Icons.badge_outlined,
                              size: 15, color: _V.primary)),
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
        _Glass(
          radius: 18,
          padding: const EdgeInsets.all(12),
          borderColor: _V.primary.withOpacity(0.35),
          child: Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: _V.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.shield_rounded,
                      color: _V.primary, size: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l10n.t('vault_send_subtitle'),
                    style: const TextStyle(
                        color: _V.textSec,
                        fontSize: 10.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _V.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9)),
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
                final locked = _isLocked(s);
                final hasPw =
                    (s['password_hash'] as String?)?.isNotEmpty == true;
                final c = st == 'opened'
                    ? _V.ok
                    : (locked ? _V.warn : _V.primary);
                return _DocItem(
                  icon: st == 'opened'
                      ? Icons.mark_email_read_rounded
                      : (locked
                          ? Icons.schedule_send_rounded
                          : Icons.send_rounded),
                  accent: c,
                  title: (s['recipient_thix_id'] as String?) ?? '—',
                  subtitle: (s['subject'] as String?)?.isNotEmpty == true
                      ? s['subject'] as String
                      : l10n.t('vault_send_subtitle'),
                  trailing: locked
                      ? l10n.t('vault_st_pending')
                      : _stLabel(l10n, st),
                  hasPassword: hasPw,
                  progress: _progressFor(l10n, s),
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
// ONGLET REÇUS
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
          return _spinner();
        }
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
          return Center(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_rounded, size: 40, color: _V.textMut),
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
            final locked = _isLocked(s);
            final senderThix = s['sender_thix_id'] as String?;
            final senderId = (s['sender_id'] as String?) ?? '';
            final sender = senderThix ??
                (senderId.length >= 8 ? senderId.substring(0, 8) : '—');
            final accent =
                locked ? _V.warn : (st == 'opened' ? _V.ok : _V.primary);
            return _DocItem(
              icon: locked
                  ? Icons.lock_clock_rounded
                  : Icons.mark_email_unread_rounded,
              accent: accent,
              title: (s['subject'] as String?)?.isNotEmpty == true
                  ? s['subject'] as String
                  : l10n.t('vault_attachment'),
              subtitle:
                  '${l10n.t('vault_from')} $sender • ${widget.fmtDate(s['created_at'])}${shots > 0 ? ' • 📸 $shots' : ''}',
              trailing: locked
                  ? l10n.t('vault_st_pending')
                  : (st == 'opened'
                      ? l10n.t('vault_st_opened')
                      : l10n.t('vault_st_available')),
              hasPassword: hasPw,
              borderColor: locked ? _V.warn.withOpacity(0.45) : null,
              onTap: () => _showDetail(s),
              progress: _progressFor(l10n, s),
            );
          }).toList(),
        );
      },
    );
  }
}

// =============================================================
// SHEET DÉTAIL REÇU
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
        content: Text(m, style: const TextStyle(fontSize: 11, color: Colors.white)),
        backgroundColor: error ? _V.dangerBright : _V.ok,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2)));
  }

  bool _guardLocked() {
    if (_isLocked(widget.share)) {
      final af = DateTime.tryParse(
          (widget.share['available_from'] ?? '').toString());
      _snack(
          af != null
              ? 'Document verrouillé jusqu\'au ${_fmtDT(af)}.'
              : 'Document verrouillé.',
          error: true);
      return true;
    }
    return false;
  }

  Future<void> _open() async {
    if (_doc == null || _guardLocked()) return;
    final hasPw =
        (widget.share['password_hash'] as String?)?.isNotEmpty == true;
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
    if (_doc == null || widget.me == null || _guardLocked()) return;
    setState(() => _busy = true);
    try {
      final url = await widget.docs.resolveRowDownloadUrl(_doc!);
      final resp = await http.get(Uri.parse(url));
      final name = (_doc!['file_name'] as String?) ??
          (_doc!['title'] as String?) ??
          'document';
      final file = PlatformFile(
          name: name, bytes: resp.bodyBytes, size: resp.bodyBytes.length);
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
    if (_doc == null || widget.me == null || _guardLocked()) return;
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _SendSheet(
        documents: [_doc!],
        docsService: widget.docs,
        initialDocId: _doc!['id'].toString(),
        onDone: (ok) {
          if (ok && sheetCtx.mounted) Navigator.of(sheetCtx).pop();
          _snack(l10n.t(ok ? 'vault_send_ok' : 'vault_send_failed'),
              error: !ok);
        },
      ),
    );
  }

  Future<void> _download() async {
    if (_doc == null || _guardLocked()) return;
    try {
      final url = await widget.docs.resolveRowDownloadUrl(_doc!);
      await launchUrl(Uri.parse(url),
          mode: kIsWeb
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication);
    } catch (_) {
      _snack(AppLocalizations.of(context).t('vault_download_failed'),
          error: true);
    }
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(t,
            style:
                TextStyle(color: c, fontSize: 8.5, fontWeight: FontWeight.w900)),
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
    final cd =
        DateTime.tryParse((s['created_at'] ?? '').toString()) ?? DateTime.now();
    final locked = _isLocked(s);
    final name =
        (_sender?['full_name'] as String?) ?? l10n.t('vault_anonymous');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final mime = (_doc?['mime_type'] as String?) ?? '';
    final docType = _doc?['doc_type'] as String?;
    final isImage = _isImageMime(mime, _doc?['file_name'] as String?);
    final dColor = _typeColor(mime, docType);
    final dIcon = _typeIcon(mime, docType);
    final sid = (s['sender_id'] as String?) ?? '';

    return _SheetShell(
      maxFactor: 0.92,
      child: _loading
          ? SizedBox(height: 120, child: _spinner())
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
                            color: _V.primary.withOpacity(0.13),
                            shape: BoxShape.circle),
                        child: Center(
                            child: Text(initial,
                                style: const TextStyle(
                                    color: _V.primary,
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
                                    '${l10n.t('vault_from')} ${sid.length >= 8 ? sid.substring(0, 8) : '—'}',
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
                          color: _V.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w900)),
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
                          locked
                              ? _V.warn
                              : (st == 'opened' ? _V.ok : _V.primary)),
                      if (hasPw) _chip(l10n.t('vault_password'), _V.gold),
                      if (shots > 0) _chip('📸 $shots', _V.warn),
                      if (locked && af != null) _chip(_fmtDT(af), _V.primary),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Glass(
                    radius: 12,
                    padding: const EdgeInsets.all(10),
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
                      child: _Glass(
                        radius: 14,
                        padding: const EdgeInsets.all(9),
                        borderColor: _V.primary.withOpacity(0.35),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                  color: dColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(11)),
                              child: isImage && !locked
                                  ? FutureBuilder<String>(
                                      future: widget.docs
                                          .resolveRowDownloadUrl(_doc!),
                                      builder: (c, sn) => sn.hasData
                                          ? _CachedImg(
                                              url: sn.data!,
                                              size: 44,
                                              fallback: Icon(dIcon,
                                                  color: dColor, size: 18))
                                          : Icon(dIcon, color: dColor, size: 18))
                                  : Icon(locked ? Icons.lock_rounded : dIcon,
                                      color: dColor, size: 18),
                            ),
                            const SizedBox(width: 10),
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
                                size: 15, color: _V.primary),
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
                        color: _V.primary),
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
                              color: _V.primary,
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
                  const SizedBox(height: 4),
                ],
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
            backgroundColor: Colors.white.withOpacity(0.55),
            side: BorderSide(color: color.withOpacity(0.5)),
            foregroundColor: color,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
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
          return _spinner();
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
                c = _V.primary;
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
            return _DocItem(
              icon: ic,
              accent: c,
              title: lb,
              subtitle:
                  (t['detail'] as String?) ?? (t['doc_id'] as String?) ?? '',
              trailing: fmtDate(t['created_at']),
            );
          }).toList(),
        );
      },
    );
  }
}

                            // =============================================================
// DIALOG DOCUMENT CERTIFIÉ
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
      final name =
          (res['file_name'] as String?) ?? (res['title'] as String?) ?? 'doc';
      final file = PlatformFile(
          name: name, bytes: resp.bodyBytes, size: resp.bodyBytes.length);
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

  String _dateOf(dynamic v) {
    final d = DateTime.tryParse((v ?? '').toString());
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final path = (res['storage_path'] as String?) ?? '';
    final mime = res['mime_type'] as String?;
    final dType = res['doc_type'] as String?;
    final color = _typeColor(mime, dType);
    final img = _isImageMime(mime, res['file_name'] as String?);
    final fallbackIcon = Icon(_typeIcon(mime, dType), color: color, size: 30);

    return _GlassDialog(
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
                      Text(
                          (res['owner_name'] as String?) ??
                              l10n.t('vault_from'),
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
              height: img ? 200 : 90,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.35))),
              clipBehavior: Clip.antiAlias,
              child: img && path.isNotEmpty
                  ? FutureBuilder<String>(
                      future: docs.createDownloadUrl(storagePath: path),
                      builder: (context, snap) => snap.hasData
                          ? _CachedImg(
                              url: snap.data!,
                              fallback: Center(child: fallbackIcon))
                          : _spinner())
                  : Center(child: fallbackIcon),
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
                if (res['size_bytes'] != null) ...[
                  Text(
                      '${l10n.t('vault_size')}: ${(((res['size_bytes'] as num).toInt()) / 1024).toStringAsFixed(0)} KB',
                      style:
                          const TextStyle(color: _V.textSec, fontSize: 9.5)),
                  const SizedBox(width: 10),
                ],
                Text('${l10n.t('vault_date')}: ${_dateOf(res['created_at'])}',
                    style: const TextStyle(color: _V.textSec, fontSize: 9.5)),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 36,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _V.primary, foregroundColor: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SheetShell(
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
                    color: _V.primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
            Text(l10n.t('vault_auto_id'),
                style: const TextStyle(color: _V.textMut, fontSize: 9)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _folderId,
              dropdownColor: Colors.white,
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
              dropdownColor: Colors.white,
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
                    backgroundColor: Colors.white.withOpacity(0.55),
                    side: const BorderSide(color: _V.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11)),
                onPressed: () async {
                  final now = DateTime.now();
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _expiresAt ?? now,
                    firstDate: now.subtract(const Duration(days: 365 * 20)),
                    lastDate: now.add(const Duration(days: 365 * 50)),
                    builder: _lightPicker,
                  );
                  if (p != null) {
                    setState(() =>
                        _expiresAt = DateTime(p.year, p.month, p.day));
                  }
                },
                icon: const Icon(Icons.event_available_rounded,
                    size: 14, color: _V.primary),
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
                    backgroundColor: _V.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  if (_needsExpiry && _expiresAt == null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l10n.t('vault_expiry_required'),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white)),
                        backgroundColor: _V.dangerBright));
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
    );
  }
}

// =============================================================
// SHEET ENVOI (avec date de disponibilité)
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
  DateTime? _availableFrom;
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

  void _err(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontSize: 11, color: Colors.white)),
        backgroundColor: _V.dangerBright));
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

  Future<void> _pickAvailable() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _availableFrom ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: _lightPicker,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _availableFrom ?? now.add(const Duration(hours: 1))),
      builder: _lightPicker,
    );
    if (t == null || !mounted) return;
    final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (!dt.isAfter(DateTime.now())) {
      _err('Choisissez une date et une heure futures.');
      return;
    }
    setState(() => _availableFrom = dt);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_docId == null) {
      _err(l10n.t('vault_select_archive'));
      return;
    }
    final recips = _recipC.text
        .split(RegExp(r'[,;\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (recips.isEmpty) {
      _err(l10n.t('vault_need_recipient'));
      return;
    }
    setState(() => _sending = true);
    final sel =
        widget.documents.firstWhere((d) => d['id'].toString() == _docId);
    try {
      final me = context.read<AuthController>().currentUser;
      await widget.docsService.shareDocument(
        senderId: me!.id,
        documentId: _docId!,
        docId: (sel['generated_doc_id'] as String?) ??
            (sel['doc_id'] as String?),
        recipientThixIds: recips,
        subject: _subjectC.text.trim().isEmpty ? null : _subjectC.text.trim(),
        body: _bodyC.text.trim().isEmpty ? null : _bodyC.text.trim(),
        password: _pwC.text.trim().isEmpty ? null : _pwC.text.trim(),
        availableFrom: _availableFrom,
        autoDestructIn: _dur(),
      );
      widget.onDone(true);
    } catch (_) {
      if (mounted) setState(() => _sending = false);
      widget.onDone(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SheetShell(
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
              dropdownColor: Colors.white,
              isExpanded: true,
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
                      style:
                          const TextStyle(color: _V.textMut, fontSize: 9.5)))
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
                            color:
                                _verified == 'KO' ? _V.dangerBright : _V.ok)),
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
            const SizedBox(height: 10),
            // ===== Date de disponibilité =====
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        backgroundColor: _availableFrom == null
                            ? Colors.white.withOpacity(0.55)
                            : _V.primary.withOpacity(0.08),
                        side: BorderSide(
                            color: _availableFrom == null
                                ? _V.border
                                : _V.primary.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12)),
                    onPressed: _pickAvailable,
                    icon: Icon(Icons.schedule_rounded,
                        size: 15,
                        color: _availableFrom == null
                            ? _V.textSec
                            : _V.primary),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          _availableFrom == null
                              ? 'Disponibilité immédiate (programmer une date)'
                              : 'Disponible le ${_fmtDT(_availableFrom!)}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _availableFrom == null
                                  ? _V.textSec
                                  : _V.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                if (_availableFrom != null) ...[
                  const SizedBox(width: 6),
                  _IconBtn(
                      icon: Icons.close_rounded,
                      onTap: () => setState(() => _availableFrom = null)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            _Glass(
              radius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: _V.dangerBright,
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
            ),
            if (_autoDestruct) ...[
              const SizedBox(height: 8),
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
                      dropdownColor: Colors.white,
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
                      onChanged: (v) =>
                          setState(() => _unit = v ?? 'minutes'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _V.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(
                        _availableFrom == null
                            ? Icons.send_rounded
                            : Icons.schedule_send_rounded,
                        size: 14),
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
    );
  }
}

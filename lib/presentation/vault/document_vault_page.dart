// lib/presentation/vault/document_vault_page.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' show ReadContext, WatchContext;
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/document_service.dart';

import 'vault_providers.dart';
import 'vault_sheets.dart';
import 'vault_state.dart';
import 'vault_theme.dart';

/// Point d'entrée inchangé : `DocumentVaultPage()`.
/// Embarque son propre ProviderScope (état Riverpod isolé, libéré à la sortie).
class DocumentVaultPage extends StatelessWidget {
  const DocumentVaultPage({super.key});
  @override
  Widget build(BuildContext context) => const ProviderScope(child: _VaultRoot());
}

class _VaultRoot extends StatelessWidget {
  const _VaultRoot();
  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().currentUser;
    if (me == null) {
      return const Scaffold(
          backgroundColor: VT.bg,
          body: Center(child: Text('Connectez-vous pour accéder au coffre.')));
    }
    final user = VaultUser(uid: me.id, thixId: me.thixId);
    return VaultPinGate(user: user, child: _VaultScaffold(user: user));
  }
}

class _VaultScaffold extends ConsumerStatefulWidget {
  final VaultUser user;
  const _VaultScaffold({required this.user});
  @override
  ConsumerState<_VaultScaffold> createState() => _VaultScaffoldState();
}

class _VaultScaffoldState extends ConsumerState<_VaultScaffold> {
  int _tab = 0;
  final _search = TextEditingController();

  VaultUser get u => widget.user;
  DocumentService get _docs => ref.read(documentServiceProvider);
  VaultNotifier get _n => ref.read(vaultStateProvider(u).notifier);

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.imageCache
      ..maximumSize = 300
      ..maximumSizeBytes = 120 * 1024 * 1024;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _back() {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) {
      final t = auth.currentUser?.accountType;
      context.go(t == AccountType.enterprise
          ? AppRoutes.enterpriseDashboard
          : AppRoutes.userDashboard);
      return;
    }
    context.go(AppRoutes.home);
  }

  Future<void> _add() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final file = picked.files.first;
    final st = ref.read(vaultStateProvider(u));
    final payload = await showUploadSheet(context,
        fileName: file.name, folders: st.folders, preselectedFolderId: st.folderFilter);
    if (payload == null || !mounted) return;
    try {
      final id = await _n.upload(
          file: file,
          docType: payload.docType,
          title: payload.title,
          expiresAt: payload.expiresAt,
          folderId: payload.folderId);
      vSnack(context, 'Document scellé et enregistré · $id');
    } catch (_) {
      vSnack(context, 'Échec de l’enregistrement du fichier.', error: true);
    }
  }

  void _openSend() {
    final docs = ref.read(vaultStateProvider(u)).documents;
    if (docs.isEmpty) {
      vSnack(context, 'Ajoutez d’abord un document au coffre.', error: true);
      return;
    }
    showSendSheet(context, u, docs);
  }

  Future<void> _createFolder() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VT.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Nouveau dossier',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: TextField(controller: c, autofocus: true, decoration: vInput('Nom du dossier')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: VT.ink),
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Créer')),
        ],
      ),
    );
    c.dispose();
    if (name == null || name.isEmpty) return;
    try {
      await _n.createFolder(name);
    } catch (_) {
      if (mounted) vSnack(context, 'Création impossible.', error: true);
    }
  }

  // ------------------------------------------------------------ Build
  @override
  Widget build(BuildContext context) {
    final isAdmin =
        ref.watch(vaultAdminProvider).maybeWhen(data: (v) => v, orElse: () => false);
    final received = ref.watch(receivedSharesProvider(u));
    final unread = received.where((s) => s['status'] == 'available').length;
    final tabs = ['Coffre', 'Envois', unread > 0 ? 'Reçus · $unread' : 'Reçus', 'Audit', if (isAdmin) 'Admin'];
    if (_tab >= tabs.length) _tab = 0;

    return Scaffold(
      backgroundColor: VT.bg,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              backgroundColor: VT.ink,
              elevation: 4,
              shape: const CircleBorder(),
              onPressed: _add,
              child: const Icon(Icons.add_rounded, color: VT.mint, size: 28),
            )
          : null,
      body: SafeArea(
        child: Column(children: [
          _header(),
          const SizedBox(height: 8),
          _tabBar(tabs),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
              children: [
                if (_tab == 0) _hero(),
                ..._content(isAdmin),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(children: [
          _RoundBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: _back),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Coffre-fort',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: VT.ink)),
              Row(children: [
                Icon(Icons.verified_user_rounded, size: 12, color: VT.ok),
                SizedBox(width: 4),
                Text('Scellé · signé · audité',
                    style: TextStyle(fontSize: 10.5, color: VT.sub, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
          _RoundBtn(icon: Icons.verified_outlined, onTap: () => showVerifySheet(context, u)),
          const SizedBox(width: 8),
          _RoundBtn(icon: Icons.shield_outlined, onTap: () => showSecuritySheet(context, u)),
        ]),
      );

  Widget _tabBar(List<String> tabs) => SizedBox(
        height: 42,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final sel = i == _tab;
            return GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: sel ? VT.ink : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sel ? VT.ink : VT.line)),
                child: Text(tabs[i],
                    style: TextStyle(
                        color: sel ? Colors.white : VT.sub,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5)),
              ),
            );
          },
        ),
      );

  Widget _hero() {
    final s = ref.watch(vaultStatsProvider(u));
    final ratio = s.total == 0 ? 0.0 : s.sealed / s.total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [VT.forest, VT.forest2]),
          ),
          child: Stack(children: [
            Positioned(
                right: -40,
                top: -40,
                child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: VT.mint.withOpacity(0.10)))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                    color: VT.mint.withOpacity(0.16), borderRadius: BorderRadius.circular(8)),
                child: const Text('PROTECTION ACTIVE',
                    style: TextStyle(
                        color: VT.mint, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
              ),
              const SizedBox(height: 12),
              Text('${s.total} document${s.total > 1 ? 's' : ''} sécurisé${s.total > 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${s.signed} signé${s.signed > 1 ? 's' : ''} · ${s.publicCount} public${s.publicCount > 1 ? 's' : ''} · ${fmtSize(s.bytes)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation(VT.mint)),
              ),
              const SizedBox(height: 5),
              Text('${(ratio * 100).round()} % scellés SHA-256',
                  style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: VButton('Ajouter', icon: Icons.add_rounded, kind: VKind.mint, height: 42, onTap: _add)),
                const SizedBox(width: 8),
                Expanded(
                    child: Material(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: _openSend,
                    child: const SizedBox(
                      height: 42,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.send_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Envoyer',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      ]),
                    ),
                  ),
                )),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }

  List<Widget> _content(bool isAdmin) {
    switch (_tab) {
      case 0:
        return _vaultTab();
      case 1:
        return _sentTab();
      case 2:
        return _receivedTab();
      case 3:
        return _auditTab();
      default:
        return isAdmin ? [const _AdminPanel()] : [];
    }
  }

  // ------------------------------------------------------------ Coffre
  List<Widget> _vaultTab() {
    final st = ref.watch(vaultStateProvider(u));
    final docs = ref.watch(filteredDocsProvider(u));
    final expiring = ref.watch(expiringDocsProvider(u));
    final svc = _docs;
    return [
      if (expiring.isNotEmpty) _ExpiryBanner(docs: expiring),
      SizedBox(
        height: 38,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          _Chip(
              icon: Icons.grid_view_rounded,
              label: 'Tous',
              selected: st.folderFilter == null,
              onTap: () => _n.setFolderFilter(null)),
          ...st.folders.map((f) => _Chip(
              icon: Icons.folder_rounded,
              label: (f['name'] as String?) ?? '—',
              selected: st.folderFilter == f['id'].toString(),
              onTap: () => _n.setFolderFilter(f['id'].toString()))),
          _Chip(
              icon: Icons.create_new_folder_rounded,
              label: 'Nouveau dossier',
              selected: false,
              onTap: _createFolder),
        ]),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _search,
        onChanged: _n.setSearch,
        decoration: vInput('', hint: 'Rechercher titre, ID, type…', icon: Icons.search_rounded)
            .copyWith(
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _search.clear();
                          _n.setSearch('');
                          setState(() {});
                        })),
      ),
      const SizedBox(height: 12),
      if (!st.loaded)
        vSpinner()
      else if (docs.isEmpty)
        const _Empty(icon: Icons.shield_outlined, title: 'Coffre vide', hint: 'Touchez + pour ajouter votre premier document.')
      else
        ...docs.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DocRow(
                  row: d, docs: svc, onTap: () => showDocSheet(context, u, d)),
            )),
    ];
  }

  // ------------------------------------------------------------ Envois
  List<Widget> _sentTab() {
    final shares = ref.watch(sentSharesProvider(u));
    return [
      VCard(
        color: VT.forestSoft,
        borderColor: Colors.transparent,
        child: Row(children: [
          const Icon(Icons.shield_rounded, color: VT.forest, size: 22),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Envoyez avec mot de passe, date programmée, autodestruction et révocation.',
                  style: TextStyle(fontSize: 11.5, color: VT.forest, height: 1.35, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          VButton('Nouveau', expand: false, height: 38, onTap: _openSend),
        ]),
      ),
      const SizedBox(height: 12),
      if (shares.isEmpty)
        const _Empty(icon: Icons.send_rounded, title: 'Aucun envoi', hint: 'Vos envois actifs apparaîtront ici.')
      else
        ...shares.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ShareRow(
                share: s,
                docs: _docs,
                sent: true,
                onTap: () => showShareSheet(context, u, s, sent: true)))),
    ];
  }

  // ------------------------------------------------------------ Reçus
  List<Widget> _receivedTab() {
    final shares = ref.watch(receivedSharesProvider(u));
    if (shares.isEmpty) {
      return const [_Empty(icon: Icons.inbox_rounded, title: 'Aucun document reçu', hint: 'Les documents partagés avec votre THIX ID arriveront ici.')];
    }
    return shares
        .map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ShareRow(
                share: s,
                docs: _docs,
                sent: false,
                onTap: () => showShareSheet(context, u, s, sent: false))))
        .toList();
  }

  // ------------------------------------------------------------ Audit
  List<Widget> _auditTab() {
    final log = ref.watch(vaultStateProvider(u).select((s) => s.auditLog));
    if (log.isEmpty) {
      return const [_Empty(icon: Icons.history_rounded, title: 'Journal vide', hint: 'Chaque action est enregistrée de façon immuable.')];
    }
    return log.map((t) => _AuditRow(t: t)).toList();
  }
}

// ================================================================= Widgets page
class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: VT.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 18, color: VT.ink)),
        ),
      );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
              color: selected ? VT.forest : Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: selected ? VT.forest : VT.line)),
          child: Row(children: [
            Icon(icon, size: 14, color: selected ? VT.mint : VT.forest),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : VT.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  const _Empty({required this.icon, required this.title, required this.hint});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 54),
        child: Column(children: [
          Icon(icon, size: 42, color: VT.mute),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: VT.sub)),
          const SizedBox(height: 4),
          Text(hint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: VT.mute)),
        ]),
      );
}

class _ExpiryBanner extends StatelessWidget {
  final List<JsonMap> docs;
  const _ExpiryBanner({required this.docs});
  @override
  Widget build(BuildContext context) {
    final first = docs.take(2).map((d) {
      final e = DateTime.parse(d['expires_at'].toString());
      final days = e.difference(DateTime.now()).inDays;
      return '${(d['title'] as String?) ?? '—'} (${days < 0 ? 'expiré' : 'J-$days'})';
    }).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VCard(
        color: const Color(0xFFFFF4DF),
        borderColor: VT.amber.withOpacity(0.35),
        child: Row(children: [
          const Icon(Icons.notification_important_rounded, color: VT.amber, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${docs.length} document${docs.length > 1 ? 's' : ''} à renouveler',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: VT.ink)),
              const SizedBox(height: 2),
              Text(first,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: VT.sub)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final JsonMap row;
  final DocumentService docs;
  final VoidCallback onTap;
  const _DocRow({required this.row, required this.docs, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final docId = (row['generated_doc_id'] as String?) ?? '';
    final title = (row['title'] as String?) ?? (docId.isNotEmpty ? docId : '—');
    return VCard(
      onTap: onTap,
      onLongPress: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        VThumb(row: row, docs: docs),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: VT.ink)),
            const SizedBox(height: 2),
            Text('${fmtDate(row['created_at'])} · ${fmtSize((row['size_bytes'] as num?)?.toInt() ?? 0)}',
                style: const TextStyle(fontSize: 10.5, color: VT.sub, fontWeight: FontWeight.w600)),
            const SizedBox(height: 7),
            Wrap(spacing: 4, runSpacing: 4, children: docTags(row)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: VT.mute),
      ]),
    );
  }
}

class _ShareRow extends StatefulWidget {
  final JsonMap share;
  final DocumentService docs;
  final bool sent;
  final VoidCallback onTap;
  const _ShareRow({required this.share, required this.docs, required this.sent, required this.onTap});
  @override
  State<_ShareRow> createState() => _ShareRowState();
}

class _ShareRowState extends State<_ShareRow> {
  late Future<JsonMap?> _doc;
  @override
  void initState() {
    super.initState();
    _doc = _load();
  }

  Future<JsonMap?> _load() async {
    final id = widget.share['document_id']?.toString();
    if (id == null || id.isEmpty) return null;
    try {
      return await widget.docs.fetchDocumentById(id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.share;
    final st = (s['status'] as String?) ?? 'pending';
    final locked = isShareLocked(s);
    final hasPw = (s['password_hash'] as String?)?.isNotEmpty == true;
    final sid = (s['sender_id'] as String?) ?? '';
    final who = widget.sent
        ? 'À ${(s['recipient_thix_id'] as String?) ?? '—'}'
        : 'De ${(s['sender_thix_id'] as String?) ?? (sid.length >= 8 ? sid.substring(0, 8) : '—')}';
    final tagText = locked ? 'VERROUILLÉ' : (st == 'opened' ? 'OUVERT' : (widget.sent ? 'ENVOYÉ' : 'DISPONIBLE'));
    final tagColor = locked ? VT.amber : (st == 'opened' ? VT.ok : VT.blue);
    final cd = shareCountdown(s);
    return FutureBuilder<JsonMap?>(
      future: _doc,
      builder: (c, sn) {
        final d = sn.data;
        final title = (d?['title'] as String?) ??
            ((s['subject'] as String?)?.isNotEmpty == true ? s['subject'] as String : 'Pièce jointe');
        return VCard(
          onTap: widget.onTap,
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              d == null
                  ? Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: VT.forestSoft, borderRadius: BorderRadius.circular(15)),
                      child: Icon(widget.sent ? Icons.send_rounded : Icons.inbox_rounded,
                          color: VT.forest, size: 22))
                  : VThumb(row: d, docs: widget.docs, size: 48, radius: 15),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('$who · ${fmtDate(s['created_at'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: VT.sub)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, runSpacing: 4, children: [
                    VTag(tagText, tagColor),
                    if (hasPw) const VTag('MOT DE PASSE', VT.ink, icon: Icons.key_rounded),
                  ]),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: VT.mute),
            ]),
            if (cd != null) ...[const SizedBox(height: 10), cd],
          ]),
        );
      },
    );
  }
}

class _AuditRow extends StatelessWidget {
  final JsonMap t;
  const _AuditRow({required this.t});
  @override
  Widget build(BuildContext context) {
    final a = (t['action'] as String?) ?? '';
    const map = <String, List<Object>>{
      'upload': [Icons.cloud_upload_rounded, VT.blue, 'Dépôt'],
      'send': [Icons.send_rounded, VT.forest, 'Envoi'],
      'open': [Icons.visibility_rounded, VT.ok, 'Ouverture'],
      'delete': [Icons.delete_outline_rounded, VT.red, 'Suppression'],
      'screenshot': [Icons.camera_alt_rounded, VT.amber, 'Capture détectée'],
      'public_toggle': [Icons.public_rounded, VT.amber, 'Visibilité modifiée'],
      'folder_create': [Icons.create_new_folder_rounded, VT.blue, 'Dossier créé'],
      'sign': [Icons.verified_rounded, VT.ok, 'Signature'],
    };
    final m = map[a];
    final icon = (m?[0] as IconData?) ?? Icons.history_rounded;
    final color = (m?[1] as Color?) ?? VT.sub;
    final label = (m?[2] as String?) ?? a;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VCard(
        radius: 18,
        padding: const EdgeInsets.all(11),
        child: Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              if (((t['detail'] as String?) ?? (t['doc_id'] as String?) ?? '').isNotEmpty)
                Text((t['detail'] as String?) ?? (t['doc_id'] as String?) ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: VT.sub)),
            ]),
          ),
          Text(fmtDate(t['created_at']), style: const TextStyle(fontSize: 10, color: VT.mute)),
        ]),
      ),
    );
  }
}

// ================================================================= Admin
class _AdminPanel extends ConsumerStatefulWidget {
  const _AdminPanel();
  @override
  ConsumerState<_AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends ConsumerState<_AdminPanel> {
  late Future<List<dynamic>> _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  Future<List<dynamic>> _load() {
    final sec = ref.read(vaultSecurityProvider);
    return Future.wait<dynamic>([sec.adminStats(), sec.adminReports()]);
  }

  Future<void> _resolve(String id, bool confirm) async {
    try {
      await ref.read(vaultSecurityProvider).resolveReport(id, confirm: confirm);
      if (mounted) setState(() => _f = _load());
    } catch (_) {
      vSnack(context, 'Action refusée.', error: true);
    }
  }

  Widget _stat(String label, dynamic v, Color c) => SizedBox(
        width: (MediaQuery.of(context).size.width - 32 - 10) / 2,
        child: VCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${v ?? 0}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: VT.sub, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _f,
      builder: (c, sn) {
        if (sn.connectionState == ConnectionState.waiting) return vSpinner();
        if (sn.hasError || !sn.hasData) {
          return const _Empty(icon: Icons.lock_rounded, title: 'Accès refusé', hint: 'Droits administrateur requis.');
        }
        final stats = sn.data![0] as JsonMap;
        final reports = (sn.data![1] as List).cast<JsonMap>();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            _stat('Documents', stats['total_docs'], VT.ink),
            _stat('Signés', stats['signed_docs'], VT.ok),
            _stat('Signalés', stats['flagged_docs'], VT.red),
            _stat('Signalements ouverts', stats['open_reports'], VT.amber),
            _stat('Partages (24 h)', stats['shares_24h'], VT.blue),
          ]),
          const SizedBox(height: 16),
          const Text('Signalements de contrefaçon',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (reports.isEmpty)
            const _Empty(icon: Icons.flag_outlined, title: 'Aucun signalement', hint: 'Tout est calme.')
          else
            ...reports.map((r) {
              final open = r['status'] == 'open';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: VCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(
                          child: Text((r['generated_doc_id'] as String?) ?? '—',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900))),
                      VTag(
                          open ? 'OUVERT' : (r['status'] == 'confirmed' ? 'CONFIRMÉ' : 'REJETÉ'),
                          open ? VT.amber : (r['status'] == 'confirmed' ? VT.red : VT.mute)),
                    ]),
                    const SizedBox(height: 6),
                    Text((r['reason'] as String?) ?? '',
                        style: const TextStyle(fontSize: 12, color: VT.sub, height: 1.35)),
                    const SizedBox(height: 4),
                    Text(fmtDT(DateTime.tryParse((r['created_at'] ?? '').toString()) ?? DateTime.now()),
                        style: const TextStyle(fontSize: 10, color: VT.mute)),
                    if (open) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: VButton('Confirmer',
                                icon: Icons.gpp_bad_rounded,
                                kind: VKind.danger,
                                height: 40,
                                onTap: () => _resolve(r['id'].toString(), true))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: VButton('Rejeter',
                                kind: VKind.soft,
                                height: 40,
                                onTap: () => _resolve(r['id'].toString(), false))),
                      ]),
                    ],
                  ]),
                ),
              );
            }),
        ]);
      },
    );
  }
}

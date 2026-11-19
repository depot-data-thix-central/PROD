// lib/presentation/vault/vault_sheets.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide shortHash;
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/document_service.dart';

import 'vault_providers.dart';
import 'vault_state.dart';
import 'vault_theme.dart';

// =============================================================== Cache / vignette
class VImgCache {
  VImgCache._();
  static final Map<String, Future<Uint8List>> _m = {};
  static Future<Uint8List> fetch(String url) => _m.putIfAbsent(url, () async {
        try {
          final r = await http.get(Uri.parse(url));
          if (r.statusCode != 200) throw Exception('http ${r.statusCode}');
          if (_m.length > 120) _m.remove(_m.keys.first);
          return r.bodyBytes;
        } catch (_) {
          _m.remove(url);
          rethrow;
        }
      });
}

class VThumb extends StatefulWidget {
  final JsonMap row;
  final DocumentService docs;
  final double size;
  final double radius;
  const VThumb({super.key, required this.row, required this.docs, this.size = 52, this.radius = 16});
  @override
  State<VThumb> createState() => _VThumbState();
}

class _VThumbState extends State<VThumb> {
  Future<String>? _url;
  @override
  void initState() {
    super.initState();
    _prep();
  }

  @override
  void didUpdateWidget(covariant VThumb old) {
    super.didUpdateWidget(old);
    if (old.row['id'] != widget.row['id']) _prep();
  }

  void _prep() {
    final d = widget.row;
    _url = isImageMime(d['mime_type'] as String?, d['file_name'] as String?)
        ? widget.docs.resolveRowDownloadUrl(d)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.row;
    final color = typeColor(d['mime_type'] as String?, d['doc_type'] as String?);
    final fallback = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(widget.radius)),
      child: Icon(typeIcon(d['mime_type'] as String?, d['doc_type'] as String?),
          color: color, size: widget.size * 0.44),
    );
    if (_url == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: FutureBuilder<String>(
          future: _url,
          builder: (c, sn) => !sn.hasData
              ? fallback
              : FutureBuilder<Uint8List>(
                  future: VImgCache.fetch(sn.data!),
                  builder: (c2, s2) => s2.hasData
                      ? Image.memory(s2.data!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => fallback)
                      : fallback),
        ),
      ),
    );
  }
}

List<Widget> docTags(JsonMap d) {
  final tags = <Widget>[];
  final signed = d['signed_at'] != null;
  final sealed = (d['sha256'] as String?)?.isNotEmpty == true;
  if (d['flagged'] == true) tags.add(const VTag('SIGNALÉ', VT.red, icon: Icons.flag_rounded));
  if (signed) {
    tags.add(const VTag('SIGNÉ', VT.ok, icon: Icons.verified_rounded));
  } else if (sealed) {
    tags.add(const VTag('SCELLÉ', VT.blue, icon: Icons.lock_rounded));
  } else {
    tags.add(const VTag('NON SCELLÉ', VT.mute));
  }
  if (d['is_public'] == true) tags.add(const VTag('PUBLIC', VT.amber, icon: Icons.public_rounded));
  final e = DateTime.tryParse((d['expires_at'] ?? '').toString());
  if (e != null) {
    final days = e.difference(DateTime.now()).inDays;
    if (days < 0) {
      tags.add(const VTag('EXPIRÉ', VT.red));
    } else if (days <= 45) {
      tags.add(VTag('J-$days', VT.amber));
    }
  }
  return tags;
}

// =============================================================== Ouverture fichiers
Future<void> openFileUrl(BuildContext context, String url, String mime, String name) async {
  if (url.trim().isEmpty) {
    vSnack(context, 'Ouverture impossible : lien introuvable.', error: true);
    return;
  }
  if (isImageMime(mime, name)) {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VImageViewer(url: url, title: name)));
    return;
  }
  var ok = await launchOut(url);
  if (!ok) {
    final n = name.toLowerCase();
    final office = ['.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx'].any(n.endsWith);
    if (office) {
      ok = await launchOut(
          'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}');
    }
  }
  if (!ok) {
    vSnack(context, 'Aucune application ne peut ouvrir ce fichier. Utilisez Télécharger.',
        error: true);
  }
}

Future<void> openDocumentRow(BuildContext context, DocumentService docs, JsonMap row) async {
  try {
    final url = await docs.resolveRowDownloadUrl(row);
    if (!context.mounted) return;
    await openFileUrl(context, url, (row['mime_type'] as String?) ?? '',
        (row['file_name'] as String?) ?? (row['title'] as String?) ?? 'document');
  } catch (_) {
    vSnack(context, 'Téléchargement impossible.', error: true);
  }
}

class VImageViewer extends StatelessWidget {
  final String url;
  final String title;
  const VImageViewer({super.key, required this.url, required this.title});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(title,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
          actions: [
            IconButton(
                icon: const Icon(Icons.download_rounded), onPressed: () => launchOut(url))
          ],
        ),
        body: FutureBuilder<Uint8List>(
          future: VImgCache.fetch(url),
          builder: (c, sn) {
            if (sn.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            if (!sn.hasData) {
              return Center(
                  child: VButton('Ouvrir avec une autre application',
                      icon: Icons.open_in_new_rounded,
                      expand: false,
                      kind: VKind.mint,
                      onTap: () => launchOut(url)));
            }
            return InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                child: Center(child: Image.memory(sn.data!, fit: BoxFit.contain)));
          },
        ),
      );
}

// =============================================================== QR / ID
Future<void> showIdentitySheet(BuildContext context,
    {required String title, required String value, String? caption}) {
  return showVSheet<void>(context, builder: (ctx) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: VT.ink)),
      if (caption != null) ...[
        const SizedBox(height: 4),
        Text(caption,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: VT.sub)),
      ],
      const SizedBox(height: 16),
      Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: VT.line)),
          child: QrImageView(data: value, size: 190, backgroundColor: Colors.white),
        ),
      ),
      const SizedBox(height: 12),
      SelectableText(value,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: VT.forest, letterSpacing: 0.8)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
            child: VButton('Copier', icon: Icons.copy_rounded, kind: VKind.soft, onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          vSnack(ctx, 'Copié.');
        })),
        const SizedBox(width: 8),
        Expanded(child: VButton('Fermer', onTap: () => Navigator.pop(ctx))),
      ]),
    ]);
  });
}

// =============================================================== Mot de passe de partage
Future<bool> askSharePassword(BuildContext context, DocumentService docs, String hash) async {
  final c = TextEditingController();
  String? err;
  bool busy = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: VT.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Mot de passe requis',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: c, obscureText: true, decoration: vInput('Mot de passe')),
          if (err != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(err!, style: const TextStyle(color: VT.red, fontSize: 12))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VT.ink),
            onPressed: busy
                ? null
                : () async {
                    set(() => busy = true);
                    final v = await docs.verifyPassword(password: c.text, hash: hash);
                    if (v) {
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } else {
                      set(() {
                        busy = false;
                        err = 'Mot de passe incorrect.';
                      });
                    }
                  },
            child: const Text('Déverrouiller'),
          ),
        ],
      ),
    ),
  );
  c.dispose();
  return ok == true;
}

// =============================================================== Upload
class UploadPayload {
  final String docType;
  final String? title;
  final DateTime? expiresAt;
  final String? folderId;
  const UploadPayload({required this.docType, this.title, this.expiresAt, this.folderId});
}

Future<UploadPayload?> showUploadSheet(BuildContext context,
        {required String fileName,
        required List<JsonMap> folders,
        String? preselectedFolderId}) =>
    showVSheet<UploadPayload>(context,
        builder: (_) => _UploadForm(
            fileName: fileName, folders: folders, folderId: preselectedFolderId));

class _UploadForm extends StatefulWidget {
  final String fileName;
  final List<JsonMap> folders;
  final String? folderId;
  const _UploadForm({required this.fileName, required this.folders, this.folderId});
  @override
  State<_UploadForm> createState() => _UploadFormState();
}

class _UploadFormState extends State<_UploadForm> {
  static const _types = {
    'CIN': 'Carte d’identité',
    'Passeport': 'Passeport',
    'Permis': 'Permis de conduire',
    'Diplôme': 'Diplôme / attestation',
    'PreuveAdresse': 'Preuve d’adresse',
    'Autre': 'Autre document',
  };
  String _type = 'Autre';
  String? _folder;
  DateTime? _exp;
  final _title = TextEditingController();

  @override
  void initState() {
    super.initState();
    _folder = widget.folderId;
    if (_folder != null && !widget.folders.any((f) => f['id'].toString() == _folder)) {
      _folder = null;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _needsExpiry => _type == 'CIN' || _type == 'Passeport' || _type == 'Permis';

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Nouveau document',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: VT.ink)),
      const SizedBox(height: 4),
      Text(widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: VT.forest, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      VCard(
        color: VT.forestSoft,
        borderColor: Colors.transparent,
        padding: const EdgeInsets.all(12),
        child: const Row(children: [
          Icon(Icons.fingerprint_rounded, color: VT.forest, size: 20),
          SizedBox(width: 10),
          Expanded(
              child: Text(
                  'Une empreinte SHA-256 sera calculée et scellée pour détecter toute falsification.',
                  style: TextStyle(fontSize: 11.5, color: VT.forest, height: 1.35))),
        ]),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String?>(
        value: _folder,
        decoration: vInput('Dossier'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Racine')),
          ...widget.folders.map((f) => DropdownMenuItem<String?>(
              value: f['id'].toString(), child: Text((f['name'] as String?) ?? '—'))),
        ],
        onChanged: (v) => setState(() => _folder = v),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _type,
        decoration: vInput('Classification'),
        items: _types.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) => setState(() {
          _type = v ?? 'Autre';
          if (!_needsExpiry) _exp = null;
        }),
      ),
      const SizedBox(height: 10),
      TextField(controller: _title, decoration: vInput('Libellé (optionnel)')),
      if (_needsExpiry) ...[
        const SizedBox(height: 10),
        VButton(
          _exp == null ? 'Date d’expiration' : 'Expire le ${fmtDate(_exp)}',
          icon: Icons.event_available_rounded,
          kind: VKind.outline,
          onTap: () async {
            final now = DateTime.now();
            final p = await showDatePicker(
                context: context,
                initialDate: _exp ?? now,
                firstDate: now.subtract(const Duration(days: 365 * 20)),
                lastDate: now.add(const Duration(days: 365 * 50)));
            if (p != null) setState(() => _exp = DateTime(p.year, p.month, p.day));
          },
        ),
      ],
      const SizedBox(height: 16),
      VButton('Sceller et enregistrer', icon: Icons.lock_rounded, onTap: () {
        if (_needsExpiry && _exp == null) {
          vSnack(context, 'La date d’expiration est requise.', error: true);
          return;
        }
        Navigator.pop(
            context,
            UploadPayload(
                docType: _type,
                title: _title.text.trim().isEmpty ? null : _title.text.trim(),
                expiresAt: _exp,
                folderId: _folder));
      }),
    ]);
  }
}

// =============================================================== Envoi
Future<void> showSendSheet(BuildContext context, VaultUser user, List<JsonMap> docs,
        {String? initialDocId}) =>
    showVSheet<void>(context,
        builder: (_) => _SendForm(user: user, docs: docs, initialDocId: initialDocId));

class _SendForm extends ConsumerStatefulWidget {
  final VaultUser user;
  final List<JsonMap> docs;
  final String? initialDocId;
  const _SendForm({required this.user, required this.docs, this.initialDocId});
  @override
  ConsumerState<_SendForm> createState() => _SendFormState();
}

class _SendFormState extends ConsumerState<_SendForm> {
  String? _docId;
  final _recip = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final _pw = TextEditingController();
  final _dur = TextEditingController(text: '10');
  String _unit = 'minutes';
  bool _auto = false;
  DateTime? _from;
  bool _sending = false;
  bool _verifying = false;
  String? _verified;
  Timer? _deb;

  @override
  void initState() {
    super.initState();
    _docId = widget.initialDocId;
    if (_docId != null && !widget.docs.any((d) => d['id'].toString() == _docId)) _docId = null;
    if (_docId == null && widget.docs.length == 1) _docId = widget.docs.first['id'].toString();
  }

  @override
  void dispose() {
    for (final c in [_recip, _subject, _body, _pw, _dur]) {
      c.dispose();
    }
    _deb?.cancel();
    super.dispose();
  }

  List<String> _ids(String v) =>
      v.split(RegExp(r'[,;\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  void _onRecip(String v) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      final ids = _ids(v);
      if (ids.isEmpty) {
        setState(() => _verified = null);
        return;
      }
      setState(() => _verifying = true);
      final p = await ref.read(documentServiceProvider).verifyThixId(ids.last);
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verified = p == null ? 'KO' : (p['full_name'] as String? ?? 'OK');
      });
    });
  }

  Duration? _duration() {
    if (!_auto) return null;
    final v = int.tryParse(_dur.text.trim());
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

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context,
        initialDate: _from ?? now,
        firstDate: now,
        lastDate: now.add(const Duration(days: 730)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_from ?? now.add(const Duration(hours: 1))));
    if (t == null || !mounted) return;
    final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (!dt.isAfter(DateTime.now())) {
      vSnack(context, 'Choisissez une date et une heure futures.', error: true);
      return;
    }
    setState(() => _from = dt);
  }

  Future<void> _submit() async {
    final recips = _ids(_recip.text);
    if (_docId == null) {
      vSnack(context, 'Sélectionnez un document.', error: true);
      return;
    }
    if (recips.isEmpty) {
      vSnack(context, 'Indiquez au moins un THIX ID destinataire.', error: true);
      return;
    }
    final sel = widget.docs.firstWhere((d) => d['id'].toString() == _docId,
        orElse: () => <String, dynamic>{});
    if (sel.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(vaultStateProvider(widget.user).notifier).sendDocument(
            documentId: _docId!,
            docIdLabel: (sel['generated_doc_id'] as String?) ?? (sel['doc_id'] as String?) ?? '',
            recipients: recips,
            subject: _subject.text.trim().isEmpty ? null : _subject.text.trim(),
            body: _body.text.trim().isEmpty ? null : _body.text.trim(),
            password: _pw.text.trim().isEmpty ? null : _pw.text.trim(),
            availableFrom: _from,
            autoDestructIn: _duration(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      vSnackOn(messenger, 'Document envoyé de façon sécurisée.');
    } catch (_) {
      if (mounted) setState(() => _sending = false);
      vSnackOn(messenger, 'Envoi impossible.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Envoi sécurisé',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: VT.ink)),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: _docId,
        isExpanded: true,
        decoration: vInput('Document'),
        items: widget.docs
            .map((d) => DropdownMenuItem(
                value: d['id'].toString(),
                child: Text((d['title'] as String?) ?? '—', overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (v) => setState(() => _docId = v),
      ),
      const SizedBox(height: 10),
      TextField(
          controller: _recip,
          onChanged: _onRecip,
          decoration: vInput('THIX ID destinataire(s)', icon: Icons.alternate_email_rounded)),
      if (_verifying)
        const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Text('Vérification…', style: TextStyle(fontSize: 11, color: VT.mute)))
      else if (_verified != null)
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(children: [
            Icon(_verified == 'KO' ? Icons.error_rounded : Icons.check_circle_rounded,
                size: 14, color: _verified == 'KO' ? VT.red : VT.ok),
            const SizedBox(width: 5),
            Text(_verified == 'KO' ? 'THIX ID introuvable' : _verified!,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _verified == 'KO' ? VT.red : VT.ok)),
          ]),
        ),
      const SizedBox(height: 10),
      TextField(controller: _subject, decoration: vInput('Objet')),
      const SizedBox(height: 10),
      TextField(controller: _body, maxLines: 3, decoration: vInput('Message')),
      const SizedBox(height: 10),
      TextField(
          controller: _pw,
          obscureText: true,
          decoration: vInput('Mot de passe (optionnel)', icon: Icons.key_rounded)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: VButton(
            _from == null ? 'Disponible immédiatement' : 'Dispo. ${fmtDT(_from!)}',
            icon: Icons.schedule_rounded,
            kind: _from == null ? VKind.outline : VKind.soft,
            onTap: _pickFrom,
          ),
        ),
        if (_from != null) ...[
          const SizedBox(width: 6),
          IconButton(
              onPressed: () => setState(() => _from = null), icon: const Icon(Icons.close_rounded)),
        ],
      ]),
      const SizedBox(height: 8),
      VCard(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        radius: 16,
        child: SwitchListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          activeColor: VT.red,
          title: const Text('Autodestruction',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          subtitle: const Text('Le partage disparaît après le délai (appliqué côté serveur)',
              style: TextStyle(fontSize: 10.5, color: VT.sub)),
          value: _auto,
          onChanged: (v) => setState(() => _auto = v),
        ),
      ),
      if (_auto) ...[
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              flex: 2,
              child: TextField(
                  controller: _dur,
                  keyboardType: TextInputType.number,
                  decoration: vInput('Délai'))),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: _unit,
              decoration: vInput(''),
              items: const [
                DropdownMenuItem(value: 's', child: Text('Secondes')),
                DropdownMenuItem(value: 'minutes', child: Text('Minutes')),
                DropdownMenuItem(value: 'h', child: Text('Heures')),
                DropdownMenuItem(value: 'd', child: Text('Jours')),
              ],
              onChanged: (v) => setState(() => _unit = v ?? 'minutes'),
            ),
          ),
        ]),
      ],
      const SizedBox(height: 16),
      VButton(_from == null ? 'Envoyer' : 'Programmer l’envoi',
          icon: _from == null ? Icons.send_rounded : Icons.schedule_send_rounded,
          busy: _sending,
          onTap: _submit),
    ]);
  }
}

// =============================================================== Fiche document
Future<void> showDocSheet(BuildContext context, VaultUser user, JsonMap row) =>
    showVSheet<void>(context, builder: (_) => _DocSheet(user: user, row: row));

class _DocSheet extends ConsumerStatefulWidget {
  final VaultUser user;
  final JsonMap row;
  const _DocSheet({required this.user, required this.row});
  @override
  ConsumerState<_DocSheet> createState() => _DocSheetState();
}

class _DocSheetState extends ConsumerState<_DocSheet> {
  bool _busy = false;
  IntegrityStatus? _integrity;

  VaultNotifier get _n => ref.read(vaultStateProvider(widget.user).notifier);
  JsonMap _find(List<JsonMap> docs) => docs.firstWhere(
      (d) => d['id'].toString() == widget.row['id'].toString(),
      orElse: () => widget.row);

  Future<void> _verify(JsonMap row) async {
    setState(() => _busy = true);
    try {
      final r = await _n.verifyIntegrity(row);
      if (mounted) setState(() => _integrity = r);
    } catch (_) {
      vSnack(context, 'Vérification impossible.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String msg, String action, {bool danger = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VT.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: Text(msg, style: const TextStyle(fontSize: 13, color: VT.sub, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: danger ? VT.red : VT.ink),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _sign(JsonMap row) async {
    if (!await _confirm('Signer ce document ?',
        'Une signature électronique horodatée sera générée côté serveur et liée à l’empreinte SHA-256. Action définitive.',
        'Signer')) {
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await _n.signDocument(row);
      vSnack(context, 'Signé · ${r['code'] ?? ''}');
    } catch (e) {
      final m = e.toString();
      vSnack(
          context,
          m.contains('no_hash')
              ? 'Document non scellé : impossible de signer.'
              : m.contains('already_signed')
                  ? 'Ce document est déjà signé.'
                  : 'Signature impossible.',
          error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(JsonMap row) async {
    if (!await _confirm('Supprimer ce document ?', 'Le fichier sera supprimé définitivement.',
        'Supprimer',
        danger: true)) {
      return;
    }
    try {
      await _n.deleteDocument(row);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      vSnack(context, 'Suppression impossible.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = _find(ref.watch(vaultStateProvider(widget.user).select((s) => s.documents)));
    final docs = ref.read(documentServiceProvider);
    final title = (row['title'] as String?) ?? '—';
    final docId = (row['generated_doc_id'] as String?) ?? '';
    final sha = row['sha256'] as String?;
    final signedAt = DateTime.tryParse((row['signed_at'] ?? '').toString());
    final code = row['signature_code'] as String?;
    final isPublic = (row['is_public'] as bool?) ?? false;

    Widget integrityResult() {
      if (_integrity == null) return const SizedBox.shrink();
      final ok = _integrity == IntegrityStatus.ok;
      final c = ok ? VT.ok : VT.red;
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.warning_rounded, color: c, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  ok
                      ? 'Intègre : le fichier correspond à l’empreinte scellée.'
                      : _integrity == IntegrityStatus.tampered
                          ? 'ALERTE : le fichier a été modifié depuis le dépôt.'
                          : 'Document non scellé.',
                  style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800))),
        ]),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        VThumb(row: row, docs: docs, size: 60, radius: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: VT.ink)),
            const SizedBox(height: 3),
            Text('${row['doc_type'] ?? '—'} · $docId',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: VT.mute)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: docTags(row)),
      const SizedBox(height: 14),
      VCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.fingerprint_rounded, size: 18, color: VT.forest),
            SizedBox(width: 8),
            Text('Empreinte d’intégrité',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          SelectableText(sha ?? 'Non scellé (dépôt antérieur à la v2)',
              style: const TextStyle(fontSize: 10.5, color: VT.sub, height: 1.4)),
          integrityResult(),
          const SizedBox(height: 10),
          VButton('Vérifier l’intégrité',
              icon: Icons.verified_user_rounded,
              kind: VKind.soft,
              busy: _busy && _integrity == null,
              onTap: sha == null ? null : () => _verify(row)),
        ]),
      ),
      const SizedBox(height: 10),
      VCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(signedAt != null ? Icons.verified_rounded : Icons.edit_note_rounded,
                size: 18, color: signedAt != null ? VT.ok : VT.forest),
            const SizedBox(width: 8),
            Text(signedAt != null ? 'Signé électroniquement' : 'Signature électronique',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          if (signedAt != null) ...[
            Text('$code · ${fmtDT(signedAt)}',
                style: const TextStyle(fontSize: 11, color: VT.sub)),
            const SizedBox(height: 10),
            VButton('QR de vérification',
                icon: Icons.qr_code_2_rounded,
                kind: VKind.soft,
                onTap: () => showIdentitySheet(context,
                    title: 'Vérification d’authenticité',
                    value: code ?? '',
                    caption: 'Scannez ou saisissez ce code dans « Vérifier » pour prouver l’authenticité.')),
          ] else ...[
            const Text('Lie ce document à votre identité avec une preuve infalsifiable.',
                style: TextStyle(fontSize: 11, color: VT.sub)),
            const SizedBox(height: 10),
            VButton('Signer maintenant',
                icon: Icons.draw_rounded,
                busy: _busy && _integrity != null,
                onTap: sha == null ? null : () => _sign(row)),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: VButton('Ouvrir',
                icon: Icons.open_in_new_rounded, onTap: () => openDocumentRow(context, docs, row))),
        const SizedBox(width: 8),
        Expanded(
            child: VButton('Envoyer',
                icon: Icons.send_rounded,
                kind: VKind.mint,
                onTap: () => showSendSheet(
                    context, widget.user, [row], initialDocId: row['id'].toString()))),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: VButton('QR / ID',
                icon: Icons.qr_code_2_rounded,
                kind: VKind.outline,
                onTap: () => showIdentitySheet(context,
                    title: title, value: docId.isNotEmpty ? docId : title))),
        const SizedBox(width: 8),
        Expanded(
            child: VButton('Supprimer',
                icon: Icons.delete_outline_rounded, kind: VKind.danger, onTap: () => _delete(row))),
      ]),
      const SizedBox(height: 8),
      VCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: SwitchListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          activeColor: VT.forest,
          title: Text(isPublic ? 'Public' : 'Privé',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          subtitle: Text(
              isPublic
                  ? 'Vérifiable par tous via son ID'
                  : 'Visible uniquement par vous et vos destinataires',
              style: const TextStyle(fontSize: 10.5, color: VT.sub)),
          value: isPublic,
          onChanged: (v) async {
            try {
              await _n.togglePublic(row, v);
            } catch (_) {
              vSnack(context, 'Modification impossible.', error: true);
            }
          },
        ),
      ),
    ]);
  }
}

// =============================================================== Fiche partage
Future<void> showShareSheet(BuildContext context, VaultUser user, JsonMap share,
        {required bool sent}) =>
    showVSheet<void>(context, builder: (_) => _ShareSheet(user: user, share: share, sent: sent));

class _ShareSheet extends ConsumerStatefulWidget {
  final VaultUser user;
  final JsonMap share;
  final bool sent;
  const _ShareSheet({required this.user, required this.share, required this.sent});
  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  JsonMap? _doc;
  JsonMap? _sender;
  bool _loading = true;
  bool _busy = false;

  DocumentService get _docs => ref.read(documentServiceProvider);
  VaultNotifier get _n => ref.read(vaultStateProvider(widget.user).notifier);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final docId = widget.share['document_id']?.toString();
    final senderId = widget.share['sender_id']?.toString();
    try {
      final doc = docId == null ? null : await _docs.fetchDocumentById(docId);
      JsonMap? sender;
      if (!widget.sent && senderId != null) {
        final r = await Supabase.instance.client
            .from('profiles')
            .select('full_name, thix_id')
            .eq('id', senderId)
            .maybeSingle();
        sender = r == null ? null : (r as Map).cast<String, dynamic>();
      }
      if (!mounted) return;
      setState(() {
        _doc = doc;
        _sender = sender;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _locked => isShareLocked(widget.share);

  bool _guard() {
    if (!_locked) return false;
    final af = DateTime.tryParse((widget.share['available_from'] ?? '').toString());
    vSnack(context, af != null ? 'Verrouillé jusqu’au ${fmtDT(af)}.' : 'Document verrouillé.',
        error: true);
    return true;
  }

  Future<bool> _passwordOk() async {
    final h = widget.share['password_hash'] as String?;
    if (h == null || h.isEmpty) return true;
    return askSharePassword(context, _docs, h);
  }

  Future<void> _open() async {
    if (_doc == null || _guard()) return;
    if (!widget.sent && !await _passwordOk()) return;
    if (!mounted) return;
    if (!widget.sent) {
      await _docs.markShareOpened(widget.share['id'].toString(),
          uid: _doc!['user_id']?.toString(), docId: _doc!['generated_doc_id']?.toString());
    }
    if (mounted) await openDocumentRow(context, _docs, _doc!);
  }

  Future<void> _download() async {
    if (_doc == null || _guard() || !await _passwordOk()) return;
    try {
      final ok = await launchOut(await _docs.resolveRowDownloadUrl(_doc!));
      if (!ok) throw Exception('launch');
    } catch (_) {
      vSnack(context, 'Téléchargement impossible.', error: true);
    }
  }

  Future<void> _save() async {
    if (_doc == null || _guard() || !await _passwordOk()) return;
    setState(() => _busy = true);
    try {
      final url = await _docs.resolveRowDownloadUrl(_doc!);
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200) throw Exception('http');
      final name = (_doc!['file_name'] as String?) ?? (_doc!['title'] as String?) ?? 'document';
      await _n.upload(
          file: PlatformFile(name: name, bytes: r.bodyBytes, size: r.bodyBytes.length),
          docType: (_doc!['doc_type'] as String?) ?? 'Autre',
          title: _doc!['title'] as String?);
      vSnack(context, 'Enregistré dans votre coffre.');
    } catch (_) {
      vSnack(context, 'Enregistrement impossible.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    setState(() => _busy = true);
    try {
      final ok = await _n.revokeShare(widget.share['id'].toString());
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        vSnack(context, 'Révocation refusée.', error: true);
      }
    } catch (_) {
      vSnack(context, 'Révocation impossible.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report() async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VT.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Signaler une contrefaçon',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: TextField(controller: c, maxLines: 3, decoration: vInput('Motif')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: VT.red),
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Signaler')),
        ],
      ),
    );
    c.dispose();
    if (reason == null || reason.isEmpty || _doc == null) return;
    try {
      await _n.reportDocument((_doc!['generated_doc_id'] as String?) ?? '', reason);
      vSnack(context, 'Signalement transmis à l’administration.');
    } catch (e) {
      vSnack(context,
          e.toString().contains('rate_limited') ? 'Trop de signalements, réessayez plus tard.' : 'Signalement impossible.',
          error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return vSpinner();
    final s = widget.share;
    final st = (s['status'] as String?) ?? 'pending';
    final hasPw = (s['password_hash'] as String?)?.isNotEmpty == true;
    final shots = (s['screenshot_count'] as num?)?.toInt() ?? 0;
    final who = widget.sent
        ? 'À ${(s['recipient_thix_id'] as String?) ?? '—'}'
        : 'De ${(_sender?['full_name'] as String?) ?? (s['sender_thix_id'] as String?) ?? 'Anonyme'}';
    final cd = shareCountdown(s);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(who,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: VT.sub)),
      const SizedBox(height: 4),
      Text(
          (s['subject'] as String?)?.isNotEmpty == true
              ? s['subject'] as String
              : 'Pièce jointe sécurisée',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: VT.ink)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        VTag(_locked ? 'VERROUILLÉ' : (st == 'opened' ? 'OUVERT' : 'DISPONIBLE'),
            _locked ? VT.amber : (st == 'opened' ? VT.ok : VT.blue)),
        if (hasPw) const VTag('MOT DE PASSE', VT.ink, icon: Icons.key_rounded),
        if (shots > 0) VTag('$shots CAPTURE(S)', VT.red, icon: Icons.camera_alt_rounded),
        if (_doc != null) ...docTags(_doc!).take(2),
      ]),
      const SizedBox(height: 12),
      VCard(
        child: SelectableText(
            (s['body'] as String?)?.isNotEmpty == true ? s['body'] as String : 'Aucun message.',
            style: const TextStyle(fontSize: 12.5, color: VT.sub, height: 1.5)),
      ),
      if (_doc != null) ...[
        const SizedBox(height: 10),
        VCard(
          onTap: _open,
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            VThumb(row: _doc!, docs: _docs, size: 46, radius: 14),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((_doc!['title'] as String?) ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                Text('${_doc!['doc_type'] ?? '—'} · ${_doc!['generated_doc_id'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: VT.mute)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: VT.mute),
          ]),
        ),
      ],
      if (cd != null) ...[const SizedBox(height: 12), cd],
      const SizedBox(height: 14),
      if (widget.sent) ...[
        Row(children: [
          Expanded(child: VButton('Ouvrir', icon: Icons.open_in_new_rounded, onTap: _open)),
          const SizedBox(width: 8),
          Expanded(
              child: VButton('Révoquer',
                  icon: Icons.block_rounded, kind: VKind.danger, busy: _busy, onTap: _revoke)),
        ]),
      ] else ...[
        Row(children: [
          Expanded(child: VButton('Ouvrir', icon: Icons.open_in_new_rounded, onTap: _open)),
          const SizedBox(width: 8),
          Expanded(
              child: VButton('Télécharger',
                  icon: Icons.download_rounded, kind: VKind.soft, onTap: _download)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: VButton('Dans mon coffre',
                  icon: Icons.save_rounded, kind: VKind.mint, busy: _busy, onTap: _save)),
          const SizedBox(width: 8),
          Expanded(
              child: VButton('Signaler',
                  icon: Icons.flag_rounded, kind: VKind.danger, onTap: _report)),
        ]),
      ],
    ]);
  }
}

// =============================================================== Vérification publique
Future<void> showVerifySheet(BuildContext context, VaultUser user) =>
    showVSheet<void>(context, builder: (_) => _VerifyForm(user: user));

class _VerifyForm extends ConsumerStatefulWidget {
  final VaultUser user;
  const _VerifyForm({required this.user});
  @override
  ConsumerState<_VerifyForm> createState() => _VerifyFormState();
}

class _VerifyFormState extends ConsumerState<_VerifyForm> {
  final _c = TextEditingController();
  bool _busy = false;
  bool _checking = false;
  String? _error;
  JsonMap? _doc;
  JsonMap? _sig;
  String _url = '';
  IntegrityStatus? _integrity;

  DocumentService get _docs => ref.read(documentServiceProvider);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _c.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _doc = null;
      _sig = null;
      _integrity = null;
      _url = '';
    });
    try {
      if (q.toUpperCase().startsWith('THIX-SIG')) {
        final r = await ref.read(vaultSecurityProvider).verifySignature(q);
        if (!mounted) return;
        setState(() => _sig = r.isEmpty ? null : r);
        if (r.isEmpty) setState(() => _error = 'Réponse invalide.');
      } else {
        final r = await _docs.searchPublicDocument(q);
        if (!mounted) return;
        if (r == null) {
          setState(() => _error = 'Aucun document public trouvé pour cet identifiant.');
        } else {
          String u = '';
          final path = (r['storage_path'] as String?) ?? '';
          if (path.isNotEmpty) {
            try {
              u = await _docs.createDownloadUrl(storagePath: path);
            } catch (_) {}
          }
          if (!mounted) return;
          setState(() {
            _doc = r;
            _url = u;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Vérification impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _integrityCheck() async {
    setState(() => _checking = true);
    try {
      final r = await ref
          .read(vaultSecurityProvider)
          .checkIntegrity(url: _url, expected: _doc!['sha256'] as String?);
      if (mounted) setState(() => _integrity = r);
    } catch (_) {
      vSnack(context, 'Contrôle impossible.', error: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _saveToVault() async {
    setState(() => _busy = true);
    try {
      final r = await http.get(Uri.parse(_url));
      if (r.statusCode != 200) throw Exception('http');
      final name = (_doc!['file_name'] as String?) ?? (_doc!['title'] as String?) ?? 'document';
      await ref.read(vaultStateProvider(widget.user).notifier).upload(
          file: PlatformFile(name: name, bytes: r.bodyBytes, size: r.bodyBytes.length),
          docType: (_doc!['doc_type'] as String?) ?? 'Autre',
          title: _doc!['title'] as String?);
      vSnack(context, 'Enregistré dans votre coffre.');
    } catch (_) {
      vSnack(context, 'Enregistrement impossible.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _sigCard() {
    final s = _sig!;
    final valid = s['valid'] == true;
    final c = valid ? VT.ok : VT.red;
    return VCard(
      color: c.withOpacity(0.07),
      borderColor: c.withOpacity(0.3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(valid ? Icons.verified_rounded : Icons.gpp_bad_rounded, color: c, size: 26),
          const SizedBox(width: 10),
          Expanded(
              child: Text(valid ? 'SIGNATURE AUTHENTIQUE' : 'SIGNATURE INVALIDE',
                  style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 10),
        if (valid) ...[
          _kv('Signataire', (s['signer_name'] as String?) ?? '—'),
          _kv('Signé le', fmtDT(DateTime.tryParse((s['signed_at'] ?? '').toString()) ?? DateTime.now())),
          _kv('Document', (s['title'] as String?) ?? '—'),
          _kv('Empreinte', shortHash(s['sha256'] as String?)),
        ] else
          Text(
              s['reason'] == 'not_found'
                  ? 'Ce code n’existe pas : document potentiellement contrefait.'
                  : s['revoked'] == true
                      ? 'Cette signature a été révoquée par l’administration.'
                      : 'Le document a été modifié depuis la signature ou la preuve est corrompue.',
              style: const TextStyle(fontSize: 12.5, color: VT.ink, height: 1.4)),
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 84, child: Text(k, style: const TextStyle(fontSize: 11.5, color: VT.sub))),
          Expanded(
              child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
        ]),
      );

  Widget _docCard() {
    final d = _doc!;
    final signed = d['signed_at'] != null;
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((d['owner_name'] as String?) ?? '—',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              Text((d['owner_thix_id'] as String?) ?? '—',
                  style: const TextStyle(fontSize: 10.5, color: VT.mute)),
            ]),
          ),
          VTag(signed ? 'CERTIFIÉ · SIGNÉ' : 'CERTIFIÉ', VT.ok, icon: Icons.verified_rounded),
        ]),
        const SizedBox(height: 12),
        Text((d['title'] as String?) ?? '—',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text('${d['doc_type'] ?? '—'} · ${d['generated_doc_id'] ?? '—'}',
            style: const TextStyle(fontSize: 10.5, color: VT.mute)),
        const SizedBox(height: 8),
        _kv('Empreinte', shortHash(d['sha256'] as String?)),
        _kv('Date', fmtDate(d['created_at'])),
        if (_integrity != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                _integrity == IntegrityStatus.ok
                    ? '✓ Fichier intègre : conforme à l’original scellé.'
                    : _integrity == IntegrityStatus.tampered
                        ? '⚠ ALERTE : fichier différent de l’original (contrefaçon probable).'
                        : 'Document non scellé : contrôle impossible.',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _integrity == IntegrityStatus.ok ? VT.ok : VT.red)),
          ),
        const SizedBox(height: 12),
        VButton('Ouvrir le fichier',
            icon: Icons.open_in_new_rounded,
            onTap: () => openFileUrl(context, _url, (d['mime_type'] as String?) ?? '',
                (d['file_name'] as String?) ?? (d['title'] as String?) ?? 'document')),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: VButton('Télécharger',
                  icon: Icons.download_rounded,
                  kind: VKind.soft,
                  onTap: _url.isEmpty ? null : () => launchOut(_url))),
          const SizedBox(width: 8),
          Expanded(
              child: VButton('Intégrité',
                  icon: Icons.fingerprint_rounded,
                  kind: VKind.soft,
                  busy: _checking,
                  onTap: _url.isEmpty ? null : _integrityCheck)),
        ]),
        const SizedBox(height: 8),
        VButton('Enregistrer dans mon coffre',
            icon: Icons.save_rounded,
            kind: VKind.mint,
            busy: _busy,
            onTap: _url.isEmpty ? null : _saveToVault),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Vérifier l’authenticité',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: VT.ink)),
      const SizedBox(height: 4),
      const Text('Saisissez un ID document (THIX-DOC-…) ou un code de signature (THIX-SIG-…).',
          style: TextStyle(fontSize: 11.5, color: VT.sub)),
      const SizedBox(height: 14),
      TextField(
          controller: _c,
          textCapitalization: TextCapitalization.characters,
          onSubmitted: (_) => _search(),
          decoration: vInput('THIX-DOC-… ou THIX-SIG-…', icon: Icons.search_rounded)),
      const SizedBox(height: 10),
      VButton('Vérifier', icon: Icons.verified_user_rounded, busy: _busy && _doc == null, onTap: _search),
      const SizedBox(height: 14),
      if (_error != null)
        VCard(
            color: VT.red.withOpacity(0.07),
            borderColor: VT.red.withOpacity(0.3),
            child: Text(_error!, style: const TextStyle(color: VT.red, fontWeight: FontWeight.w700))),
      if (_sig != null) _sigCard(),
      if (_doc != null) _docCard(),
    ]);
  }
}

// =============================================================== Sécurité / PIN
Future<void> showSecuritySheet(BuildContext context, VaultUser user) =>
    showVSheet<void>(context, builder: (_) => _SecurityForm(user: user));

class _SecurityForm extends ConsumerStatefulWidget {
  final VaultUser user;
  const _SecurityForm({required this.user});
  @override
  ConsumerState<_SecurityForm> createState() => _SecurityFormState();
}

class _SecurityFormState extends ConsumerState<_SecurityForm> {
  bool? _hasPin;
  bool _busy = false;
  final _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(documentServiceProvider).hasVaultLock(widget.user.uid).then((v) {
      if (mounted) setState(() => _hasPin = v);
    }).catchError((_) {
      if (mounted) setState(() => _hasPin = false);
    });
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = _pin.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(p)) {
      vSnack(context, 'Le PIN doit contenir 4 à 6 chiffres.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(documentServiceProvider).setVaultPin(uid: widget.user.uid, pin: p);
      _pin.clear();
      if (mounted) setState(() => _hasPin = true);
      vSnack(context, 'Verrou PIN activé.');
    } catch (_) {
      vSnack(context, 'Activation impossible.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(IconData i, String t, String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 18, color: VT.ok),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              Text(s, style: const TextStyle(fontSize: 11, color: VT.sub, height: 1.3)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Sécurité du coffre',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: VT.ink)),
      const SizedBox(height: 12),
      VCard(
        child: Column(children: [
          _row(Icons.fingerprint_rounded, 'Scellement SHA-256', 'Toute modification du fichier est détectée.'),
          _row(Icons.draw_rounded, 'Signature serveur (HMAC)', 'Le secret ne quitte jamais la base de données.'),
          _row(Icons.history_rounded, 'Audit immuable', 'Aucune ligne du journal ne peut être modifiée ou supprimée.'),
          _row(Icons.schedule_rounded, 'Accès différé serveur', 'Un envoi verrouillé reste inaccessible même hors de l’app.'),
        ]),
      ),
      const SizedBox(height: 12),
      VCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(_hasPin == true ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: _hasPin == true ? VT.ok : VT.amber, size: 18),
            const SizedBox(width: 8),
            Text(_hasPin == true ? 'Verrou PIN actif' : 'Verrou PIN désactivé',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          TextField(
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: vInput(_hasPin == true ? 'Nouveau PIN (4 à 6 chiffres)' : 'Choisir un PIN (4 à 6 chiffres)')
                  .copyWith(counterText: '')),
          const SizedBox(height: 10),
          VButton(_hasPin == true ? 'Modifier le PIN' : 'Activer le verrou',
              icon: Icons.lock_rounded, busy: _busy, onTap: _save),
        ]),
      ),
    ]);
  }
}

class VaultPinGate extends ConsumerStatefulWidget {
  final VaultUser user;
  final Widget child;
  const VaultPinGate({super.key, required this.user, required this.child});
  @override
  ConsumerState<VaultPinGate> createState() => _VaultPinGateState();
}

class _VaultPinGateState extends ConsumerState<VaultPinGate> {
  bool? _hasPin;
  final _c = TextEditingController();
  String? _err;
  int _fails = 0;
  DateTime? _lockedUntil;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(documentServiceProvider).hasVaultLock(widget.user.uid).then((v) {
      if (mounted) setState(() => _hasPin = v);
    }).catchError((_) {
      if (mounted) setState(() => _hasPin = false);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_lockedUntil != null && _lockedUntil!.isAfter(DateTime.now())) {
      setState(() => _err = 'Trop d’essais. Réessayez dans quelques secondes.');
      return;
    }
    setState(() => _busy = true);
    final ok = await ref
        .read(documentServiceProvider)
        .verifyVaultPin(uid: widget.user.uid, pin: _c.text.trim());
    if (!mounted) return;
    if (ok) {
      ref.read(vaultUnlockedProvider.notifier).state = true;
      return;
    }
    _fails++;
    setState(() {
      _busy = false;
      _c.clear();
      if (_fails >= 5) {
        _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
        _fails = 0;
        _err = 'Verrouillé 30 secondes.';
      } else {
        _err = 'PIN incorrect.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPin == null) {
      return Scaffold(backgroundColor: VT.bg, body: vSpinner());
    }
    final unlocked = ref.watch(vaultUnlockedProvider);
    if (_hasPin == false || unlocked) return widget.child;
    return Scaffold(
      backgroundColor: VT.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(color: VT.forest, shape: BoxShape.circle),
                child: const Icon(Icons.lock_rounded, color: VT.mint, size: 32),
              ),
              const SizedBox(height: 18),
              const Text('Coffre verrouillé',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: VT.ink)),
              const SizedBox(height: 6),
              const Text('Entrez votre PIN pour accéder à vos documents.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: VT.sub)),
              const SizedBox(height: 22),
              TextField(
                  controller: _c,
                  obscureText: true,
                  autofocus: true,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _unlock(),
                  style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w800),
                  decoration: vInput('').copyWith(counterText: '')),
              if (_err != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_err!, style: const TextStyle(color: VT.red, fontSize: 12))),
              const SizedBox(height: 14),
              VButton('Déverrouiller', icon: Icons.lock_open_rounded, busy: _busy, onTap: _unlock),
            ]),
          ),
        ),
      ),
    );
  }
}

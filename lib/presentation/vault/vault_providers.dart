// lib/presentation/vault/vault_providers.dart
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/services/document_service.dart';

import 'vault_security_service.dart';
import 'vault_state.dart';

// ------------------------------------------------------------- Services
final documentServiceProvider = Provider<DocumentService>((ref) => DocumentService());
final vaultSecurityProvider =
    Provider<VaultSecurityService>((ref) => VaultSecurityService());

// ------------------------------------------------------------- Etat
final vaultStateProvider = StateNotifierProvider.autoDispose
    .family<VaultNotifier, VaultState, VaultUser>((ref, user) => VaultNotifier(ref, user));

final vaultAdminProvider = FutureProvider.autoDispose<bool>(
    (ref) => ref.watch(vaultSecurityProvider).isAdmin());

final vaultUnlockedProvider = StateProvider<bool>((ref) => false);

// ------------------------------------------------------------- Derivés
bool shareHidden(JsonMap s) {
  final st = (s['status'] as String?) ?? 'pending';
  if (st == 'destroyed' || st == 'expired') return true;
  final ad = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
  return ad != null && ad.isBefore(DateTime.now());
}

final filteredDocsProvider =
    Provider.autoDispose.family<List<JsonMap>, VaultUser>((ref, u) {
  final docs = ref.watch(vaultStateProvider(u).select((s) => s.documents));
  final folder = ref.watch(vaultStateProvider(u).select((s) => s.folderFilter));
  final q = ref.watch(vaultStateProvider(u).select((s) => s.searchQuery));
  return docs.where((d) {
    if (folder != null && d['folder_id'] != folder) return false;
    if (q.isEmpty) return true;
    final hay =
        '${d['title'] ?? ''} ${d['generated_doc_id'] ?? ''} ${d['doc_type'] ?? ''} ${d['file_name'] ?? ''}'
            .toLowerCase();
    return hay.contains(q);
  }).toList();
});

final sentSharesProvider =
    Provider.autoDispose.family<List<JsonMap>, VaultUser>((ref, u) => ref
        .watch(vaultStateProvider(u).select((s) => s.sentShares))
        .where((s) => !shareHidden(s))
        .toList());

final receivedSharesProvider =
    Provider.autoDispose.family<List<JsonMap>, VaultUser>((ref, u) => ref
        .watch(vaultStateProvider(u).select((s) => s.receivedShares))
        .where((s) => !shareHidden(s))
        .toList());

final expiringDocsProvider =
    Provider.autoDispose.family<List<JsonMap>, VaultUser>((ref, u) {
  final docs = ref.watch(vaultStateProvider(u).select((s) => s.documents));
  final now = DateTime.now();
  final list = docs.where((d) {
    final e = DateTime.tryParse((d['expires_at'] ?? '').toString());
    return e != null && e.difference(now).inDays <= 45;
  }).toList();
  list.sort((a, b) => DateTime.parse(a['expires_at'].toString())
      .compareTo(DateTime.parse(b['expires_at'].toString())));
  return list;
});

class VaultStats {
  final int total, signed, sealed, publicCount, bytes;
  const VaultStats(this.total, this.signed, this.sealed, this.publicCount, this.bytes);
}

final vaultStatsProvider = Provider.autoDispose.family<VaultStats, VaultUser>((ref, u) {
  final docs = ref.watch(vaultStateProvider(u).select((s) => s.documents));
  var signed = 0, sealed = 0, pub = 0, bytes = 0;
  for (final d in docs) {
    if (d['signed_at'] != null) signed++;
    if ((d['sha256'] as String?)?.isNotEmpty == true) sealed++;
    if (d['is_public'] == true) pub++;
    bytes += (d['size_bytes'] as num?)?.toInt() ?? 0;
  }
  return VaultStats(docs.length, signed, sealed, pub, bytes);
});

// ------------------------------------------------------------- Notifier
class VaultNotifier extends StateNotifier<VaultState> {
  final Ref _ref;
  final VaultUser user;
  final List<StreamSubscription<dynamic>> _subs = [];
  final Set<String> _swept = {};
  Timer? _timer;

  VaultNotifier(this._ref, this.user) : super(const VaultState()) {
    _init();
  }

  DocumentService get _docs => _ref.read(documentServiceProvider);
  VaultSecurityService get _sec => _ref.read(vaultSecurityProvider);

  void _listen<T>(Stream<T> s, VaultState Function(VaultState, T) apply) {
    _subs.add(s.listen((v) {
      if (!mounted) return;
      state = apply(state, v);
      _sweep();
    }, onError: (Object e) {
      if (mounted) state = state.copyWith(error: e.toString());
    }));
  }

  void _init() {
    _listen<List<JsonMap>>(_docs.streamDocuments(user.uid),
        (s, v) => s.copyWith(documents: v, loaded: true));
    _listen<List<JsonMap>>(
        _docs.streamFolders(user.uid), (s, v) => s.copyWith(folders: v));
    _listen<List<JsonMap>>(
        _docs.streamSentShares(user.uid), (s, v) => s.copyWith(sentShares: v));
    _listen<List<JsonMap>>(
        _docs.streamTransactions(user.uid), (s, v) => s.copyWith(auditLog: v));
    if (user.thixId != null && user.thixId!.isNotEmpty) {
      _listen<List<JsonMap>>(_docs.streamReceivedShares(user.uid, user.thixId!),
          (s, v) => s.copyWith(receivedShares: v));
    }
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _sweep());
  }

  /// Détruit les partages dont l'échéance est passée (hors du build).
  void _sweep() {
    final now = DateTime.now();
    for (final s in [...state.sentShares, ...state.receivedShares]) {
      final id = s['id']?.toString();
      final st = (s['status'] as String?) ?? 'pending';
      final ad = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
      if (id == null || ad == null || st == 'destroyed' || st == 'expired') continue;
      if (ad.isBefore(now) && _swept.add(id)) {
        _docs.markShareDestroyed(id).catchError((_) {});
      }
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _timer?.cancel();
    super.dispose();
  }

  // ----------------------------------------------------------- UI state
  void setFolderFilter(String? id) => state =
      id == null ? state.copyWith(clearFolder: true) : state.copyWith(folderFilter: id);
  void setSearch(String q) => state = state.copyWith(searchQuery: q.trim().toLowerCase());

  // ----------------------------------------------------------- Actions
  Future<void> createFolder(String name) => _docs.createFolder(uid: user.uid, name: name);

  Future<String> upload({
    required PlatformFile file,
    required String docType,
    String? title,
    DateTime? expiresAt,
    String? folderId,
  }) async {
    state = state.copyWith(isUploading: true, clearError: true);
    try {
      final id = await _docs.uploadPickedFileSimple(
        uid: user.uid,
        file: file,
        docType: docType,
        expiresAt: expiresAt,
        title: title,
        folderId: folderId,
        isPublic: false,
      );
      final bytes = file.bytes;
      if (bytes != null) {
        await _sec.sealDocument(uid: user.uid, generatedId: id, bytes: bytes);
      }
      return id;
    } finally {
      if (mounted) state = state.copyWith(isUploading: false);
    }
  }

  Future<void> sendDocument({
    required String documentId,
    required String docIdLabel,
    required List<String> recipients,
    String? subject,
    String? body,
    String? password,
    DateTime? availableFrom,
    Duration? autoDestructIn,
  }) async {
    state = state.copyWith(isSending: true, clearError: true);
    try {
      await _docs.shareDocument(
        senderId: user.uid,
        documentId: documentId,
        docId: docIdLabel,
        recipientThixIds: recipients,
        subject: subject,
        body: body,
        password: password,
        availableFrom: availableFrom,
        autoDestructIn: autoDestructIn,
      );
    } finally {
      if (mounted) state = state.copyWith(isSending: false);
    }
  }

  Future<void> deleteDocument(JsonMap row) => _docs.deleteDocument(
        uid: user.uid,
        documentId: row['id'].toString(),
        storagePath: (row['storage_path'] as String?) ?? '',
        docId: row['generated_doc_id'] as String?,
      );

  Future<void> togglePublic(JsonMap row, bool v) => _docs.togglePublic(
        uid: user.uid,
        documentId: row['id'].toString(),
        docId: row['generated_doc_id'] as String?,
        isPublic: v,
      );

  Future<JsonMap> signDocument(JsonMap row) => _sec.signDocument(row['id'].toString());

  Future<IntegrityStatus> verifyIntegrity(JsonMap row) async {
    final expected = row['sha256'] as String?;
    if (expected == null || expected.isEmpty) return IntegrityStatus.unsealed;
    final url = await _docs.resolveRowDownloadUrl(row);
    return _sec.checkIntegrity(url: url, expected: expected);
  }

  Future<bool> revokeShare(String id) => _sec.revokeShare(id);

  Future<void> reportDocument(String docId, String reason) =>
      _sec.reportDocument(docId: docId, reason: reason);
}

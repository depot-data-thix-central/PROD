import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/services/profile_service.dart';         // ✅ remplace firestore_user_service
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

import '../../theme.dart';

/// Bottom sheets used across the app to verify a THIX ID / UID and optional Doc ID,
/// scan QR codes, scan NFC tags, and share/invite via THIX ID.
class ThixIdentitySheets {
  static Future<void> showVerifySheet(BuildContext context, {String? initialUidOrThixId, String? initialDocId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ThixVerifyBottomSheet(initialUidOrThixId: initialUidOrThixId, initialDocId: initialDocId),
    );
  }

  static Future<void> showQrScanSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ThixQrScanBottomSheet(mode: _QrMode.verify),
    );
  }

  /// Returns a scanned/pasted THIX ID or Firebase UID (and optional Doc ID)
  /// to be used by features like THIX CHAT.
  static Future<({String uidOrThixId, String? docId})?> showQrScanForResult(BuildContext context) {
    return showModalBottomSheet<({String uidOrThixId, String? docId})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ThixQrScanBottomSheet(mode: _QrMode.returnResult),
    );
  }

  static Future<void> showInviteSheet(BuildContext context, {required String thixId, required String displayName}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ThixInviteBottomSheet(thixId: thixId, displayName: displayName),
    );
  }

  static Future<void> showNfcScanSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ThixNfcScanBottomSheet(),
    );
  }
}

class _ThixInviteBottomSheet extends StatelessWidget {
  final String thixId;
  final String displayName;
  const _ThixInviteBottomSheet({required this.thixId, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final normalized = thixId.trim().toUpperCase();
    final inviteText = 'THIX ID: $normalized\nProfil: $displayName\nOuvrir: thix://public?thixId=$normalized';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.xl), topRight: Radius.circular(AppRadius.xl)),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Inviter', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded), color: Theme.of(context).colorScheme.onSurface),
              ],
            ),
            Text('Partagez votre THIX ID pour qu’un contact ouvre votre identité publique.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, height: 1.4)),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.badge_rounded, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(normalized, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: normalized));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('THIX ID copié.')));
                        }
                      },
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copier'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: normalized.isEmpty
                          ? null
                          : () async {
                              await Share.share(inviteText, subject: 'Invitation THIX ID');
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LightModeColors.accent,
                        foregroundColor: const Color(0xFF0A2F5C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.share_rounded, color: Color(0xFF0A2F5C)),
                      label: const Text('Partager'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _ThixNfcScanBottomSheet extends StatefulWidget {
  const _ThixNfcScanBottomSheet();

  @override
  State<_ThixNfcScanBottomSheet> createState() => _ThixNfcScanBottomSheetState();
}

class _ThixNfcScanBottomSheetState extends State<_ThixNfcScanBottomSheet> {
  bool _supported = true;
  bool _scanning = false;
  String? _payload;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ok = await NfcManager.instance.isAvailable();
      if (!mounted) return;
      setState(() => _supported = ok);
      if (ok) await _start();
    } catch (e) {
      debugPrint('NFC: isAvailable failed: $e');
      if (mounted) setState(() => _supported = false);
    }
  }

  @override
  void dispose() {
    if (_scanning) {
      NfcManager.instance.stopSession();
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _payload = null;
      _error = null;
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: const {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
        onDiscovered: (tag) async {
          try {
            final text = tag.data.toString();
            if (!mounted) return;
            setState(() {
              _payload = text;
              _scanning = false;
            });
            await NfcManager.instance.stopSession();
          } catch (e) {
            debugPrint('NFC: read failed: $e');
            if (!mounted) return;
            setState(() {
              _error = 'Lecture NFC impossible.';
              _scanning = false;
            });
            await NfcManager.instance.stopSession();
          }
        },
      );
    } catch (e) {
      debugPrint('NFC: startSession failed: $e');
      if (mounted) {
        setState(() {
          _error = 'NFC indisponible ou permission refusée.';
          _scanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.xl), topRight: Radius.circular(AppRadius.xl)),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lecture NFC', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded), color: Theme.of(context).colorScheme.onSurface),
              ],
            ),
            Text('Approchez une carte/tag NFC contenant un THIX ID ou un lien.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, height: 1.4)),
            const SizedBox(height: AppSpacing.lg),
            if (!_supported)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.nfc_rounded, color: LightModeColors.hint),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text('NFC non disponible sur cet appareil.', style: context.textStyles.bodyMedium)),
                  ],
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(_scanning ? Icons.radar_rounded : Icons.nfc_rounded, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _scanning ? 'Scan en cours…' : (_payload != null ? 'Tag détecté.' : (_error ?? 'Prêt à scanner.')),
                        style: context.textStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (_payload != null) ...[
                const SizedBox(height: AppSpacing.md),
                SelectableText(_payload!, style: context.textStyles.bodySmall?.copyWith(height: 1.4)),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _scanning ? null : _start,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LightModeColors.accent,
                    foregroundColor: const Color(0xFF0A2F5C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF0A2F5C)),
                  label: Text(_scanning ? 'SCANNING…' : 'RELANCER', style: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF0A2F5C))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class Ndef {
}

enum _QrMode { verify, returnResult }

class _ThixVerifyBottomSheet extends StatefulWidget {
  final String? initialUidOrThixId;
  final String? initialDocId;

  const _ThixVerifyBottomSheet({this.initialUidOrThixId, this.initialDocId});

  @override
  State<_ThixVerifyBottomSheet> createState() => _ThixVerifyBottomSheetState();
}

class _ThixVerifyBottomSheetState extends State<_ThixVerifyBottomSheet> {
  // ✅ remplace FirestoreUserService par ProfileService
  final _profileService = ProfileService();
  late final TextEditingController _uidController;
  late final TextEditingController _docController;
  bool _loading = false;

  static final RegExp _thixIdLooseRegex = RegExp(r'^THIX-', caseSensitive: false);
  static final RegExp _docIdRegex = RegExp(r'^(CIN|DIP|BIRTH|RES|DRIV)-\d{4}-\d{3}$', caseSensitive: false);
  static final RegExp _uidLikeRegex = RegExp(r'^[A-Za-z0-9_\-]{20,}$');

  @override
  void initState() {
    super.initState();
    _uidController = TextEditingController(text: widget.initialUidOrThixId ?? '');
    _docController = TextEditingController(text: widget.initialDocId ?? '');
  }

  @override
  void dispose() {
    _uidController.dispose();
    _docController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final uidRaw = _uidController.text.trim();
    final doc = _docController.text.trim();

    if (uidRaw.isEmpty) {
      _showSnack('Veuillez saisir un THIX ID ou un UID.');
      return;
    }
    final uidNormalized = ThixIdService.normalize(uidRaw);
    final isThix = uidNormalized.startsWith('THIX-');
    final isUid = _uidLikeRegex.hasMatch(uidRaw);
    if (!isThix && !isUid) {
      _showSnack('Identifiant invalide. Exemple: ${ThixIdService.exampleV2} ou ${ThixIdService.exampleV1} ou UID.');
      return;
    }
    if (isThix && !ThixIdService.isValid(uidNormalized)) {
      _showSnack('THIX ID invalide. Vérifiez le format et le checksum.');
      return;
    }
    if (doc.isNotEmpty && !_docIdRegex.hasMatch(doc)) {
      _showSnack('Doc ID invalide. Exemple: CIN-2023-001.');
      return;
    }

    setState(() => _loading = true);
    try {
      // ✅ Appels corrigés avec ProfileService
      final other = isThix 
          ? await _profileService.fetchPublicProfileByThixId(uidNormalized.toUpperCase()) 
          : await _profileService.fetchPublicProfileByUserId(uidRaw);

      if (other == null) throw Exception(isThix ? 'THIX ID introuvable.' : 'UID introuvable.');

      if (doc.isNotEmpty) {
        final docId = doc.toUpperCase();
        final row = await SupabaseConfig.client
            .from(DocumentService.table)
            .select('id')
            .eq('user_id', other.userId)   // ✅ other.userId au lieu de other.id
            .eq('doc_id', docId)
            .limit(1)
            .maybeSingle();
        if (row == null) {
          _showSnack('Document introuvable pour ce Doc ID.');
          return;
        }
      }

      if (!mounted) return;
      context.pop();
      final thixForRoute = other.thixId.trim().toUpperCase();
      _showSnack('Profil vérifié: ${other.displayName} ($thixForRoute).', positive: true);
      if (thixForRoute.isNotEmpty) context.push('${AppRoutes.publicProfile}?thixId=$thixForRoute');
    } catch (e) {
      debugPrint('VerifySheet: failed to verify uid=$uidRaw doc=$doc err=$e');
      if (!mounted) return;
      final msg = e.toString();
      if (msg.toLowerCase().contains('introuvable')) {
        _showSnack(msg);
      } else {
        _showSnack('Vérification impossible.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String message, {bool positive = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: positive ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.xl),
            topRight: Radius.circular(AppRadius.xl),
          ),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Vérification THIX ID', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                IconButton(
                  onPressed: _loading ? null : () => context.pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ],
            ),
            Text(
              'Entrez un THIX ID et, si besoin, un Doc ID pour vérifier l’existence du profil et du document.',
              style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _uidController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'THIX ID / UID',
                hintText: ThixIdService.exampleV2,
                prefixIcon: const Icon(Icons.verified_user_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _docController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading ? null : _verify(),
              decoration: InputDecoration(
                labelText: 'Doc ID (optionnel)',
                hintText: 'CIN-2023-001',
                prefixIcon: const Icon(Icons.description_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightModeColors.accent,
                  foregroundColor: const Color(0xFF0A2F5C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                  elevation: 0,
                ),
                icon: _loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: const Color(0xFF0A2F5C).withValues(alpha: 0.8)),
                      )
                    : const Icon(Icons.check_circle_rounded, color: Color(0xFF0A2F5C)),
                label: Text('VÉRIFIER', style: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF0A2F5C))),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _ThixQrScanBottomSheet extends StatefulWidget {
  final _QrMode mode;
  const _ThixQrScanBottomSheet({required this.mode});

  @override
  State<_ThixQrScanBottomSheet> createState() => _ThixQrScanBottomSheetState();
}

class _ThixQrScanBottomSheetState extends State<_ThixQrScanBottomSheet> {
  final _controller = TextEditingController();
  final MobileScannerController _scanner = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _loading = false;
  bool _cameraMode = true;

  @override
  void dispose() {
    _controller.dispose();
    _scanner.dispose();
    super.dispose();
  }

  ({String? uid, String? docId}) _parsePayload(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return (uid: null, docId: null);
    if (v.toLowerCase().startsWith('thix://')) {
      try {
        final uri = Uri.parse(v);
        final uid = uri.queryParameters['uid'] ?? uri.queryParameters['thixId'];
        final doc = uri.queryParameters['doc'] ?? uri.queryParameters['docId'];
        return (uid: uid, docId: doc);
      } catch (_) {
        return (uid: null, docId: null);
      }
    }
    if (v.toLowerCase().startsWith('thix-')) return (uid: v, docId: null);
    if (RegExp(r'^[A-Za-z0-9_\-]{20,}$').hasMatch(v)) return (uid: v, docId: null);
    return (uid: null, docId: null);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_loading) return;
    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null || raw.trim().isEmpty) return;
    _controller.text = raw;
    await _continue();
  }

  Future<void> _continue() async {
    final parsed = _parsePayload(_controller.text);
    if (parsed.uid == null) {
      _showSnack('QR invalide. Exemple: thix://verify?uid=${ThixIdService.exampleV2}&doc=CIN-2023-001');
      return;
    }

    setState(() => _loading = true);
    try {
      if (!mounted) return;
      if (widget.mode == _QrMode.returnResult) {
        context.pop((uidOrThixId: parsed.uid!, docId: parsed.docId));
        return;
      }
      context.pop();
      await ThixIdentitySheets.showVerifySheet(context, initialUidOrThixId: parsed.uid, initialDocId: parsed.docId);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.xl), topRight: Radius.circular(AppRadius.xl)),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Scanner QR', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                IconButton(
                  onPressed: _loading ? null : () => context.pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ],
            ),
            Text(
              'Scannez un QR THIX (caméra) ou collez son contenu.',
              style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() => _cameraMode = true);
                          },
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Caméra'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _cameraMode ? const Color(0xFF0A2F5C) : Theme.of(context).colorScheme.primary,
                      backgroundColor: _cameraMode ? LightModeColors.accent : null,
                      side: BorderSide(color: _cameraMode ? LightModeColors.accent : Theme.of(context).dividerColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() => _cameraMode = false);
                          },
                    icon: const Icon(Icons.content_paste_rounded),
                    label: const Text('Coller'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: !_cameraMode ? const Color(0xFF0A2F5C) : Theme.of(context).colorScheme.primary,
                      backgroundColor: !_cameraMode ? LightModeColors.accent : null,
                      side: BorderSide(color: !_cameraMode ? LightModeColors.accent : Theme.of(context).dividerColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_cameraMode) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: SizedBox(
                  height: 220,
                  child: MobileScanner(
                    controller: _scanner,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) {
                      debugPrint('QrScanSheet: camera error=$error');
                      return Container(
                        color: Theme.of(context).colorScheme.surface,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                          child: Text(
                            'Caméra indisponible. Utilisez “Coller”.',
                            style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading ? null : _continue(),
              decoration: InputDecoration(
                labelText: 'Payload QR',
                hintText: 'thix://verify?uid=${ThixIdService.exampleV2}&doc=CIN-2023-001',
                prefixIcon: const Icon(Icons.qr_code_2_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightModeColors.accent,
                  foregroundColor: const Color(0xFF0A2F5C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0A2F5C)),
                label: Text('CONTINUER', style: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF0A2F5C))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

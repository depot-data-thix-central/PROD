import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/theme.dart';

extension _ReceiptThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
}

class ActivationReceiptPage extends StatefulWidget {
  final String? txRef;
  final String? method;
  final String? amount;
  final String? currency;
  final DateTime? paidAt;

  const ActivationReceiptPage({
    super.key,
    this.txRef,
    this.method,
    this.amount,
    this.currency,
    this.paidAt,
  });

  @override
  State<ActivationReceiptPage> createState() => _ActivationReceiptPageState();
}

class _ActivationReceiptPageState extends State<ActivationReceiptPage> {
  final _profiles = ProfileService();
  bool _busy = false;
  bool _ensuringThixId = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureRealThixId());
  }

  // ✅ Méthode locale pour assigner un vrai THIX ID
  Future<String> _assignRealThixIdIfMissing({required String uid}) async {
    final profile = await _profiles.fetchPublicProfileByUserId(uid);
    if (profile != null && !_isPendingThixId(profile.thixId)) {
      return profile.thixId;
    }
    final newId = await _profiles.generateThixId(uid: uid);
    // ✅ CORRECTION : utiliser le bon nom de paramètre 'thixId'
    await _profiles.updateProfile(userId: uid, thixId: newId);
    return newId;
  }

  Future<void> _ensureRealThixId() async {
    if (_ensuringThixId) return;
    final auth = context.read<AuthController>();
    final me = auth.currentUser;
    if (me == null) return;
    if (!_isPendingThixId(me.thixId)) return;
    setState(() => _ensuringThixId = true);
    try {
      final real = await _assignRealThixIdIfMissing(uid: me.id);
      await auth.updateCurrentUser(me.copyWith(thixId: real, updatedAt: DateTime.now()));
    } catch (e) {
      debugPrint('ActivationReceipt: ensureRealThixId failed err=$e');
    } finally {
      if (mounted) setState(() => _ensuringThixId = false);
    }
  }

  String _fmtTs(DateTime? dt) {
    final safe = dt ?? DateTime.now();
    final m = safe.month.toString().padLeft(2, '0');
    final d = safe.day.toString().padLeft(2, '0');
    final h = safe.hour.toString().padLeft(2, '0');
    final min = safe.minute.toString().padLeft(2, '0');
    return '${safe.year}-$m-$d  $h:$min';
  }

  Future<Map<String, dynamic>?> _fetchLatestPayment(String uid) async {
    try {
      if ((widget.txRef ?? '').trim().isNotEmpty) {
        return {
          'tx_ref': widget.txRef,
          'method': widget.method,
          'amount': widget.amount,
          'currency': widget.currency,
          'created_at': (widget.paidAt ?? DateTime.now().toUtc()).toIso8601String(),
        };
      }
      final row = await SupabaseConfig.client.from('thix_payments').select('*').eq('user_id', uid).order('created_at', ascending: false).limit(1).maybeSingle();
      return row == null ? null : (row as Map).cast<String, dynamic>();
    } catch (e) {
      debugPrint('ActivationReceipt: fetchLatestPayment failed uid=$uid err=$e');
      return null;
    }
  }

  bool _isPendingThixId(String thixId) {
    final v = thixId.trim().toUpperCase();
    return v.isEmpty || v == 'THIX-PENDING' || v == 'THIX-000000';
  }

  Future<Uint8List> _buildPdf({
    required String thixId,
    required String chatId,
    required String fullName,
    required String country,
    required String txId,
    required String amount,
    required String currency,
    required String dateTime,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('THIX ID Receipt', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('THIX ID Successfully Activated', style: pw.TextStyle(fontSize: 14)),
                pw.Divider(height: 24),
                pw.Text('THIX ID: $thixId', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Chat ID: $chatId'),
                pw.Text('Full Name: $fullName'),
                pw.Text('Country: $country'),
                pw.SizedBox(height: 12),
                pw.Text('Transaction ID: $txId'),
                pw.Text('Amount: $amount $currency'),
                pw.Text('Date & Time: $dateTime'),
                pw.SizedBox(height: 12),
                pw.Text('Status: VERIFIED'),
              ],
            ),
          );
        },
      ),
    );
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final me = auth.currentUser;
    if (me == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A2F5C),
        body: SafeArea(
          child: Center(
            child: Text('Session requise.', style: context.textStyles.titleMedium?.copyWith(color: Colors.white)),
          ),
        ),
      );
    }

    return StreamBuilder<ThixProfile?>(
      stream: _profiles.streamMyProfile(me.id),
      builder: (context, snap) {
        final p = snap.data;
        final thixIdCandidate = me.thixId.trim();
        final thixId = (_isPendingThixId(thixIdCandidate) ? (p?.thixId ?? thixIdCandidate) : thixIdCandidate).trim().toUpperCase();
        final chatId = (me.thixChat.trim().isNotEmpty ? me.thixChat : (p?.thixChat ?? '')).trim();
        final fullName = (me.displayName.trim().isNotEmpty ? me.displayName : (p?.displayName ?? 'Utilisateur')).trim();
        final countryRaw = (me.countryOrOrigin?.trim().isNotEmpty ?? false) ? me.countryOrOrigin : p?.countryOrOrigin;
        final country = (countryRaw ?? '—').trim().isEmpty ? '—' : (countryRaw ?? '—').trim();
        final url = 'https://thix.id/user/$thixId';

        if (_isPendingThixId(thixId) && !_ensuringThixId) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _ensureRealThixId());
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: _fetchLatestPayment(me.id),
          builder: (context, paySnap) {
            final payment = paySnap.data;
            final txId = (payment?['tx_ref'] ?? widget.txRef ?? '—').toString();
            final method = (payment?['method'] ?? widget.method ?? '—').toString();
            final amount = (payment?['amount'] ?? widget.amount ?? '5.00').toString();
            final currency = (payment?['currency'] ?? widget.currency ?? 'USD').toString();
            final createdRaw = payment?['created_at'];
            final paidAt = (createdRaw is DateTime)
                ? createdRaw
                : (createdRaw is String)
                    ? DateTime.tryParse(createdRaw)
                    : null;
            final dateTime = _fmtTs(widget.paidAt ?? paidAt);

            Future<void> downloadPdf() async {
              if (_busy) return;
              setState(() => _busy = true);
              try {
                final bytes = await _buildPdf(
                  thixId: thixId,
                  chatId: chatId,
                  fullName: fullName,
                  country: country,
                  txId: txId,
                  amount: amount,
                  currency: currency,
                  dateTime: dateTime,
                );
                await Printing.sharePdf(bytes: bytes, filename: 'THIX_ID_Receipt_$thixId.pdf');
              } catch (e) {
                debugPrint('ActivationReceipt: pdf failed err=$e');
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            }

            Future<void> shareReceipt() async {
              final text = 'THIX ID Activated\n\nTHIX ID: $thixId\nChat ID: $chatId\nName: $fullName\nCountry: $country\nTX: $txId\nAmount: $amount $currency\nStatus: VERIFIED\n\n$url';
              try {
                await Share.share(text);
              } catch (e) {
                debugPrint('ActivationReceipt: share failed err=$e');
              }
            }

            final showPendingOverlay = _isPendingThixId(thixId);

            return Scaffold(
              backgroundColor: const Color(0xFF0A2F5C),
              body: SafeArea(
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.6,
                          colors: [Color(0xFF0F2B4A), Color(0xFF0A2F5C)],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Opacity(
                        opacity: 0.08,
                        child: Image.asset(
                          'assets/images/gold_fingerprint_abstract_transparent_1775573968885.png',
                          height: 420,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(Icons.fingerprint, size: 420, color: LightModeColors.accent),
                        ),
                      ),
                    ),

                    if (showPendingOverlay)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.35),
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                border: Border.all(color: context.theme.dividerColor),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Attribution du THIX ID…',
                                    style: context.textStyles.bodyMedium?.copyWith(color: context.theme.colorScheme.onSurface),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  final t = auth.currentUser?.accountType;
                                  context.go(t == null ? AppRoutes.home : (t == AccountType.enterprise ? AppRoutes.enterpriseDashboard : AppRoutes.userDashboard));
                                },
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text('Reçu d\'activation', style: context.textStyles.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(AppRadius.xl),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 18)),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF17B26A).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(AppRadius.lg),
                                            ),
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF17B26A), size: 30),
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('THIX ID Successfully Activated', style: context.textStyles.titleLarge?.copyWith(color: const Color(0xFF0A3D62), fontWeight: FontWeight.w900)),
                                                const SizedBox(height: 4),
                                                Text('Status: VERIFIED', style: context.textStyles.bodySmall?.copyWith(color: const Color(0xFF17B26A), fontWeight: FontWeight.w800)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      Container(
                                        padding: const EdgeInsets.all(AppSpacing.md),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0A3D62).withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(AppRadius.lg),
                                          border: Border.all(color: const Color(0xFF0A3D62).withValues(alpha: 0.08)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Text('THIX ID', style: context.textStyles.labelLarge?.copyWith(color: const Color(0xFF0A3D62), fontWeight: FontWeight.w900)),
                                            const SizedBox(height: 6),
                                            SelectableText(
                                              thixId,
                                              style: context.textStyles.headlineSmall?.copyWith(color: const Color(0xFF0A3D62), fontWeight: FontWeight.w900, letterSpacing: 0.6),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      _ReceiptRow(label: 'Chat ID', value: chatId.isEmpty ? '—' : chatId),
                                      _ReceiptRow(label: 'Full Name', value: fullName),
                                      _ReceiptRow(label: 'Country', value: country),
                                      _ReceiptRow(label: 'Date & Time', value: dateTime),
                                      _ReceiptRow(label: 'Transaction ID', value: txId),
                                      _ReceiptRow(label: 'Payment', value: '$amount $currency · $method'),
                                      const SizedBox(height: AppSpacing.lg),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.all(AppSpacing.md),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0A3D62).withValues(alpha: 0.04),
                                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Sender', style: context.textStyles.labelMedium?.copyWith(color: LightModeColors.secondaryText, fontWeight: FontWeight.w800)),
                                                  const SizedBox(height: 6),
                                                  Text('THIX System', style: context.textStyles.bodyLarge?.copyWith(color: const Color(0xFF0A3D62), fontWeight: FontWeight.w800)),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.all(AppSpacing.md),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0A3D62).withValues(alpha: 0.04),
                                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Receiver', style: context.textStyles.labelMedium?.copyWith(color: LightModeColors.secondaryText, fontWeight: FontWeight.w800)),
                                                  const SizedBox(height: 6),
                                                  Text(fullName, style: context.textStyles.bodyLarge?.copyWith(color: const Color(0xFF0A3D62), fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(AppSpacing.sm),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(AppRadius.lg),
                                            border: Border.all(color: const Color(0xFF0A3D62).withValues(alpha: 0.10)),
                                          ),
                                          child: QrImageView(
                                            data: url,
                                            size: 140,
                                            backgroundColor: Colors.white,
                                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0A3D62)),
                                            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0A3D62)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(url, textAlign: TextAlign.center, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _busy ? null : downloadPdf,
                                        icon: Icon(Icons.download_rounded, color: context.theme.colorScheme.onPrimary),
                                        label: Text(_busy ? 'Préparation…' : 'Download', style: TextStyle(color: context.theme.colorScheme.onPrimary)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: context.theme.colorScheme.primary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: shareReceipt,
                                        icon: Icon(Icons.share_rounded, color: context.theme.colorScheme.primary),
                                        label: Text('Share', style: TextStyle(color: context.theme.colorScheme.primary)),
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                                          side: BorderSide(color: context.theme.colorScheme.primary, width: 1.4),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed: thixId.trim().isEmpty
                                        ? null
                                        : () => context.go('${AppRoutes.publicProfile}?thixId=${Uri.encodeComponent(thixId)}'),
                                    icon: Icon(Icons.public_rounded, color: const Color(0xFF0A2F5C)),
                                    label: const Text('View Public Profile', style: TextStyle(color: Color(0xFF0A2F5C), fontWeight: FontWeight.w900)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: LightModeColors.accent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(value, style: context.textStyles.bodyMedium?.copyWith(color: const Color(0xFF0A3D62), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

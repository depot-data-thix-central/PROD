import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';
import 'package:thix_id/core/utils/currency_formatter.dart';
import 'package:thix_id/core/providers/currency_provider.dart';

import '../../providers/agency_dashboard_provider.dart';
import '../../data/models/booking_model.dart';
// Import math pour les constantes
import 'dart:math' as math;

/// ============================================================================
/// AgencyQrScanPage
/// ============================================================================
///
/// Page de scan de QR code pour validation des billets côté agence.
///
/// Features :
/// - Scanner QR temps réel avec mobile_scanner (caméra native)
/// - Overlay visuel avec zone de scan animée
/// - Validation avec feedback haptique (succès/échec)
/// - Vue de résultat détaillée (succès avec infos passager / échec avec raison)
/// - Historique des 10 derniers scans (en mémoire)
/// - Saisie manuelle du code (fallback sans caméra)
/// - Vérification que l'agence est active
/// - Anti-double-scan (cooldown 2s)
/// - Flash/torch toggle
/// - i18n complète (FR/EN/LN)
/// - Accessibilité complète (Semantics)
/// - Design system ThixPolicy
/// - Gestion d'erreurs enrichie
///
/// ============================================================================
class AgencyQrScanPage extends ConsumerStatefulWidget {
  const AgencyQrScanPage({super.key});

  @override
  ConsumerState<AgencyQrScanPage> createState() => _AgencyQrScanPageState();
}

class _AgencyQrScanPageState extends ConsumerState<AgencyQrScanPage>
    with WidgetsBindingObserver {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final List<_ScanRecord> _recentScans = [];
  _ScanResult? _currentResult;
  bool _isProcessing = false;
  DateTime? _lastScanTime;
  String? _lastScannedCode;

  // Cooldown anti-double-scan (2 secondes)
  static const Duration _scanCooldown = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verifyAgencyAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Arrêter la caméra quand l'app est en background
    if (state == AppLifecycleState.paused) {
      _cameraController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _cameraController.start();
    }
  }

  void _verifyAgencyAccess() {
    final agencyState = ref.read(agencyDashboardProvider);
    if (!agencyState.hasAgency || !agencyState.isAgencyActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAgencyRequiredDialog();
      });
    }
  }

  void _showAgencyRequiredDialog() {
    final l10n = context.l10n;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        ),
        icon: Icon(
          Icons.business_rounded,
          color: ThixPolicy.warning,
          size: 36,
        ),
        title: Text(l10n.qrScanAgencyRequiredTitle),
        content: Text(l10n.qrScanAgencyRequiredMessage),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/agency/dashboard');
            },
            child: Text(l10n.qrScanGoToAgency),
          ),
        ],
      ),
    );
  }

  Future<void> _handleScanResult(String qrCode) async {
    if (_isProcessing) return;

    // Anti-double-scan : même code dans les 2 dernières secondes
    final now = DateTime.now();
    if (_lastScannedCode == qrCode &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!) < _scanCooldown) {
      return;
    }

    _lastScannedCode = qrCode;
    _lastScanTime = now;

    setState(() => _isProcessing = true);

    // Arrêter la caméra pendant le traitement
    await _cameraController.stop();

    try {
      final booking = await ref
          .read(agencyDashboardProvider.notifier)
          .validateQr(qrCode);

      if (!mounted) return;

      if (booking != null) {
        await HapticFeedback.heavyImpact();
        final record = _ScanRecord(
          booking: booking,
          timestamp: DateTime.now(),
          success: true,
        );
        setState(() {
          _recentScans.insert(0, record);
          if (_recentScans.length > 10) _recentScans.removeLast();
          _currentResult = _ScanResult.success(booking);
          _isProcessing = false;
        });
      } else {
        await HapticFeedback.mediumImpact();
        final record = _ScanRecord(
          timestamp: DateTime.now(),
          success: false,
          qrCode: qrCode,
        );
        setState(() {
          _recentScans.insert(0, record);
          if (_recentScans.length > 10) _recentScans.removeLast();
          _currentResult = _ScanResult.failure(
            reason: _ScanFailureReason.invalid,
            qrCode: qrCode,
          );
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      await HapticFeedback.mediumImpact();

      final reason = _parseError(e.toString());
      final record = _ScanRecord(
        timestamp: DateTime.now(),
        success: false,
        qrCode: qrCode,
        error: e.toString(),
      );
      setState(() {
        _recentScans.insert(0, record);
        if (_recentScans.length > 10) _recentScans.removeLast();
        _currentResult = _ScanResult.failure(reason: reason, qrCode: qrCode);
        _isProcessing = false;
      });
    }
  }

  _ScanFailureReason _parseError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('already') || lower.contains('utilisé')) {
      return _ScanFailureReason.alreadyUsed;
    }
    if (lower.contains('network') || lower.contains('timeout')) {
      return _ScanFailureReason.network;
    }
    if (lower.contains('expired')) {
      return _ScanFailureReason.expired;
    }
    if (lower.contains('cancelled')) {
      return _ScanFailureReason.cancelled;
    }
    return _ScanFailureReason.invalid;
  }

  Future<void> _resumeScan() async {
    setState(() {
      _currentResult = null;
      _isProcessing = false;
    });
    try {
      await _cameraController.start();
    } catch (_) {}
  }

  void _toggleTorch() async {
    await HapticFeedback.selectionClick();
    await _cameraController.toggleTorch();
    setState(() {}); // Rebuild pour afficher l'état du torch
  }

  void _openManualEntry() async {
    await HapticFeedback.selectionClick();
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ManualEntrySheet(),
    );
    if (code != null && code.isNotEmpty) {
      _handleScanResult(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final domainColor = ThixPolicy.domainReservation;
    final agencyState = ref.watch(agencyDashboardProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: _buildAppBar(domainColor, agencyState),
      body: SafeArea(
        child: _currentResult != null
            ? _ResultView(
                result: _currentResult!,
                onResume: _resumeScan,
                domainColor: domainColor,
              )
            : _ScannerBody(
                controller: _cameraController,
                isProcessing: _isProcessing,
                recentScans: _recentScans,
                onScan: _handleScanResult,
                onToggleTorch: _toggleTorch,
                onManualEntry: _openManualEntry,
                domainColor: domainColor,
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    Color domainColor,
    AgencyDashboardState agencyState,
  ) {
    final l10n = context.l10n;
    final agencyName = agencyState.myAgency?.name;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      toolbarHeight: 64,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
        onPressed: () => context.pop(),
        tooltip: l10n.commonBack,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.qrScanTitle,
            style: ThixPolicy.titleStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              fontSize: 15,
              color: ThixPolicy.textMain,
            ),
          ),
          if (agencyName != null)
            Row(
              children: [
                Icon(
                  Icons.storefront_rounded,
                  size: 11,
                  color: domainColor,
                ),
                SizedBox(width: ThixPolicy.s4),
                Flexible(
                  child: Text(
                    agencyName,
                    style: ThixPolicy.microStyle.copyWith(
                      color: ThixPolicy.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
      actions: [
        if (_currentResult == null && !_isProcessing) ...[
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: ThixPolicy.textMain),
            tooltip: l10n.qrScanManualEntry,
            onPressed: _openManualEntry,
          ),
        ],
        SizedBox(width: ThixPolicy.s4),
      ],
    );
  }
}

/// ============================================================================
/// _ScanResult — Résultat d'un scan (succès ou échec)
/// ============================================================================
class _ScanResult {
  final bool success;
  final BookingModel? booking;
  final _ScanFailureReason? reason;
  final String? qrCode;

  const _ScanResult._({
    required this.success,
    this.booking,
    this.reason,
    this.qrCode,
  });

  factory _ScanResult.success(BookingModel booking) => _ScanResult._(
        success: true,
        booking: booking,
      );

  factory _ScanResult.failure({
    required _ScanFailureReason reason,
    String? qrCode,
  }) =>
      _ScanResult._(
        success: false,
        reason: reason,
        qrCode: qrCode,
      );
}

enum _ScanFailureReason {
  invalid,
  alreadyUsed,
  expired,
  cancelled,
  network,
}

/// ============================================================================
/// _ScanRecord — Enregistrement d'un scan dans l'historique
/// ============================================================================
class _ScanRecord {
  final BookingModel? booking;
  final DateTime timestamp;
  final bool success;
  final String? qrCode;
  final String? error;

  const _ScanRecord({
    this.booking,
    required this.timestamp,
    required this.success,
    this.qrCode,
    this.error,
  });
}

/// ============================================================================
/// _ScannerBody — Corps principal avec caméra + historique
/// ============================================================================
class _ScannerBody extends StatelessWidget {
  final MobileScannerController controller;
  final bool isProcessing;
  final List<_ScanRecord> recentScans;
  final void Function(String) onScan;
  final VoidCallback onToggleTorch;
  final VoidCallback onManualEntry;
  final Color domainColor;

  const _ScannerBody({
    required this.controller,
    required this.isProcessing,
    required this.recentScans,
    required this.onScan,
    required this.onToggleTorch,
    required this.onManualEntry,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        // Scanner avec overlay
        Expanded(
          flex: 3,
          child: _ScannerView(
            controller: controller,
            isProcessing: isProcessing,
            onScan: onScan,
            onToggleTorch: onToggleTorch,
            domainColor: domainColor,
          ),
        ),

        // Instructions + actions
        _InstructionsPanel(
          domainColor: domainColor,
        ),

        // Historique des scans récents
        if (recentScans.isNotEmpty)
          Expanded(
            flex: 2,
            child: _RecentScansList(
              scans: recentScans,
              domainColor: domainColor,
            ),
          ),
      ],
    );
  }
}

/// ============================================================================
/// _ScannerView — Vue caméra avec overlay de scan
/// ============================================================================
class _ScannerView extends StatelessWidget {
  final MobileScannerController controller;
  final bool isProcessing;
  final void Function(String) onScan;
  final VoidCallback onToggleTorch;
  final Color domainColor;

  const _ScannerView({
    required this.controller,
    required this.isProcessing,
    required this.onScan,
    required this.onToggleTorch,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Stack(
      children: [
        // Caméra
        MobileScanner(
          controller: controller,
          onDetect: (capture) {
            if (isProcessing) return;
            final barcodes = capture.barcodes;
            if (barcodes.isEmpty) return;
            final code = barcodes.first.rawValue;
            if (code != null && code.isNotEmpty) {
              onScan(code);
            }
          },
          errorBuilder: (ctx, error, child) => _CameraError(
            error: error,
            domainColor: domainColor,
          ),
        ),

        // Overlay sombre avec trou
        _ScannerOverlay(domainColor: domainColor),

        // Boutons de contrôle (en haut)
        Positioned(
          top: ThixPolicy.s16,
          right: ThixPolicy.s16,
          child: Column(
            children: [
              // Torch
              ValueListenableBuilder(
                valueListenable: controller.torchState,
                builder: (_, state, __) {
                  final isOn = state == TorchState.on;
                  return _ControlButton(
                    icon: isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    label: isOn ? l10n.qrScanTorchOn : l10n.qrScanTorchOff,
                    isActive: isOn,
                    onTap: onToggleTorch,
                  );
                },
              ),
            ],
          ),
        ),

        // Processing overlay
        if (isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                    SizedBox(height: ThixPolicy.s12),
                    Text(
                      l10n.qrScanValidating,
                      style: ThixPolicy.titleStyle.copyWith(
                        color: Colors.white,
                        fontWeight: ThixPolicy.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
          child: Container(
            padding: EdgeInsets.all(ThixPolicy.s10),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _ScannerOverlay — Overlay avec zone de scan carrée
/// ============================================================================
class _ScannerOverlay extends StatelessWidget {
  final Color domainColor;

  const _ScannerOverlay({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScannerOverlayPainter(
        borderColor: domainColor,
        borderRadius: 20,
        borderLength: 30,
        borderWidth: 5,
        cutOutSize: 260,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  _ScannerOverlayPainter({
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
    required this.cutOutSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final halfSize = cutOutSize / 2;

    // Fond sombre semi-transparent
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutOutRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: cutOutSize,
        height: cutOutSize,
      ),
      Radius.circular(borderRadius),
    );
    bgPath.addRRect(cutOutRect);
    bgPath.fillType = PathFillType.evenOdd;

    canvas.drawPath(bgPath, bgPaint);

    // Coins de la zone de scan
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final left = centerX - halfSize;
    final right = centerX + halfSize;
    final top = centerY - halfSize;
    final bottom = centerY + halfSize;

    // Coin haut-gauche
    canvas.drawLine(Offset(left, top + borderLength), Offset(left, top + borderRadius), borderPaint);
    canvas.drawArc(Rect.fromLTWH(left, top, borderRadius * 2, borderRadius * 2), math.pi, math.pi / 2, false, borderPaint);
    canvas.drawLine(Offset(left + borderRadius, top), Offset(left + borderLength, top), borderPaint);

    // Coin haut-droit
    canvas.drawLine(Offset(right - borderLength, top), Offset(right - borderRadius, top), borderPaint);
    canvas.drawArc(Rect.fromLTWH(right - borderRadius * 2, top, borderRadius * 2, borderRadius * 2), 3 * math.pi / 2, math.pi / 2, false, borderPaint);
    canvas.drawLine(Offset(right, top + borderRadius), Offset(right, top + borderLength), borderPaint);

    // Coin bas-gauche
    canvas.drawLine(Offset(left, bottom - borderLength), Offset(left, bottom - borderRadius), borderPaint);
    canvas.drawArc(Rect.fromLTWH(left, bottom - borderRadius * 2, borderRadius * 2, borderRadius * 2), math.pi / 2, math.pi / 2, false, borderPaint);
    canvas.drawLine(Offset(left + borderRadius, bottom), Offset(left + borderLength, bottom), borderPaint);

    // Coin bas-droit
    canvas.drawLine(Offset(right - borderLength, bottom), Offset(right - borderRadius, bottom), borderPaint);
    canvas.drawArc(Rect.fromLTWH(right - borderRadius * 2, bottom - borderRadius * 2, borderRadius * 2, borderRadius * 2), 0, math.pi / 2, false, borderPaint);
    canvas.drawLine(Offset(right, bottom - borderRadius), Offset(right, bottom - borderLength), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// ============================================================================
/// _InstructionsPanel — Panel d'instructions sous le scanner
/// ============================================================================
class _InstructionsPanel extends StatelessWidget {
  final Color domainColor;

  const _InstructionsPanel({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: ThixPolicy.border),
          bottom: BorderSide(color: ThixPolicy.border),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(ThixPolicy.s8),
            decoration: BoxDecoration(
              color: domainColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              size: 20,
              color: domainColor,
            ),
          ),
          SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.qrScanInstructionTitle,
                  style: ThixPolicy.bodyStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    color: ThixPolicy.textMain,
                  ),
                ),
                SizedBox(height: ThixPolicy.s2),
                Text(
                  l10n.qrScanInstructionSubtitle,
                  style: ThixPolicy.microStyle.copyWith(
                    color: ThixPolicy.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _RecentScansList — Historique des scans récents
/// ============================================================================
class _RecentScansList extends StatelessWidget {
  final List<_ScanRecord> scans;
  final Color domainColor;

  const _RecentScansList({
    required this.scans,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      color: ThixPolicy.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              ThixPolicy.s16,
              ThixPolicy.s12,
              ThixPolicy.s16,
              ThixPolicy.s8,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: ThixPolicy.textSecondary,
                ),
                SizedBox(width: ThixPolicy.s6),
                Text(
                  l10n.qrScanRecentTitle,
                  style: ThixPolicy.labelStyle.copyWith(
                    color: ThixPolicy.textSecondary,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${scans.length}',
                  style: ThixPolicy.labelStyle.copyWith(
                    color: domainColor,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
              physics: const BouncingScrollPhysics(),
              itemCount: scans.length,
              separatorBuilder: (_, __) => SizedBox(height: ThixPolicy.s6),
              itemBuilder: (_, i) => _ScanHistoryTile(
                record: scans[i],
                domainColor: domainColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanHistoryTile extends StatelessWidget {
  final _ScanRecord record;
  final Color domainColor;

  const _ScanHistoryTile({
    required this.record,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final time = DateFormat('HH:mm:ss').format(record.timestamp);

    if (record.success && record.booking != null) {
      final b = record.booking!;
      return Container(
        padding: EdgeInsets.all(ThixPolicy.s10),
        decoration: BoxDecoration(
          color: ThixPolicy.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          border: Border.all(
            color: ThixPolicy.success.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(ThixPolicy.s6),
              decoration: BoxDecoration(
                color: ThixPolicy.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
            SizedBox(width: ThixPolicy.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.passengerName ?? l10n.qrScanUnknownPassenger,
                    style: ThixPolicy.bodySmallStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      color: ThixPolicy.textMain,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${b.seats.join(", ")} • $time',
                    style: ThixPolicy.microStyle.copyWith(
                      color: ThixPolicy.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Échec
    return Container(
      padding: EdgeInsets.all(ThixPolicy.s10),
      decoration: BoxDecoration(
        color: ThixPolicy.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(
          color: ThixPolicy.danger.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(ThixPolicy.s6),
            decoration: BoxDecoration(
              color: ThixPolicy.danger,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
          SizedBox(width: ThixPolicy.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.qrScanFailed,
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    color: ThixPolicy.danger,
                  ),
                ),
                Text(
                  '${record.qrCode?.substring(0, (record.qrCode?.length ?? 0).clamp(0, 12)) ?? "?"}... • $time',
                  style: ThixPolicy.microStyle.copyWith(
                    color: ThixPolicy.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _ResultView — Vue de résultat (succès ou échec)
/// ============================================================================
class _ResultView extends StatelessWidget {
  final _ScanResult result;
  final VoidCallback onResume;
  final Color domainColor;

  const _ResultView({
    required this.result,
    required this.onResume,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    if (result.success) {
      return _SuccessResultView(
        booking: result.booking!,
        onResume: onResume,
        domainColor: domainColor,
      );
    }
    return _FailureResultView(
      reason: result.reason ?? _ScanFailureReason.invalid,
      qrCode: result.qrCode,
      onResume: onResume,
      domainColor: domainColor,
    );
  }
}

class _SuccessResultView extends ConsumerWidget {
  final BookingModel booking;
  final VoidCallback onResume;
  final Color domainColor;

  const _SuccessResultView({
    required this.booking,
    required this.onResume,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currencyState = ref.watch(currencyProvider);
    final trip = booking.trip;

    final displayPrice = currencyState.convert(
      booking.totalPriceFcfa,
      fromCurrency: 'CDF',
    );
    final formattedPrice = CurrencyFormatter.format(
      displayPrice,
      currency: currencyState.currency.code,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(ThixPolicy.s20),
      child: Column(
        children: [
          SizedBox(height: ThixPolicy.s20),

          // Success icon
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: ThixPolicy.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: ThixPolicy.success,
            ),
          ),
          SizedBox(height: ThixPolicy.s20),

          Text(
            l10n.qrScanSuccessTitle,
            style: ThixPolicy.h2Style.copyWith(
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.success,
            ),
          ),
          SizedBox(height: ThixPolicy.s4),
          Text(
            l10n.qrScanSuccessSubtitle,
            style: ThixPolicy.bodySmallStyle.copyWith(
              color: ThixPolicy.textSecondary,
            ),
          ),
          SizedBox(height: ThixPolicy.s24),

          // Carte passager
          Container(
            padding: EdgeInsets.all(ThixPolicy.s18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(color: ThixPolicy.border),
              boxShadow: ThixPolicy.shadowSoft(),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: domainColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: domainColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: ThixPolicy.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.passengerName ?? l10n.qrScanUnknownPassenger,
                            style: ThixPolicy.titleStyle.copyWith(
                              fontWeight: ThixPolicy.bold,
                            ),
                          ),
                          Text(
                            'ID: ${booking.id.substring(0, 8).toUpperCase()}',
                            style: ThixPolicy.microStyle.copyWith(
                              color: ThixPolicy.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ThixPolicy.s16),
                Divider(height: 1, color: ThixPolicy.border),
                SizedBox(height: ThixPolicy.s16),

                _InfoRow(
                  icon: Icons.event_seat_rounded,
                  label: l10n.qrScanSeats,
                  value: booking.seats.join(', '),
                  domainColor: domainColor,
                ),
                SizedBox(height: ThixPolicy.s10),
                _InfoRow(
                  icon: Icons.payments_rounded,
                  label: l10n.qrScanAmount,
                  value: formattedPrice,
                  domainColor: domainColor,
                  valueColor: ThixPolicy.success,
                ),
                if (trip != null) ...[
                  SizedBox(height: ThixPolicy.s10),
                  _InfoRow(
                    icon: Icons.route_rounded,
                    label: l10n.qrScanRoute,
                    value: '${trip.departureCity} → ${trip.arrivalCity}',
                    domainColor: domainColor,
                  ),
                  SizedBox(height: ThixPolicy.s10),
                  _InfoRow(
                    icon: Icons.access_time_rounded,
                    label: l10n.qrScanDeparture,
                    value: DateFormat('HH:mm • d MMM').format(trip.departureTime),
                    domainColor: domainColor,
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: ThixPolicy.s24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: Text(
                l10n.qrScanNext,
                style: ThixPolicy.titleStyle.copyWith(
                  color: Colors.white,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: domainColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureResultView extends StatelessWidget {
  final _ScanFailureReason reason;
  final String? qrCode;
  final VoidCallback onResume;
  final Color domainColor;

  const _FailureResultView({
    required this.reason,
    required this.qrCode,
    required this.onResume,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = _getFailureInfo(reason, l10n);

    return SingleChildScrollView(
      padding: EdgeInsets.all(ThixPolicy.s20),
      child: Column(
        children: [
          SizedBox(height: ThixPolicy.s20),

          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: info.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(info.icon, size: 64, color: info.color),
          ),
          SizedBox(height: ThixPolicy.s20),

          Text(
            info.title,
            style: ThixPolicy.h2Style.copyWith(
              fontWeight: ThixPolicy.bold,
              color: info.color,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ThixPolicy.s8),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              info.message,
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: ThixPolicy.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          if (qrCode != null) ...[
            SizedBox(height: ThixPolicy.s20),
            Container(
              padding: EdgeInsets.all(ThixPolicy.s12),
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_rounded,
                    size: 14,
                    color: ThixPolicy.textSecondary,
                  ),
                  SizedBox(width: ThixPolicy.s8),
                  Text(
                    qrCode!,
                    style: ThixPolicy.bodySmallStyle.copyWith(
                      fontFamily: 'monospace',
                      color: ThixPolicy.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: ThixPolicy.s32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                l10n.qrScanRetry,
                style: ThixPolicy.titleStyle.copyWith(
                  color: Colors.white,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: domainColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _FailureInfo _getFailureInfo(_ScanFailureReason reason, dynamic l10n) {
    switch (reason) {
      case _ScanFailureReason.alreadyUsed:
        return _FailureInfo(
          icon: Icons.hourglass_top_rounded,
          color: ThixPolicy.warning,
          title: l10n.qrScanFailAlreadyUsedTitle,
          message: l10n.qrScanFailAlreadyUsedMessage,
        );
      case _ScanFailureReason.expired:
        return _FailureInfo(
          icon: Icons.timer_off_rounded,
          color: ThixPolicy.warning,
          title: l10n.qrScanFailExpiredTitle,
          message: l10n.qrScanFailExpiredMessage,
        );
      case _ScanFailureReason.cancelled:
        return _FailureInfo(
          icon: Icons.cancel_rounded,
          color: ThixPolicy.danger,
          title: l10n.qrScanFailCancelledTitle,
          message: l10n.qrScanFailCancelledMessage,
        );
      case _ScanFailureReason.network:
        return _FailureInfo(
          icon: Icons.cloud_off_rounded,
          color: ThixPolicy.danger,
          title: l10n.qrScanFailNetworkTitle,
          message: l10n.qrScanFailNetworkMessage,
        );
      case _ScanFailureReason.invalid:
        return _FailureInfo(
          icon: Icons.error_outline_rounded,
          color: ThixPolicy.danger,
          title: l10n.qrScanFailInvalidTitle,
          message: l10n.qrScanFailInvalidMessage,
        );
    }
  }
}

class _FailureInfo {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _FailureInfo({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color domainColor;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.domainColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: domainColor),
        SizedBox(width: ThixPolicy.s8),
        Expanded(
          child: Text(
            label,
            style: ThixPolicy.bodySmallStyle.copyWith(
              color: ThixPolicy.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: ThixPolicy.bodySmallStyle.copyWith(
            fontWeight: ThixPolicy.bold,
            color: valueColor ?? ThixPolicy.textMain,
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// _ManualEntrySheet — Saisie manuelle du code QR (fallback)
/// ============================================================================
class _ManualEntrySheet extends StatefulWidget {
  const _ManualEntrySheet();

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = context.l10n.qrScanManualEmpty);
      return;
    }
    if (code.length < 6) {
      setState(() => _error = context.l10n.qrScanManualTooShort);
      return;
    }
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final domainColor = ThixPolicy.domainReservation;

    return Container(
      padding: EdgeInsets.fromLTRB(
        ThixPolicy.s20,
        ThixPolicy.s16,
        ThixPolicy.s20,
        MediaQuery.of(context).viewInsets.bottom + ThixPolicy.s20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ThixPolicy.r2Xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ThixPolicy.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          SizedBox(height: ThixPolicy.s20),

          Row(
            children: [
              Container(
                padding: EdgeInsets.all(ThixPolicy.s8),
                decoration: BoxDecoration(
                  color: domainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: domainColor,
                  size: 20,
                ),
              ),
              SizedBox(width: ThixPolicy.s12),
              Text(
                l10n.qrScanManualTitle,
                style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: ThixPolicy.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.qrScanManualSubtitle,
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: ThixPolicy.textSecondary,
              ),
            ),
          ),
          SizedBox(height: ThixPolicy.s20),

          TextField(
            controller: _controller,
            focusNode: _focusNode,
            textCapitalization: TextCapitalization.characters,
            style: ThixPolicy.titleStyle.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 2,
              fontWeight: ThixPolicy.bold,
            ),
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              hintText: 'XXXX-XXXX-XXXX',
              errorText: _error,
              filled: true,
              fillColor: ThixPolicy.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                borderSide: BorderSide(color: ThixPolicy.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                borderSide: BorderSide(color: domainColor, width: 1.5),
              ),
              contentPadding: EdgeInsets.all(ThixPolicy.s16),
            ),
          ),
          SizedBox(height: ThixPolicy.s20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: domainColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                ),
              ),
              child: Text(
                l10n.qrScanManualValidate,
                style: ThixPolicy.titleStyle.copyWith(
                  color: Colors.white,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _CameraError — Erreur de caméra
/// ============================================================================
class _CameraError extends StatelessWidget {
  final MobileScannerException error;
  final Color domainColor;

  const _CameraError({required this.error, required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(ThixPolicy.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.no_photography_rounded,
                size: 48,
                color: Colors.white70,
              ),
              SizedBox(height: ThixPolicy.s12),
              Text(
                l10n.qrScanCameraError,
                style: ThixPolicy.titleStyle.copyWith(
                  color: Colors.white,
                  fontWeight: ThixPolicy.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: ThixPolicy.s8),
              Text(
                error.errorDetails?.message ?? '',
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

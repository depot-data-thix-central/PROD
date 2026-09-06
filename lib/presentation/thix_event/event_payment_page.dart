// lib/presentation/thix_event/event_payment_page.dart
//
// EventPaymentPage — Production Enterprise (Sécurité + i18n + A11y)
//
// Features :
// - Validation UUID stricte sur bookingId
// - Validation phone regex international
// - Sanitization XSS sur tous les inputs
// - Throttling anti-double-pay (1s)
// - Timeout stream 5 minutes
// - Intégration AppLocalizations (8 langues)
// - Semantics complet pour a11y
// - Logging structuré (_PaymentLogger)
// - Provider Riverpod corrigé (autoDispose)
// - Utilisation EventTheme + ThixPolicy
// - Mounted checks systématiques
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/thix_design_policy.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/event_payment_provider.dart';
import '../../services/event_payment_service.dart';

// ============================================================================
// EVENT THEME (adapté depuis ThixPolicy)
// ============================================================================
class EventTheme {
  static const Color bg = ThixPolicy.inkDeep;
  static const Color surface = Color(0xFF101B30);
  static const Color surfaceAlt = Color(0xFF14213A);
  static const Color border = Color(0xFF243451);
  static const Color primary = ThixPolicy.domainEvents;
  static const Color accent = ThixPolicy.gold;
  static const Color textMain = ThixPolicy.textOnDark;
  static const Color textSecondary = Color(0xFFA8B6CC);
  static const Color textMuted = Color(0xFF64748B);
}

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kPayThrottle = Duration(seconds: 1);
const Duration _kStreamTimeout = Duration(minutes: 5);
const Duration _kPaymentTimeout = Duration(seconds: 30);

// ============================================================================
// LOGGING
// ============================================================================
class _PaymentLogger {
  static const _tag = 'EventPayment';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);

  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// VALIDATORS & SANITIZERS
// ============================================================================
class _Validators {
  _Validators._();
  
  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  
  static final _phoneRegex = RegExp(r'^\+?[1-9]\d{6,14}$');
  
  static bool isValidUuid(String? id) =>
      id != null && id.length == 36 && _uuidRegex.hasMatch(id);
  
  static bool isValidPhone(String? phone) =>
      phone != null && _phoneRegex.hasMatch(phone.trim());
}

class _Sanitizer {
  _Sanitizer._();
  static String text(String? input, {int maxLength = 20}) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[^\d+\s-]'), '') // Only digits, +, spaces, dashes
        .trim();
    if (s.length > maxLength) s = s.substring(0, maxLength);
    return s;
  }
}

// ============================================================================
// PROVIDER (corrigé - autoDispose + factory)
// ============================================================================
final eventPaymentProvider = Provider.autoDispose<EventPaymentProvider>((ref) {
  return EventPaymentProvider(EventPaymentService(Supabase.instance.client));
});

// ============================================================================
// PAYMENT METHODS (avec i18n)
// ============================================================================
class _PaymentMethod {
  final String id;
  final String nameKey;
  final String brand;
  final Color color;
  final IconData icon;
  final bool requiresPhone;

  const _PaymentMethod({
    required this.id,
    required this.nameKey,
    required this.brand,
    required this.color,
    required this.icon,
    required this.requiresPhone,
  });
}

const List<_PaymentMethod> _kMethods = [
  _PaymentMethod(
    id: 'mpesa',
    nameKey: 'payment_mpesa',
    brand: 'Vodacom',
    color: Color(0xFF00A651),
    icon: Icons.phone_android_rounded,
    requiresPhone: true,
  ),
  _PaymentMethod(
    id: 'airtel',
    nameKey: 'payment_airtel',
    brand: 'Airtel',
    color: Color(0xFFFF0000),
    icon: Icons.phone_android_rounded,
    requiresPhone: true,
  ),
  _PaymentMethod(
    id: 'orange',
    nameKey: 'payment_orange',
    brand: 'Orange',
    color: Color(0xFFFF6600),
    icon: Icons.phone_android_rounded,
    requiresPhone: true,
  ),
  _PaymentMethod(
    id: 'visa_master',
    nameKey: 'payment_card',
    brand: 'Card',
    color: Color(0xFF1A1F71),
    icon: Icons.credit_card_rounded,
    requiresPhone: false,
  ),
];

// ============================================================================
// PAGE
// ============================================================================
class EventPaymentPage extends ConsumerStatefulWidget {
  final String bookingId;
  final double amount;
  final String currency;

  const EventPaymentPage({
    super.key,
    required this.bookingId,
    required this.amount,
    required this.currency,
  });

  @override
  ConsumerState<EventPaymentPage> createState() => _EventPaymentPageState();
}

class _EventPaymentPageState extends ConsumerState<EventPaymentPage> {
  String _selectedId = 'airtel';
  final _phoneCtrl = TextEditingController();
  StreamSubscription? _sub;
  Timer? _streamTimer;
  bool _processing = false;
  DateTime? _lastPay;

  _PaymentMethod get _selectedMethod =>
      _kMethods.firstWhere((m) => m.id == _selectedId);

  @override
  void initState() {
    super.initState();
    
    // Validation UUID
    if (!_Validators.isValidUuid(widget.bookingId)) {
      _PaymentLogger.error('Invalid bookingId', {'id': widget.bookingId});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          _showError(l10n.t('error_validation'));
          context.pop();
        }
      });
      return;
    }
    
    _PaymentLogger.info('EventPaymentPage init', {
      'bookingId': widget.bookingId,
      'amount': widget.amount,
      'currency': widget.currency,
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _sub?.cancel();
    _streamTimer?.cancel();
    _PaymentLogger.info('EventPaymentPage disposed');
    super.dispose();
  }

  bool _canPay() {
    final now = DateTime.now();
    if (_lastPay != null && now.difference(_lastPay!) < _kPayThrottle) {
      _PaymentLogger.warn('Pay throttled');
      return false;
    }
    _lastPay = now;
    return true;
  }

  Future<void> _pay() async {
    if (!_canPay()) return;
    
    final l10n = AppLocalizations.of(context);
    
    // Validation phone si requise
    if (_selectedMethod.requiresPhone) {
      final phone = _Sanitizer.text(_phoneCtrl.text);
      if (!_Validators.isValidPhone(phone)) {
        _showError(l10n.t('payment_invalid_phone'));
        return;
      }
    }
    
    HapticFeedback.mediumImpact();
    setState(() => _processing = true);
    _PaymentLogger.info('Payment started', {
      'method': _selectedId,
      'amount': widget.amount,
    });
    
    try {
      final svc = ref.read(eventPaymentProvider);
      final phone = _selectedMethod.requiresPhone
          ? _Sanitizer.text(_phoneCtrl.text)
          : null;
      
      final ok = await svc
          .makePayment(
            bookingId: widget.bookingId,
            amount: widget.amount,
            currency: widget.currency,
            paymentMethod: _selectedId,
            phoneNumber: phone,
          )
          .timeout(_kPaymentTimeout);
      
      if (!mounted) return;
      
      setState(() => _processing = false);
      
      if (ok) {
        _PaymentLogger.info('Payment initiated, waiting confirmation');
        _showWaitingDialog(l10n);
      } else {
        _PaymentLogger.warn('Payment initiation failed');
        _showError(l10n.t('payment_failed'));
      }
    } on TimeoutException {
      _PaymentLogger.error('Payment timeout');
      if (mounted) {
        setState(() => _processing = false);
        _showError(l10n.t('error_timeout'));
      }
    } catch (e, stack) {
      _PaymentLogger.error('Payment error', {
        'error': '$e',
        'stack': stack.toString(),
      });
      if (mounted) {
        setState(() => _processing = false);
        _showError(l10n.t('payment_failed'));
      }
    }
  }

  void _showWaitingDialog(AppLocalizations l10n) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => Semantics(
        namesRoute: true,
        scopesRoute: true,
        child: Dialog(
          backgroundColor: EventTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThixPolicy.r2Xl),
            side: BorderSide(color: EventTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(ThixPolicy.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: EventTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pending_actions_rounded,
                    color: EventTheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: ThixPolicy.s16),
                Text(
                  l10n.t('payment_processing_title'),
                  style: ThixPolicy.h3Style.copyWith(
                    color: EventTheme.textMain,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: ThixPolicy.s8),
                Text(
                  l10n.t('payment_processing_msg'),
                  textAlign: TextAlign.center,
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    color: EventTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: ThixPolicy.s20),
                CircularProgressIndicator(color: EventTheme.primary),
                const SizedBox(height: ThixPolicy.s16),
                Text(
                  l10n.t('payment_validate_on_phone'),
                  style: ThixPolicy.captionStyle.copyWith(
                    color: EventTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    _startStreamListening();
  }

  void _startStreamListening() {
    _sub?.cancel();
    _streamTimer?.cancel();
    
    _sub = Supabase.instance.client
        .from('event_bookings')
        .stream(primaryKey: ['id'])
        .eq('id', widget.bookingId)
        .listen(
      (data) {
        if (!mounted || data.isEmpty) return;
        
        final status = data.first['payment_status']?.toString();
        
        if (status == 'paid') {
          _PaymentLogger.info('Payment confirmed');
          _onPaymentSuccess();
        } else if (status == 'failed' || status == 'cancelled') {
          _PaymentLogger.warn('Payment failed/cancelled', {'status': status});
          _onPaymentFailure(status ?? 'failed');
        }
      },
      onError: (error) {
        _PaymentLogger.error('Stream error', {'error': '$error'});
        _onPaymentFailure('stream_error');
      },
    );
    
    // Timeout de 5 minutes
    _streamTimer = Timer(_kStreamTimeout, () {
      if (mounted) {
        _PaymentLogger.warn('Stream timeout');
        _onPaymentFailure('timeout');
      }
    });
  }

  void _onPaymentSuccess() {
    _sub?.cancel();
    _streamTimer?.cancel();
    
    if (!mounted) return;
    
    Navigator.of(context, rootNavigator: true).pop();
    context.pushReplacement('/thix-event/ticket/${widget.bookingId}');
  }

  void _onPaymentFailure(String reason) {
    _sub?.cancel();
    _streamTimer?.cancel();
    
    if (!mounted) return;
    
    Navigator.of(context, rootNavigator: true).pop();
    
    final l10n = AppLocalizations.of(context);
    String message;
    
    switch (reason) {
      case 'timeout':
        message = l10n.t('payment_timeout');
        break;
      case 'failed':
      case 'cancelled':
        message = l10n.t('payment_rejected');
        break;
      case 'stream_error':
        message = l10n.t('error_network');
        break;
      default:
        message = l10n.t('payment_failed');
    }
    
    _showError(message);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: EventTheme.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: EventTheme.bg.withOpacity(0.85),
              elevation: 0,
              leading: Semantics(
                button: true,
                label: l10n.t('common_back'),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                      border: Border.all(color: EventTheme.border),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  onPressed: () => context.pop(),
                ),
              ),
              title: Text(
                l10n.t('payment_title'),
                style: ThixPolicy.titleStyle.copyWith(
                  color: EventTheme.textMain,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(ThixPolicy.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── MONTANT ──
            _buildAmountCard(l10n),
            const SizedBox(height: ThixPolicy.s24),
            
            // ── MÉTHODES DE PAIEMENT ──
            Text(
              l10n.t('payment_choose_method'),
              style: ThixPolicy.titleStyle.copyWith(
                color: EventTheme.textMain,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: ThixPolicy.s12),
            ..._kMethods.map((m) => _buildMethodCard(l10n, m)),
            
            // ── CHAMP TÉLÉPHONE ──
            if (_selectedMethod.requiresPhone) ...[
              const SizedBox(height: ThixPolicy.s16),
              _buildPhoneField(l10n),
            ],
            
            // ── INFO SÉCURITÉ ──
            const SizedBox(height: ThixPolicy.s20),
            _buildSecurityInfo(l10n),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(l10n),
    );
  }

  Widget _buildAmountCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s20),
      decoration: BoxDecoration(
        color: EventTheme.surface,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: EventTheme.border),
      ),
      child: Column(
        children: [
          Text(
            l10n.t('payment_amount_due'),
            style: ThixPolicy.captionStyle.copyWith(
              color: EventTheme.textMuted,
            ),
          ),
          const SizedBox(height: ThixPolicy.s8),
          Text(
            '${widget.amount.toInt()} ${widget.currency}',
            style: ThixPolicy.displayStyle.copyWith(
              color: EventTheme.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: ThixPolicy.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.confirmation_num_rounded,
                size: 14,
                color: EventTheme.textSecondary,
              ),
              const SizedBox(width: ThixPolicy.s6),
              Text(
                'ID: ${widget.bookingId.substring(0, 8).toUpperCase()}...',
                style: ThixPolicy.captionStyle.copyWith(
                  color: EventTheme.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard(AppLocalizations l10n, _PaymentMethod method) {
    final isSelected = _selectedId == method.id;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: ThixPolicy.s10),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: l10n.t(method.nameKey),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedId = method.id);
          },
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          child: Container(
            padding: const EdgeInsets.all(ThixPolicy.s14),
            decoration: BoxDecoration(
              color: isSelected
                  ? method.color.withOpacity(0.10)
                  : EventTheme.surface,
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: Border.all(
                color: isSelected ? method.color : EventTheme.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(ThixPolicy.s8),
                  decoration: BoxDecoration(
                    color: method.color.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(method.icon, color: method.color, size: 18),
                ),
                const SizedBox(width: ThixPolicy.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t(method.nameKey),
                        style: ThixPolicy.bodyMediumStyle.copyWith(
                          color: EventTheme.textMain,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        method.brand,
                        style: ThixPolicy.captionStyle.copyWith(
                          color: EventTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: isSelected ? method.color : EventTheme.textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField(AppLocalizations l10n) {
    return Semantics(
      textField: true,
      label: l10n.t('payment_phone_label'),
      child: TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        style: ThixPolicy.bodyStyle.copyWith(color: EventTheme.textMain),
        decoration: InputDecoration(
          labelText: l10n.t('payment_phone_label'),
          labelStyle: ThixPolicy.captionStyle.copyWith(
            color: EventTheme.textMuted,
          ),
          hintText: '+243...',
          hintStyle: ThixPolicy.bodyStyle.copyWith(
            color: EventTheme.textMuted,
          ),
          prefixIcon: Icon(
            Icons.phone_outlined,
            color: EventTheme.textSecondary,
          ),
          filled: true,
          fillColor: EventTheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            borderSide: const BorderSide(color: EventTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            borderSide: const BorderSide(color: EventTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            borderSide: const BorderSide(color: EventTheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityInfo(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s12),
      decoration: BoxDecoration(
        color: EventTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(color: EventTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: EventTheme.primary, size: 18),
          const SizedBox(width: ThixPolicy.s10),
          Expanded(
            child: Text(
              l10n.t('payment_security_info'),
              style: ThixPolicy.captionStyle.copyWith(
                color: EventTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: EventTheme.surface.withOpacity(0.96),
        border: Border(top: BorderSide(color: EventTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Semantics(
          button: true,
          label: l10n.t('payment_pay_now'),
          enabled: !_processing,
          child: SizedBox(
            height: ThixPolicy.buttonHeight,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _processing ? null : _pay,
              style: ElevatedButton.styleFrom(
                backgroundColor: EventTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                ),
                elevation: 0,
              ),
              child: _processing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${l10n.t('payment_pay_now')} ${widget.amount.toInt()} ${widget.currency}',
                          style: ThixPolicy.buttonText.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

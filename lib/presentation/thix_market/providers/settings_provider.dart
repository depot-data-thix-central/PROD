// lib/presentation/thix_market/providers/settings_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:html/parser.dart' as html_parser;

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const Duration _kToggleDebounce = Duration(milliseconds: 500);
const int _kMaxRetries = 1;

// SharedPreferences keys
const String _kPrefPush = 'settings_push_notifications';
const String _kPrefMessages = 'settings_message_notifications';
const String _kPrefPromo = 'settings_promo_notifications';
const String _kPrefPriceAlert = 'settings_price_alert_notifications';
const String _kPrefProfessional = 'settings_professional_mode';
const String _kPrefPublicProfile = 'settings_public_profile';
const String _kPrefShowEmail = 'settings_show_email';
const String _kPrefShowPhone = 'settings_show_phone';
const String _kPrefLoaded = 'settings_loaded_v1';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _SettingsValidators {
  _SettingsValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static bool isValidEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    return RegExp(r'^[a-zA-Z0-9.!#$%&\'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$')
        .hasMatch(email.trim());
  }

  static int safeCount(dynamic response) {
    if (response is List) return response.length;
    return 0;
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SettingsProvider] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[SettingsProvider] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[SettingsProvider] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// MODÈLE TYPÉ
// ============================================================================
class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.createdAt,
  });

  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;
  String get initials => name
      .split(' ')
      .take(2)
      .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
      .join('');

  factory UserProfile.fromMap(Map<String, dynamic> map, String fallbackEmail) {
    final name = _SettingsValidators.sanitize(
      map['name']?.toString() ?? fallbackEmail.split('@').first,
      maxLength: 100,
    );
    final email = _SettingsValidators.sanitize(
      map['email']?.toString() ?? fallbackEmail,
      maxLength: 200,
    );
    final phone = _SettingsValidators.sanitize(map['phone']?.toString(), maxLength: 20);
    final avatar = _SettingsValidators.sanitizeUrl(map['avatar']?.toString());

    DateTime? createdAt;
    try {
      if (map['created_at'] != null) {
        createdAt = DateTime.parse(map['created_at'].toString());
      }
    } catch (_) {}

    return UserProfile(
      id: map['id']?.toString() ?? '',
      name: name.isEmpty ? 'Utilisateur THIX' : name,
      email: email,
      phone: phone.isEmpty ? null : phone,
      avatarUrl: avatar,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar': avatarUrl,
      };
}

// ============================================================================
// SETTINGS PROVIDER
// ============================================================================
class SettingsProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ------------------------------------------------------------------
  // STATE
  // ------------------------------------------------------------------
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  // User profile (typed)
  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;
  @Deprecated('Use userProfile instead')
  Map<String, dynamic>? get user => _userProfile?.toMap();

  // Payment & addresses
  int? _thixMoneyBalance;
  int? get thixMoneyBalance => _thixMoneyBalance;

  bool _isThixMoneyLinked = false;
  bool get isThixMoneyLinked => _isThixMoneyLinked;

  int _cardsCount = 0;
  int get cardsCount => _cardsCount;

  String? _mobileMoneyNumber;
  String? get mobileMoneyNumber => _mobileMoneyNumber;

  int _addressesCount = 0;
  int get addressesCount => _addressesCount;

  // Notifications (persistés en SharedPreferences + DB)
  bool _pushNotifications = true;
  bool get pushNotifications => _pushNotifications;

  bool _messageNotifications = true;
  bool get messageNotifications => _messageNotifications;

  bool _promoNotifications = true;
  bool get promoNotifications => _promoNotifications;

  bool _priceAlertNotifications = true;
  bool get priceAlertNotifications => _priceAlertNotifications;

  // Security
  bool _is2FAEnabled = false;
  bool get is2FAEnabled => _is2FAEnabled;

  // Professional
  bool _isProfessionalMode = false;
  bool get isProfessionalMode => _isProfessionalMode;

  String? _subscriptionStatus;
  String? get subscriptionStatus => _subscriptionStatus;

  // Privacy (persistés en DB)
  bool _isPublicProfile = true;
  bool get isPublicProfile => _isPublicProfile;

  bool _showEmail = false;
  bool get showEmail => _showEmail;

  bool _showPhone = false;
  bool get showPhone => _showPhone;

  // Debounce timers pour toggles
  Timer? _privacyDebounceTimer;
  Timer? _notificationsDebounceTimer;

  SettingsProvider() {
    _loadPreferencesSync();
  }

  @override
  void dispose() {
    _privacyDebounceTimer?.cancel();
    _notificationsDebounceTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // CHARGEMENT PRÉFÉRENCES LOCALES (instantané au démarrage)
  // ------------------------------------------------------------------
  Future<void> _loadPreferencesSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = prefs.getBool(_kPrefLoaded) ?? false;

      if (loaded) {
        _pushNotifications = prefs.getBool(_kPrefPush) ?? true;
        _messageNotifications = prefs.getBool(_kPrefMessages) ?? true;
        _promoNotifications = prefs.getBool(_kPrefPromo) ?? true;
        _priceAlertNotifications = prefs.getBool(_kPrefPriceAlert) ?? true;
        _isProfessionalMode = prefs.getBool(_kPrefProfessional) ?? false;
        _isPublicProfile = prefs.getBool(_kPrefPublicProfile) ?? true;
        _showEmail = prefs.getBool(_kPrefShowEmail) ?? false;
        _showPhone = prefs.getBool(_kPrefShowPhone) ?? false;
        debugPrint('[SettingsProvider] ✓ Local preferences loaded');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SettingsProvider] ⚠️ Load prefs error: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool(_kPrefPush, _pushNotifications),
        prefs.setBool(_kPrefMessages, _messageNotifications),
        prefs.setBool(_kPrefPromo, _promoNotifications),
        prefs.setBool(_kPrefPriceAlert, _priceAlertNotifications),
        prefs.setBool(_kPrefProfessional, _isProfessionalMode),
        prefs.setBool(_kPrefPublicProfile, _isPublicProfile),
        prefs.setBool(_kPrefShowEmail, _showEmail),
        prefs.setBool(_kPrefShowPhone, _showPhone),
        prefs.setBool(_kPrefLoaded, true),
      ]);
    } catch (e) {
      debugPrint('[SettingsProvider] ⚠️ Save prefs error: $e');
    }
  }

  // ------------------------------------------------------------------
  // LOAD SETTINGS (parallel + retry + sanitization)
  // ------------------------------------------------------------------
  Future<void> loadSettings() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) {
      debugPrint('[SettingsProvider] ⚠️ No authenticated user');
      _lastError = null;
      return;
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    debugPrint('[SettingsProvider] 🔄 Loading settings for ${authUser.id.substring(0, 8)}...');

    try {
      // Requêtes parallèles pour performance
      final profileFuture = _withRetry(
        () => _supabase
            .from('users')
            .select('id, name, email, avatar, phone, created_at, is_2fa_enabled, is_public_profile, show_email, show_phone, subscription_status')
            .eq('id', authUser.id)
            .maybeSingle(),
        label: 'fetchUserProfile',
      );

      final addressesFuture = _withRetry(
        () => _supabase.from('addresses').select('id').eq('user_id', authUser.id),
        label: 'countAddresses',
      ).catchError((_) => <dynamic>[]);

      final cardsFuture = _withRetry(
        () => _supabase.from('payment_methods').select('id').eq('user_id', authUser.id),
        label: 'countCards',
      ).catchError((_) => <dynamic>[]);

      final walletFuture = _withRetry(
        () => _supabase.from('wallets').select('balance, is_linked').eq('user_id', authUser.id).maybeSingle(),
        label: 'fetchWallet',
      ).catchError((_) => null);

      final mobileMoneyFuture = _withRetry(
        () => _supabase
            .from('mobile_money_accounts')
            .select('phone_number')
            .eq('user_id', authUser.id)
            .eq('is_verified', true)
            .maybeSingle(),
        label: 'fetchMobileMoney',
      ).catchError((_) => null);

      // Exécution parallèle
      final results = await Future.wait([
        profileFuture,
        addressesFuture,
        cardsFuture,
        walletFuture,
        mobileMoneyFuture,
      ]);

      // Parse profile
      final profileRaw = results[0] as Map<String, dynamic>?;
      if (profileRaw != null) {
        _userProfile = UserProfile.fromMap(profileRaw, authUser.email ?? 'Utilisateur THIX');

        // Override privacy from DB (DB wins over local prefs)
        if (profileRaw['is_public_profile'] != null) {
          _isPublicProfile = profileRaw['is_public_profile'] == true;
        }
        if (profileRaw['show_email'] != null) {
          _showEmail = profileRaw['show_email'] == true;
        }
        if (profileRaw['show_phone'] != null) {
          _showPhone = profileRaw['show_phone'] == true;
        }
        if (profileRaw['is_2fa_enabled'] != null) {
          _is2FAEnabled = profileRaw['is_2fa_enabled'] == true;
        }
        if (profileRaw['subscription_status'] != null) {
          _subscriptionStatus = _SettingsValidators.sanitize(
            profileRaw['subscription_status'].toString(),
            maxLength: 50,
          );
        }
      } else {
        _userProfile = UserProfile(
          id: authUser.id,
          name: authUser.userMetadata?['name']?.toString() ?? 'Utilisateur THIX',
          email: authUser.email ?? '',
        );
      }

      // Parse counts
      _addressesCount = _SettingsValidators.safeCount(results[1]);
      _cardsCount = _SettingsValidators.safeCount(results[2]);

      // Parse wallet
      final wallet = results[3] as Map<String, dynamic>?;
      if (wallet != null) {
        final balance = wallet['balance'];
        _thixMoneyBalance = balance is num ? balance.toInt() : null;
        _isThixMoneyLinked = wallet['is_linked'] == true;
      }

      // Parse mobile money
      final mobileMoney = results[4] as Map<String, dynamic>?;
      if (mobileMoney != null) {
        _mobileMoneyNumber = _SettingsValidators.sanitize(
          mobileMoney['phone_number']?.toString(),
          maxLength: 20,
        );
      }

      // Sauvegarder en local pour prochain démarrage instantané
      await _savePreferences();

      debugPrint('[SettingsProvider] ✓ Loaded: ${_userProfile?.name}, '
          '${_addressesCount} addresses, ${_cardsCount} cards, '
          '2FA=${_is2FAEnabled}, pro=${_isProfessionalMode}');
    } catch (e, st) {
      debugPrint('[SettingsProvider] ❌ Load error: $e\n$st');
      _lastError = 'Erreur lors du chargement des paramètres';
      // Fallback minimal
      _userProfile = UserProfile(
        id: authUser.id,
        name: authUser.userMetadata?['name']?.toString() ?? 'Utilisateur THIX',
        email: authUser.email ?? '',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------
  // TOGGLES NOTIFICATIONS (local + persist)
  // ------------------------------------------------------------------
  void togglePushNotifications(bool value) {
    if (_pushNotifications == value) return;
    _pushNotifications = value;
    debugPrint('[SettingsProvider] 🔔 Push: $value');
    notifyListeners();
    _scheduleNotificationsSave();
  }

  void toggleMessageNotifications(bool value) {
    if (_messageNotifications == value) return;
    _messageNotifications = value;
    debugPrint('[SettingsProvider] 💬 Messages: $value');
    notifyListeners();
    _scheduleNotificationsSave();
  }

  void togglePromoNotifications(bool value) {
    if (_promoNotifications == value) return;
    _promoNotifications = value;
    debugPrint('[SettingsProvider] 🎁 Promo: $value');
    notifyListeners();
    _scheduleNotificationsSave();
  }

  void togglePriceAlertNotifications(bool value) {
    if (_priceAlertNotifications == value) return;
    _priceAlertNotifications = value;
    debugPrint('[SettingsProvider] 📉 Price alerts: $value');
    notifyListeners();
    _scheduleNotificationsSave();
  }

  void _scheduleNotificationsSave() {
    _notificationsDebounceTimer?.cancel();
    _notificationsDebounceTimer = Timer(_kToggleDebounce, () {
      _savePreferences();
      // TODO: Sync with backend notifications preferences
    });
  }

  // ------------------------------------------------------------------
  // TOGGLE PROFESSIONAL MODE (local + persist)
  // ------------------------------------------------------------------
  void toggleProfessionalMode(bool value) {
    if (_isProfessionalMode == value) return;
    _isProfessionalMode = value;
    debugPrint('[SettingsProvider] 💼 Professional mode: $value');
    notifyListeners();
    _savePreferences();
    // TODO: Update DB subscription tier if needed
  }

  // ------------------------------------------------------------------
  // TOGGLES PRIVACY (local + persist en DB avec debounce)
  // ------------------------------------------------------------------
  void togglePublicProfile(bool value) {
    if (_isPublicProfile == value) return;
    _isPublicProfile = value;
    debugPrint('[SettingsProvider] 🌐 Public profile: $value');
    notifyListeners();
    _schedulePrivacySave('is_public_profile', value);
  }

  void toggleShowEmail(bool value) {
    if (_showEmail == value) return;
    _showEmail = value;
    debugPrint('[SettingsProvider] 📧 Show email: $value');
    notifyListeners();
    _schedulePrivacySave('show_email', value);
  }

  void toggleShowPhone(bool value) {
    if (_showPhone == value) return;
    _showPhone = value;
    debugPrint('[SettingsProvider] 📱 Show phone: $value');
    notifyListeners();
    _schedulePrivacySave('show_phone', value);
  }

  void _schedulePrivacySave(String field, bool value) {
    _savePreferences(); // Local immédiatement

    // DB avec debounce (évite spam si toggle rapide)
    _privacyDebounceTimer?.cancel();
    _privacyDebounceTimer = Timer(_kToggleDebounce, () async {
      await _persistPrivacyField(field, value);
    });
  }

  Future<bool> _persistPrivacyField(String field, bool value) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return false;

    try {
      await _withRetry(
        () => _supabase.from('users').update({field: value}).eq('id', uid),
        label: 'persistPrivacy[$field]',
      );
      debugPrint('[SettingsProvider] ✓ Persisted $field=$value to DB');
      return true;
    } catch (e) {
      debugPrint('[SettingsProvider] ❌ Persist $field error: $e');
      _lastError = 'Erreur de sauvegarde ($field)';
      notifyListeners();
      return false;
    }
  }

  // ------------------------------------------------------------------
  // CLEANUP (à appeler au logout)
  // ------------------------------------------------------------------
  Future<void> clearOnLogout() async {
    debugPrint('[SettingsProvider] 🧹 Clearing settings on logout');
    _userProfile = null;
    _thixMoneyBalance = null;
    _isThixMoneyLinked = false;
    _cardsCount = 0;
    _mobileMoneyNumber = null;
    _addressesCount = 0;
    _is2FAEnabled = false;
    _subscriptionStatus = null;
    _lastError = null;
    // Garder préférences locales (notifications) pour prochain login
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------------
  bool get isAuthenticated => _supabase.auth.currentUser != null;
  String? get userId => _supabase.auth.currentUser?.id;
  String? get userEmail => _supabase.auth.currentUser?.email;

  bool hasError() => _lastError != null;
  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }
}

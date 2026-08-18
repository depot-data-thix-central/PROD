import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic>? user;
  int? thixMoneyBalance;
  bool isThixMoneyLinked = false;
  int cardsCount = 0;
  String? mobileMoneyNumber;
  int addressesCount = 0;
  bool pushNotifications = true;
  bool messageNotifications = true;
  bool promoNotifications = true;
  bool priceAlertNotifications = true;
  bool is2FAEnabled = false;
  bool isProfessionalMode = false;
  String? subscriptionStatus;
  bool isPublicProfile = true;
  bool showEmail = false;
  bool showPhone = false;

  Future<void> loadSettings() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) return;
    try {
      final profile = await _supabase.from('users').select('name, email, avatar, phone').eq('id', authUser.id).maybeSingle();
      user = profile ?? {'name': authUser.email ?? 'Utilisateur THIX', 'email': authUser.email};
      addressesCount = (await _supabase.from('addresses').select('id').eq('user_id', authUser.id)).length;
    } catch (_) {
      user = {'name': authUser.email ?? 'Utilisateur THIX', 'email': authUser.email};
    }
    notifyListeners();
  }

  void togglePushNotifications(bool value) { pushNotifications = value; notifyListeners(); }
  void toggleMessageNotifications(bool value) { messageNotifications = value; notifyListeners(); }
  void togglePromoNotifications(bool value) { promoNotifications = value; notifyListeners(); }
  void togglePriceAlertNotifications(bool value) { priceAlertNotifications = value; notifyListeners(); }
  void toggleProfessionalMode(bool value) { isProfessionalMode = value; notifyListeners(); }
  void togglePublicProfile(bool value) { isPublicProfile = value; notifyListeners(); }
  void toggleShowEmail(bool value) { showEmail = value; notifyListeners(); }
  void toggleShowPhone(bool value) { showPhone = value; notifyListeners(); }
}

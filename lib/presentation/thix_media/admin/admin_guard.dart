import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Cache 2min pour éviter spam DB à chaque build
DateTime? _lastCheck;
bool _cachedIsAdmin = false;

final isAdminProvider = StateProvider<bool>((ref)=> AdminGuard.isAdminSync);

final adminGuardProvider = Provider<AdminGuardService>((ref)=> AdminGuardService());

class AdminGuardService {
  final _client = Supabase.instance.client;

  Future<bool> checkIsAdmin({bool force=false}) async {
    if(!force && _lastCheck!=null && DateTime.now().difference(_lastCheck!).inSeconds < 120){
      return _cachedIsAdmin;
    }

    final user = _client.auth.currentUser;
    if(user==null){ _cachedIsAdmin=false; _lastCheck=DateTime.now(); return false; }

    // 1. JWT app_metadata / user_metadata (instant, 0 DB)
    final metaRole = user.appMetadata['role'] ?? user.userMetadata?['role'];
    if(metaRole=='admin' || metaRole=='super_admin'){
      _cachedIsAdmin=true; _lastCheck=DateTime.now(); return true;
    }

    // 2. Whitelist env (secours)
    const whitelist = ['admin@thix.id', 'thix@thix.id'];
    if(whitelist.contains(user.email)){
      _cachedIsAdmin=true; _lastCheck=DateTime.now(); return true;
    }

    // 3. Table profiles.role avec RLS (source de vérité)
    try{
      final res = await _client.from('profiles').select('role').eq('id', user.id).maybeSingle();
      final role = res?['role'];
      final isAdmin = role=='admin' || role=='super_admin';
      _cachedIsAdmin=isAdmin; _lastCheck=DateTime.now();
      return isAdmin;
    }catch(_){
      _cachedIsAdmin=false; _lastCheck=DateTime.now();
      return false;
    }
  }

  Stream<bool> watchAdminStatus(){
    return _client.auth.onAuthStateChange.asyncMap((_)=> checkIsAdmin(force: true)).asBroadcastStream();
  }

  Future<void> requireAdmin() async {
    final ok = await checkIsAdmin();
    if(!ok) throw const AdminException('Accès admin requis');
  }
}

class AdminGuard {
  // Sync rapide pour UI (sans DB)
  static bool get isAdminSync {
    final user = Supabase.instance.client.auth.currentUser;
    if(user==null) return false;
    final role = user.appMetadata['role'] ?? user.userMetadata?['role'];
    if(role=='admin' || role=='super_admin') return true;
    const admins = ['admin@thix.id', 'thix@thix.id'];
    return admins.contains(user.email);
  }

  // Legacy API compat
  static bool get isAdmin => isAdminSync;

  static Future<bool> canAccess() async {
    return AdminGuardService().checkIsAdmin();
  }

  static void clearCache(){
    _lastCheck=null;
    _cachedIsAdmin=false;
  }
}

class AdminException implements Exception {
  final String message;
  const AdminException(this.message);
  @override String toString()=> message;
}

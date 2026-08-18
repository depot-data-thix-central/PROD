import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Canonical access point for Supabase within the app.
///
/// This file intentionally keeps the surface area small and predictable:
/// - `supabase` for queries / RPC
/// - `currentUser` for the authenticated user
/// - `requireUserId()` to enforce auth where needed
///
/// IMPORTANT (per requirements): authentication must use
/// `Supabase.instance.client` and `supabase.auth.currentUser`.
///
/// We keep this as a getter (not a top-level `final`) so importing this file
/// never eagerly reads the client before `Supabase.initialize()` runs.
SupabaseClient get supabase => Supabase.instance.client;

User? get currentUser => supabase.auth.currentUser;

/// Throws a [StateError] if the user is not authenticated.
String requireUserId() {
  final user = currentUser;
  if (user == null) {
    debugPrint('SupabaseClient: requireUserId failed (not authenticated)');
    throw StateError('User is not authenticated');
  }
  return user.id;
}

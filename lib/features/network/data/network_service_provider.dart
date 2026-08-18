import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/network_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
final networkServiceProvider = Provider<NetworkService>((ref) => NetworkService(ref.read(supabaseClientProvider)));

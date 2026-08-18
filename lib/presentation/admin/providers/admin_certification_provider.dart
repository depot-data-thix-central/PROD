// lib/presentation/admin/providers/admin_certification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/admin_certification_service.dart';

final adminCertificationServiceProvider = Provider<AdminCertificationService>((ref) {
  return AdminCertificationService(Supabase.instance.client);
});

final pendingEnterpriseCertificationsProvider =
    FutureProvider.autoDispose<List<PendingEnterpriseCertification>>((ref) async {
  return ref.read(adminCertificationServiceProvider).getPendingEnterprise();
});

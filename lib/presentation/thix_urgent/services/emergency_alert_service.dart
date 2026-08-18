// lib/presentation/thix_urgent/services/emergency_alert_service.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controllers/urgent_controller.dart';

class EmergencyAlertService {
  final _supa = Supabase.instance.client;
  static const _tableAlerts = 'emergency_alerts';
  static const _tableLocations = 'emergency_locations';

  // CRÉATION ALERTE scalable: insert léger + job en background
  Future<String> triggerEmergency({required EmergencyType type, Position? position}) async {
    final user = _supa.auth.currentUser;
    if (user == null) throw Exception('Non connecté');

    final criseId = 'crise_${DateTime.now().millisecondsSinceEpoch}_${user.id.substring(0, 6)}';

    // 1. Insert alerte principale (léger)
    await _supa.from(_tableAlerts).insert({
      'id': criseId,
      'user_id': user.id,
      'type': type.name,
      'lat': position?.latitude,
      'lng': position?.longitude,
      'is_live': true,
      'created_at': DateTime.now().toIso8601String(),
      'photo_count': 0,
    });

    // 2. Première position dans table séparée pour ne pas surcharger la table principale
    if (position!= null) {
      await _supa.from(_tableLocations).insert({
        'crise_id': criseId,
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    // 3. Déclenche Edge Function qui notifie les gardiens (pas dans le client pour scale)
    try {
      await _supa.functions.invoke('notify-guardians', body: {'crise_id': criseId, 'type': type.name});
    } catch (_) {}

    return criseId;
  }

  // PAGINATION scalable pour historique
  Future<List<Map<String, dynamic>>> getAlertHistoryPaginated({required int page, required int pageSize}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;
    final user = _supa.auth.currentUser;
    if (user == null) return [];

    final res = await _supa
       .from(_tableAlerts)
       .select()
       .eq('user_id', user.id)
       .order('created_at', ascending: false)
       .range(from, to);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> updateLiveLocation(String criseId, Position pos) async {
    await _supa.from(_tableLocations).insert({
      'crise_id': criseId,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

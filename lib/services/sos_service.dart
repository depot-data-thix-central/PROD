import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import '../models/sos_models.dart';

class SosService {
  final SupabaseClient _client;
  SosService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  String? get _uid => SupabaseConfig.currentUser?.id;

  String _generatePublicId() {
    final n = 10000 + Random().nextInt(90000);
    return 'SOS #THX-$n';
  }

  // ── Contacts ────────────────────────────────────────────────
  Future<List<SosContact>> getContacts() async {
    final uid = _uid;
    if (uid == null) return [];
    final res = await _client
        .from('thix_sos_contacts')
        .select()
        .eq('owner_id', uid)
        .order('circle')
        .order('priority');
    return (res as List)
        .map((e) => SosContact.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SosContact> addContact({
    required String name,
    required int circle,
    String? phone,
    String? thixId,
    String? relation,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Non authentifié');
    final res = await _client.from('thix_sos_contacts').insert({
      'owner_id': uid,
      'name': name.trim(),
      'circle': circle,
      'phone': phone,
      'thix_id': thixId,
      'relation': relation,
    }).select().single();
    return SosContact.fromJson(Map<String, dynamic>.from(res));
  }

  // ── Incident actif ──────────────────────────────────────────
  Future<SosIncident?> getActiveIncident() async {
    final uid = _uid;
    if (uid == null) return null;
    final res = await _client
        .from('thix_sos_incidents')
        .select()
        .eq('victim_id', uid)
        .not('status', 'in', '(cancelled,resolved,archived)')
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return SosIncident.fromJson(Map<String, dynamic>.from(res));
  }

  /// Déclenche un SOS complet (localisation + incident + event)
  Future<SosIncident> triggerSos() async {
    final uid = _uid;
    if (uid == null) throw Exception('Non authentifié');

    // Permission + position
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {}

    final publicId = _generatePublicId();

    final row = await _client.from('thix_sos_incidents').insert({
      'public_id': publicId,
      'victim_id': uid,
      'status': 'active',
      'active_circle': 1,
      'last_lat': pos?.latitude,
      'last_lng': pos?.longitude,
      'last_accuracy_m': pos?.accuracy,
      'last_location_at': pos != null ? DateTime.now().toIso8601String() : null,
      'heartbeat_at': DateTime.now().toIso8601String(),
      'started_at': DateTime.now().toIso8601String(),
    }).select().single();

    final incident = SosIncident.fromJson(Map<String, dynamic>.from(row));

    // Première position
    if (pos != null) {
      await _client.from('thix_sos_locations').insert({
        'incident_id': incident.id,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy_m': pos.accuracy,
        'speed_mps': pos.speed,
        'heading_deg': pos.heading,
      });
    }

    // Event
    await _client.from('thix_sos_events').insert({
      'incident_id': incident.id,
      'type': 'SOS_CREATED',
      'payload': {
        'public_id': publicId,
        'lat': pos?.latitude,
        'lng': pos?.longitude,
      },
    });

    // Escalade cercle 1
    await _client.from('thix_sos_incidents').update({
      'status': 'calling_circle_1',
    }).eq('id', incident.id);

    await _client.from('thix_sos_events').insert({
      'incident_id': incident.id,
      'type': 'CIRCLE_1_STARTED',
      'payload': {},
    });

    return incident.copyWithStatus(SosStatus.callingCircle1);
  }

  Future<void> heartbeat(String incidentId, {int? batteryPct}) async {
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {}

    final patch = <String, dynamic>{
      'heartbeat_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (batteryPct != null) patch['battery_pct'] = batteryPct;
    if (pos != null) {
      patch['last_lat'] = pos.latitude;
      patch['last_lng'] = pos.longitude;
      patch['last_accuracy_m'] = pos.accuracy;
      patch['last_location_at'] = DateTime.now().toIso8601String();
      await _client.from('thix_sos_locations').insert({
        'incident_id': incidentId,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy_m': pos.accuracy,
      });
    }
    await _client.from('thix_sos_incidents').update(patch).eq('id', incidentId);
  }

  Future<void> resolveIncident(String incidentId) async {
    await _client.from('thix_sos_incidents').update({
      'status': 'resolved',
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', incidentId);
    await _client.from('thix_sos_events').insert({
      'incident_id': incidentId,
      'type': 'SOS_RESOLVED',
      'payload': {},
    });
  }

  Future<List<SosIncident>> getHistory({int limit = 20}) async {
    final uid = _uid;
    if (uid == null) return [];
    final res = await _client
        .from('thix_sos_incidents')
        .select()
        .eq('victim_id', uid)
        .order('started_at', ascending: false)
        .limit(limit);
    return (res as List)
        .map((e) => SosIncident.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

extension on SosIncident {
  SosIncident copyWithStatus(SosStatus s) => SosIncident(
        id: id,
        publicId: publicId,
        victimId: victimId,
        status: s,
        activeCircle: activeCircle,
        lastLat: lastLat,
        lastLng: lastLng,
        heartbeatAt: heartbeatAt,
        batteryPct: batteryPct,
        startedAt: startedAt,
        resolvedAt: resolvedAt,
      );
}

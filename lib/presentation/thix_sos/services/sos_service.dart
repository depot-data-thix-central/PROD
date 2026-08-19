/// THIX SOS — Service Supabase (production)
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

import '../models/sos_models.dart';

class SosServiceException implements Exception {
  final String message;
  final Object? cause;
  SosServiceException(this.message, [this.cause]);
  @override
  String toString() => 'SosServiceException: $message';
}

class SosService {
  SosService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  static const _tableContacts = 'thix_sos_contacts';
  static const _tableIncidents = 'thix_sos_incidents';
  static const _tableLocations = 'thix_sos_locations';
  static const _tableEvents = 'thix_sos_events';

  String? get _uid => SupabaseConfig.currentUser?.id;

  void _ensureAuth() {
    if (_uid == null) {
      throw SosServiceException('Utilisateur non authentifié');
    }
  }

  String _generatePublicId() {
    final n = 10000 + Random().nextInt(90000);
    return 'SOS #THX-$n';
  }

  // ═══════════════════════════════════════════════════════════
  // CONTACTS / CERCLES
  // ═══════════════════════════════════════════════════════════

  Future<List<SosContact>> getContacts() async {
    _ensureAuth();
    try {
      final res = await _client
          .from(_tableContacts)
          .select()
          .eq('owner_id', _uid!)
          .order('circle', ascending: true)
          .order('priority', ascending: true);

      return (res as List)
          .map((e) => SosContact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, st) {
      debugPrint('SosService.getContacts: $e\n$st');
      throw SosServiceException('Impossible de charger les secours', e);
    }
  }

  Future<List<SosContact>> getContactsByCircle(int circle) async {
    final all = await getContacts();
    return all.where((c) => c.circle == circle).toList();
  }

  Future<SosContact> addContact({
    required String name,
    required int circle,
    String? phone,
    String? thixId,
    String? relation,
    int priority = 1,
  }) async {
    _ensureAuth();
    if (circle < 1 || circle > 3) {
      throw SosServiceException('Cercle invalide (1, 2 ou 3)');
    }
    if (name.trim().isEmpty) {
      throw SosServiceException('Le nom est obligatoire');
    }
    try {
      final res = await _client
          .from(_tableContacts)
          .insert({
            'owner_id': _uid,
            'name': name.trim(),
            'circle': circle,
            'phone': phone?.trim(),
            'thix_id': thixId?.trim(),
            'relation': relation?.trim(),
            'priority': priority,
          })
          .select()
          .single();

      return SosContact.fromJson(Map<String, dynamic>.from(res));
    } catch (e, st) {
      debugPrint('SosService.addContact: $e\n$st');
      throw SosServiceException('Impossible d\'ajouter le secours', e);
    }
  }

  Future<SosContact> updateContact(SosContact contact) async {
    _ensureAuth();
    try {
      final res = await _client
          .from(_tableContacts)
          .update({
            'name': contact.name.trim(),
            'phone': contact.phone?.trim(),
            'thix_id': contact.thixId?.trim(),
            'photo_url': contact.photoUrl,
            'relation': contact.relation?.trim(),
            'circle': contact.circle,
            'priority': contact.priority,
            'verified': contact.verified,
            'available': contact.available,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', contact.id)
          .eq('owner_id', _uid!)
          .select()
          .single();

      return SosContact.fromJson(Map<String, dynamic>.from(res));
    } catch (e, st) {
      debugPrint('SosService.updateContact: $e\n$st');
      throw SosServiceException('Impossible de modifier le secours', e);
    }
  }

  Future<void> deleteContact(String contactId) async {
    _ensureAuth();
    try {
      await _client
          .from(_tableContacts)
          .delete()
          .eq('id', contactId)
          .eq('owner_id', _uid!);
    } catch (e, st) {
      debugPrint('SosService.deleteContact: $e\n$st');
      throw SosServiceException('Impossible de supprimer le secours', e);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // INCIDENTS
  // ═══════════════════════════════════════════════════════════

  Future<SosIncident?> getActiveIncident() async {
    _ensureAuth();
    try {
      final res = await _client
          .from(_tableIncidents)
          .select()
          .eq('victim_id', _uid!)
          .not('status', 'in', '(cancelled,resolved,archived)')
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) return null;
      return SosIncident.fromJson(Map<String, dynamic>.from(res));
    } catch (e, st) {
      debugPrint('SosService.getActiveIncident: $e\n$st');
      return null;
    }
  }

  Future<SosIncident?> getIncidentById(String id) async {
    _ensureAuth();
    try {
      final res = await _client
          .from(_tableIncidents)
          .select()
          .eq('id', id)
          .eq('victim_id', _uid!)
          .maybeSingle();
      if (res == null) return null;
      return SosIncident.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      return null;
    }
  }

  Future<List<SosIncident>> getHistory({int limit = 30}) async {
    _ensureAuth();
    try {
      final res = await _client
          .from(_tableIncidents)
          .select()
          .eq('victim_id', _uid!)
          .order('started_at', ascending: false)
          .limit(limit);

      return (res as List)
          .map((e) => SosIncident.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, st) {
      debugPrint('SosService.getHistory: $e\n$st');
      throw SosServiceException('Impossible de charger l\'historique', e);
    }
  }

  /// Déclenche un SOS complet (position + incident + events + escalade cercle 1)
  Future<SosIncident> triggerSos() async {
    _ensureAuth();

    // Éviter double SOS actif
    final existing = await getActiveIncident();
    if (existing != null) {
      throw SosServiceException('Un SOS est déjà en cours (${existing.publicId})');
    }

    Position? position;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      debugPrint('SosService.triggerSos position: $e');
    }

    final publicId = _generatePublicId();
    final now = DateTime.now().toIso8601String();

    try {
      final row = await _client
          .from(_tableIncidents)
          .insert({
            'public_id': publicId,
            'victim_id': _uid,
            'status': SosStatus.active.dbValue,
            'active_circle': 1,
            'last_lat': position?.latitude,
            'last_lng': position?.longitude,
            'last_accuracy_m': position?.accuracy,
            'last_location_at': position != null ? now : null,
            'heartbeat_at': now,
            'started_at': now,
          })
          .select()
          .single();

      final incident = SosIncident.fromJson(Map<String, dynamic>.from(row));

      if (position != null) {
        await _client.from(_tableLocations).insert({
          'incident_id': incident.id,
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy_m': position.accuracy,
          'speed_mps': position.speed,
          'heading_deg': position.heading,
        });
      }

      await _logEvent(incident.id, 'SOS_CREATED', {
        'public_id': publicId,
        'lat': position?.latitude,
        'lng': position?.longitude,
      });

      // Escalade automatique Cercle 1
      await _client.from(_tableIncidents).update({
        'status': SosStatus.callingCircle1.dbValue,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', incident.id);

      await _logEvent(incident.id, 'CIRCLE_1_STARTED', {});

      return incident.copyWith(status: SosStatus.callingCircle1);
    } catch (e, st) {
      debugPrint('SosService.triggerSos: $e\n$st');
      throw SosServiceException('Échec du déclenchement SOS', e);
    }
  }

  Future<void> heartbeat(String incidentId, {int? batteryPct}) async {
    _ensureAuth();

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {}

    final now = DateTime.now().toIso8601String();
    final patch = <String, dynamic>{
      'heartbeat_at': now,
      'updated_at': now,
    };
    if (batteryPct != null) patch['battery_pct'] = batteryPct;

    if (position != null) {
      patch['last_lat'] = position.latitude;
      patch['last_lng'] = position.longitude;
      patch['last_accuracy_m'] = position.accuracy;
      patch['last_location_at'] = now;

      try {
        await _client.from(_tableLocations).insert({
          'incident_id': incidentId,
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy_m': position.accuracy,
          'speed_mps': position.speed,
          'heading_deg': position.heading,
        });
      } catch (e) {
        debugPrint('SosService.heartbeat location insert: $e');
      }
    }

    try {
      await _client
          .from(_tableIncidents)
          .update(patch)
          .eq('id', incidentId)
          .eq('victim_id', _uid!);
    } catch (e, st) {
      debugPrint('SosService.heartbeat: $e\n$st');
    }
  }

  Future<void> escalateToCircle(String incidentId, int circle) async {
    _ensureAuth();
    if (circle < 1 || circle > 3) return;

    final status = circle == 1
        ? SosStatus.callingCircle1
        : circle == 2
            ? SosStatus.callingCircle2
            : SosStatus.callingCircle3;

    try {
      await _client.from(_tableIncidents).update({
        'status': status.dbValue,
        'active_circle': circle,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', incidentId).eq('victim_id', _uid!);

      await _logEvent(incidentId, 'CIRCLE_${circle}_STARTED', {'circle': circle});
    } catch (e, st) {
      debugPrint('SosService.escalateToCircle: $e\n$st');
      throw SosServiceException('Échec escalade cercle $circle', e);
    }
  }

  Future<void> resolveIncident(String incidentId) async {
    _ensureAuth();
    try {
      await _client.from(_tableIncidents).update({
        'status': SosStatus.resolved.dbValue,
        'resolved_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', incidentId).eq('victim_id', _uid!);

      await _logEvent(incidentId, 'SOS_RESOLVED', {});
    } catch (e, st) {
      debugPrint('SosService.resolveIncident: $e\n$st');
      throw SosServiceException('Impossible de terminer le SOS', e);
    }
  }

  Future<void> cancelIncident(String incidentId) async {
    _ensureAuth();
    try {
      await _client.from(_tableIncidents).update({
        'status': SosStatus.cancelled.dbValue,
        'resolved_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', incidentId).eq('victim_id', _uid!);

      await _logEvent(incidentId, 'SOS_CANCELLED', {});
    } catch (e, st) {
      debugPrint('SosService.cancelIncident: $e\n$st');
      throw SosServiceException('Impossible d\'annuler le SOS', e);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // LOCATIONS / EVENTS
  // ═══════════════════════════════════════════════════════════

  Future<List<SosLocationPoint>> getLocations(
    String incidentId, {
    int limit = 100,
  }) async {
    _ensureAuth();
    try {
      final res = await _client
          .from(_tableLocations)
          .select()
          .eq('incident_id', incidentId)
          .order('captured_at', ascending: false)
          .limit(limit);

      return (res as List)
          .map((e) => SosLocationPoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<SosEvent>> getEvents(String incidentId, {int limit = 50}) async {
    _ensureAuth();
    try {
      final res = await _client
          .from(_tableEvents)
          .select()
          .eq('incident_id', incidentId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (res as List)
          .map((e) => SosEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _logEvent(
    String incidentId,
    String type,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _client.from(_tableEvents).insert({
        'incident_id': incidentId,
        'type': type,
        'payload': payload,
      });
    } catch (e) {
      debugPrint('SosService._logEvent($type): $e');
    }
  }
}

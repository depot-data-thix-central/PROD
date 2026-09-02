/// THIX SOS — Service Supabase (Production Enterprise)
/// ✅ SÉCURISÉ : timeouts, retry, validation, anti-race, PII protection
/// ✅ ROBUSTE : logs structurés, atomicité best-effort, sanitization
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

import '../models/sos_models.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kQueryTimeout = Duration(seconds: 15);
const Duration _kTriggerTimeout = Duration(seconds: 30);
const Duration _kGeolocatorTimeout = Duration(seconds: 8);
const int _kMaxRetries = 1;
const Duration _kRetryDelay = Duration(milliseconds: 600);
const int _kMaxNameLength = 100;
const int _kMaxRelationLength = 50;
const int _kMaxIdLength = 64;
const int _kDefaultHistoryLimit = 30;
const int _kMaxHistoryLimit = 200;
const int _kDefaultLocationsLimit = 100;
const int _kMaxLocationsLimit = 1000;
const int _kDefaultEventsLimit = 50;
const int _kMaxEventsLimit = 500;
const int _kMinCircle = 1;
const int _kMaxCircle = 3;

// ============================================================================
// EXCEPTION
// ============================================================================
class SosServiceException implements Exception {
  final String message;
  final Object? cause;
  final String? code;
  
  SosServiceException(this.message, [this.cause, this.code]);
  
  @override
  String toString() => 'SosServiceException: $message${code != null ? ' [$code]' : ''}';
}

// ============================================================================
// VALIDATORS
// ============================================================================
class _ServiceValidators {
  _ServiceValidators._();

  static bool isValidId(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    return trimmed.isNotEmpty && trimmed.length <= _kMaxIdLength;
  }

  static bool isValidName(String? name) {
    if (name == null) return false;
    final trimmed = name.trim();
    return trimmed.isNotEmpty && trimmed.length <= _kMaxNameLength;
  }

  static bool isValidCircle(int circle) {
    return circle >= _kMinCircle && circle <= _kMaxCircle;
  }

  static int clampLimit(int limit, int defaultVal, int maxVal) {
    if (limit <= 0) return defaultVal;
    return limit.clamp(1, maxVal);
  }

  static String sanitizePayload(String? input, {int maxLength = 200}) {
    if (input == null) return '';
    final trimmed = input.trim();
    return trimmed.length > maxLength
        ? trimmed.substring(0, maxLength)
        : trimmed;
  }

  /// ✅ RGPD : masque partiellement un ID dans les logs
  static String maskId(String? id) {
    if (id == null || id.length <= 8) return '***';
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }

  /// ✅ RGPD : arrondi GPS pour éviter traçabilité précise
  static double? roundCoordinate(double? coord) {
    if (coord == null) return null;
    return (coord * 10000).round() / 10000; // 4 décimales (~10m)
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _serviceRetry<T>(
  Future<T> Function() fn, {
  required String label,
  Duration timeout = _kQueryTimeout,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SosService] ❌ $label: timeout after $attempt');
        throw SosServiceException('Délai dépassé: $label', null, 'TIMEOUT');
      }
      debugPrint('[SosService] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } on PostgrestException catch (e) {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SosService] ❌ $label: Postgrest ${e.code} ${e.message}');
        throw SosServiceException('Erreur base de données: ${e.message}', e, e.code);
      }
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SosService] ❌ $label: $e');
        rethrow;
      }
      await Future.delayed(_kRetryDelay);
    }
  }
}

// ============================================================================
// SERVICE
// ============================================================================
class SosService {
  SosService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;
  
  // ✅ Flag anti-race pour triggerSos
  bool _isTriggering = false;

  static const _tableContacts = 'thix_sos_contacts';
  static const _tableIncidents = 'thix_sos_incidents';
  static const _tableLocations = 'thix_sos_locations';
  static const _tableEvents = 'thix_sos_events';

  String? get _uid => SupabaseConfig.currentUser?.id;

  void _ensureAuth() {
    if (_uid == null) {
      debugPrint('[SosService] ⚠️ Auth required but no user');
      throw SosServiceException('Utilisateur non authentifié', null, 'AUTH_REQUIRED');
    }
  }

  // ✅ FIX : Random sécurisé + préfixe timestamp pour éviter doublons
  String _generatePublicId() {
    final r = Random.secure();
    final n = 10000 + r.nextInt(90000);
    final ts = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    return 'SOS-THX-$ts-$n';
  }

  // ✅ FIX : UUID v4-like avec Random.secure
  String _generateUuid() {
    final r = Random.secure();
    String h(int bytes) {
      final buffer = StringBuffer();
      for (var i = 0; i < bytes; i++) {
        buffer.write(r.nextInt(256).toRadixString(16).padLeft(2, '0'));
      }
      return buffer.toString();
    }
    return '${h(4)}-${h(2)}-4${h(1).substring(1)}-${(8 + r.nextInt(4)).toRadixString(16)}${h(1).substring(1)}-${h(6)}';
  }

  /// Correction : utilisation de _logEvent existant avec timeout
  Future<void> logEventPublic(
    String incidentId,
    String eventType,
    Map<String, dynamic> metadata,
  ) async {
    if (!_ServiceValidators.isValidId(incidentId)) {
      debugPrint('[SosService] ⚠️ logEventPublic: invalid incidentId');
      return;
    }
    await _logEvent(incidentId, eventType, metadata);
  }

  // ═══════════════════════════════════════════════════════════
  // CONTACTS / CERCLES
  // ═══════════════════════════════════════════════════════════

  Future<List<SosContact>> getContacts() async {
    _ensureAuth();
    try {
      final res = await _serviceRetry(
        () => _client
            .from(_tableContacts)
            .select()
            .eq('owner_id', _uid!)
            .order('circle', ascending: true)
            .order('priority', ascending: true),
        label: 'getContacts',
      );

      debugPrint('[SosService] ✓ getContacts: ${(res as List).length} contacts');
      return res
          .map((e) => SosContact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[SosService] ❌ getContacts: $e');
      throw SosServiceException('Impossible de charger les secours', e);
    }
  }

  // ✅ FIX : query directe au lieu de re-fetch tous les contacts
  Future<List<SosContact>> getContactsByCircle(int circle) async {
    _ensureAuth();
    if (!_ServiceValidators.isValidCircle(circle)) {
      debugPrint('[SosService] ⚠️ Invalid circle: $circle');
      return [];
    }
    try {
      final res = await _serviceRetry(
        () => _client
            .from(_tableContacts)
            .select()
            .eq('owner_id', _uid!)
            .eq('circle', circle)
            .order('priority', ascending: true),
        label: 'getContactsByCircle[$circle]',
      );

      final list = (res as List)
          .map((e) => SosContact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      debugPrint('[SosService] ✓ getContactsByCircle[$circle]: ${list.length}');
      return list;
    } catch (e) {
      debugPrint('[SosService] ❌ getContactsByCircle[$circle]: $e');
      throw SosServiceException('Impossible de charger les secours du cercle $circle', e);
    }
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
    if (!_ServiceValidators.isValidCircle(circle)) {
      throw SosServiceException('Cercle invalide (1, 2 ou 3)', null, 'INVALID_CIRCLE');
    }
    if (!_ServiceValidators.isValidName(name)) {
      throw SosServiceException('Le nom est obligatoire (max $_kMaxNameLength caractères)', null, 'INVALID_NAME');
    }
    
    final sanitizedName = _ServiceValidators.sanitizePayload(name, maxLength: _kMaxNameLength);
    final sanitizedRelation = relation != null
        ? _ServiceValidators.sanitizePayload(relation, maxLength: _kMaxRelationLength)
        : null;

    try {
      final res = await _serviceRetry(
        () => _client
            .from(_tableContacts)
            .insert({
              'owner_id': _uid,
              'name': sanitizedName,
              'circle': circle,
              'phone': phone?.trim(),
              'thix_id': thixId?.trim(),
              'relation': sanitizedRelation,
              'priority': priority,
            })
            .select()
            .single(),
        label: 'addContact',
      );

      debugPrint('[SosService] ✓ addContact: $sanitizedName (circle $circle)');
      return SosContact.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[SosService] ❌ addContact: $e');
      throw SosServiceException('Impossible d\'ajouter le secours', e);
    }
  }

  Future<SosContact> updateContact(SosContact contact) async {
    _ensureAuth();
    if (!_ServiceValidators.isValidId(contact.id)) {
      throw SosServiceException('ID contact invalide', null, 'INVALID_ID');
    }
    
    try {
      final res = await _serviceRetry(
        () => _client
            .from(_tableContacts)
            .update({
              'name': _ServiceValidators.sanitizePayload(contact.name, maxLength: _kMaxNameLength),
              'phone': contact.phone?.trim(),
              'thix_id': contact.thixId?.trim(),
              'photo_url': contact.photoUrl,
              'relation': contact.relation != null
                  ? _ServiceValidators.sanitizePayload(contact.relation, maxLength: _kMaxRelationLength)
                  : null,
              'circle': contact.circle,
              'priority': contact.priority,
              'verified': contact.verified,
              'available': contact.available,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', contact.id)
            .eq('owner_id', _uid!)
            .select()
            .single(),
        label: 'updateContact[${_ServiceValidators.maskId(contact.id)}]',
      );

      debugPrint('[SosService] ✓ updateContact: ${_ServiceValidators.maskId(contact.id)}');
      return SosContact.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[SosService] ❌ updateContact: $e');
      throw SosServiceException('Impossible de modifier le secours', e);
    }
  }

  Future<void> deleteContact(String contactId) async {
    _ensureAuth();
    if (!_ServiceValidators.isValidId(contactId)) {
      throw SosServiceException('ID contact invalide', null, 'INVALID_ID');
    }
    
    try {
      await _serviceRetry(
        () => _client
            .from(_tableContacts)
            .delete()
            .eq('id', contactId)
            .eq('owner_id', _uid!),
        label: 'deleteContact[${_ServiceValidators.maskId(contactId)}]',
      );
      debugPrint('[SosService] ✓ deleteContact: ${_ServiceValidators.maskId(contactId)}');
    } catch (e) {
      debugPrint('[SosService] ❌ deleteContact: $e');
      throw SosServiceException('Impossible de supprimer le secours', e);
    }
  }

  /// Recherche un profil THIX par son THIX ID
  Future<Map<String, dynamic>?> lookupProfileByThixId(String thixId) async {
    final normalized = thixId.trim().toUpperCase();
    if (normalized.isEmpty || normalized.length > _kMaxIdLength) {
      debugPrint('[SosService] ⚠️ Invalid THIX ID length');
      return null;
    }

    try {
      final res = await _serviceRetry(
        () => _client
            .from('profiles')
            .select('id, thix_id, full_name, avatar_url')
            .ilike('thix_id', normalized)
            .maybeSingle(),
        label: 'lookupProfileByThixId[$normalized]',
      );

      if (res == null) {
        debugPrint('[SosService] ℹ️ THIX ID not found: $normalized');
        return null;
      }
      debugPrint('[SosService] ✓ THIX ID found: $normalized');
      return Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint('[SosService] ❌ lookupProfileByThixId: $e');
      throw SosServiceException('Impossible de rechercher ce THIX ID', e);
    }
  }

  /// Ajout secours lié à un compte THIX
  Future<SosContact> addContactFromThixProfile({
    required String thixId,
    required String contactUserId,
    required String name,
    required int circle,
    String? photoUrl,
    String? phone,
    String? relation,
  }) async {
    _ensureAuth();
    if (!_ServiceValidators.isValidCircle(circle)) {
      throw SosServiceException('Cercle invalide (1, 2 ou 3)', null, 'INVALID_CIRCLE');
    }
    if (!_ServiceValidators.isValidId(contactUserId)) {
      throw SosServiceException('ID utilisateur invalide', null, 'INVALID_USER_ID');
    }

    final normalizedThixId = thixId.trim().toUpperCase();

    // Éviter les doublons
    final existing = await _serviceRetry(
      () => _client
          .from(_tableContacts)
          .select('id')
          .eq('owner_id', _uid!)
          .eq('thix_id', normalizedThixId)
          .eq('circle', circle)
          .maybeSingle(),
      label: 'checkDuplicate[$normalizedThixId]',
    );

    if (existing != null) {
      throw SosServiceException(
        'Ce secours est déjà dans le cercle $circle',
        null,
        'DUPLICATE_CONTACT',
      );
    }

    try {
      final res = await _serviceRetry(
        () => _client
            .from(_tableContacts)
            .insert({
              'owner_id': _uid,
              'name': _ServiceValidators.sanitizePayload(name, maxLength: _kMaxNameLength),
              'circle': circle,
              'phone': phone?.trim(),
              'thix_id': normalizedThixId,
              'photo_url': photoUrl,
              'relation': relation != null
                  ? _ServiceValidators.sanitizePayload(relation, maxLength: _kMaxRelationLength)
                  : null,
            })
            .select()
            .single(),
        label: 'addContactFromThix[$normalizedThixId]',
      );

      debugPrint('[SosService] ✓ addContactFromThix: $normalizedThixId (circle $circle)');
      return SosContact.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[SosService] ❌ addContactFromThixProfile: $e');
      throw SosServiceException('Impossible d\'ajouter le secours', e);
    }
  }

  /// Résout le user_id d'un contact
  Future<String?> resolveContactUserId(SosContact c) async {
    if (c.thixId == null || c.thixId!.isEmpty) return null;
    try {
      final profile = await lookupProfileByThixId(c.thixId!);
      return profile?['id'] as String?;
    } catch (e) {
      debugPrint('[SosService] ⚠️ resolveContactUserId failed: $e');
      return null;
    }
  }

  // ✅ FIX : throw au lieu de return null + timeout + logs structurés
  Future<String> createSosChat({
    required String incidentId,
    required String publicId,
    required List<String> participantUserIds,
  }) async {
    _ensureAuth();
    if (!_ServiceValidators.isValidId(incidentId)) {
      throw SosServiceException('ID incident invalide', null, 'INVALID_INCIDENT_ID');
    }
    
    final uid = _uid!;
    final conversationId = _generateUuid();
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      // 1. Créer conversation
      await _serviceRetry(
        () => _client.from('conversations').insert({
          'id': conversationId,
          'is_group': true,
          'group_name': 'THIX CHAT $publicId',
          'created_at': now,
          'updated_at': now,
        }),
        label: 'createConversation',
      );

      // 2. Ajouter victime (admin)
      await _serviceRetry(
        () => _client.from('conversation_participants').insert({
          'conversation_id': conversationId,
          'user_id': uid,
          'role': 'admin',
          'last_read_at': now,
        }),
        label: 'addAdminParticipant',
      );

      // 3. Ajouter autres participants
      final uniqueParticipants = participantUserIds.toSet()..remove(uid);
      for (final pid in uniqueParticipants) {
        if (!_ServiceValidators.isValidId(pid)) continue;
        try {
          await _serviceRetry(
            () => _client.from('conversation_participants').insert({
              'conversation_id': conversationId,
              'user_id': pid,
              'role': 'member',
              'last_read_at': now,
            }),
            label: 'addParticipant[${_ServiceValidators.maskId(pid)}]',
          );
        } catch (e) {
          debugPrint('[SosService] ⚠️ Failed to add participant ${_ServiceValidators.maskId(pid)}: $e');
        }
      }

      // 4. Message système (best effort)
      try {
        await _serviceRetry(
          () => _client.from('messages').insert({
            'conversation_id': conversationId,
            'sender_id': uid,
            'content': '🔴 SOS déclenché — $publicId\nRejoignez la chambre de crise.',
            'type': 'system',
            'created_at': now,
          }),
          label: 'createSystemMessage',
        );
      } catch (e) {
        debugPrint('[SosService] ⚠️ System message failed (non-critical): $e');
      }

      // 5. Link conversation to incident
      await _serviceRetry(
        () => _client.from(_tableIncidents).update({
          'chat_conversation_id': conversationId,
          'updated_at': now,
        }).eq('id', incidentId),
        label: 'linkChatToIncident',
      );

      await _logEvent(incidentId, 'CHAT_CREATED', {
        'conversation_id': conversationId,
        'participants_count': uniqueParticipants.length,
      });

      debugPrint('[SosService] ✓ Chat SOS created: ${_ServiceValidators.maskId(conversationId)}');
      return conversationId;
    } catch (e) {
      debugPrint('[SosService] ❌ createSosChat: $e');
      // ✅ FIX : throw au lieu de return null
      throw SosServiceException('Impossible de créer le chat SOS', e);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // INCIDENTS
  // ═══════════════════════════════════════════════════════════

  Future<SosIncident?> getActiveIncident() async {
    _ensureAuth();
    try {
      final res = await _serviceRetry(
        () => _client
            .from(_tableIncidents)
            .select()
            .eq('victim_id', _uid!)
            .not('status', 'in', '(cancelled,resolved,archived)')
            .order('started_at', ascending: false)
            .limit(1)
            .maybeSingle(),
        label: 'getActiveIncident',
      );

      if (res == null) return null;
      return SosIncident.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      // ✅ FIX : log structuré
      debugPrint('[SosService] ⚠️ getActiveIncident: $e');
      return null;
    }
  }

  Future<SosIncident?> getIncidentById(String id) async {
    _ensureAuth();
    if (!_ServiceValidators.isValidId(id)) {
      debugPrint('[SosService] ⚠️ getIncidentById: invalid id');
      return null;
    }
    try {
      final res = await _serviceRetry(
        () => _client
            .from(_tableIncidents)
            .select()
            .eq('id', id)
            .eq('victim_id', _uid!)
            .maybeSingle(),
        label: 'getIncidentById[${_ServiceValidators.maskId(id)}]',
      );
      if (res == null) return null;
      return SosIncident.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      // ✅ FIX : log structuré au lieu de catch silencieux
      debugPrint('[SosService] ⚠️ getIncidentById: $e');
      return null;
    }
  }

  /// Lecture secours : sans filtre victim_id (soumis au RLS)
  Future<SosIncident?> getIncidentForRescue(String id) async {
    _ensureAuth();
    if (!_ServiceValidators.isValidId(id)) {
      debugPrint('[SosService] ⚠️ getIncidentForRescue: invalid id');
      return null;
    }
    try {
      final res = await _serviceRetry(
        () => _client
            .from(_tableIncidents)
            .select()
            .eq('id', id)
            .maybeSingle(),
        label: 'getIncidentForRescue[${_ServiceValidators.maskId(id)}]',
      );
      if (res == null) return null;
      return SosIncident.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[SosService] ⚠️ getIncidentForRescue: $e');
      return null;
    }
  }

  Future<SosIncident?> findActiveByVictim(String victimId) async {
    _ensureAuth();
    if (!_ServiceValidators.isValidId(victimId)) {
      debugPrint('[SosService] ⚠️ findActiveByVictim: invalid victimId');
      return null;
    }
    try {
      final res = await _serviceRetry(
        () => _client
            .from(_tableIncidents)
            .select()
            .eq('victim_id', victimId)
            .not('status', 'in', '(cancelled,resolved,archived)')
            .order('started_at', ascending: false)
            .limit(1)
            .maybeSingle(),
        label: 'findActiveByVictim[${_ServiceValidators.maskId(victimId)}]',
      );
      if (res == null) return null;
      return SosIncident.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[SosService] ⚠️ findActiveByVictim: $e');
      return null;
    }
  }

  Future<List<SosIncident>> getHistory({int limit = _kDefaultHistoryLimit}) async {
    _ensureAuth();
    final safeLimit = _ServiceValidators.clampLimit(limit, _kDefaultHistoryLimit, _kMaxHistoryLimit);
    
    try {
      final res = await _serviceRetry(
        () => _client
            .from(_tableIncidents)
            .select()
            .eq('victim_id', _uid!)
            .order('started_at', ascending: false)
            .limit(safeLimit),
        label: 'getHistory',
      );

      final list = (res as List)
          .map((e) => SosIncident.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      debugPrint('[SosService] ✓ getHistory: ${list.length} incidents');
      return list;
    } catch (e) {
      debugPrint('[SosService] ❌ getHistory: $e');
      throw SosServiceException('Impossible de charger l\'historique', e);
    }
  }

  // ✅ FIX P0 : anti-race + timeout global + logs PII-safe
  Future<SosIncident> triggerSos() async {
    _ensureAuth();

    // Anti-race : empêche double-trigger simultané
    if (_isTriggering) {
      debugPrint('[SosService] ⚠️ triggerSos already in progress');
      throw SosServiceException('Un SOS est déjà en cours de déclenchement', null, 'TRIGGER_IN_PROGRESS');
    }
    _isTriggering = true;

    try {
      // Vérifier SOS actif existant
      final existing = await getActiveIncident();
      if (existing != null) {
        throw SosServiceException(
          'Un SOS est déjà en cours (${existing.publicId})',
          null,
          'SOS_ALREADY_ACTIVE',
        );
      }

      // Récupérer position GPS (best effort)
      Position? position;
      try {
        var permission = await Geolocator.checkPermission().timeout(_kGeolocatorTimeout);
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission().timeout(_kGeolocatorTimeout);
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: _kGeolocatorTimeout,
            ),
          );
          debugPrint('[SosService] 📍 GPS acquired');
        }
      } catch (e) {
        debugPrint('[SosService] ⚠️ GPS acquisition failed (non-critical): $e');
      }

      final publicId = _generatePublicId();
      final now = DateTime.now().toIso8601String();

      // ✅ RGPD : coordonnées arrondies dans les logs
      final safeLat = _ServiceValidators.roundCoordinate(position?.latitude);
      final safeLng = _ServiceValidators.roundCoordinate(position?.longitude);

      try {
        final row = await _serviceRetry(
          () => _client
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
              .single(),
          label: 'createIncident',
          timeout: _kTriggerTimeout,
        );

        final incident = SosIncident.fromJson(Map<String, dynamic>.from(row));

        // Insérer point GPS initial
        if (position != null) {
          try {
            await _serviceRetry(
              () => _client.from(_tableLocations).insert({
                'incident_id': incident.id,
                'lat': position.latitude,
                'lng': position.longitude,
                'accuracy_m': position.accuracy,
                'speed_mps': position.speed,
                'heading_deg': position.heading,
              }),
              label: 'insertInitialLocation',
            );
          } catch (e) {
            debugPrint('[SosService] ⚠️ Initial location insert failed: $e');
          }
        }

        await _logEvent(incident.id, 'SOS_CREATED', {
          'public_id': publicId,
          'lat': safeLat, // ✅ RGPD : arrondi
          'lng': safeLng,
        });

        // Escalade automatique Cercle 1
        await _serviceRetry(
          () => _client.from(_tableIncidents).update({
            'status': SosStatus.callingCircle1.dbValue,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', incident.id),
          label: 'escalateCircle1',
        );

        await _logEvent(incident.id, 'CIRCLE_1_STARTED', {});

        debugPrint('[SosService] 🚨 SOS triggered: $publicId');
        return incident.copyWith(status: SosStatus.callingCircle1);
      } catch (e) {
        debugPrint('[SosService] ❌ triggerSos: $e');
        throw SosServiceException('Échec du déclenchement SOS', e);
      }
    } finally {
      _isTriggering = false;
    }
  }

  Future<void> heartbeat(String incidentId, {int? batteryPct}) async {
    _ensureAuth();
    if (!_ServiceValidators.isValidId(incidentId)) {
      debugPrint('[SosService] ⚠️ heartbeat: invalid incidentId');
      return;
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('[SosService] ⚠️ heartbeat GPS failed (non-critical): $e');
    }

    final now = DateTime.now().toIso8601String();
    final patch = <String, dynamic>{
      'heartbeat_at': now,
      'updated_at': now,
    };
    if (batteryPct != null) patch['battery_pct'] = batteryPct.clamp(0, 100);

    if (position != null) {
      patch['last_lat'] = position.latitude;
      patch['last_lng'] = position.longitude;
      patch['last_accuracy_m'] = position.accuracy;
      patch['last_location_at'] = now;

      // ✅ FIX : log structuré au lieu de catch silencieux
      try {
        await _serviceRetry(
          () => _client.from(_tableLocations).insert({
            'incident_id': incidentId,
            'lat': position.latitude,
            'lng': position.longitude,
            'accuracy_m': position.accuracy,
            'speed_mps': position.speed,
            'heading_deg': position.heading,
          }),
          label: 'heartbeatLocation',
        );
      } catch (e) {
        debugPrint('[SosService] ⚠️ heartbeat location insert failed: $e');
      }
    }

    try {
      await _serviceRetry(
        () => _client
            .from(_tableIncidents)
            .update(patch)
            .eq('id', incidentId)
            .eq('victim_id', _uid!),
        label: 'heartbeat[${_ServiceValidators.maskId(incidentId)}]',
      );
    } catch (e) {
      debugPrint('[SosService] ❌ heartbeat update failed: $e');
    }
  }

  Future<void> escalateToCircle(String incidentId, int circle) async {
    _ensureAuth();
    if (!_ServiceValidators.isValidId(incidentId)) {
      throw SosServiceException('ID incident invalide', null, 'INVALID_INCIDENT_ID');
    }
    if (!_ServiceValidators.isValidCircle(circle)) {
      debugPrint('[SosService] ⚠️ escalateToCircle: invalid circle $circle');
      return;
    }

    final status = circle == 1
        ? SosStatus.callingCircle1
        : circle == 2
            ? SosStatus.callingCircle2
            : SosStatus.callingCircle3;

    try {
      await _serviceRetry(
        () => _client.from(_tableIncidents).update({
          'status': status.dbValue,
          'active_circle': circle,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', incidentId).eq('victim_id', _uid!),
        label: 'escalateToCircle[$circle]',
      );

      await _logEvent(incidentId, 'CIRCLE_${circle}_STARTED', {'circle': circle});
      debugPrint('[SosService] ✓ Escalated to circle $circle');
    } catch (e) {
      debugPrint('[SosService] ❌ escalateToCircle[$circle]: $e');
      throw SosServiceException('Échec escalade cercle $circle', e);
    }
  }

  Future<void> resolveIncident(String incidentId) async {
    _ensureAuth();
    if (!_ServiceValidators.isValidId(incidentId)) {
      throw SosServiceException('ID incident invalide', null, 'INVALID_INCIDENT_ID');
    }
    
    try {
      await _serviceRetry(
        () => _client.from(_tableIncidents).update({
          'status': SosStatus.resolved.dbValue,
          'resolved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', incidentId).eq('victim_id', _uid!),
        label: 'resolveIncident[${_ServiceValidators.maskId(incidentId)}]',
      );

      await _logEvent(incidentId, 'SOS_RESOLVED', {});
      debugPrint('[SosService] ✓ Incident resolved');
    } catch (e) {
      debugPrint('[SosService] ❌ resolveIncident: $e');
      throw SosServiceException('Impossible de terminer le SOS', e);
    }
  }

  Future<void> cancelIncident(String incidentId) async {
    _ensureAuth();
    if (!_ServiceValidators.isValidId(incidentId)) {
      throw SosServiceException('ID incident invalide', null, 'INVALID_INCIDENT_ID');
    }
    
    try {
      await _serviceRetry(
        () => _client.from(_tableIncidents).update({
          'status': SosStatus.cancelled.dbValue,
          'resolved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', incidentId).eq('victim_id', _uid!),
        label: 'cancelIncident[${_ServiceValidators.maskId(incidentId)}]',
      );

      await _logEvent(incidentId, 'SOS_CANCELLED', {});
      debugPrint('[SosService] ✓ Incident cancelled');
    } catch (e) {
      debugPrint('[SosService] ❌ cancelIncident: $e');
      throw SosServiceException('Impossible d\'annuler le SOS', e);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // LOCATIONS / EVENTS
  // ═══════════════════════════════════════════════════════════

  Future<List<SosLocationPoint>> getLocations(
    String incidentId, {
    int limit = _kDefaultLocationsLimit,
  }) async {
    _ensureAuth();
    if (!_ServiceValidators.isValidId(incidentId)) return [];
    final safeLimit = _ServiceValidators.clampLimit(limit, _kDefaultLocationsLimit, _kMaxLocationsLimit);
    
    try {
      final res = await _serviceRetry(
        () => _client
            .from(_tableLocations)
            .select()
            .eq('incident_id', incidentId)
            .order('captured_at', ascending: false)
            .limit(safeLimit),
        label: 'getLocations[${_ServiceValidators.maskId(incidentId)}]',
      );

      return (res as List)
          .map((e) => SosLocationPoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      // ✅ FIX : log structuré au lieu de catch silencieux
      debugPrint('[SosService] ⚠️ getLocations: $e');
      return [];
    }
  }

  Future<List<SosEvent>> getEvents(String incidentId, {int limit = _kDefaultEventsLimit}) async {
    _ensureAuth();
    if (!_ServiceValidators.isValidId(incidentId)) return [];
    final safeLimit = _ServiceValidators.clampLimit(limit, _kDefaultEventsLimit, _kMaxEventsLimit);
    
    try {
      final res = await _serviceRetry(
        () => _client
            .from(_tableEvents)
            .select()
            .eq('incident_id', incidentId)
            .order('created_at', ascending: false)
            .limit(safeLimit),
        label: 'getEvents[${_ServiceValidators.maskId(incidentId)}]',
      );

      return (res as List)
          .map((e) => SosEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      // ✅ FIX : log structuré au lieu de catch silencieux
      debugPrint('[SosService] ⚠️ getEvents: $e');
      return [];
    }
  }

  // ✅ FIX : timeout + log structuré
  Future<void> _logEvent(
    String incidentId,
    String type,
    Map<String, dynamic> payload,
  ) async {
    if (!_ServiceValidators.isValidId(incidentId)) {
      debugPrint('[SosService] ⚠️ _logEvent: invalid incidentId');
      return;
    }
    try {
      await _serviceRetry(
        () => _client.from(_tableEvents).insert({
          'incident_id': incidentId,
          'type': type,
          'payload': payload,
        }),
        label: 'logEvent[$type]',
        maxRetries: 0, // log events ne doivent pas retry (éviter spam)
      );
    } catch (e) {
      debugPrint('[SosService] ⚠️ _logEvent[$type] failed: $e');
    }
  }
}

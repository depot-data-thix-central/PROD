// lib/presentation/thix_weeding/pages/guest/group_gifts_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cadeaux_page.dart';

final groupGiftsRepositoryProvider = Provider<GroupGiftsRepository>((ref) => GroupGiftsRepository());

class GroupGiftsRepository {
  final _c = Supabase.instance.client;

  Future<List<GroupGift>> getGroupGifts(String weddingId) async {
    final res = await _c
        .from('thix_weeding_group_gifts')
        .select('*, participants:thix_weeding_group_gift_participants(thix_id)')
        .eq('wedding_id', weddingId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res).map((j) {
      final participants = (j['participants'] as List? ?? [])
          .map((p) => (p as Map)['thix_id'] as String)
          .toList();
      return GroupGift(
        id: j['id'] as String,
        name: j['name'] as String,
        imageUrl: j['image_url'] as String? ?? '',
        targetAmount: (j['target_amount'] as num).toDouble(),
        currentAmount: (j['current_amount'] as num? ?? 0).toDouble(),
        participants: participants,
        chatId: j['chat_id'] as String?,
        organizerName: j['organizer_name'] as String? ?? 'Anonyme',
      );
    }).toList();
  }

  Future<void> joinGroupGift(String groupGiftId, String thixId) async {
    await _c.from('thix_weeding_group_gift_participants').upsert({
      'group_gift_id': groupGiftId,
      'thix_id': thixId,
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> createGroupGift({
    required String weddingId,
    required String name,
    required double targetAmount,
    required String organizerThixId,
  }) async {
    // 1. Créer le cadeau de groupe
    final res = await _c
        .from('thix_weeding_group_gifts')
        .insert({
          'wedding_id': weddingId,
          'name': name,
          'target_amount': targetAmount,
          'current_amount': 0,
          'organizer_thix_id': organizerThixId,
          'organizer_name': 'Moi', // TODO: Récupérer vrai nom
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    final groupId = res['id'] as String;

    // 2. Auto-inscrire l'organisateur
    await joinGroupGift(groupId, organizerThixId);

    // 3. Créer le chat de groupe Thix Chat
    final chatRes = await _c
        .from('thix_weeding_chats')
        .insert({
          'wedding_id': weddingId,
          'type': 'group_gift',
          'reference_id': groupId,
          'title': '💬 Chat : $name',
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    // 4. Associer le chat au cadeau
    await _c.from('thix_weeding_group_gifts').update({'chat_id': chatRes['id']}).eq('id', groupId);
  }

  Future<void> proposeSpecialGift({
    required String weddingId,
    required String name,
    required String description,
    required double budget,
    required String proposerThixId,
  }) async {
    await _c.from('thix_weeding_gift_proposals').insert({
      'wedding_id': weddingId,
      'name': name,
      'description': description,
      'budget_estimate': budget,
      'proposer_thix_id': proposerThixId,
      'status': 'pending_approval',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

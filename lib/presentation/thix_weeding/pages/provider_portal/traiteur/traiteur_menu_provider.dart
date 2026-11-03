// lib/presentation/thix_weeding/pages/provider_portal/traiteur/traiteur_menu_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'menu_models.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// THIX WEDDING — PROVIDER MENU TRAITEUR (Riverpod + Supabase)
/// ═══════════════════════════════════════════════════════════════════════

final supabaseClient = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final menuProvider = AsyncNotifierProvider.autoDispose.family<MenuNotifier, WeddingMenu?, String>(
  MenuNotifier.new,
);

class MenuNotifier extends AutoDisposeFamilyAsyncNotifier<WeddingMenu?, String> {
  SupabaseClient get _client => ref.read(supabaseClient);

  @override
  Future<WeddingMenu?> build(String orderId) async {
    return _fetchMenu(orderId);
  }

  Future<WeddingMenu?> _fetchMenu(String orderId) async {
    try {
      final response = await _client
          .from('wedding_menus')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();

      if (response == null) return null;
      return WeddingMenu.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erreur lors du chargement du menu: $e');
    }
  }

  Future<WeddingMenu> createMenu({
    required String orderId,
    required String providerId,
    required String title,
    String? description,
    required int maxGuests,
    double? pricePerPerson,
    Map<String, dynamic>? additionalInfo,
  }) async {
    try {
      final menu = WeddingMenu(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        orderId: orderId,
        providerId: providerId,
        title: title,
        description: description,
        items: [],
        status: MenuStatus.draft,
        createdAt: DateTime.now(),
        maxGuests: maxGuests,
        pricePerPerson: pricePerPerson,
        additionalInfo: additionalInfo,
      );

      final response = await _client
          .from('wedding_menus')
          .insert(menu.toJson())
          .select()
          .single();

      final newMenu = WeddingMenu.fromJson(response as Map<String, dynamic>);
      state = AsyncValue.data(newMenu);
      
      return newMenu;
    } catch (e) {
      throw Exception('Erreur lors de la création du menu: $e');
    }
  }

  Future<void> addMenuItem({
    required String menuId,
    required MenuItem item,
  }) async {
    try {
      final menu = state.value;
      if (menu == null) return;

      final updatedItems = [...menu.items, item];
      final updatedMenu = menu.copyWith(items: updatedItems);

      await _client
          .from('wedding_menus')
          .update({'items': updatedMenu.items.map((i) => i.toJson()).toList()})
          .eq('id', menuId);

      state = AsyncValue.data(updatedMenu);
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout du plat: $e');
    }
  }

  Future<void> updateMenuItem({
    required String menuId,
    required String itemId,
    required MenuItem updatedItem,
  }) async {
    try {
      final menu = state.value;
      if (menu == null) return;

      final updatedItems = menu.items.map((item) {
        if (item.id == itemId) return updatedItem;
        return item;
      }).toList();

      final updatedMenu = menu.copyWith(items: updatedItems);

      await _client
          .from('wedding_menus')
          .update({'items': updatedMenu.items.map((i) => i.toJson()).toList()})
          .eq('id', menuId);

      state = AsyncValue.data(updatedMenu);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du plat: $e');
    }
  }

  Future<void> removeMenuItem({
    required String menuId,
    required String itemId,
  }) async {
    try {
      final menu = state.value;
      if (menu == null) return;

      final updatedItems = menu.items.where((item) => item.id != itemId).toList();
      final updatedMenu = menu.copyWith(items: updatedItems);

      await _client
          .from('wedding_menus')
          .update({'items': updatedMenu.items.map((i) => i.toJson()).toList()})
          .eq('id', menuId);

      state = AsyncValue.data(updatedMenu);
    } catch (e) {
      throw Exception('Erreur lors de la suppression du plat: $e');
    }
  }

  Future<void> submitForValidation({
    required String menuId,
    required String providerId,
  }) async {
    try {
      final menu = state.value;
      if (menu == null) return;

      final updatedMenu = menu.copyWith(
        status: MenuStatus.submitted,
        submittedAt: DateTime.now(),
      );

      await _client
          .from('wedding_menus')
          .update({
            'status': MenuStatus.submitted.name,
            'submitted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', menuId);

      state = AsyncValue.data(updatedMenu);

      // Créer une notification pour le staff
      await _createStaffNotification(
        menuId: menuId,
        providerId: providerId,
        type: 'menu_validation_request',
        message: 'Nouveau menu à valider',
      );
    } catch (e) {
      throw Exception('Erreur lors de la soumission: $e');
    }
  }

  Future<void> validateMenu({
    required String menuId,
    required String staffId,
    required String staffName,
    required bool approved,
    String? comment,
    List<String>? requestedChanges,
  }) async {
    try {
      final menu = state.value;
      if (menu == null) return;

      final validation = MenuValidation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        menuId: menuId,
        staffId: staffId,
        staffName: staffName,
        approved: approved,
        comment: comment,
        validatedAt: DateTime.now(),
        requestedChanges: requestedChanges,
      );

      // Sauvegarder la validation
      await _client
          .from('menu_validations')
          .insert(validation.toJson());

      final updatedMenu = menu.copyWith(
        status: approved ? MenuStatus.validated : MenuStatus.draft,
        validatedAt: approved ? DateTime.now() : null,
        validationNote: comment,
      );

      await _client
          .from('wedding_menus')
          .update({
            'status': updatedMenu.status.name,
            'validated_at': updatedMenu.validatedAt?.toIso8601String(),
            'validation_note': updatedMenu.validationNote,
          })
          .eq('id', menuId);

      state = AsyncValue.data(updatedMenu);
    } catch (e) {
      throw Exception('Erreur lors de la validation: $e');
    }
  }

  Future<void> publishMenu({
    required String menuId,
    required String orderId,
  }) async {
    try {
      final menu = state.value;
      if (menu == null) return;

      final updatedMenu = menu.copyWith(
        status: MenuStatus.public,
        isPublic: true,
        publishedAt: DateTime.now(),
      );

      await _client
          .from('wedding_menus')
          .update({
            'status': MenuStatus.public.name,
            'is_public': true,
            'published_at': DateTime.now().toIso8601String(),
          })
          .eq('id', menuId);

      // Mettre à jour la commande
      await _client
          .from('wedding_orders')
          .update({
            'menu_id': menuId,
            'menu_public': true,
          })
          .eq('id', orderId);

      state = AsyncValue.data(updatedMenu);
    } catch (e) {
      throw Exception('Erreur lors de la publication: $e');
    }
  }

  Future<void> finalizeMenu({
    required String menuId,
    required String orderId,
  }) async {
    try {
      final menu = state.value;
      if (menu == null) return;

      final updatedMenu = menu.copyWith(
        status: MenuStatus.finalized,
        isPublic: false,
      );

      await _client
          .from('wedding_menus')
          .update({
            'status': MenuStatus.finalized.name,
            'is_public': false,
          })
          .eq('id', menuId);

      state = AsyncValue.data(updatedMenu);
    } catch (e) {
      throw Exception('Erreur lors de la finalisation: $e');
    }
  }

  Future<void> _createStaffNotification({
    required String menuId,
    required String providerId,
    required String type,
    required String message,
  }) async {
    try {
      await _client.from('staff_notifications').insert({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'menu_id': menuId,
        'provider_id': providerId,
        'type': type,
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });
    } catch (e) {
      // Ignorer les erreurs de notification
      print('Erreur notification: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PROVIDER VOTES INVITÉS
// ═══════════════════════════════════════════════════════════════════════

final guestVotesProvider = AsyncNotifierProvider.autoDispose.family<GuestVotesNotifier, List<GuestVote>, String>(
  GuestVotesNotifier.new,
);

class GuestVotesNotifier extends AutoDisposeFamilyAsyncNotifier<List<GuestVote>, String> {
  SupabaseClient get _client => ref.read(supabaseClient);

  @override
  Future<List<GuestVote>> build(String menuId) async {
    return _fetchVotes(menuId);
  }

  Future<List<GuestVote>> _fetchVotes(String menuId) async {
    try {
      final response = await _client
          .from('guest_votes')
          .select()
          .eq('menu_id', menuId)
          .order('voted_at', ascending: false);

      return response
          .map((json) => GuestVote.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors du chargement des votes: $e');
    }
  }

  Future<void> submitVote({
    required String menuId,
    required String guestId,
    required String guestName,
    required String guestEmail,
    required Map<String, List<String>> choices,
    String? comment,
    List<String>? dietaryRestrictions,
  }) async {
    try {
      final vote = GuestVote(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        guestId: guestId,
        guestName: guestName,
        guestEmail: guestEmail,
        menuId: menuId,
        choices: choices,
        comment: comment,
        votedAt: DateTime.now(),
        dietaryRestrictions: dietaryRestrictions,
      );

      await _client.from('guest_votes').insert(vote.toJson());

      final votes = await _fetchVotes(menuId);
      state = AsyncValue.data(votes);
    } catch (e) {
      throw Exception('Erreur lors du vote: $e');
    }
  }

  Future<void> updateVote({
    required String voteId,
    required Map<String, List<String>> choices,
    String? comment,
    List<String>? dietaryRestrictions,
  }) async {
    try {
      await _client
          .from('guest_votes')
          .update({
            'choices': choices,
            'comment': comment,
            'dietary_restrictions': dietaryRestrictions,
            'voted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', voteId);

      final votes = await _fetchVotes(arg);
      state = AsyncValue.data(votes);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du vote: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PROVIDER STATISTIQUES MENU
// ═══════════════════════════════════════════════════════════════════════

final menuStatsProvider = FutureProvider.autoDispose.family<MenuStatistics, String>((ref, menuId) async {
  final client = ref.read(supabaseClient);

  try {
    // Récupérer le menu
    final menuResponse = await client
        .from('wedding_menus')
        .select()
        .eq('id', menuId)
        .single();

    final menu = WeddingMenu.fromJson(menuResponse as Map<String, dynamic>);

    // Récupérer les votes
    final votesResponse = await client
        .from('guest_votes')
        .select()
        .eq('menu_id', menuId);

    final votes = votesResponse
        .map((json) => GuestVote.fromJson(json as Map<String, dynamic>))
        .toList();

    // Calculer les statistiques
    final votesByCategory = <String, int>{};
    final itemVotes = <String, Map<String, int>>{};

    for (var vote in votes) {
      for (var entry in vote.choices.entries) {
        final category = entry.key;
        votesByCategory[category] = (votesByCategory[category] ?? 0) + 1;

        if (!itemVotes.containsKey(category)) {
          itemVotes[category] = {};
        }

        for (var itemId in entry.value) {
          itemVotes[category]![itemId] = (itemVotes[category]![itemId] ?? 0) + 1;
        }
      }
    }

    return MenuStatistics(
      menuId: menuId,
      totalVotes: votes.length,
      totalGuests: menu.maxGuests,
      votesByCategory: votesByCategory,
      itemVotes: itemVotes,
      lastUpdated: DateTime.now(),
    );
  } catch (e) {
    throw Exception('Erreur lors du calcul des statistiques: $e');
  }
});

// ═══════════════════════════════════════════════════════════════════════
// PROVIDERS DÉRIVÉS
// ═══════════════════════════════════════════════════════════════════════

final menusAwaitingValidationProvider = FutureProvider.autoDispose<List<WeddingMenu>>((ref) async {
  final client = ref.read(supabaseClient);

  try {
    final response = await client
        .from('wedding_menus')
        .select()
        .eq('status', MenuStatus.submitted.name)
        .order('submitted_at', ascending: true);

    return response
        .map((json) => WeddingMenu.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (e) {
    throw Exception('Erreur: $e');
  }
});

final publicMenusProvider = FutureProvider.autoDispose<List<WeddingMenu>>((ref) async {
  final client = ref.read(supabaseClient);

  try {
    final response = await client
        .from('wedding_menus')
        .select()
        .eq('is_public', true)
        .order('published_at', ascending: false);

    return response
        .map((json) => WeddingMenu.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (e) {
    throw Exception('Erreur: $e');
  }
});

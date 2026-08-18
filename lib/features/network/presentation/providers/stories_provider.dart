import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/network_story.dart';

// Stream temps réel mais filtré à tes connexions seulement
final activeStoriesProvider = StreamProvider<List<NetworkStory>>((ref) async* {
  final supabase = Supabase.instance.client;
  final uid = supabase.auth.currentUser!.id;

  // 1. tes connexions
  final conn = await supabase.from('connections').select('connection_id, friend_id, connected_user_id').eq('user_id', uid).eq('status','accepted');
  final ids = <String>{uid};
  for(final r in conn as List){ ids.add((r['connection_id']?? r['friend_id']?? r['connected_user_id']) as String); }

  // 2. stream limité 50 stories actives
  final stream = supabase.from('stories')
   .stream(primaryKey: ['id'])
   .eq('is_active', true)
   .order('created_at', ascending: false)
   .limit(50)
   .map((list) => list.map((j) => NetworkStory.fromJson(j)).where((s) => ids.contains(s.userId) && s.expiresAt.isAfter(DateTime.now())).toList());

  await for(final data in stream){ yield data; }
});

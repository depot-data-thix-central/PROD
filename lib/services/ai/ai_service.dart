import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

// Les 3 modèles disponibles que nous avons configurés
enum AiProvider { openai, anthropic, mistral }

class AiService {
  final SupabaseClient _supabase;

  AiService(this._supabase);

  /// Envoie un message à l'IA via la Edge Function
  Future<String> askAi({
    required String prompt,
    AiProvider provider = AiProvider.openai, // OpenAI par défaut
    String? systemPrompt,
    String? model,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-chat',
        body: {
          'provider': provider.name,
          'prompt': prompt,
          'systemPrompt': systemPrompt,
          'model': model,
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('error')) {
          throw Exception(data['error']);
        }
        return data['reply'] as String;
      } else {
        throw Exception('Erreur de communication avec l\'IA (Code ${response.status})');
      }
    } catch (e) {
      debugPrint('❌ Erreur AiService: $e');
      rethrow;
    }
  }
}

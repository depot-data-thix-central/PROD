import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// OpenAI proxy integration for THIX ID.
class OpenAiConfig {
  static const apiKey = String.fromEnvironment('OPENAI_PROXY_API_KEY');
  static const endpoint = String.fromEnvironment('OPENAI_PROXY_ENDPOINT');

  static bool get isConfigured => apiKey.trim().isNotEmpty && endpoint.trim().isNotEmpty;

  static Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  static Future<List<Map<String, dynamic>>> recommendJobs({
    required Map<String, dynamic> userProfile,
    required List<Map<String, dynamic>> jobs,
    int limit = 8,
  }) async {
    if (!isConfigured) return const [];
    final safeLimit = limit.clamp(1, 20);

    final payload = {
      'model': 'gpt-4o-mini',
      'temperature': 0.35,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are an AI job-matching engine for THIX ID (African verified employment). Output MUST be a JSON object only.'
        },
        {
          'role': 'user',
          'content': jsonEncode({
            'task': 'rank_jobs',
            'output_schema': {
              'recommendations': [
                {
                  'job_id': 'string',
                  'score': 0,
                  'reasons': ['string'],
                  'missing_skills': ['string'],
                  'suggested_trainings': ['string'],
                  'fake_job_risk': 'low|medium|high',
                  'suggested_salary_range': 'string'
                }
              ]
            },
            'constraints': {
              'max_recommendations': safeLimit,
              'only_use_job_ids_from_input': true,
              'prefer_verified_employers': true,
            },
            'user_profile': userProfile,
            'jobs': jobs,
          })
        }
      ],
    };

    try {
      final uri = Uri.parse(endpoint);
      final res = await http.post(uri, headers: _headers(), body: jsonEncode(payload));
      final bytes = res.bodyBytes;
      final text = utf8.decode(bytes);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('OpenAiConfig.recommendJobs failed status=${res.statusCode} body=$text');
        return const [];
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) return const [];
      final content = decoded['choices']?[0]?['message']?['content'];
      if (content is! String) return const [];
      final obj = jsonDecode(content);
      if (obj is! Map) return const [];
      final recs = obj['recommendations'];
      if (recs is! List) return const [];
      return recs.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
    } catch (e) {
      debugPrint('OpenAiConfig.recommendJobs error=$e');
      return const [];
    }
  }
}

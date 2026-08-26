import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/business_plan_config.dart';

class BpConfigRepository {
  BpConfigRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<BusinessPlanConfig?> getByProject(String projectCode) async {
    final row = await _client
        .from('thix_bp_config')
        .select()
        .eq('project_code', projectCode)
        .maybeSingle();
    if (row == null) return null;
    return BusinessPlanConfig.fromJson(Map<String, dynamic>.from(row));
  }

  Future<BusinessPlanConfig> upsert(BusinessPlanConfig config) async {
    final userId = _client.auth.currentUser?.id;
    final payload = config.toJson();
    if (userId != null) payload['owner_id'] = userId;

    final row = await _client
        .from('thix_bp_config')
        .upsert(payload, onConflict: 'project_code')
        .select()
        .single();

    return BusinessPlanConfig.fromJson(Map<String, dynamic>.from(row));
  }

  /// Seed Execution depuis la config Supabase (pas de mock)
  Future<void> seedExecution(String projectCode) async {
    final config = await getByProject(projectCode);
    if (config == null) return;

    final capital = config.initialCapital ?? 0.0;
    if (capital <= 0) return;

    // Vérifier si un capital a déjà été enregistré pour ce projet
    final existing = await _client
        .from('thix_execution_finances')
        .select('id')
        .eq('project_code', projectCode)
        .eq('type', 'capital')
        .eq('category', 'Apport fondateur (BP Pre-Flight)')
        .maybeSingle();

    if (existing != null) return; // déjà seedé

    await _client.from('thix_execution_finances').insert({
      'project_code': projectCode,
      'type': 'capital',
      'category': 'Apport fondateur (BP Pre-Flight)',
      'amount': capital,
      'currency': 'USD',
      'description': 'Capital initial depuis thix_bp_config',
      'date': DateTime.now().toIso8601String(),
    });

    // Recalcul trésorerie simple
    final txs = await _client
        .from('thix_execution_finances')
        .select('type, amount')
        .eq('project_code', projectCode);

    double treasury = 0;
    for (final t in (txs as List)) {
      final amount = (t['amount'] as num).toDouble();
      final type = t['type'] as String? ?? '';
      if (type == 'income' || type == 'capital') {
        treasury += amount;
      } else if (type == 'expense') {
        treasury -= amount;
      }
    }

    await _client.from('thix_execution_projects').upsert({
      'project_code': projectCode,
      'treasury': treasury,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'project_code');
  }
}

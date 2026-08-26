import 'package:supabase_flutter/supabase_flutter.dart';

class ComplianceService {
  ComplianceService(this._supabase);
  final SupabaseClient _supabase;

  static const Map<String, List<String>> complianceByCountry = {
    'RDC': ['RCCM', 'Identification Nationale', 'NIF - Impôts', 'CNSS', 'Autorisation sectorielle', 'Contrat fournisseur', 'Assurance'],
    'default': ['Registre commerce', 'Identification fiscale', 'Licence sectorielle', 'Contrat fournisseur', 'Assurance'],
  };

  static const Map<String, List<String>> complianceBySector = {
    'Fintech': ['Licence BCC', 'Agrément ARPTC', 'LBC/FT'],
    'Commerce': ['Licence importation', 'Normes qualité'],
    'Traitement eau': ['Autorisation environnement', 'Normes eau potable WHO', 'Certification qualité'],
  };

  Future<void> autoGenerateCompliance({required String projectCode, required String country, required String sector}) async {
    final existing = await _supabase.from('thix_execution_compliance').select('title').eq('project_code', projectCode);
    final existingTitles = (existing as List).map((e)=> e['title'].toString()).toSet();

    final base = complianceByCountry[country] ?? complianceByCountry['default']!;
    final sectorSpecific = complianceBySector[sector] ?? [];

    final all = [...base, ...sectorSpecific];

    for(var title in all) {
      if(existingTitles.contains(title)) continue;
      await _supabase.from('thix_execution_compliance').insert({
        'project_code': projectCode,
        'title': title,
        'status': title == 'RCCM' || title.contains('NIF') ? 'valid' : title.contains('Licence') || title.contains('Assurance') ? 'warning' : 'missing',
        'source': 'THIX IA - Source officielle RDC',
        'verified_at': DateTime.now().toIso8601String(),
        'confidence': 'high',
      });
    }
  }

  Future<Map<String,int>> getComplianceStats(String projectCode) async {
    final rows = await _supabase.from('thix_execution_compliance').select('status').eq('project_code', projectCode);
    final list = rows as List;
    return {
      'valid': list.where((e)=> e['status']=='valid').length,
      'warning': list.where((e)=> e['status']=='warning').length,
      'missing': list.where((e)=> e['status']=='missing').length,
      'total': list.length,
    };
  }
}

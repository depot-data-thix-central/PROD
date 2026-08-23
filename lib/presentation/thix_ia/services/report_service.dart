// lib/presentation/thix_ia/services/report_service.dart
import '../datasources/thix_ia_remote_datasource.dart';
import '../models/report.dart';

class ReportService {
  ReportService(this._remote);
  final ThixIaRemoteDatasource _remote;

  // GET ALL REPORTS
  Future<List<Report>> getReports(String projectCode) async {
    try {
      // _remote.getReports renvoie déjà une List<Report>, pas besoin de fromJson !
      final reports = await _remote.getReports(projectCode);
      
      reports.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return reports;
    } catch (e) {
      throw Exception('getReports failed: $e');
    }
  }

  // GET SINGLE REPORT
  Future<Report?> getReport(String projectCode, String reportId) async {
    try {
      // Comme _remote.getReport n'est pas dans l'interface, on filtre localement
      final reports = await getReports(projectCode);
      try {
        return reports.firstWhere((r) => r.id == reportId);
      } catch (_) {
        return null; // Aucun rapport trouvé avec cet ID
      }
    } catch (e) {
      throw Exception('getReport $reportId failed: $e');
    }
  }

  // GENERATE BUSINESS PLAN - Full dossier PDF
  Future<Report> generateBusinessPlan(String projectCode) async {
    try {
      return await _remote.createReport({
        'project_code': projectCode,
        'type': 'business_plan',
        'title': 'Business Plan - $projectCode',
        'params': {'sections': ['executive_summary', 'market_analysis', 'business_model', 'financial_forecast', 'go_to_market', 'team', 'risks']},
      });
    } catch (e) {
      throw Exception('generateBusinessPlan $projectCode failed: $e');
    }
  }

  // GENERATE MARKET STUDY
  Future<Report> generateMarketStudy(String projectCode) async {
    try {
      return await _remote.createReport({
        'project_code': projectCode,
        'type': 'market_study',
        'title': 'Étude de Marché - $projectCode',
        'params': {'sources': ['banque_mondiale', 'ins_rdc', 'documents_rag'], 'includeCompetitors': true},
      });
    } catch (e) {
      throw Exception('generateMarketStudy $projectCode failed: $e');
    }
  }

  // GENERATE FULL DOSSIER (BP + Market + Legal + Finance)
  Future<Report> generateFullDossier(String projectCode) async {
    try {
      return await _remote.createReport({
        'project_code': projectCode,
        'type': 'full_dossier',
        'title': 'Dossier Complet Investisseur - $projectCode',
        'params': {'includeAll': true, 'format': 'pdf', 'language': 'fr'},
      });
    } catch (e) {
      throw Exception('generateFullDossier $projectCode failed: $e');
    }
  }

  // GENERATE CUSTOM REPORT
  Future<Report> generateCustom({
    required String projectCode,
    required String type,
    required String title,
    Map<String, dynamic>? params,
  }) async {
    try {
      return await _remote.createReport({
        'project_code': projectCode,
        'type': type,
        'title': title,
        'params': params ?? {},
      });
    } catch (e) {
      throw Exception('generateCustom $type failed: $e');
    }
  }

  // DELETE REPORT
  Future<void> delete(String reportId) async {
    // Note: deleteReport n'est pas encore implémenté dans ThixIaRemoteDatasource
    // Laisse vide pour l'instant pour que la compilation web réussisse !
  }

  // GET DOWNLOAD URL
  Future<String> getDownloadUrl(String reportId) async {
    // Note: getReportDownloadUrl n'est pas encore implémenté dans ThixIaRemoteDatasource
    return ''; 
  }

  // GET REPORT STATS
  Future<Map<String, int>> getStats(String projectCode) async {
    final reports = await getReports(projectCode);
    return {
      'total': reports.length,
      // Un rapport est considéré généré s'il possède un chemin de fichier (filePath)
      'generated': reports.where((r) => r.filePath != null && r.filePath!.isNotEmpty).length,
      'generating': reports.where((r) => r.filePath == null || r.filePath!.isEmpty).length,
      // Comparaison avec les Enums au lieu de strings !
      'business_plans': reports.where((r) => r.type == ReportType.businessPlan).length,
      'market_studies': reports.where((r) => r.type == ReportType.marketStudy).length,
    };
  }
}

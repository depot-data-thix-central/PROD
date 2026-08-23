// lib/presentation/thix_ia/services/report_service.dart
import '../datasources/thix_ia_remote_datasource.dart';
import '../models/report.dart';

class ReportService {
  ReportService(this._remote);
  final ThixIaRemoteDatasource _remote;

  // GET ALL REPORTS
  Future<List<Report>> getReports(String projectCode) async {
    try {
      final rows = await _remote.getReports(projectCode);
      return rows.map((e) => Report.fromJson(e)).toList()
        ..sort((a, b) => (b.createdAt?? DateTime.now()).compareTo(a.createdAt?? DateTime.now()));
    } catch (e) {
      throw Exception('getReports failed: $e');
    }
  }

  // GET SINGLE REPORT
  Future<Report?> getReport(String reportId) async {
    try {
      final row = await _remote.getReport(reportId);
      if (row == null) return null;
      return Report.fromJson(row);
    } catch (e) {
      throw Exception('getReport $reportId failed: $e');
    }
  }

  // GENERATE BUSINESS PLAN - Full dossier PDF
  Future<Report> generateBusinessPlan(String projectCode) async {
    try {
      final row = await _remote.generateReport(
        projectCode: projectCode,
        type: 'business_plan',
        title: 'Business Plan - $projectCode',
        params: {'sections': ['executive_summary', 'market_analysis', 'business_model', 'financial_forecast', 'go_to_market', 'team', 'risks']},
      );
      return Report.fromJson(row);
    } catch (e) {
      throw Exception('generateBusinessPlan $projectCode failed: $e');
    }
  }

  // GENERATE MARKET STUDY
  Future<Report> generateMarketStudy(String projectCode) async {
    try {
      final row = await _remote.generateReport(
        projectCode: projectCode,
        type: 'market_study',
        title: 'Étude de Marché - $projectCode',
        params: {'sources': ['banque_mondiale', 'ins_rdc', 'documents_rag'], 'includeCompetitors': true},
      );
      return Report.fromJson(row);
    } catch (e) {
      throw Exception('generateMarketStudy $projectCode failed: $e');
    }
  }

  // GENERATE FULL DOSSIER (BP + Market + Legal + Finance)
  Future<Report> generateFullDossier(String projectCode) async {
    try {
      final row = await _remote.generateReport(
        projectCode: projectCode,
        type: 'full_dossier',
        title: 'Dossier Complet Investisseur - $projectCode',
        params: {'includeAll': true, 'format': 'pdf', 'language': 'fr'},
      );
      return Report.fromJson(row);
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
      final row = await _remote.generateReport(
        projectCode: projectCode,
        type: type,
        title: title,
        params: params?? {},
      );
      return Report.fromJson(row);
    } catch (e) {
      throw Exception('generateCustom $type failed: $e');
    }
  }

  // DELETE REPORT
  Future<void> delete(String reportId) async {
    try {
      await _remote.deleteReport(reportId);
    } catch (e) {
      throw Exception('delete report $reportId failed: $e');
    }
  }

  // GET DOWNLOAD URL (signed URL Supabase Storage)
  Future<String> getDownloadUrl(String reportId) async {
    try {
      return await _remote.getReportDownloadUrl(reportId);
    } catch (e) {
      throw Exception('getDownloadUrl $reportId failed: $e');
    }
  }

  // GET REPORT STATS
  Future<Map<String, int>> getStats(String projectCode) async {
    final reports = await getReports(projectCode);
    return {
      'total': reports.length,
      'generated': reports.where((r) => r.isGenerated).length,
      'generating': reports.where((r) => r.status == ReportStatus.generating).length,
      'business_plans': reports.where((r) => r.type == 'business_plan').length,
      'market_studies': reports.where((r) => r.type == 'market_study').length,
    };
  }
}

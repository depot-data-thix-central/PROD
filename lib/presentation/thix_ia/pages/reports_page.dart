// lib/presentation/thix_ia/pages/reports_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/thix_ia_provider.dart';
import '../services/report_service.dart';
import '../models/report.dart';
import '../widgets/empty_state_widget.dart';

final reportServiceProvider = Provider<ReportService>((ref) => ReportService(ref.watch(thixRemoteDatasourceProvider)));
final reportsProvider = FutureProvider.family<List<Report>, String>((ref, code) async {
  return ref.watch(reportServiceProvider).getReports(code);
});

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key, required this.projectCode});
  final String projectCode;
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  bool _generating = false;

  Future<void> _generate(String type) async {
    setState(() => _generating = true);
    try {
      final service = ref.read(reportServiceProvider);
      if (type == 'business_plan') await service.generateBusinessPlan(widget.projectCode);
      if (type == 'market_study') await service.generateMarketStudy(widget.projectCode);
      if (type == 'fullDossier') await service.generateFullDossier(widget.projectCode);
      ref.invalidate(reportsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rapport $type généré')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(reportsProvider(widget.projectCode));

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(backgroundColor: Colors.white, title: Text('Rapports', style: ThixPolicy.h3Style)),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _GenBtn(icon: Icons.description_rounded, label: 'Business Plan', onTap: _generating? null : () => _generate('business_plan'))),
                SizedBox(width: 8),
                Expanded(child: _GenBtn(icon: Icons.analytics_rounded, label: 'Étude Marché', onTap: _generating? null : () => _generate('market_study'))),
                SizedBox(width: 8),
                Expanded(child: _GenBtn(icon: Icons.folder_special_rounded, label: 'Dossier Complet', onTap: _generating? null : () => _generate('fullDossier'))),
              ],
            ),
          ),
          if (_generating) LinearProgressIndicator(color: ThixPolicy.primary),
          Expanded(
            child: reportsAsync.when(
              loading: () => Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur $e')),
              data: (reports) {
                if (reports.isEmpty) return EmptyStateWidget(icon: Icons.picture_as_pdf_outlined, title: 'Aucun rapport', subtitle: 'Générez votre business plan, étude de marché ou dossier complet en 1 clic.', actionLabel: 'Générer Business Plan', onAction: () => _generate('business_plan'));
                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (_, i) {
                    final r = reports[i];
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border)),
                      child: ListTile(
                        leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.picture_as_pdf_rounded, color: ThixPolicy.danger)),
                        title: Text(r.title, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                        subtitle: Text('v${r.version} • ${r.fileType.toUpperCase()} • Confiance ${(r.confidence * 100).toInt()}%', style: ThixPolicy.captionStyle),
                        trailing: IconButton(icon: Icon(Icons.download_rounded, color: ThixPolicy.primary), onPressed: () async {
                          if (r.fileUrl!= null) {
                            final uri = Uri.tryParse(r.fileUrl!);
                            if (uri!= null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GenBtn extends StatelessWidget {
  const _GenBtn({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.primary.withOpacity(0.2))),
        child: Column(children: [Icon(icon, size: 20, color: ThixPolicy.primary), SizedBox(height: 4), Text(label, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.semiBold), textAlign: TextAlign.center)]),
      ),
    );
  }
}

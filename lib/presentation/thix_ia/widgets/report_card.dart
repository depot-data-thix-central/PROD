// lib/presentation/thix_ia/widgets/report_card.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../models/report.dart';

class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report, this.onRegenerate});

  final Report report;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowCard(opacity: 0.04)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.picture_as_pdf_rounded, color: ThixPolicy.danger)),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(report.title, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 2),
                Text('v${report.version} • ${report.fileType.toUpperCase()} • ${(report.confidence * 100).toInt()}% confiance • ${report.createdAt?.day}/${report.createdAt?.month}/${report.createdAt?.year}', style: ThixPolicy.captionStyle),
              ])),
              Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: report.isGenerated? ThixPolicy.success.withOpacity(0.12) : ThixPolicy.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text(report.status.name.toUpperCase(), style: ThixPolicy.microStyle.copyWith(color: report.isGenerated? ThixPolicy.success : ThixPolicy.warning, fontWeight: ThixPolicy.bold, fontSize: 8))),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () async { if (report.fileUrl!= null) { final uri = Uri.tryParse(report.fileUrl!); if (uri!= null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); } }, icon: Icon(Icons.download_rounded, size: 16), label: Text('Télécharger'), style: OutlinedButton.styleFrom(side: BorderSide(color: ThixPolicy.border)))),
              if (onRegenerate!= null)...[SizedBox(width: 8), Expanded(child: ElevatedButton.icon(onPressed: onRegenerate, icon: Icon(Icons.refresh_rounded, size: 16, color: Colors.white), label: Text('Régénérer'), style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary)))],
            ],
          ),
        ],
      ),
    );
  }
}

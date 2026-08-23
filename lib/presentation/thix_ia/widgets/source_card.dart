// lib/presentation/thix_ia/widgets/source_card.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/thix_design_policy.dart';

class SourceCard extends StatelessWidget {
  const SourceCard({super.key, required this.name, this.url, this.type = 'fact', this.confidence = 0.8});

  final String name;
  final String? url;
  final String type;
  final double confidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: ThixPolicy.surfaceStrong, borderRadius: BorderRadius.circular(ThixPolicy.rSm), border: Border.all(color: ThixPolicy.border)),
      child: Row(
        children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)), child: Icon(_icon, size: 16, color: _color)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.semiBold), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (url!= null) Text(url!, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.info), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: ThixPolicy.border)), child: Text('${(confidence * 100).toInt()}%', style: ThixPolicy.microStyle.copyWith(fontSize: 9, fontWeight: ThixPolicy.bold))),
          if (url!= null)...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(url!);
                if (uri!= null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Icon(Icons.open_in_new_rounded, size: 14, color: ThixPolicy.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Color get _color {
    switch (type) {
      case 'official': return ThixPolicy.success;
      case 'fact': return ThixPolicy.info;
      case 'estimation': return ThixPolicy.warning;
      default: return ThixPolicy.textSecondary;
    }
  }

  IconData get _icon {
    switch (type) {
      case 'official': return Icons.account_balance_rounded;
      case 'fact': return Icons.verified_rounded;
      case 'estimation': return Icons.calculate_rounded;
      default: return Icons.link_rounded;
    }
  }
}

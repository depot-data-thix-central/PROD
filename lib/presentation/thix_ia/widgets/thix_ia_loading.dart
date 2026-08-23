// lib/presentation/thix_ia/widgets/thix_ia_loading.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';

class ThixIaLoading extends StatelessWidget {
  const ThixIaLoading({super.key, this.message = 'THIX IA analyse...', this.progress});

  final String message;
  final int? progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 64, height: 64, child: CircularProgressIndicator(strokeWidth: 3, color: ThixPolicy.primary, backgroundColor: ThixPolicy.surfaceStrong)),
              Icon(Icons.auto_awesome_rounded, color: ThixPolicy.primary, size: 28),
            ]),
          ),
          SizedBox(height: 20),
          Text(message, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold), textAlign: TextAlign.center),
          if (progress!= null)...[SizedBox(height: 8), Text('$progress%', style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.primary))],
          SizedBox(height: 12),
          Text('Vérification sources officielles • Calculs déterministes • RAG documents', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class ThixIaShimmer extends StatelessWidget {
  const ThixIaShimmer({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(padding: EdgeInsets.all(16), itemCount: 5, itemBuilder: (_, __) => Container(margin: EdgeInsets.only(bottom: 12), height: 80, decoration: BoxDecoration(color: ThixPolicy.surfaceStrong, borderRadius: BorderRadius.circular(ThixPolicy.rMd))));
  }
}

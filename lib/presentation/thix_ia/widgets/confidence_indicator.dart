// lib/presentation/thix_ia/widgets/confidence_indicator.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';

class ConfidenceIndicator extends StatelessWidget {
  const ConfidenceIndicator({super.key, required this.value, this.size = 36, this.showLabel = true});

  final double value; // 0.0 - 1.0
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).toInt();
    final color = _color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              SizedBox(width: size, height: size, child: CircularProgressIndicator(value: value, strokeWidth: 3, backgroundColor: ThixPolicy.surfaceStrong, valueColor: AlwaysStoppedAnimation(color))),
              Center(child: Text('$percent%', style: TextStyle(fontSize: size * 0.28, fontWeight: FontWeight.bold, color: color))),
            ],
          ),
        ),
        if (showLabel)...[
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_label, style: ThixPolicy.microStyle.copyWith(color: color, fontWeight: ThixPolicy.bold)),
            Text('confiance', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 8)),
          ]),
        ],
      ],
    );
  }

  Color get _color {
    if (value >= 0.8) return ThixPolicy.success;
    if (value >= 0.5) return ThixPolicy.warning;
    return ThixPolicy.danger;
  }

  String get _label {
    if (value >= 0.8) return 'Élevée';
    if (value >= 0.5) return 'Moyenne';
    return 'Faible';
  }
}

class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(value: value, minHeight: 4, backgroundColor: ThixPolicy.surfaceStrong, valueColor: AlwaysStoppedAnimation(value >= 0.8? ThixPolicy.success : value >= 0.5? ThixPolicy.warning : ThixPolicy.danger)),
    );
  }
}

// lib/presentation/thix_ia/widgets/source_badge.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';

class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source, this.type = 'official'});

  final String source;
  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(ThixPolicy.rFull), border: Border.all(color: _color.withOpacity(0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_icon, size: 10, color: _color),
        const SizedBox(width: 4),
        Text(source.toUpperCase(), style: ThixPolicy.microStyle.copyWith(color: _color, fontWeight: ThixPolicy.bold, fontSize: 8)),
      ]),
    );
  }

  Color get _color {
    switch (type) {
      case 'official': return ThixPolicy.success;
      case 'banque_mondiale': return ThixPolicy.info;
      case 'government': return ThixPolicy.primary;
      default: return ThixPolicy.textSecondary;
    }
  }

  Color get _bg => _color.withOpacity(0.1);

  IconData get _icon {
    switch (type) {
      case 'official': return Icons.verified_user_rounded;
      case 'banque_mondiale': return Icons.public_rounded;
      case 'government': return Icons.account_balance_rounded;
      default: return Icons.source_rounded;
    }
  }
}

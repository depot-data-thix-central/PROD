// lib/presentation/thix_ia/core/extensions/analysis_extensions.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';

/// ============================================================================
/// ANALYSIS EXTENSIONS
/// ============================================================================

extension AnalysisTypeX on String {
  String get label {
    switch (toLowerCase()) {
      case 'idea':
        return 'Analyse d\'idée';
      case 'market':
        return 'Étude de marché';
      case 'competitor':
        return 'Concurrence';
      case 'legal':
        return 'Réglementation';
      case 'tax':
        return 'Fiscalité';
      case 'finance':
        return 'Modèle financier';
      case 'business_plan':
        return 'Business Plan';
      case 'strategy':
        return 'Stratégie';
      case 'design':
        return 'Design & Maquette';
      default:
        return this;
    }
  }

  IconData get icon {
    switch (toLowerCase()) {
      case 'idea':
        return Icons.lightbulb_rounded;
      case 'market':
        return Icons.bar_chart_rounded;
      case 'competitor':
        return Icons.groups_rounded;
      case 'legal':
        return Icons.balance_rounded;
      case 'tax':
        return Icons.receipt_long_rounded;
      case 'finance':
        return Icons.monetization_on_rounded;
      case 'business_plan':
        return Icons.business_center_rounded;
      case 'strategy':
        return Icons.trending_up_rounded;
      case 'design':
        return Icons.palette_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  Color get color {
    switch (toLowerCase()) {
      case 'idea':
        return ThixPolicy.domainOpportunity;
      case 'market':
        return ThixPolicy.domainMarket;
      case 'competitor':
        return ThixPolicy.domainNetwork;
      case 'legal':
        return ThixPolicy.domainGov;
      case 'tax':
        return ThixPolicy.domainMoney;
      case 'finance':
        return ThixPolicy.domainMoney;
      case 'business_plan':
        return ThixPolicy.primary;
      case 'strategy':
        return ThixPolicy.primaryDeep;
      case 'design':
        return ThixPolicy.domainMedia;
      default:
        return ThixPolicy.textSecondary;
    }
  }
}

extension ConfidenceX on double {
  String get label {
    if (this >= 0.85) return 'Très fiable';
    if (this >= 0.6) return 'Fiable';
    if (this >= 0.4) return 'À vérifier';
    return 'Incertain';
  }

  Color get color {
    if (this >= 0.85) return ThixPolicy.success;
    if (this >= 0.6) return ThixPolicy.info;
    if (this >= 0.4) return ThixPolicy.warning;
    return ThixPolicy.danger;
  }
}

extension ProgressX on double {
  String get percentLabel => '${(this * 100).toInt()}%';
  bool get isCompleted => this >= 1.0;
}

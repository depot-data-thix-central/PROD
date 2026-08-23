// lib/presentation/thix_ia/core/utils/project_code_generator.dart
import 'dart:math';
import '../constants/thix_ia_constants.dart';

/// ============================================================================
/// PROJECT CODE GENERATOR - THX-BIZ-YYYY-NNNNNN
/// Thread-safe, testable, sans dépendance serveur
/// ============================================================================

class ProjectCodeGenerator {
  ProjectCodeGenerator._();

  static final _random = Random.secure();

  /// Génère un code unique côté client (optimistic)
  /// Le backend doit confirmer / remplacer par séquence atomique
  static String generate({DateTime? now}) {
    final year = (now?? DateTime.now()).year;
    final seq = _random.nextInt(999999).toString().padLeft(6, '0');
    return '${ThixIAConstants.projectCodePrefix}-$year-$seq';
  }

  /// Génère avec séquence serveur (recommandé)
  static String fromServerSequence({
    required int year,
    required int sequence,
  }) {
    final seqStr = sequence.toString().padLeft(
          ThixIAConstants.projectCodeSeqLength,
          '0',
        );
    return '${ThixIAConstants.projectCodePrefix}-$year-$seqStr';
  }

  /// Validation stricte
  static bool isValid(String code) {
    final reg = RegExp(ThixIAConstants.projectCodePattern);
    return reg.hasMatch(code);
  }

  /// Parse
  static ({int year, int sequence})? parse(String code) {
    if (!isValid(code)) return null;
    try {
      final parts = code.split('-');
      // THX-BIZ-YYYY-NNNNNN -> [THX, BIZ, YYYY, NNNNNN]
      final year = int.parse(parts[2]);
      final seq = int.parse(parts[3]);
      return (year: year, sequence: seq);
    } catch (_) {
      return null;
    }
  }

  /// Pour affichage court: THX-000127
  static String shortCode(String fullCode) {
    final parsed = parse(fullCode);
    if (parsed == null) return fullCode;
    return 'THX-${parsed.sequence.toString().padLeft(6, '0')}';
  }
}

// lib/presentation/thix_money/utils/validators.dart
class ThixValidators {
  // Numéros RDC: 08x, 09x, 07x - 10 chiffres
  static final _cdPhone = RegExp(r'^(08|09|07)\d{8}$');

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Numéro requis';
    final clean = v.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 10) return '10 chiffres requis (ex: 0991234567)';
    if (!_cdPhone.hasMatch(clean)) return 'Numéro RDC invalide (08x, 09x, 07x)';
    return null;
  }

  static String? montant(String? v, String devise) {
    if (v == null || v.trim().isEmpty) return 'Montant requis';
    final clean = v.replaceAll(' ', '');
    final m = int.tryParse(clean);
    if (m == null) return 'Montant invalide';
    if (devise == 'CDF') {
      if (m < 1000) return 'Minimum 1 000 CDF';
      if (m > 10000000) return 'Maximum 10 000 000 CDF';
    }
    if (devise == 'USD') {
      if (m < 1) return 'Minimum 1 USD';
      if (m > 5000) return 'Maximum 5 000 USD';
    }
    return null;
  }

  static String? motif(String? v) {
    if (v == null || v.trim().isEmpty) return 'Motif requis';
    if (v.trim().length < 3) return 'Motif trop court';
    return null;
  }
}

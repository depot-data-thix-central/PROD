import 'package:intl/intl.dart';

/// Formateur centralisé pour les prix multi-devises.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formate un montant en prix lisible.
  ///
  /// Exemples :
  /// - `format(25000, currency: 'CDF')` → "25 000 FCFA"
  /// - `format(25000, currency: 'CDF', compact: true)` → "25K FCFA"
  /// - `format(8.5, currency: 'USD')` → "$8.50"
  static String format(
    num amount, {
    String currency = 'CDF',
    bool compact = false,
    String? locale,
  }) {
    final effectiveLocale = locale ?? 'fr_FR';
    final cur = currency.toUpperCase();

    if (compact) {
      return _formatCompact(amount, cur, effectiveLocale);
    }

    switch (cur) {
      case 'USD':
        return NumberFormat.currency(
          locale: 'en_US',
          symbol: '\$',
          decimalDigits: amount % 1 == 0 ? 0 : 2,
        ).format(amount);

      case 'EUR':
        return NumberFormat.currency(
          locale: 'fr_FR',
          symbol: '€',
          decimalDigits: 0,
        ).format(amount);

      case 'CDF':
        return '${NumberFormat.decimalPattern(effectiveLocale).format(amount)} CDF';

      case 'FCFA':
      default:
        return '${NumberFormat.decimalPattern(effectiveLocale).format(amount)} FCFA';
    }
  }

  static String _formatCompact(num amount, String cur, String locale) {
    String value;
    if (amount >= 1000000) {
      value = '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      value = '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K';
    } else {
      value = amount.toString();
    }

    final symbol = switch (cur) {
      'USD' => '\$',
      'EUR' => '€',
      'CDF' => 'CDF',
      _ => 'FCFA',
    };

    return '$value $symbol';
  }
}

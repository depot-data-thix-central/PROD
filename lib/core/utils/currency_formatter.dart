import 'package:intl/intl.dart';
import 'currency_registry.dart';

/// ============================================================================
/// CurrencyFormatter
/// ============================================================================
///
/// Formateur centralisé pour toutes les devises supportées.
///
/// Features :
/// - Détection automatique du format selon la devise
/// - Mode compact (25K, 1.2M) pour les UI limitées en espace
/// - Séparateurs de milliers adaptés à la locale
/// - Support RTL pour les devises arabes (SDG, DZD, etc.)
/// - Symbole avant/après selon les conventions locales
///
/// Utilisation :
/// ```dart
/// CurrencyFormatter.format(25000, currency: 'XOF');
/// // → "25 000 CFA"
///
/// CurrencyFormatter.format(25000, currency: 'NGN');
/// // → "₦25,000.00"
///
/// CurrencyFormatter.format(25000, currency: 'USD', compact: true);
/// // → "\$25K"
/// ```
/// ============================================================================
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formate un montant dans la devise donnée.
  static String format(
    num amount, {
    String currency = 'XOF',
    bool compact = false,
    bool showSymbol = true,
    bool symbolFirst,
    String? locale,
  }) {
    final cur = CurrencyRegistry.byCode(currency);
    final effectiveLocale = locale ?? cur.locale;

    if (compact) {
      return _formatCompact(amount, cur, effectiveLocale, showSymbol);
    }

    return _formatFull(amount, cur, effectiveLocale, showSymbol, symbolFirst);
  }

  static String _formatFull(
    num amount,
    ThixCurrency cur,
    String locale,
    bool showSymbol,
    bool? symbolFirst,
  ) {
    final formatter = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = cur.decimalDigits
      ..maximumFractionDigits = cur.decimalDigits;

    final formatted = formatter.format(amount);

    if (!showSymbol) return formatted;

    // Convention par défaut selon la devise
    final isFirst = symbolFirst ?? _symbolFirstByConvention(cur.code);

    // Espace insécable entre montant et symbole
    const nbsp = '\u00A0';

    return isFirst ? '${cur.symbol}$nbsp$formatted' : '$formatted$nbsp${cur.symbol}';
  }

  static String _formatCompact(
    num amount,
    ThixCurrency cur,
    String locale,
    bool showSymbol,
  ) {
    String value;
    final abs = amount.abs();

    if (abs >= 1000000000) {
      value = '${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (abs >= 1000000) {
      value = '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (abs >= 1000) {
      final divided = amount / 1000;
      value = divided % 1 == 0
          ? '${divided.toInt()}K'
          : '${divided.toStringAsFixed(1)}K';
    } else {
      value = amount.toString();
    }

    if (!showSymbol) return value;

    const nbsp = '\u00A0';
    final isFirst = _symbolFirstByConvention(cur.code);
    return isFirst ? '${cur.symbol}$nbsp$value' : '$value$nbsp${cur.symbol}';
  }

  /// Détermine si le symbole va avant ou après selon les conventions locales.
  static bool _symbolFirstByConvention(String code) {
    // Symboles qui vont AVANT le montant
    const prefixSymbols = {
      'USD', 'EUR', 'GBP', 'CAD', 'AUD', 'NZD', 'HKD', 'SGD',
      'NGN', 'GHS', 'EGP', 'ZAR', 'KES', 'CNY', 'JPY', 'INR',
    };
    return prefixSymbols.contains(code.toUpperCase());
  }

  /// Raccourci pour le formatage avec devise populaire.
  static String formatPopular(num amount, {bool compact = false}) {
    return format(amount, currency: 'XOF', compact: compact);
  }
}

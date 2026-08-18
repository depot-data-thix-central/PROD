// lib/presentation/thix_money/utils/formatter.dart
import 'package:intl/intl.dart';

class ThixFormatter {
  // Formatage CDF: 12 500 000 FCFA
  static String formatCdf(int amount) {
    final f = NumberFormat('#,###', 'fr_FR');
    return '${f.format(amount).replaceAll(',', ' ')} FC';
  }

  // Formatage USD: 20 500 USD
  static String formatUsd(int amount) {
    final f = NumberFormat('#,###', 'en_US');
    return '${f.format(amount)} USD';
  }

  // Auto-détecte la devise
  static String formatAmount(int amount, String devise) {
    return devise == 'USD' ? formatUsd(amount) : formatCdf(amount);
  }

  // Format téléphone: 099 123 45 67
  static String formatPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 10) return phone;
    return '${clean.substring(0,3)} ${clean.substring(3,6)} ${clean.substring(6,8)} ${clean.substring(8)}';
  }

  // Date FR
  static String formatDate(DateTime d) {
    return DateFormat('dd MMM yyyy • HH:mm', 'fr_FR').format(d);
  }

  static String formatDateShort(DateTime d) {
    return DateFormat('dd MMM', 'fr_FR').format(d);
  }
}

// lib/presentation/thix_money/utils/ref_generator.dart
import 'dart:math';

class RefGenerator {
  static const _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final _rnd = Random.secure();

  // Génère RefTransa 20 chars pour WonyaPay (anti-doublon)
  static String generateRefTransa() {
    return List.generate(20, (_) => _chars[_rnd.nextInt(_chars.length)]).join();
  }

  // Order ID interne THIX
  static String generateOrderId() {
    return 'THIX-${DateTime.now().millisecondsSinceEpoch}-${_rnd.nextInt(999)}';
  }

  // Idempotency key pour retry safe
  static String idempotencyKey() {
    return '${DateTime.now().millisecondsSinceEpoch}-${_rnd.nextInt(999999)}';
  }
}

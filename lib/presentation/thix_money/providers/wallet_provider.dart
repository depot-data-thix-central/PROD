// lib/presentation/thix_money/providers/wallet_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wallet_service.dart';

final walletServiceProvider = Provider((ref) => WalletService());

final currentThixIdProvider = FutureProvider<String>((ref) async {
  return ref.read(walletServiceProvider).getVerifiedThixId();
});

final walletStreamProvider = StreamProvider<WalletModel>((ref) {
  return ref.read(walletServiceProvider).streamWallet();
});

import 'package:freezed_annotation/freezed_annotation.dart';

part 'vault_state.freezed.dart';

@freezed
class VaultState with _$VaultState {
  const factory VaultState({
    @Default([]) List<Map<String, dynamic>> documents,
    @Default([]) List<Map<String, dynamic>> folders,
    @Default([]) List<Map<String, dynamic>> sentShares,
    @Default([]) List<Map<String, dynamic>> receivedShares,
    @Default([]) List<Map<String, dynamic>> auditLog,
    @Default(false) bool isLoading,
    @Default(false) bool isUploading,
    @Default(false) bool isSending,
    String? error,
    String? folderFilter,
    String searchQuery = '',
  }) = _VaultState;
}

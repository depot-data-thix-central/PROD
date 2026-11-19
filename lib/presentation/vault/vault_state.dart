// lib/presentation/vault/vault_state.dart
import 'package:flutter/foundation.dart';

typedef JsonMap = Map<String, dynamic>;

@immutable
class VaultUser {
  final String uid;
  final String? thixId;
  const VaultUser({required this.uid, this.thixId});
  @override
  bool operator ==(Object other) =>
      other is VaultUser && other.uid == uid && other.thixId == thixId;
  @override
  int get hashCode => Object.hash(uid, thixId);
}

enum IntegrityStatus { ok, tampered, unsealed }

@immutable
class VaultState {
  final List<JsonMap> documents;
  final List<JsonMap> folders;
  final List<JsonMap> sentShares;
  final List<JsonMap> receivedShares;
  final List<JsonMap> auditLog;
  final String? folderFilter;
  final String searchQuery;
  final bool loaded;
  final bool isUploading;
  final bool isSending;
  final String? error;

  const VaultState({
    this.documents = const [],
    this.folders = const [],
    this.sentShares = const [],
    this.receivedShares = const [],
    this.auditLog = const [],
    this.folderFilter,
    this.searchQuery = '',
    this.loaded = false,
    this.isUploading = false,
    this.isSending = false,
    this.error,
  });

  VaultState copyWith({
    List<JsonMap>? documents,
    List<JsonMap>? folders,
    List<JsonMap>? sentShares,
    List<JsonMap>? receivedShares,
    List<JsonMap>? auditLog,
    String? folderFilter,
    bool clearFolder = false,
    String? searchQuery,
    bool? loaded,
    bool? isUploading,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) =>
      VaultState(
        documents: documents ?? this.documents,
        folders: folders ?? this.folders,
        sentShares: sentShares ?? this.sentShares,
        receivedShares: receivedShares ?? this.receivedShares,
        auditLog: auditLog ?? this.auditLog,
        folderFilter: clearFolder ? null : (folderFilter ?? this.folderFilter),
        searchQuery: searchQuery ?? this.searchQuery,
        loaded: loaded ?? this.loaded,
        isUploading: isUploading ?? this.isUploading,
        isSending: isSending ?? this.isSending,
        error: clearError ? null : (error ?? this.error),
      );
}

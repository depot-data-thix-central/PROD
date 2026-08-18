// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authUserStreamHash() => r'410b32ad27d548c28514e9e5832eb11454a0617c';

/// See also [authUserStream].
@ProviderFor(authUserStream)
final authUserStreamProvider = StreamProvider<dynamic>.internal(
  authUserStream,
  name: r'authUserStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authUserStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AuthUserStreamRef = StreamProviderRef<dynamic>;
String _$appUserNotifierHash() => r'63bf3c96424fe15f57d2db87cba7d3c266d01e82';

/// See also [AppUserNotifier].
@ProviderFor(AppUserNotifier)
final appUserNotifierProvider =
    AsyncNotifierProvider<AppUserNotifier, AppUser?>.internal(
  AppUserNotifier.new,
  name: r'appUserNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appUserNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppUserNotifier = AsyncNotifier<AppUser?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

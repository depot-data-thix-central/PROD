// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'programme_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$weddingProgramHash() => r'2402680bc3364968c63c9814adf2517613e88f9c';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [weddingProgram].
@ProviderFor(weddingProgram)
const weddingProgramProvider = WeddingProgramFamily();

/// See also [weddingProgram].
class WeddingProgramFamily extends Family<AsyncValue<List<ProgramItem>>> {
  /// See also [weddingProgram].
  const WeddingProgramFamily();

  /// See also [weddingProgram].
  WeddingProgramProvider call(
    String weddingId,
  ) {
    return WeddingProgramProvider(
      weddingId,
    );
  }

  @override
  WeddingProgramProvider getProviderOverride(
    covariant WeddingProgramProvider provider,
  ) {
    return call(
      provider.weddingId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'weddingProgramProvider';
}

/// See also [weddingProgram].
class WeddingProgramProvider
    extends AutoDisposeFutureProvider<List<ProgramItem>> {
  /// See also [weddingProgram].
  WeddingProgramProvider(
    String weddingId,
  ) : this._internal(
          (ref) => weddingProgram(
            ref as WeddingProgramRef,
            weddingId,
          ),
          from: weddingProgramProvider,
          name: r'weddingProgramProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$weddingProgramHash,
          dependencies: WeddingProgramFamily._dependencies,
          allTransitiveDependencies:
              WeddingProgramFamily._allTransitiveDependencies,
          weddingId: weddingId,
        );

  WeddingProgramProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.weddingId,
  }) : super.internal();

  final String weddingId;

  @override
  Override overrideWith(
    FutureOr<List<ProgramItem>> Function(WeddingProgramRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WeddingProgramProvider._internal(
        (ref) => create(ref as WeddingProgramRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        weddingId: weddingId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<ProgramItem>> createElement() {
    return _WeddingProgramProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WeddingProgramProvider && other.weddingId == weddingId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, weddingId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin WeddingProgramRef on AutoDisposeFutureProviderRef<List<ProgramItem>> {
  /// The parameter `weddingId` of this provider.
  String get weddingId;
}

class _WeddingProgramProviderElement
    extends AutoDisposeFutureProviderElement<List<ProgramItem>>
    with WeddingProgramRef {
  _WeddingProgramProviderElement(super.provider);

  @override
  String get weddingId => (origin as WeddingProgramProvider).weddingId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

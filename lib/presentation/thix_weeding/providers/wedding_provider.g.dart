// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wedding_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$guestWeddingHash() => r'423c1145fd6e98ce3acfd45b9f2acba484234580';

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

/// See also [guestWedding].
@ProviderFor(guestWedding)
const guestWeddingProvider = GuestWeddingFamily();

/// See also [guestWedding].
class GuestWeddingFamily extends Family<AsyncValue<WeddingEntity>> {
  /// See also [guestWedding].
  const GuestWeddingFamily();

  /// See also [guestWedding].
  GuestWeddingProvider call(
    String weddingId,
  ) {
    return GuestWeddingProvider(
      weddingId,
    );
  }

  @override
  GuestWeddingProvider getProviderOverride(
    covariant GuestWeddingProvider provider,
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
  String? get name => r'guestWeddingProvider';
}

/// See also [guestWedding].
class GuestWeddingProvider extends AutoDisposeFutureProvider<WeddingEntity> {
  /// See also [guestWedding].
  GuestWeddingProvider(
    String weddingId,
  ) : this._internal(
          (ref) => guestWedding(
            ref as GuestWeddingRef,
            weddingId,
          ),
          from: guestWeddingProvider,
          name: r'guestWeddingProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$guestWeddingHash,
          dependencies: GuestWeddingFamily._dependencies,
          allTransitiveDependencies:
              GuestWeddingFamily._allTransitiveDependencies,
          weddingId: weddingId,
        );

  GuestWeddingProvider._internal(
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
    FutureOr<WeddingEntity> Function(GuestWeddingRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GuestWeddingProvider._internal(
        (ref) => create(ref as GuestWeddingRef),
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
  AutoDisposeFutureProviderElement<WeddingEntity> createElement() {
    return _GuestWeddingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GuestWeddingProvider && other.weddingId == weddingId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, weddingId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin GuestWeddingRef on AutoDisposeFutureProviderRef<WeddingEntity> {
  /// The parameter `weddingId` of this provider.
  String get weddingId;
}

class _GuestWeddingProviderElement
    extends AutoDisposeFutureProviderElement<WeddingEntity>
    with GuestWeddingRef {
  _GuestWeddingProviderElement(super.provider);

  @override
  String get weddingId => (origin as GuestWeddingProvider).weddingId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

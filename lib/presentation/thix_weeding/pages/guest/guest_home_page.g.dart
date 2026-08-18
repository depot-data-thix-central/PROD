// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guest_home_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$guestEventStatsHash() => r'61f5f085dfef1d514e9a1cc28004c6cd46762714';

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

/// See also [guestEventStats].
@ProviderFor(guestEventStats)
const guestEventStatsProvider = GuestEventStatsFamily();

/// See also [guestEventStats].
class GuestEventStatsFamily extends Family<AsyncValue<Map<String, int>>> {
  /// See also [guestEventStats].
  const GuestEventStatsFamily();

  /// See also [guestEventStats].
  GuestEventStatsProvider call(
    String weddingId,
  ) {
    return GuestEventStatsProvider(
      weddingId,
    );
  }

  @override
  GuestEventStatsProvider getProviderOverride(
    covariant GuestEventStatsProvider provider,
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
  String? get name => r'guestEventStatsProvider';
}

/// See also [guestEventStats].
class GuestEventStatsProvider
    extends AutoDisposeFutureProvider<Map<String, int>> {
  /// See also [guestEventStats].
  GuestEventStatsProvider(
    String weddingId,
  ) : this._internal(
          (ref) => guestEventStats(
            ref as GuestEventStatsRef,
            weddingId,
          ),
          from: guestEventStatsProvider,
          name: r'guestEventStatsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$guestEventStatsHash,
          dependencies: GuestEventStatsFamily._dependencies,
          allTransitiveDependencies:
              GuestEventStatsFamily._allTransitiveDependencies,
          weddingId: weddingId,
        );

  GuestEventStatsProvider._internal(
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
    FutureOr<Map<String, int>> Function(GuestEventStatsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GuestEventStatsProvider._internal(
        (ref) => create(ref as GuestEventStatsRef),
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
  AutoDisposeFutureProviderElement<Map<String, int>> createElement() {
    return _GuestEventStatsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GuestEventStatsProvider && other.weddingId == weddingId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, weddingId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin GuestEventStatsRef on AutoDisposeFutureProviderRef<Map<String, int>> {
  /// The parameter `weddingId` of this provider.
  String get weddingId;
}

class _GuestEventStatsProviderElement
    extends AutoDisposeFutureProviderElement<Map<String, int>>
    with GuestEventStatsRef {
  _GuestEventStatsProviderElement(super.provider);

  @override
  String get weddingId => (origin as GuestEventStatsProvider).weddingId;
}

String _$guestVendorsHash() => r'0c7a8fccc03873f1d48998f3c0a8138b54b61ec4';

/// See also [guestVendors].
@ProviderFor(guestVendors)
const guestVendorsProvider = GuestVendorsFamily();

/// See also [guestVendors].
class GuestVendorsFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [guestVendors].
  const GuestVendorsFamily();

  /// See also [guestVendors].
  GuestVendorsProvider call(
    String weddingId,
  ) {
    return GuestVendorsProvider(
      weddingId,
    );
  }

  @override
  GuestVendorsProvider getProviderOverride(
    covariant GuestVendorsProvider provider,
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
  String? get name => r'guestVendorsProvider';
}

/// See also [guestVendors].
class GuestVendorsProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// See also [guestVendors].
  GuestVendorsProvider(
    String weddingId,
  ) : this._internal(
          (ref) => guestVendors(
            ref as GuestVendorsRef,
            weddingId,
          ),
          from: guestVendorsProvider,
          name: r'guestVendorsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$guestVendorsHash,
          dependencies: GuestVendorsFamily._dependencies,
          allTransitiveDependencies:
              GuestVendorsFamily._allTransitiveDependencies,
          weddingId: weddingId,
        );

  GuestVendorsProvider._internal(
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
    FutureOr<List<Map<String, dynamic>>> Function(GuestVendorsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GuestVendorsProvider._internal(
        (ref) => create(ref as GuestVendorsRef),
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
  AutoDisposeFutureProviderElement<List<Map<String, dynamic>>> createElement() {
    return _GuestVendorsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GuestVendorsProvider && other.weddingId == weddingId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, weddingId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin GuestVendorsRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `weddingId` of this provider.
  String get weddingId;
}

class _GuestVendorsProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with GuestVendorsRef {
  _GuestVendorsProviderElement(super.provider);

  @override
  String get weddingId => (origin as GuestVendorsProvider).weddingId;
}

String _$guestUpdatesHash() => r'e9f8deae326eec834146c9799e89c2710198e119';

/// See also [guestUpdates].
@ProviderFor(guestUpdates)
const guestUpdatesProvider = GuestUpdatesFamily();

/// See also [guestUpdates].
class GuestUpdatesFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [guestUpdates].
  const GuestUpdatesFamily();

  /// See also [guestUpdates].
  GuestUpdatesProvider call(
    String weddingId,
  ) {
    return GuestUpdatesProvider(
      weddingId,
    );
  }

  @override
  GuestUpdatesProvider getProviderOverride(
    covariant GuestUpdatesProvider provider,
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
  String? get name => r'guestUpdatesProvider';
}

/// See also [guestUpdates].
class GuestUpdatesProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// See also [guestUpdates].
  GuestUpdatesProvider(
    String weddingId,
  ) : this._internal(
          (ref) => guestUpdates(
            ref as GuestUpdatesRef,
            weddingId,
          ),
          from: guestUpdatesProvider,
          name: r'guestUpdatesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$guestUpdatesHash,
          dependencies: GuestUpdatesFamily._dependencies,
          allTransitiveDependencies:
              GuestUpdatesFamily._allTransitiveDependencies,
          weddingId: weddingId,
        );

  GuestUpdatesProvider._internal(
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
    FutureOr<List<Map<String, dynamic>>> Function(GuestUpdatesRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GuestUpdatesProvider._internal(
        (ref) => create(ref as GuestUpdatesRef),
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
  AutoDisposeFutureProviderElement<List<Map<String, dynamic>>> createElement() {
    return _GuestUpdatesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GuestUpdatesProvider && other.weddingId == weddingId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, weddingId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin GuestUpdatesRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `weddingId` of this provider.
  String get weddingId;
}

class _GuestUpdatesProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with GuestUpdatesRef {
  _GuestUpdatesProviderElement(super.provider);

  @override
  String get weddingId => (origin as GuestUpdatesProvider).weddingId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

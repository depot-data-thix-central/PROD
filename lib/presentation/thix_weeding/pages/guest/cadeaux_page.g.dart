// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cadeaux_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$weddingGiftsHash() => r'95142433298efb5858bdb59cea807c993adc1a31';

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

/// See also [weddingGifts].
@ProviderFor(weddingGifts)
const weddingGiftsProvider = WeddingGiftsFamily();

/// See also [weddingGifts].
class WeddingGiftsFamily extends Family<AsyncValue<List<GiftItem>>> {
  /// See also [weddingGifts].
  const WeddingGiftsFamily();

  /// See also [weddingGifts].
  WeddingGiftsProvider call(
    String weddingId,
  ) {
    return WeddingGiftsProvider(
      weddingId,
    );
  }

  @override
  WeddingGiftsProvider getProviderOverride(
    covariant WeddingGiftsProvider provider,
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
  String? get name => r'weddingGiftsProvider';
}

/// See also [weddingGifts].
class WeddingGiftsProvider extends AutoDisposeFutureProvider<List<GiftItem>> {
  /// See also [weddingGifts].
  WeddingGiftsProvider(
    String weddingId,
  ) : this._internal(
          (ref) => weddingGifts(
            ref as WeddingGiftsRef,
            weddingId,
          ),
          from: weddingGiftsProvider,
          name: r'weddingGiftsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$weddingGiftsHash,
          dependencies: WeddingGiftsFamily._dependencies,
          allTransitiveDependencies:
              WeddingGiftsFamily._allTransitiveDependencies,
          weddingId: weddingId,
        );

  WeddingGiftsProvider._internal(
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
    FutureOr<List<GiftItem>> Function(WeddingGiftsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WeddingGiftsProvider._internal(
        (ref) => create(ref as WeddingGiftsRef),
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
  AutoDisposeFutureProviderElement<List<GiftItem>> createElement() {
    return _WeddingGiftsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WeddingGiftsProvider && other.weddingId == weddingId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, weddingId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin WeddingGiftsRef on AutoDisposeFutureProviderRef<List<GiftItem>> {
  /// The parameter `weddingId` of this provider.
  String get weddingId;
}

class _WeddingGiftsProviderElement
    extends AutoDisposeFutureProviderElement<List<GiftItem>>
    with WeddingGiftsRef {
  _WeddingGiftsProviderElement(super.provider);

  @override
  String get weddingId => (origin as WeddingGiftsProvider).weddingId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'galerie_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$weddingGalleryHash() => r'488b543e34d1d83121a18ff729533027e208a3d0';

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

abstract class _$WeddingGallery
    extends BuildlessAutoDisposeAsyncNotifier<GalleryState> {
  late final String weddingId;

  FutureOr<GalleryState> build(
    String weddingId,
  );
}

/// See also [WeddingGallery].
@ProviderFor(WeddingGallery)
const weddingGalleryProvider = WeddingGalleryFamily();

/// See also [WeddingGallery].
class WeddingGalleryFamily extends Family<AsyncValue<GalleryState>> {
  /// See also [WeddingGallery].
  const WeddingGalleryFamily();

  /// See also [WeddingGallery].
  WeddingGalleryProvider call(
    String weddingId,
  ) {
    return WeddingGalleryProvider(
      weddingId,
    );
  }

  @override
  WeddingGalleryProvider getProviderOverride(
    covariant WeddingGalleryProvider provider,
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
  String? get name => r'weddingGalleryProvider';
}

/// See also [WeddingGallery].
class WeddingGalleryProvider
    extends AutoDisposeAsyncNotifierProviderImpl<WeddingGallery, GalleryState> {
  /// See also [WeddingGallery].
  WeddingGalleryProvider(
    String weddingId,
  ) : this._internal(
          () => WeddingGallery()..weddingId = weddingId,
          from: weddingGalleryProvider,
          name: r'weddingGalleryProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$weddingGalleryHash,
          dependencies: WeddingGalleryFamily._dependencies,
          allTransitiveDependencies:
              WeddingGalleryFamily._allTransitiveDependencies,
          weddingId: weddingId,
        );

  WeddingGalleryProvider._internal(
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
  FutureOr<GalleryState> runNotifierBuild(
    covariant WeddingGallery notifier,
  ) {
    return notifier.build(
      weddingId,
    );
  }

  @override
  Override overrideWith(WeddingGallery Function() create) {
    return ProviderOverride(
      origin: this,
      override: WeddingGalleryProvider._internal(
        () => create()..weddingId = weddingId,
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
  AutoDisposeAsyncNotifierProviderElement<WeddingGallery, GalleryState>
      createElement() {
    return _WeddingGalleryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WeddingGalleryProvider && other.weddingId == weddingId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, weddingId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin WeddingGalleryRef on AutoDisposeAsyncNotifierProviderRef<GalleryState> {
  /// The parameter `weddingId` of this provider.
  String get weddingId;
}

class _WeddingGalleryProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<WeddingGallery,
        GalleryState> with WeddingGalleryRef {
  _WeddingGalleryProviderElement(super.provider);

  @override
  String get weddingId => (origin as WeddingGalleryProvider).weddingId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

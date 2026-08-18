// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guest_menu_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$guestMenuHash() => r'e7a39e5a13dc21be2f636616e97f299217636d81';

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

/// Menu dynamique scalable.
/// On peut filtrer selon la config du mariage (ex: cadeaux désactivés)
/// On peut ajouter des badges temps réel (ex: 3 annonces)
///
/// Copied from [guestMenu].
@ProviderFor(guestMenu)
const guestMenuProvider = GuestMenuFamily();

/// Menu dynamique scalable.
/// On peut filtrer selon la config du mariage (ex: cadeaux désactivés)
/// On peut ajouter des badges temps réel (ex: 3 annonces)
///
/// Copied from [guestMenu].
class GuestMenuFamily extends Family<List<GuestAction>> {
  /// Menu dynamique scalable.
  /// On peut filtrer selon la config du mariage (ex: cadeaux désactivés)
  /// On peut ajouter des badges temps réel (ex: 3 annonces)
  ///
  /// Copied from [guestMenu].
  const GuestMenuFamily();

  /// Menu dynamique scalable.
  /// On peut filtrer selon la config du mariage (ex: cadeaux désactivés)
  /// On peut ajouter des badges temps réel (ex: 3 annonces)
  ///
  /// Copied from [guestMenu].
  GuestMenuProvider call(
    String weddingId,
  ) {
    return GuestMenuProvider(
      weddingId,
    );
  }

  @override
  GuestMenuProvider getProviderOverride(
    covariant GuestMenuProvider provider,
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
  String? get name => r'guestMenuProvider';
}

/// Menu dynamique scalable.
/// On peut filtrer selon la config du mariage (ex: cadeaux désactivés)
/// On peut ajouter des badges temps réel (ex: 3 annonces)
///
/// Copied from [guestMenu].
class GuestMenuProvider extends AutoDisposeProvider<List<GuestAction>> {
  /// Menu dynamique scalable.
  /// On peut filtrer selon la config du mariage (ex: cadeaux désactivés)
  /// On peut ajouter des badges temps réel (ex: 3 annonces)
  ///
  /// Copied from [guestMenu].
  GuestMenuProvider(
    String weddingId,
  ) : this._internal(
          (ref) => guestMenu(
            ref as GuestMenuRef,
            weddingId,
          ),
          from: guestMenuProvider,
          name: r'guestMenuProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$guestMenuHash,
          dependencies: GuestMenuFamily._dependencies,
          allTransitiveDependencies: GuestMenuFamily._allTransitiveDependencies,
          weddingId: weddingId,
        );

  GuestMenuProvider._internal(
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
    List<GuestAction> Function(GuestMenuRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GuestMenuProvider._internal(
        (ref) => create(ref as GuestMenuRef),
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
  AutoDisposeProviderElement<List<GuestAction>> createElement() {
    return _GuestMenuProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GuestMenuProvider && other.weddingId == weddingId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, weddingId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin GuestMenuRef on AutoDisposeProviderRef<List<GuestAction>> {
  /// The parameter `weddingId` of this provider.
  String get weddingId;
}

class _GuestMenuProviderElement
    extends AutoDisposeProviderElement<List<GuestAction>> with GuestMenuRef {
  _GuestMenuProviderElement(super.provider);

  @override
  String get weddingId => (origin as GuestMenuProvider).weddingId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

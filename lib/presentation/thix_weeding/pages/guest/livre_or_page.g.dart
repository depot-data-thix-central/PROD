// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'livre_or_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$guestbookEntriesHash() => r'd49c6c43c5e4a9a5344894440c98a480c857b493';

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

/// See also [guestbookEntries].
@ProviderFor(guestbookEntries)
const guestbookEntriesProvider = GuestbookEntriesFamily();

/// See also [guestbookEntries].
class GuestbookEntriesFamily extends Family<AsyncValue<List<GuestbookEntry>>> {
  /// See also [guestbookEntries].
  const GuestbookEntriesFamily();

  /// See also [guestbookEntries].
  GuestbookEntriesProvider call(
    String weddingId,
  ) {
    return GuestbookEntriesProvider(
      weddingId,
    );
  }

  @override
  GuestbookEntriesProvider getProviderOverride(
    covariant GuestbookEntriesProvider provider,
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
  String? get name => r'guestbookEntriesProvider';
}

/// See also [guestbookEntries].
class GuestbookEntriesProvider
    extends AutoDisposeFutureProvider<List<GuestbookEntry>> {
  /// See also [guestbookEntries].
  GuestbookEntriesProvider(
    String weddingId,
  ) : this._internal(
          (ref) => guestbookEntries(
            ref as GuestbookEntriesRef,
            weddingId,
          ),
          from: guestbookEntriesProvider,
          name: r'guestbookEntriesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$guestbookEntriesHash,
          dependencies: GuestbookEntriesFamily._dependencies,
          allTransitiveDependencies:
              GuestbookEntriesFamily._allTransitiveDependencies,
          weddingId: weddingId,
        );

  GuestbookEntriesProvider._internal(
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
    FutureOr<List<GuestbookEntry>> Function(GuestbookEntriesRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GuestbookEntriesProvider._internal(
        (ref) => create(ref as GuestbookEntriesRef),
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
  AutoDisposeFutureProviderElement<List<GuestbookEntry>> createElement() {
    return _GuestbookEntriesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GuestbookEntriesProvider && other.weddingId == weddingId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, weddingId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin GuestbookEntriesRef
    on AutoDisposeFutureProviderRef<List<GuestbookEntry>> {
  /// The parameter `weddingId` of this provider.
  String get weddingId;
}

class _GuestbookEntriesProviderElement
    extends AutoDisposeFutureProviderElement<List<GuestbookEntry>>
    with GuestbookEntriesRef {
  _GuestbookEntriesProviderElement(super.provider);

  @override
  String get weddingId => (origin as GuestbookEntriesProvider).weddingId;
}

String _$guestbookPosterHash() => r'5c1e8176ca9a91e093c9592a10405dd2ffa87375';

/// See also [GuestbookPoster].
@ProviderFor(GuestbookPoster)
final guestbookPosterProvider =
    AutoDisposeAsyncNotifierProvider<GuestbookPoster, void>.internal(
  GuestbookPoster.new,
  name: r'guestbookPosterProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$guestbookPosterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GuestbookPoster = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

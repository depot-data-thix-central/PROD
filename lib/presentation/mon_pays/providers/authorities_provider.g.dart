// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'authorities_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authoritiesServiceHash() =>
    r'ec00358afe22d13155bd3d83c840249016bff07e';

/// See also [authoritiesService].
@ProviderFor(authoritiesService)
final authoritiesServiceProvider = Provider<AuthoritiesService>.internal(
  authoritiesService,
  name: r'authoritiesServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authoritiesServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AuthoritiesServiceRef = ProviderRef<AuthoritiesService>;
String _$topAuthoritiesHash() => r'8a115fcc27e177340a0d5038ef6dbf27b0a3d504';

/// See also [topAuthorities].
@ProviderFor(topAuthorities)
final topAuthoritiesProvider =
    AutoDisposeFutureProvider<List<Authority>>.internal(
  topAuthorities,
  name: r'topAuthoritiesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$topAuthoritiesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TopAuthoritiesRef = AutoDisposeFutureProviderRef<List<Authority>>;
String _$authorityDetailHash() => r'8a2bc5840ac717cb3483749563a4acad3ef3c010';

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

/// See also [authorityDetail].
@ProviderFor(authorityDetail)
const authorityDetailProvider = AuthorityDetailFamily();

/// See also [authorityDetail].
class AuthorityDetailFamily extends Family<AsyncValue<Authority>> {
  /// See also [authorityDetail].
  const AuthorityDetailFamily();

  /// See also [authorityDetail].
  AuthorityDetailProvider call(
    String id,
  ) {
    return AuthorityDetailProvider(
      id,
    );
  }

  @override
  AuthorityDetailProvider getProviderOverride(
    covariant AuthorityDetailProvider provider,
  ) {
    return call(
      provider.id,
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
  String? get name => r'authorityDetailProvider';
}

/// See also [authorityDetail].
class AuthorityDetailProvider extends AutoDisposeFutureProvider<Authority> {
  /// See also [authorityDetail].
  AuthorityDetailProvider(
    String id,
  ) : this._internal(
          (ref) => authorityDetail(
            ref as AuthorityDetailRef,
            id,
          ),
          from: authorityDetailProvider,
          name: r'authorityDetailProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$authorityDetailHash,
          dependencies: AuthorityDetailFamily._dependencies,
          allTransitiveDependencies:
              AuthorityDetailFamily._allTransitiveDependencies,
          id: id,
        );

  AuthorityDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<Authority> Function(AuthorityDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AuthorityDetailProvider._internal(
        (ref) => create(ref as AuthorityDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Authority> createElement() {
    return _AuthorityDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AuthorityDetailProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin AuthorityDetailRef on AutoDisposeFutureProviderRef<Authority> {
  /// The parameter `id` of this provider.
  String get id;
}

class _AuthorityDetailProviderElement
    extends AutoDisposeFutureProviderElement<Authority>
    with AuthorityDetailRef {
  _AuthorityDetailProviderElement(super.provider);

  @override
  String get id => (origin as AuthorityDetailProvider).id;
}

String _$historicalAuthoritiesHash() =>
    r'1537ba4ea205a257a9421658fe17d456d923e0f1';

/// See also [historicalAuthorities].
@ProviderFor(historicalAuthorities)
final historicalAuthoritiesProvider =
    AutoDisposeFutureProvider<List<Authority>>.internal(
  historicalAuthorities,
  name: r'historicalAuthoritiesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$historicalAuthoritiesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef HistoricalAuthoritiesRef
    = AutoDisposeFutureProviderRef<List<Authority>>;
String _$authoritiesPaginatedHash() =>
    r'74e3120675b694b415e66528f350deff27c25144';

abstract class _$AuthoritiesPaginated
    extends BuildlessAutoDisposeAsyncNotifier<PaginatedResult<Authority>> {
  late final String? category;
  late final String? search;
  late final bool? activeOnly;

  FutureOr<PaginatedResult<Authority>> build({
    String? category,
    String? search,
    bool? activeOnly,
  });
}

/// See also [AuthoritiesPaginated].
@ProviderFor(AuthoritiesPaginated)
const authoritiesPaginatedProvider = AuthoritiesPaginatedFamily();

/// See also [AuthoritiesPaginated].
class AuthoritiesPaginatedFamily
    extends Family<AsyncValue<PaginatedResult<Authority>>> {
  /// See also [AuthoritiesPaginated].
  const AuthoritiesPaginatedFamily();

  /// See also [AuthoritiesPaginated].
  AuthoritiesPaginatedProvider call({
    String? category,
    String? search,
    bool? activeOnly,
  }) {
    return AuthoritiesPaginatedProvider(
      category: category,
      search: search,
      activeOnly: activeOnly,
    );
  }

  @override
  AuthoritiesPaginatedProvider getProviderOverride(
    covariant AuthoritiesPaginatedProvider provider,
  ) {
    return call(
      category: provider.category,
      search: provider.search,
      activeOnly: provider.activeOnly,
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
  String? get name => r'authoritiesPaginatedProvider';
}

/// See also [AuthoritiesPaginated].
class AuthoritiesPaginatedProvider extends AutoDisposeAsyncNotifierProviderImpl<
    AuthoritiesPaginated, PaginatedResult<Authority>> {
  /// See also [AuthoritiesPaginated].
  AuthoritiesPaginatedProvider({
    String? category,
    String? search,
    bool? activeOnly,
  }) : this._internal(
          () => AuthoritiesPaginated()
            ..category = category
            ..search = search
            ..activeOnly = activeOnly,
          from: authoritiesPaginatedProvider,
          name: r'authoritiesPaginatedProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$authoritiesPaginatedHash,
          dependencies: AuthoritiesPaginatedFamily._dependencies,
          allTransitiveDependencies:
              AuthoritiesPaginatedFamily._allTransitiveDependencies,
          category: category,
          search: search,
          activeOnly: activeOnly,
        );

  AuthoritiesPaginatedProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.category,
    required this.search,
    required this.activeOnly,
  }) : super.internal();

  final String? category;
  final String? search;
  final bool? activeOnly;

  @override
  FutureOr<PaginatedResult<Authority>> runNotifierBuild(
    covariant AuthoritiesPaginated notifier,
  ) {
    return notifier.build(
      category: category,
      search: search,
      activeOnly: activeOnly,
    );
  }

  @override
  Override overrideWith(AuthoritiesPaginated Function() create) {
    return ProviderOverride(
      origin: this,
      override: AuthoritiesPaginatedProvider._internal(
        () => create()
          ..category = category
          ..search = search
          ..activeOnly = activeOnly,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        category: category,
        search: search,
        activeOnly: activeOnly,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<AuthoritiesPaginated,
      PaginatedResult<Authority>> createElement() {
    return _AuthoritiesPaginatedProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AuthoritiesPaginatedProvider &&
        other.category == category &&
        other.search == search &&
        other.activeOnly == activeOnly;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, category.hashCode);
    hash = _SystemHash.combine(hash, search.hashCode);
    hash = _SystemHash.combine(hash, activeOnly.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin AuthoritiesPaginatedRef
    on AutoDisposeAsyncNotifierProviderRef<PaginatedResult<Authority>> {
  /// The parameter `category` of this provider.
  String? get category;

  /// The parameter `search` of this provider.
  String? get search;

  /// The parameter `activeOnly` of this provider.
  bool? get activeOnly;
}

class _AuthoritiesPaginatedProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<AuthoritiesPaginated,
        PaginatedResult<Authority>> with AuthoritiesPaginatedRef {
  _AuthoritiesPaginatedProviderElement(super.provider);

  @override
  String? get category => (origin as AuthoritiesPaginatedProvider).category;
  @override
  String? get search => (origin as AuthoritiesPaginatedProvider).search;
  @override
  bool? get activeOnly => (origin as AuthoritiesPaginatedProvider).activeOnly;
}

String _$adminAuthoritiesHash() => r'e875ac545764f5d4ca0c5f0d63dd3924707afc63';

/// See also [AdminAuthorities].
@ProviderFor(AdminAuthorities)
final adminAuthoritiesProvider = AutoDisposeAsyncNotifierProvider<
    AdminAuthorities, List<Authority>>.internal(
  AdminAuthorities.new,
  name: r'adminAuthoritiesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$adminAuthoritiesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AdminAuthorities = AutoDisposeAsyncNotifier<List<Authority>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

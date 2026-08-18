// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'countdown_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$countdownHash() => r'2133eb37c1fd24a986edb063dec2b5b547fd0c72';

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

/// Stream temps réel, autoDispose, cancel auto quand plus écouté
/// Coût CPU quasi nul pour des millions d'users
///
/// Copied from [countdown].
@ProviderFor(countdown)
const countdownProvider = CountdownFamily();

/// Stream temps réel, autoDispose, cancel auto quand plus écouté
/// Coût CPU quasi nul pour des millions d'users
///
/// Copied from [countdown].
class CountdownFamily extends Family<AsyncValue<CountdownState>> {
  /// Stream temps réel, autoDispose, cancel auto quand plus écouté
  /// Coût CPU quasi nul pour des millions d'users
  ///
  /// Copied from [countdown].
  const CountdownFamily();

  /// Stream temps réel, autoDispose, cancel auto quand plus écouté
  /// Coût CPU quasi nul pour des millions d'users
  ///
  /// Copied from [countdown].
  CountdownProvider call(
    DateTime targetDate,
  ) {
    return CountdownProvider(
      targetDate,
    );
  }

  @override
  CountdownProvider getProviderOverride(
    covariant CountdownProvider provider,
  ) {
    return call(
      provider.targetDate,
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
  String? get name => r'countdownProvider';
}

/// Stream temps réel, autoDispose, cancel auto quand plus écouté
/// Coût CPU quasi nul pour des millions d'users
///
/// Copied from [countdown].
class CountdownProvider extends AutoDisposeStreamProvider<CountdownState> {
  /// Stream temps réel, autoDispose, cancel auto quand plus écouté
  /// Coût CPU quasi nul pour des millions d'users
  ///
  /// Copied from [countdown].
  CountdownProvider(
    DateTime targetDate,
  ) : this._internal(
          (ref) => countdown(
            ref as CountdownRef,
            targetDate,
          ),
          from: countdownProvider,
          name: r'countdownProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$countdownHash,
          dependencies: CountdownFamily._dependencies,
          allTransitiveDependencies: CountdownFamily._allTransitiveDependencies,
          targetDate: targetDate,
        );

  CountdownProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.targetDate,
  }) : super.internal();

  final DateTime targetDate;

  @override
  Override overrideWith(
    Stream<CountdownState> Function(CountdownRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CountdownProvider._internal(
        (ref) => create(ref as CountdownRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        targetDate: targetDate,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<CountdownState> createElement() {
    return _CountdownProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CountdownProvider && other.targetDate == targetDate;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, targetDate.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin CountdownRef on AutoDisposeStreamProviderRef<CountdownState> {
  /// The parameter `targetDate` of this provider.
  DateTime get targetDate;
}

class _CountdownProviderElement
    extends AutoDisposeStreamProviderElement<CountdownState> with CountdownRef {
  _CountdownProviderElement(super.provider);

  @override
  DateTime get targetDate => (origin as CountdownProvider).targetDate;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

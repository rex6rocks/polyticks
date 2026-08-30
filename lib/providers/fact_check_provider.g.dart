// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fact_check_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$factCheckNotifierHash() => r'63fda88726064e25c849d5cc7c84ee274ed57f9b';

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

abstract class _$FactCheckNotifier
    extends BuildlessAutoDisposeAsyncNotifier<FactCheckState> {
  late final String postId;

  FutureOr<FactCheckState> build(
    String postId,
  );
}

/// See also [FactCheckNotifier].
@ProviderFor(FactCheckNotifier)
const factCheckNotifierProvider = FactCheckNotifierFamily();

/// See also [FactCheckNotifier].
class FactCheckNotifierFamily extends Family<AsyncValue<FactCheckState>> {
  /// See also [FactCheckNotifier].
  const FactCheckNotifierFamily();

  /// See also [FactCheckNotifier].
  FactCheckNotifierProvider call(
    String postId,
  ) {
    return FactCheckNotifierProvider(
      postId,
    );
  }

  @override
  FactCheckNotifierProvider getProviderOverride(
    covariant FactCheckNotifierProvider provider,
  ) {
    return call(
      provider.postId,
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
  String? get name => r'factCheckNotifierProvider';
}

/// See also [FactCheckNotifier].
class FactCheckNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    FactCheckNotifier, FactCheckState> {
  /// See also [FactCheckNotifier].
  FactCheckNotifierProvider(
    String postId,
  ) : this._internal(
          () => FactCheckNotifier()..postId = postId,
          from: factCheckNotifierProvider,
          name: r'factCheckNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$factCheckNotifierHash,
          dependencies: FactCheckNotifierFamily._dependencies,
          allTransitiveDependencies:
              FactCheckNotifierFamily._allTransitiveDependencies,
          postId: postId,
        );

  FactCheckNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.postId,
  }) : super.internal();

  final String postId;

  @override
  FutureOr<FactCheckState> runNotifierBuild(
    covariant FactCheckNotifier notifier,
  ) {
    return notifier.build(
      postId,
    );
  }

  @override
  Override overrideWith(FactCheckNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: FactCheckNotifierProvider._internal(
        () => create()..postId = postId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        postId: postId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<FactCheckNotifier, FactCheckState>
      createElement() {
    return _FactCheckNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FactCheckNotifierProvider && other.postId == postId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, postId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FactCheckNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<FactCheckState> {
  /// The parameter `postId` of this provider.
  String get postId;
}

class _FactCheckNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<FactCheckNotifier,
        FactCheckState> with FactCheckNotifierRef {
  _FactCheckNotifierProviderElement(super.provider);

  @override
  String get postId => (origin as FactCheckNotifierProvider).postId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

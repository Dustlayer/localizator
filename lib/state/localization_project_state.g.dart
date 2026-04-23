// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'localization_project_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LocalizationProjectState)
final localizationProjectStateProvider = LocalizationProjectStateProvider._();

final class LocalizationProjectStateProvider
    extends
        $AsyncNotifierProvider<LocalizationProjectState, LocalizationProject?> {
  LocalizationProjectStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localizationProjectStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localizationProjectStateHash();

  @$internal
  @override
  LocalizationProjectState create() => LocalizationProjectState();
}

String _$localizationProjectStateHash() =>
    r'd3ef185fbb8e0645cb6a579844ee4f4e6b0714d7';

abstract class _$LocalizationProjectState
    extends $AsyncNotifier<LocalizationProject?> {
  FutureOr<LocalizationProject?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<LocalizationProject?>, LocalizationProject?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<LocalizationProject?>,
                LocalizationProject?
              >,
              AsyncValue<LocalizationProject?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Contains a Set of [TranslationKey]. Each of these keys means that currently there is a new key being added as new child of it.

@ProviderFor(TranslationKeysAdding)
final translationKeysAddingProvider = TranslationKeysAddingProvider._();

/// Contains a Set of [TranslationKey]. Each of these keys means that currently there is a new key being added as new child of it.
final class TranslationKeysAddingProvider
    extends $NotifierProvider<TranslationKeysAdding, ISet<TranslationKey>> {
  /// Contains a Set of [TranslationKey]. Each of these keys means that currently there is a new key being added as new child of it.
  TranslationKeysAddingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'translationKeysAddingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$translationKeysAddingHash();

  @$internal
  @override
  TranslationKeysAdding create() => TranslationKeysAdding();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ISet<TranslationKey> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ISet<TranslationKey>>(value),
    );
  }
}

String _$translationKeysAddingHash() =>
    r'3fe5299993f8159ded213e3038ac78983e7a6a47';

/// Contains a Set of [TranslationKey]. Each of these keys means that currently there is a new key being added as new child of it.

abstract class _$TranslationKeysAdding extends $Notifier<ISet<TranslationKey>> {
  ISet<TranslationKey> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ISet<TranslationKey>, ISet<TranslationKey>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ISet<TranslationKey>, ISet<TranslationKey>>,
              ISet<TranslationKey>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

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
    r'ec266411fa515c975bf67ee4721bf0485f4c9c57';

abstract class _$LocalizationProjectState
    extends $AsyncNotifier<LocalizationProject?> {
  FutureOr<LocalizationProject?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
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
    return element.handleCreate(ref, build);
  }
}

/// The git branch that was checked out the last time the translations were (re)loaded, so a
/// later branch switch made outside the app (e.g. in a terminal) can be detected - see
/// [LocalizationProjectState.hasGitBranchChanged]. `null` if the current project isn't in a git
/// repo, or no project is loaded.

@ProviderFor(CurrentGitBranch)
final currentGitBranchProvider = CurrentGitBranchProvider._();

/// The git branch that was checked out the last time the translations were (re)loaded, so a
/// later branch switch made outside the app (e.g. in a terminal) can be detected - see
/// [LocalizationProjectState.hasGitBranchChanged]. `null` if the current project isn't in a git
/// repo, or no project is loaded.
final class CurrentGitBranchProvider
    extends $NotifierProvider<CurrentGitBranch, String?> {
  /// The git branch that was checked out the last time the translations were (re)loaded, so a
  /// later branch switch made outside the app (e.g. in a terminal) can be detected - see
  /// [LocalizationProjectState.hasGitBranchChanged]. `null` if the current project isn't in a git
  /// repo, or no project is loaded.
  CurrentGitBranchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentGitBranchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentGitBranchHash();

  @$internal
  @override
  CurrentGitBranch create() => CurrentGitBranch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$currentGitBranchHash() => r'70629664a7ff8fb6baecc7d79fbd033586ae4677';

/// The git branch that was checked out the last time the translations were (re)loaded, so a
/// later branch switch made outside the app (e.g. in a terminal) can be detected - see
/// [LocalizationProjectState.hasGitBranchChanged]. `null` if the current project isn't in a git
/// repo, or no project is loaded.

abstract class _$CurrentGitBranch extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
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
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ISet<TranslationKey>, ISet<TranslationKey>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ISet<TranslationKey>, ISet<TranslationKey>>,
              ISet<TranslationKey>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

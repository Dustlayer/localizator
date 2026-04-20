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
    r'55c04e0d455aaeecdff07d96f45e690ad133e21f';

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

@ProviderFor(localizationTreeNodes)
final localizationTreeNodesProvider = LocalizationTreeNodesProvider._();

final class LocalizationTreeNodesProvider
    extends
        $FunctionalProvider<
          List<TreeViewNode<TranslationKey>>?,
          List<TreeViewNode<TranslationKey>>?,
          List<TreeViewNode<TranslationKey>>?
        >
    with $Provider<List<TreeViewNode<TranslationKey>>?> {
  LocalizationTreeNodesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localizationTreeNodesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localizationTreeNodesHash();

  @$internal
  @override
  $ProviderElement<List<TreeViewNode<TranslationKey>>?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<TreeViewNode<TranslationKey>>? create(Ref ref) {
    return localizationTreeNodes(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TreeViewNode<TranslationKey>>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TreeViewNode<TranslationKey>>?>(
        value,
      ),
    );
  }
}

String _$localizationTreeNodesHash() =>
    r'd93453899eb3804bfdcca32fb21067c410e386d8';

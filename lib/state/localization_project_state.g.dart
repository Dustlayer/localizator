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

@ProviderFor(localizationTreeNodes)
final localizationTreeNodesProvider = LocalizationTreeNodesProvider._();

final class LocalizationTreeNodesProvider
    extends
        $FunctionalProvider<
          List<TreeViewNode<TranslationKeyTreeNode>>?,
          List<TreeViewNode<TranslationKeyTreeNode>>?,
          List<TreeViewNode<TranslationKeyTreeNode>>?
        >
    with $Provider<List<TreeViewNode<TranslationKeyTreeNode>>?> {
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
  $ProviderElement<List<TreeViewNode<TranslationKeyTreeNode>>?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<TreeViewNode<TranslationKeyTreeNode>>? create(Ref ref) {
    return localizationTreeNodes(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    List<TreeViewNode<TranslationKeyTreeNode>>? value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<List<TreeViewNode<TranslationKeyTreeNode>>?>(
            value,
          ),
    );
  }
}

String _$localizationTreeNodesHash() =>
    r'76e066c18207bc9c6bb1a4cecc04538426bfd9e0';

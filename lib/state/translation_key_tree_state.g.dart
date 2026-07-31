// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translation_key_tree_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which "folder" keys are currently expanded in the [TreeView].

@ProviderFor(ExpandedTranslationKeys)
final expandedTranslationKeysProvider = ExpandedTranslationKeysProvider._();

/// Which "folder" keys are currently expanded in the [TreeView].
final class ExpandedTranslationKeysProvider
    extends $NotifierProvider<ExpandedTranslationKeys, ISet<TranslationKey>> {
  /// Which "folder" keys are currently expanded in the [TreeView].
  ExpandedTranslationKeysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expandedTranslationKeysProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expandedTranslationKeysHash();

  @$internal
  @override
  ExpandedTranslationKeys create() => ExpandedTranslationKeys();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ISet<TranslationKey> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ISet<TranslationKey>>(value),
    );
  }
}

String _$expandedTranslationKeysHash() =>
    r'e1c1e9e7af6246426c9b2794a38f702cb541ba27';

/// Which "folder" keys are currently expanded in the [TreeView].

abstract class _$ExpandedTranslationKeys
    extends $Notifier<ISet<TranslationKey>> {
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

/// The current search query used to filter translation keys in the tree.

@ProviderFor(TranslationKeyQuery)
final translationKeyQueryProvider = TranslationKeyQueryProvider._();

/// The current search query used to filter translation keys in the tree.
final class TranslationKeyQueryProvider
    extends $NotifierProvider<TranslationKeyQuery, String> {
  /// The current search query used to filter translation keys in the tree.
  TranslationKeyQueryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'translationKeyQueryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$translationKeyQueryHash();

  @$internal
  @override
  TranslationKeyQuery create() => TranslationKeyQuery();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$translationKeyQueryHash() =>
    r'c6862491a845f4a6723f482e8ca2288da0fcb25e';

/// The current search query used to filter translation keys in the tree.

abstract class _$TranslationKeyQuery extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The [TreeViewNode] representation of the current [LocalizationProject], ready to hand to a
/// [TreeView].
///
/// Always resolves to a valid (possibly empty) list rather than `null`, even while the
/// underlying project is still loading, so the [TreeView] never briefly receives an
/// inconsistent tree.
///
/// Deliberately reads (rather than watches) [expandedTranslationKeysProvider]: [TreeView] tracks
/// expand/collapse animations against the identity of the current `TreeViewNode` objects, so
/// swapping in a freshly-built list on every single node toggle fights its internal animation
/// state - causing visible flicker, and, if it happens while a node is already mid-animation, a
/// null check crash inside the package's `RenderTreeViewport`. [TreeView] already animates
/// expand/collapse itself via its `TreeViewController` using the existing node objects, so this
/// provider only needs to rebuild the tree for reasons that actually produce different nodes:
/// project data changes, the search query changing, or a key being expanded via deep link (which
/// explicitly invalidates this provider - see [ExpandedTranslationKeys.expandKeyAndParents]).

@ProviderFor(translationKeyTreeNodes)
final translationKeyTreeNodesProvider = TranslationKeyTreeNodesProvider._();

/// The [TreeViewNode] representation of the current [LocalizationProject], ready to hand to a
/// [TreeView].
///
/// Always resolves to a valid (possibly empty) list rather than `null`, even while the
/// underlying project is still loading, so the [TreeView] never briefly receives an
/// inconsistent tree.
///
/// Deliberately reads (rather than watches) [expandedTranslationKeysProvider]: [TreeView] tracks
/// expand/collapse animations against the identity of the current `TreeViewNode` objects, so
/// swapping in a freshly-built list on every single node toggle fights its internal animation
/// state - causing visible flicker, and, if it happens while a node is already mid-animation, a
/// null check crash inside the package's `RenderTreeViewport`. [TreeView] already animates
/// expand/collapse itself via its `TreeViewController` using the existing node objects, so this
/// provider only needs to rebuild the tree for reasons that actually produce different nodes:
/// project data changes, the search query changing, or a key being expanded via deep link (which
/// explicitly invalidates this provider - see [ExpandedTranslationKeys.expandKeyAndParents]).

final class TranslationKeyTreeNodesProvider
    extends
        $FunctionalProvider<
          List<TreeViewNode<TranslationKeyTreeNode>>,
          List<TreeViewNode<TranslationKeyTreeNode>>,
          List<TreeViewNode<TranslationKeyTreeNode>>
        >
    with $Provider<List<TreeViewNode<TranslationKeyTreeNode>>> {
  /// The [TreeViewNode] representation of the current [LocalizationProject], ready to hand to a
  /// [TreeView].
  ///
  /// Always resolves to a valid (possibly empty) list rather than `null`, even while the
  /// underlying project is still loading, so the [TreeView] never briefly receives an
  /// inconsistent tree.
  ///
  /// Deliberately reads (rather than watches) [expandedTranslationKeysProvider]: [TreeView] tracks
  /// expand/collapse animations against the identity of the current `TreeViewNode` objects, so
  /// swapping in a freshly-built list on every single node toggle fights its internal animation
  /// state - causing visible flicker, and, if it happens while a node is already mid-animation, a
  /// null check crash inside the package's `RenderTreeViewport`. [TreeView] already animates
  /// expand/collapse itself via its `TreeViewController` using the existing node objects, so this
  /// provider only needs to rebuild the tree for reasons that actually produce different nodes:
  /// project data changes, the search query changing, or a key being expanded via deep link (which
  /// explicitly invalidates this provider - see [ExpandedTranslationKeys.expandKeyAndParents]).
  TranslationKeyTreeNodesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'translationKeyTreeNodesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$translationKeyTreeNodesHash();

  @$internal
  @override
  $ProviderElement<List<TreeViewNode<TranslationKeyTreeNode>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<TreeViewNode<TranslationKeyTreeNode>> create(Ref ref) {
    return translationKeyTreeNodes(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TreeViewNode<TranslationKeyTreeNode>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<List<TreeViewNode<TranslationKeyTreeNode>>>(value),
    );
  }
}

String _$translationKeyTreeNodesHash() =>
    r'45d208467997629aac8c545dbeab8b0cb34a18e3';

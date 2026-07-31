import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:localizator/state/localization_project_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../model/translation.dart';

part 'translation_key_tree_state.g.dart';

/// Which "folder" keys are currently expanded in the [TreeView].
@Riverpod(keepAlive: true)
class ExpandedTranslationKeys extends _$ExpandedTranslationKeys {
  @override
  ISet<TranslationKey> build() => const ISet.empty();

  void setExpanded(TranslationKey key, bool expanded) {
    state = expanded ? state.add(key) : state.remove(key);
  }

  /// Expands [key] and all of its parents, e.g. so a key selected via deep link is visible.
  void expandKeyAndParents(TranslationKey key) {
    var updated = state;
    TranslationKey current = key;
    updated = updated.add(current);
    while (current.hasParent) {
      current = current.parent;
      updated = updated.add(current);
    }
    state = updated;
    // This is the one case where expansion should force a full tree rebuild - see the
    // comment on translationKeyTreeNodesProvider for why that isn't the default.
    ref.invalidate(translationKeyTreeNodesProvider);
  }

  /// Expands every key currently known to the project, waiting for it to finish loading first.
  Future<void> expandAllKnownKeys() async {
    final localizationProject = await ref.read(localizationProjectStateProvider.future);
    if (localizationProject == null) return;
    state = state.addAll(localizationProject.translations.keys);
  }

  void collapseAll() {
    state = const ISet.empty();
  }
}

/// The current search query used to filter translation keys in the tree.
@Riverpod(keepAlive: true)
class TranslationKeyQuery extends _$TranslationKeyQuery {
  @override
  String build() => "";

  void set(String query) {
    state = query;
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
@Riverpod(keepAlive: true)
List<TreeViewNode<TranslationKeyTreeNode>> translationKeyTreeNodes(Ref ref) {
  final localizationProject = ref.watch(localizationProjectStateProvider).value;
  if (localizationProject == null || localizationProject.translations.isEmpty) {
    return const [];
  }

  final keysBeingAdded = ref.watch(translationKeysAddingProvider);
  final expandedKeys = ref.read(expandedTranslationKeysProvider);
  final query = ref.watch(translationKeyQueryProvider);

  return localizationProject.toTreeNodes(
    keysBeingAdded: keysBeingAdded,
    expandedKeys: expandedKeys,
    query: query,
  );
}

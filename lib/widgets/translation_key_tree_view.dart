import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localizator/state/localization_project_state.dart';
import 'package:localizator/state/selected_translation_key.dart';
import 'package:localizator/state/translation_key_tree_state.dart';
import 'package:localizator/util/toast.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide TreeView;
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../model/translation.dart';
import 'translation_key_tree_node.dart';

/// Renders the [TreeView] for the currently loaded [LocalizationProject], including its
/// loading/error/empty states.
///
/// The tree itself (a `List<TreeViewNode<TranslationKeyTreeNode>>`) is always sourced from
/// [translationKeyTreeNodesProvider], which never resolves to `null` - this widget only has to
/// decide *whether* to show it, not build it.
class TranslationKeyTreeView extends ConsumerWidget {
  const TranslationKeyTreeView({
    super.key,
    required this.treeController,
    required this.verticalController,
    required this.horizontalController,
  });

  final TreeViewController treeController;
  final ScrollController verticalController;
  final ScrollController horizontalController;

  void _handleDeleteTranslationKey(
    BuildContext context,
    WidgetRef ref,
    TreeViewNode<TranslationKeyTreeNode> treeNode,
  ) {
    final projectBackup = ref.read(localizationProjectStateProvider).value;
    if (projectBackup != null) {
      showToast(
        context: context,
        builder: buildToast(
          title: "Übersetzung gelöscht",
          subtitle: "Rechts klicken um's rückgängig zu machen",
          actionLabel: "Rückgängig",
          onActionClick: () {
            ref.read(localizationProjectStateProvider.notifier).set(projectBackup);
          },
        ),
      );
    }
    // leaf node
    if (treeNode.children.isEmpty) {
      ref
          .read(localizationProjectStateProvider.notifier)
          .removeTranslation(treeNode.content.translationKey);
    } else {
      // delete whole "folder" of keys
      final folderKey = treeNode.content.translationKey.key;
      ref
          .read(localizationProjectStateProvider.notifier)
          .removeTranslationsWhere((key, _) => key.key.startsWith(folderKey));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizationProjectAsync = ref.watch(localizationProjectStateProvider);
    final tree = ref.watch(translationKeyTreeNodesProvider);
    final selectedKey = ref.watch(selectedTranslationKeyProvider);

    return switch (localizationProjectAsync) {
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
      AsyncError(error: final error) => Center(child: Text("Fehler: $error")),
      AsyncData(value: final localizationProject?) => localizationProject.translations.isEmpty
          ? const Center(child: Text("Keine Keys vorhanden"))
          : tree.isEmpty
          ? const Center(
              child: Text("Keine Keys gefunden", style: TextStyle(color: Colors.gray)),
            )
          : TreeView(
              onNodeToggle: (node) {
                ref
                    .read(expandedTranslationKeysProvider.notifier)
                    .setExpanded(node.content.translationKey, node.isExpanded);
              },
              controller: treeController,
              tree: tree,
              indentation: TreeViewIndentationType.none,
              verticalDetails: ScrollableDetails.vertical(
                controller: verticalController,
                physics: const ClampingScrollPhysics(),
              ),
              horizontalDetails: ScrollableDetails.horizontal(
                controller: horizontalController,
                physics: const ClampingScrollPhysics(),
              ),
              treeRowBuilder: (TreeViewNode<TranslationKeyTreeNode> node) {
                return TreeRow(
                  extent: node.content.isAddingKey
                      ? const FixedSpanExtent(55)
                      : const FixedSpanExtent(40),
                );
              },
              treeNodeBuilder: (context, node, toggleAnimationStyle) {
                return TranslationKeyTreeNodeWidget(
                  key: ValueKey(
                    'row_${node.content.translationKey.key}_${node.content.isAddingKey}',
                  ),
                  node: node,
                  toggleAnimationStyle: toggleAnimationStyle,
                  onSelectTranslationKey: (key) =>
                      ref.read(selectedTranslationKeyProvider.notifier).set(key),
                  selectedKey: selectedKey,
                  onStartAddTranslationKey: (key) =>
                      ref.read(translationKeysAddingProvider.notifier).add(key),
                  onFinishAddTranslationKey: (key) => ref
                      .read(translationKeysAddingProvider.notifier)
                      .finishAdding(key, node.content.translationKey),
                  onDeleteTranslationKey: (treeNode) =>
                      _handleDeleteTranslationKey(context, ref, treeNode),
                );
              },
            ),
      _ => const Center(child: Text("Unbekannter Status")),
    };
  }
}

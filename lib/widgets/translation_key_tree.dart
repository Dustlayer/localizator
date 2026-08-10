import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localizator/model/project.dart';
import 'package:localizator/state/app_config.dart';
import 'package:localizator/state/selected_translation_key.dart';
import 'package:localizator/state/translation_key_tree_state.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide TreeView;
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import 'main_edit_area.dart';
import 'top_bar.dart';
import 'translation_key_tree_view.dart';

/// The left-hand sidebar (file list, search bar and the translation key tree) plus the
/// [MainEditArea], wrapped in the [TopBar].
///
/// This widget only owns view-local concerns (scroll position, the [TreeViewController]
/// and the search [TextEditingController]) - which keys are expanded, the search query and the
/// tree nodes themselves live in Riverpod state (see translation_key_tree_state.dart) so they
/// survive rebuilds and are always in sync with each other.
class TranslationKeyTree extends ConsumerStatefulWidget {
  const TranslationKeyTree({super.key});

  @override
  ConsumerState<TranslationKeyTree> createState() => _TranslationKeyTreeState();
}

class _TranslationKeyTreeState extends ConsumerState<TranslationKeyTree> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();
  final _treeController = TreeViewController();
  final _queryTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Reset scroll position whenever the search query changes.
    ref.listenManual(translationKeyQueryProvider, (_, _) {
      _jumpScrollToTop();
    });
    // make sure keys are expanded when they're selected (e.g. via external link)
    ref.listenManual(selectedTranslationKeyProvider, (_, newTranslationKey) {
      if (newTranslationKey == null) return;
      ref.read(expandedTranslationKeysProvider.notifier).expandKeyAndParents(newTranslationKey);
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _queryTextController.dispose();
    super.dispose();
  }

  void _jumpScrollToTop() {
    _verticalController.jumpTo(0);
    _horizontalController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = ref.watch(appConfigStateProvider).value;
    return TopBar(
      child: Row(
        children: [
          FocusTraversalGroup(
            child: SizedBox(
              width: 250,
              child: Column(
                children: [
                  SizedBox(
                    height: 100,
                    child: _ProjectFileList(project: appConfig?.lastUsedProject),
                  ),
                  const Divider(),
                  _KeySearchBar(
                    queryTextController: _queryTextController,
                    onExpandAll: () async {
                      await ref.read(expandedTranslationKeysProvider.notifier).expandAllKnownKeys();
                      _treeController.expandAll();
                    },
                    onCollapseAll: () {
                      ref.read(expandedTranslationKeysProvider.notifier).collapseAll();
                      _jumpScrollToTop();
                      _treeController.collapseAll();
                    },
                  ).withPadding(all: 6),
                  appConfig?.lastUsedProject == null
                      ? const Expanded(
                          child: Center(
                            child: Text(
                              "Kein Projekt ausgewählt",
                              maxLines: 2,
                              overflow: .ellipsis,
                            ),
                          ),
                        )
                      : Expanded(
                          child: TranslationKeyTreeView(
                            treeController: _treeController,
                            verticalController: _verticalController,
                            horizontalController: _horizontalController,
                          ),
                        ),
                ],
              ),
            ),
          ),
          const VerticalDivider(),
          Expanded(child: FocusTraversalGroup(child: MainEditArea())),
        ],
      ),
    );
  }
}

/// Shows the file names belonging to the currently selected [Project].
class _ProjectFileList extends StatelessWidget {
  const _ProjectFileList({required this.project});

  final Project? project;

  @override
  Widget build(BuildContext context) {
    final filePaths = project?.filePaths ?? const IList<TranslationFile>.empty();
    if (filePaths.isEmpty) {
      return const Center(child: Text("Keine Dateien"));
    }
    return ListView.builder(
      itemCount: filePaths.length,
      itemBuilder: (context, index) {
        final translationFile = filePaths[index];
        return Text(translationFile.path.split(Platform.pathSeparator).last).withPadding(all: 8);
      },
    );
  }
}

/// The search field plus the expand/collapse-all buttons above the translation key tree.
class _KeySearchBar extends ConsumerWidget {
  const _KeySearchBar({
    required this.queryTextController,
    required this.onExpandAll,
    required this.onCollapseAll,
  });

  final TextEditingController queryTextController;
  final VoidCallback onExpandAll;
  final VoidCallback onCollapseAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      spacing: 4,
      children: [
        Expanded(
          child: TextField(
            controller: queryTextController,
            placeholder: const Text("Suche key.key..."),
            onChanged: (value) => ref.read(translationKeyQueryProvider.notifier).set(value),
          ),
        ),
        Tooltip(
          tooltip: (context) => TooltipContainer(child: const Text("Alle ausklappen")),
          child: IconButton.outline(icon: const Icon(LucideIcons.expand), onPressed: onExpandAll),
        ),
        Tooltip(
          tooltip: (context) => TooltipContainer(child: const Text("Alle einklappen")),
          child: IconButton.outline(
            icon: const Icon(LucideIcons.listCollapse),
            onPressed: onCollapseAll,
          ),
        ),
      ],
    );
  }
}

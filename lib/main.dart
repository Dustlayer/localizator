import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:localizator/state/app_config.dart';
import 'package:localizator/state/localization_project_state.dart';
import 'package:localizator/state/selected_translation_key.dart';
import 'package:localizator/util/list_utils.dart';
import 'package:localizator/util/path_utils.dart';
import 'package:localizator/util/toast.dart';
import 'package:localizator/widgets/main_edit_area.dart';
import 'package:localizator/widgets/top_bar.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide TreeView;
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logging.dart';
import 'model/translation.dart';
import 'startup.dart';
import 'widgets/translation_key_tree_node.dart';

void main() {
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    startup(ref);
    initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void initDeepLinks() {
    // Subscribe to incoming link events
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        // unknown action
        if (uri.authority != "open") return;
        Log.d("Open key link: $uri");

        final appConfig = ref.read(appConfigStateProvider).value;
        if (appConfig == null) return;

        final openedFromFilePath = uri.queryParameters["file"];
        if (openedFromFilePath == null) return;

        final gitRepo = await File(openedFromFilePath).parent.findGitRepoDirectory();
        if (gitRepo == null) return;

        final translationKeyPostfix = uri.queryParameters["key"];
        final translationKeyPrefix = uri.queryParameters["prefix"];

        String translationKey = "$translationKeyPostfix";
        if (translationKeyPrefix?.isNotEmpty ?? false) {
          translationKey = "$translationKeyPrefix.$translationKey";
        }

        final project = appConfig.projects.firstWhereOrNull((p) => p.gitRepoPath == gitRepo.path);

        Log.d("Open key '$translationKey'");

        if (project == null) {
          Log.d("Can't find project with gitRepoPath '${gitRepo.path}'");
          if (mounted) {
            showToast(
              context: context,
              builder: buildToast(
                title: "Übersetzung nicht gefunden",
                subtitle:
                    "Kein Projekt gefunden. Die Datei mit der Übersetzung muss in einem git Repo liegen.",
              ),
            );
          }
          return;
        }

        // set correct project if necessary
        if (appConfig.lastUsedProject != project) {
          ref
              .read(appConfigStateProvider.notifier)
              .set(appConfig.copyWith(lastUsedProject: project));
        }
        ref
            .read(selectedTranslationKeyProvider.notifier)
            .set(TranslationKey.fromKey(translationKey));
      },
      onError: (err) {
        if (kDebugMode) {
          debugPrint('Deep Link Error: $err');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'Flutter Demo',
      home: const TranslationKeyTree(),
      theme: ThemeData(colorScheme: ColorSchemes.darkSlate),
    );
  }
}

class TranslationKeyTree extends ConsumerStatefulWidget {
  const TranslationKeyTree({super.key});

  @override
  ConsumerState<TranslationKeyTree> createState() => _TranslationKeyTreeState();
}

class _TranslationKeyTreeState extends ConsumerState<TranslationKeyTree> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();
  final _treeController = TreeViewController();
  final Set<TranslationKey> _expandedKeys = {};
  final ValueNotifier<String> _keyQuery = ValueNotifier("");
  final _queryTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _keyQuery.addListener(() {
      _verticalController.jumpTo(0);
      _horizontalController.jumpTo(0);
    });
    // make sure keys are expanded when they're selected (e.g. via external link)
    ref.listenManual(
      selectedTranslationKeyProvider,
      (oldTranslationKey, newTranslationKey) =>
          _handleSelectedKeyUpdate(oldTranslationKey, newTranslationKey),
    );
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _keyQuery.dispose();
    _queryTextController.dispose();
    super.dispose();
  }

  void _handleSelectedKeyUpdate(
    TranslationKey? oldTranslationKey,
    TranslationKey? newTranslationKey,
  ) {
    if (newTranslationKey == null) {
      return;
    }
    if (!_expandedKeys.contains(newTranslationKey)) {
      // add translationKey and all their "parents" to expandedKeys
      _expandedKeys.add(newTranslationKey);
      if (newTranslationKey.hasParent) {
        TranslationKey currentKey = newTranslationKey.parent;
        while (currentKey.hasParent) {
          if (!_expandedKeys.contains(currentKey)) {
            _expandedKeys.add(currentKey);
          }
          currentKey = currentKey.parent;
        }
      }
    }

    setState(() {});
  }

  void _handleSelectTranslationKey(TranslationKey key) {
    ref.read(selectedTranslationKeyProvider.notifier).set(key);
  }

  void _handleDeleteTranslationKey(TreeViewNode<TranslationKeyTreeNode> treeNode) {
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
  Widget build(BuildContext context) {
    final appConfig = ref.watch(appConfigStateProvider).value;
    return TopBar(
      child: Row(
        children: [
          SizedBox(
            width: 250,
            child: Column(
              children: [
                SizedBox(
                  height: 100,
                  child: Builder(
                    builder: (context) {
                      final project = appConfig?.lastUsedProject;
                      if (project == null || project.filePaths.isEmpty) {
                        return Center(child: Text("Keine Dateien"));
                      }
                      return ListView.builder(
                        itemCount: appConfig?.lastUsedProject?.filePaths.length ?? 0,
                        itemBuilder: (context, index) {
                          final translationFile = appConfig!.lastUsedProject!.filePaths[index];
                          return Text(
                            translationFile.path.split(Platform.pathSeparator).last,
                          ).withPadding(all: 8);
                        },
                      );
                    },
                  ),
                ),
                const Divider(),
                Row(
                  spacing: 4,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _queryTextController,
                        placeholder: const Text("Suche key.key..."),
                        onChanged: (value) => _keyQuery.value = value,
                      ),
                    ),
                    Tooltip(
                      tooltip: (context) => TooltipContainer(child: const Text("Alle ausklappen")),
                      child: IconButton.outline(
                        icon: const Icon(LucideIcons.expand),
                        onPressed: () async {
                          final localizationProject = await ref.read(
                            localizationProjectStateProvider.future,
                          );
                          if (localizationProject?.translations != null) {
                            _expandedKeys.addAll(localizationProject!.translations.keys);
                          }
                          _treeController.expandAll();
                        },
                      ),
                    ),
                    Tooltip(
                      tooltip: (context) => TooltipContainer(child: const Text("Alle einklappen")),
                      child: IconButton.outline(
                        icon: const Icon(LucideIcons.listCollapse),
                        onPressed: () {
                          _expandedKeys.clear();
                          _verticalController.jumpTo(0);
                          _horizontalController.jumpTo(0);
                          _treeController.collapseAll();
                        },
                      ),
                    ),
                  ],
                ).withPadding(all: 6),
                appConfig?.lastUsedProject == null
                    ? Expanded(
                        child: Center(
                          child: Text("Kein Projekt ausgewählt", maxLines: 2, overflow: .ellipsis),
                        ),
                      )
                    : Expanded(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final localizationProject = ref.watch(localizationProjectStateProvider);
                            final keysBeingAdded = ref.watch(translationKeysAddingProvider);

                            return switch (localizationProject) {
                              AsyncLoading() => Center(child: CircularProgressIndicator()),
                              AsyncError(error: final error) => Center(
                                child: Text("Fehler: $error"),
                              ),
                              AsyncData(value: final localizationProject?) => ValueListenableBuilder(
                                valueListenable: _keyQuery,
                                builder: (BuildContext context, keyQuery, Widget? child) {
                                  if (localizationProject.translations.isEmpty) {
                                    return const Center(child: Text("Keine Keys vorhanden"));
                                  }
                                  final tree = localizationProject.toTreeNodes(
                                    keysBeingAdded: keysBeingAdded,
                                    expandedKeys: _expandedKeys,
                                    query: keyQuery,
                                  );
                                  if (tree.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        "Keine Keys gefunden",
                                        style: TextStyle(color: Colors.gray),
                                      ),
                                    );
                                  }
                                  return TreeView(
                                    onNodeToggle: (node) {
                                      if (node.isExpanded) {
                                        _expandedKeys.add(node.content.translationKey);
                                        return;
                                      }
                                      _expandedKeys.remove(node.content.translationKey);
                                    },
                                    controller: _treeController,
                                    tree: tree,
                                    indentation: TreeViewIndentationType.none,

                                    verticalDetails: ScrollableDetails.vertical(
                                      controller: _verticalController,
                                      physics: const ClampingScrollPhysics(),
                                    ),
                                    horizontalDetails: ScrollableDetails.horizontal(
                                      controller: _horizontalController,
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
                                        onSelectTranslationKey: _handleSelectTranslationKey,
                                        selectedKey: ref.watch(selectedTranslationKeyProvider),
                                        onStartAddTranslationKey: (key) {
                                          ref.read(translationKeysAddingProvider.notifier).add(key);
                                        },
                                        onFinishAddTranslationKey: (key) {
                                          ref
                                              .read(translationKeysAddingProvider.notifier)
                                              .finishAdding(key, node.content.translationKey);
                                        },
                                        onDeleteTranslationKey: _handleDeleteTranslationKey,
                                      );
                                    },
                                  );
                                },
                              ),
                              _ => Center(child: Text("Unbekannter Status")),
                            };
                          },
                        ),
                      ),
              ],
            ),
          ),
          const VerticalDivider(),
          Expanded(child: MainEditArea()),
        ],
      ),
    );
  }
}

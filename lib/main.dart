import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

import 'model/translation.dart';
import 'startup.dart';

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

        final appConfig = ref.read(appConfigStateProvider).value;
        if (appConfig == null) return;

        final openedFromFilePath = uri.queryParameters["file"];
        if (openedFromFilePath == null) return;

        final gitRepo = await File(openedFromFilePath).parent.findGitRepoDirectory();
        if (gitRepo == null) return;

        final translationKeyPostfix = uri.queryParameters["key"];
        final translationKeyPrefix = uri.queryParameters["prefix"];
        final translationKey = "$translationKeyPrefix.$translationKeyPostfix";

        final project = appConfig.projects.firstWhereOrNull((p) => p.gitRepoPath == gitRepo.path);

        if (project == null) {
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

  @override
  void initState() {
    super.initState();
    _keyQuery.addListener(() {
      _verticalController.jumpTo(0);
      _horizontalController.jumpTo(0);
    });
    // make sure keys are expanded when they're selected (e.g. via external link)
    ref.listenManual(selectedTranslationKeyProvider, (oldTranslationKey, newTranslationKey) {
      if (newTranslationKey == null) {
        return;
      }
      if (_expandedKeys.contains(newTranslationKey)) {
        return;
      }
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

      setState(() {});
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _keyQuery.dispose();
    super.dispose();
  }

  void _handleSelectTranslationKey(TranslationKey key) {
    ref.read(selectedTranslationKeyProvider.notifier).set(key);
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
                                      return _TranslationKeyTreeNodeWidget(
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
                                        onDeleteTranslationKey: (treeNode) {
                                          final projectBackup = ref
                                              .read(localizationProjectStateProvider)
                                              .value;
                                          if (projectBackup != null) {
                                            showToast(
                                              context: context,
                                              builder: buildToast(
                                                title: "Übersetzung gelöscht",
                                                subtitle:
                                                    "Rechts klicken um's rückgängig zu machen",
                                                actionLabel: "Rückgängig",
                                                onActionClick: () {
                                                  ref
                                                      .read(
                                                        localizationProjectStateProvider.notifier,
                                                      )
                                                      .set(projectBackup);
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
                                                .removeTranslationsWhere(
                                                  (key, _) => key.key.startsWith(folderKey),
                                                );
                                          }
                                        },
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

class _TranslationKeyTreeNodeWidget extends StatefulWidget {
  const _TranslationKeyTreeNodeWidget({
    super.key,
    required this.node,
    required this.toggleAnimationStyle,
    required this.onSelectTranslationKey,
    required this.onStartAddTranslationKey,
    required this.onFinishAddTranslationKey,
    this.selectedKey,
    required this.onDeleteTranslationKey,
  });

  final TreeViewNode<TranslationKeyTreeNode> node;
  final AnimationStyle toggleAnimationStyle;
  final void Function(TranslationKey key) onSelectTranslationKey;
  final void Function(TranslationKey key) onStartAddTranslationKey;

  /// Passes the new [TranslationKey] or null if this adding process should be canceled
  final void Function(TranslationKey? key) onFinishAddTranslationKey;
  final TranslationKey? selectedKey;

  final void Function(TreeViewNode<TranslationKeyTreeNode> treeNode) onDeleteTranslationKey;

  @override
  State<_TranslationKeyTreeNodeWidget> createState() => _TranslationKeyTreeNodeWidgetState();
}

class _TranslationKeyTreeNodeWidgetState extends State<_TranslationKeyTreeNodeWidget> {
  bool _isHovered = false;
  late final TextEditingController? _controller = widget.node.content.isAddingKey
      ? TextEditingController()
      : null;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final Duration animationDuration =
        widget.toggleAnimationStyle.duration ?? TreeView.defaultAnimationDuration;
    final Curve animationCurve =
        widget.toggleAnimationStyle.curve ?? TreeView.defaultAnimationCurve;
    final treeViewController = TreeViewController.of(context);
    final treeNodeDepth = widget.node.depth ?? 0;
    final isLeafNode = widget.node.children.isEmpty;

    final isVirtualAddingNode = widget.node.content.isAddingKey;

    return MouseRegion(
      onEnter: (event) => setState(() {
        _isHovered = true;
      }),
      onExit: (event) => setState(() {
        _isHovered = false;
      }),
      child: Padding(
        padding: .all(8.0),
        child: Padding(
          padding: .only(left: treeNodeDepth * 10),
          child: Row(
            children: <Widget>[
              // Icon for parent nodes
              TreeView.wrapChildToToggleNode(
                node: node,
                child: SizedBox.square(
                  dimension: 30.0,
                  child: !isLeafNode
                      ? AnimatedRotation(
                          key: ValueKey<String>(widget.node.content.translationKey.key),
                          turns: node.isExpanded ? 0.25 : 0.0,
                          duration: animationDuration,
                          curve: animationCurve,
                          child: const Icon(LucideIcons.chevronRight, size: 14),
                        )
                      : null,
                ),
              ),
              // Spacer
              const SizedBox(width: 8.0),
              // Content
              KeyedSubtree(
                key: ValueKey('content_${node.content.isAddingKey}'),
                child: isVirtualAddingNode
                    ? SizedBox(
                        width: 150,
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.escape): () {
                              widget.onFinishAddTranslationKey(null);
                            },
                          },
                          child: TextField(
                            controller: _controller,
                            placeholder: const Text("ordner.key"),
                            features: [
                              InputFeature.trailing(
                                IconButton.ghost(
                                  density: .compact,
                                  icon: const Icon(Icons.close),
                                  onPressed: () => widget.onFinishAddTranslationKey(null),
                                ),
                              ),
                            ],
                            onSubmitted: (text) {
                              FocusScope.of(context).unfocus();
                              _controller?.text = "";
                              widget.onFinishAddTranslationKey(
                                text.trim().isEmpty
                                    ? null
                                    : node.content.translationKey.withAddedKeyParts(
                                        text.split('.').toIList(),
                                      ),
                              );
                            },
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: () => isLeafNode
                            ? widget.onSelectTranslationKey(node.content.translationKey)
                            : treeViewController.toggleNode(node),
                        child: Builder(
                          builder: (context) {
                            final nodeTranslationKey = node.content.translationKey;
                            final childIsSelected =
                                widget.selectedKey?.key.startsWith(nodeTranslationKey.key) ?? false;
                            final isSelected =
                                widget.selectedKey == nodeTranslationKey || childIsSelected;
                            return Text(
                              nodeTranslationKey.keyParts.last,
                              style: TextStyle(
                                decoration: isSelected ? .underline : null,
                                color: isSelected
                                    ? Colors.emerald
                                    : !node.content.hasAllKeys
                                    ? Colors.red.shade400
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
              ),

              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _isHovered ? 1 : 0,
                child: IconButton.ghost(
                  alignment: .center,
                  size: .small,
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    widget.onDeleteTranslationKey(node);
                  },
                ),
              ).withPadding(left: 24),

              if (!isLeafNode)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _isHovered ? 1 : 0,
                  child: IconButton.ghost(
                    alignment: .center,
                    size: .small,
                    icon: const Icon(Icons.add),
                    onPressed: () => widget.onStartAddTranslationKey(node.content.translationKey),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

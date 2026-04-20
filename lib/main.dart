import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:localizator/dialogs/new_project_dialog.dart';
import 'package:localizator/model/project.dart';
import 'package:localizator/state/app_config.dart';
import 'package:localizator/state/localization_project_state.dart';
import 'package:localizator/util/list_utils.dart';
import 'package:localizator/util/toast.dart';
import 'package:shadcn_flutter/shadcn_flutter_experimental.dart' hide TreeView;
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dialogs/add_file_to_project_dialog.dart';
import 'model/translation.dart';

void main() {
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
  final _treeController = TreeViewController();

  TranslationKey? _selectedKey;
  LocalizationProject? _translations;

  void _handleSelectTranslationKey(TranslationKey key) {
    setState(() {
      _selectedKey = key;
    });
  }

  void _handleFileDrop(DropDoneDetails details) async {
    if (details.files.isEmpty) return;

    final file = details.files.first;
    if (!details.files.first.name.contains("json")) {
      showToast(
        context: context,
        builder: buildToast(
          title: "Keine JSON übergeben",
          subtitle: "Derzeit wird nur JSON unterstützt",
        ),
      );
      return;
    }

    final config = ref.read(appConfigStateProvider).value;
    if (config == null) {
      showToast(
        context: context,
        builder: buildToast(
          title: "Fehler",
          subtitle: "Unbekannter Fehler, Config nicht geladen: $config",
        ),
      );
      return;
    }

    if (config.lastUsedProject == null) {
      await showNewProjectDialog(context, filePath: details.files.first.path);
    } else {
      final translationFile = await showAddFileToProjectDialog(context, filePath: file.path);
      if (translationFile != null &&
          config.lastUsedProject!.filePaths.firstWhereOrNull(
                (p) => p.path == translationFile.path,
              ) ==
              null) {
        // only when a translation file was confirmed && the path doesn't exist yet
        final updatedProject = config.lastUsedProject!.withFiles(
          config.lastUsedProject!.filePaths.add(translationFile),
        );
        ref
            .read(appConfigStateProvider.notifier)
            .set(
              config.copyWith(
                projects: config.projects.replaceFirstWhere(
                  (p) => p.name == config.lastUsedProject!.name,
                  (p) => updatedProject,
                ),
                lastUsedProject: updatedProject,
              ),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = ref.watch(appConfigStateProvider).value;

    final projects = appConfig?.projects ?? const IList.empty();
    return Scaffold(
      headers: [
        AppBar(
          title: const Text("Localizator"),
          trailing: [
            Select<Project>(
              constraints: const BoxConstraints(minWidth: 200),
              value: appConfig?.lastUsedProject,
              onChanged: (value) {
                if (appConfig == null) return;
                ref
                    .read(appConfigStateProvider.notifier)
                    .set(appConfig.copyWith(lastUsedProject: value));
              },
              placeholder: projects.isEmpty
                  ? const Text("Noch kein Projekt vorhanden")
                  : const Text("Projekt auswählen"),
              popupConstraints: const BoxConstraints(maxHeight: 300),
              popup: SelectPopup(
                items: SelectItemList(
                  children: projects
                      .map((p) => SelectItemButton(value: p, child: Text(p.name)))
                      .toList(),
                ),
              ).call,
              itemBuilder: (context, value) => Text(value.name),
            ).withPadding(right: 8),
            IconButton.primary(
              icon: const Icon(Icons.add),
              onPressed: () => showNewProjectDialog(context),
            ),
          ],
        ),
        Divider(),
      ],
      child: DropTarget(
        enable: true,
        onDragDone: _handleFileDrop,
        child: SizedBox.expand(
          child: Row(
            children: [
              SizedBox(
                width: 250,
                child: Column(
                  children: [
                    SizedBox(
                      height: 200,
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
                    Divider(),
                    appConfig?.lastUsedProject == null
                        ? Expanded(
                            child: Center(
                              child: Text(
                                "Kein Projekt ausgewählt",
                                maxLines: 2,
                                overflow: .ellipsis,
                              ),
                            ),
                          )
                        : Expanded(
                            child: Consumer(
                              builder: (context, ref, child) {
                                final localizationProject = ref.watch(
                                  localizationProjectStateProvider,
                                );
                                final localizationTree = ref.watch(localizationTreeNodesProvider);
                                return switch (localizationProject) {
                                  AsyncLoading() => Center(child: CircularProgressIndicator()),
                                  AsyncError(error: final error) => Center(
                                    child: Text("Fehler: $error"),
                                  ),
                                  AsyncData(value: final localizationProject?) => TreeView(
                                    tree: localizationTree!,
                                    controller: _treeController,
                                    verticalDetails: const ScrollableDetails.vertical(
                                      physics: ClampingScrollPhysics(),
                                    ),
                                    horizontalDetails: const ScrollableDetails.horizontal(),
                                    treeRowBuilder: (TreeViewNode<TranslationKey> node) {
                                      return TreeRow(extent: const FixedSpanExtent(40));
                                    },
                                    treeNodeBuilder: (context, node, toggleAnimationStyle) {
                                      final Duration animationDuration =
                                          toggleAnimationStyle.duration ??
                                          TreeView.defaultAnimationDuration;
                                      final Curve animationCurve =
                                          toggleAnimationStyle.curve ??
                                          TreeView.defaultAnimationCurve;
                                      final int index = TreeViewController.of(
                                        context,
                                      ).getActiveIndexFor(node)!;
                                      return Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Row(
                                          children: <Widget>[
                                            // Icon for parent nodes
                                            TreeView.wrapChildToToggleNode(
                                              node: node,
                                              child: SizedBox.square(
                                                dimension: 30.0,
                                                child: node.children.isNotEmpty
                                                    ? AnimatedRotation(
                                                        key: ValueKey<int>(index),
                                                        turns: node.isExpanded ? 0.25 : 0.0,
                                                        duration: animationDuration,
                                                        curve: animationCurve,
                                                        // Renders a unicode right-facing arrow. >
                                                        child: const Icon(
                                                          IconData(0x25BA),
                                                          size: 14,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            // Spacer
                                            const SizedBox(width: 8.0),
                                            // Content
                                            GestureDetector(
                                              onTap: () => node.children.isEmpty
                                                  ? _handleSelectTranslationKey(node.content)
                                                  : _treeController.toggleNode(node),
                                              child: Text(
                                                node.content.toString(),
                                                style: TextStyle(
                                                  decoration: _selectedKey == node.content
                                                      ? .underline
                                                      : null,
                                                  color: _selectedKey == node.content
                                                      ? Colors.emerald
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
              Expanded(
                child: Center(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final localizationProject = ref.watch(localizationProjectStateProvider);
                      return switch (localizationProject) {
                        AsyncError(error: final error) => Center(child: Text("Fehler: $error")),
                        AsyncData(value: final localizationProject?) => Text(
                          _selectedKey == null
                              ? "Key auswählen"
                              : localizationProject.rows[_selectedKey!]?.translations.toString() ??
                                    "Nicht gefunden",
                        ),
                        AsyncData() => Center(child: Text("Noch keine Dateien")),
                        _ => CircularProgressIndicator(),
                      };
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

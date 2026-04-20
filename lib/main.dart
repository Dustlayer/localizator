import 'dart:io';

import 'package:localizator/state/app_config.dart';
import 'package:localizator/state/localization_project_state.dart';
import 'package:localizator/widgets/main_edit_area.dart';
import 'package:localizator/widgets/top_bar.dart';
import 'package:shadcn_flutter/shadcn_flutter_experimental.dart' hide TreeView;
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  void _handleSelectTranslationKey(TranslationKey key) {
    setState(() {
      _selectedKey = key;
    });
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
                            final localizationTree = ref.watch(localizationTreeNodesProvider);
                            return switch (localizationProject) {
                              AsyncLoading() => Center(child: CircularProgressIndicator()),
                              AsyncError(error: final error) => Center(
                                child: Text("Fehler: $error"),
                              ),
                              AsyncData(value: final _?) => TreeView(
                                tree: localizationTree!,
                                controller: _treeController,
                                verticalDetails: const ScrollableDetails.vertical(
                                  physics: ClampingScrollPhysics(),
                                ),
                                horizontalDetails: const ScrollableDetails.horizontal(),
                                treeRowBuilder: (TreeViewNode<TranslationKeyTreeNode> node) {
                                  return TreeRow(extent: const FixedSpanExtent(40));
                                },
                                treeNodeBuilder: (context, node, toggleAnimationStyle) {
                                  final Duration animationDuration =
                                      toggleAnimationStyle.duration ??
                                      TreeView.defaultAnimationDuration;
                                  final Curve animationCurve =
                                      toggleAnimationStyle.curve ?? TreeView.defaultAnimationCurve;
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
                                                    child: const Icon(IconData(0x25BA), size: 14),
                                                  )
                                                : null,
                                          ),
                                        ),
                                        // Spacer
                                        const SizedBox(width: 8.0),
                                        // Content
                                        GestureDetector(
                                          onTap: () => node.children.isEmpty
                                              ? _handleSelectTranslationKey(
                                                  node.content.translationKey,
                                                )
                                              : _treeController.toggleNode(node),
                                          child: Text(
                                            node.content.translationKey.toString(),
                                            style: TextStyle(
                                              decoration:
                                                  _selectedKey == node.content.translationKey
                                                  ? .underline
                                                  : null,
                                              color: _selectedKey == node.content.translationKey
                                                  ? Colors.emerald
                                                  : !node.content.hasAllKeys
                                                  ? Colors.red.shade400
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
          const VerticalDivider(),
          Expanded(child: MainEditArea(selectedKey: _selectedKey)),
        ],
      ),
    );
  }
}

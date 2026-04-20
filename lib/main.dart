import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
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
                                // TODO: nuclear option?
                                // key: ValueKey(
                                //   'tree_${ref.read(translationKeysAddingProvider).hashCode}',
                                // ),
                                controller: _treeController,
                                tree: localizationTree!,
                                indentation: TreeViewIndentationType.none,
                                verticalDetails: const ScrollableDetails.vertical(
                                  physics: ClampingScrollPhysics(),
                                ),
                                horizontalDetails: const ScrollableDetails.horizontal(),
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
                                    selectedKey: _selectedKey,
                                    onStartAddTranslationKey: (key) {
                                      ref.read(translationKeysAddingProvider.notifier).add(key);
                                    },
                                    onFinishAddTranslationKey: (key) {
                                      ref
                                          .read(translationKeysAddingProvider.notifier)
                                          .finishAdding(key, node.content.translationKey);
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
          Expanded(child: MainEditArea(selectedKey: _selectedKey)),
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
  });

  final TreeViewNode<TranslationKeyTreeNode> node;
  final AnimationStyle toggleAnimationStyle;
  final void Function(TranslationKey key) onSelectTranslationKey;
  final void Function(TranslationKey key) onStartAddTranslationKey;

  /// Passes the new [TranslationKey] or null if this adding process should be canceled
  final void Function(TranslationKey? key) onFinishAddTranslationKey;
  final TranslationKey? selectedKey;

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
    final index = treeViewController.getActiveIndexFor(widget.node);
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
                          // Renders a unicode right-facing arrow. >
                          child: const Icon(IconData(0x25BA), size: 14),
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
                        child: TextField(
                          controller: _controller,
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
                      )
                    : GestureDetector(
                        onTap: () => isLeafNode
                            ? widget.onSelectTranslationKey(node.content.translationKey)
                            : treeViewController.toggleNode(node),
                        child: Text(
                          node.content.translationKey.toString(),
                          style: TextStyle(
                            decoration: widget.selectedKey == node.content.translationKey
                                ? .underline
                                : null,
                            color: widget.selectedKey == node.content.translationKey
                                ? Colors.emerald
                                : !node.content.hasAllKeys
                                ? Colors.red.shade400
                                : null,
                          ),
                        ),
                      ),
              ),

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
                ).withPadding(left: 24),
            ],
          ),
        ),
      ),
    );
  }
}

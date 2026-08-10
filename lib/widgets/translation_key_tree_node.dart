import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:localizator/dialogs/add_new_key_dialog.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide TreeView;
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../model/translation.dart';

class TranslationKeyTreeNodeWidget extends StatefulWidget {
  const TranslationKeyTreeNodeWidget({
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
  State<TranslationKeyTreeNodeWidget> createState() => _TranslationKeyTreeNodeWidgetState();
}

class _TranslationKeyTreeNodeWidgetState extends State<TranslationKeyTreeNodeWidget> {
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
      opaque: true,
      hitTestBehavior: .opaque,
      onEnter: (event) => setState(() {
        _isHovered = true;
      }),
      onExit: (event) => setState(() {
        _isHovered = false;
      }),
      child: ConstrainedBox(
        constraints: .loose(Size(1000, double.infinity)),
        child: Padding(
          padding: .all(8.0),
          child: Padding(
            padding: .only(left: treeNodeDepth * 10),
            child: Row(
              mainAxisSize: .min,
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
                          onSecondaryTap: () async {
                            final addedKey = await showAddNewKeyDialog(
                              context,
                              parent: node.content.translationKey,
                            );
                            if (addedKey != null) {
                              widget.onSelectTranslationKey(addedKey);
                            }
                          },
                          child: Builder(
                            builder: (context) {
                              final nodeTranslationKey = node.content.translationKey;
                              final selectedKeyDepth = widget.selectedKey?.depth ?? 0;
                              final childIsSelected =
                                  selectedKeyDepth > nodeTranslationKey.depth &&
                                  (widget.selectedKey?.key.startsWith(nodeTranslationKey.key) ??
                                      false);

                              final isSelected =
                                  widget.selectedKey == nodeTranslationKey || childIsSelected;
                              return Text(
                                nodeTranslationKey.keyParts.last,
                                overflow: .ellipsis,
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
      ),
    );
  }
}

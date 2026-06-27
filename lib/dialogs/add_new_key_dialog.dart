import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localizator/model/translation.dart';
import 'package:localizator/state/app_config.dart';
import 'package:localizator/util/list_utils.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Locale;

import '../state/localization_project_state.dart';

Future<TranslationKey?> showAddNewKeyDialog(
  BuildContext context, {
  required TranslationKey? parent,
}) async {
  return await showDialog<TranslationKey?>(
    context: context,
    builder: (context) {
      return AddTranslationKeyDialog(parent: parent);
    },
  );
}

class AddTranslationKeyDialog extends ConsumerStatefulWidget {
  const AddTranslationKeyDialog({super.key, required this.parent});

  final TranslationKey? parent;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _AddTranslationKeyDialogState();
}

class _AddTranslationKeyDialogState extends ConsumerState<AddTranslationKeyDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    final keyPostfix = _controller.text.trim();
    if (keyPostfix.replaceAll('.', '').isEmpty) {
      Navigator.pop(context);
      return;
    }

    final keyPrefix = widget.parent?.key ?? "";
    final keyString = keyPrefix.isEmpty ? keyPostfix : "$keyPrefix.$keyPostfix";
    final newKey = TranslationKey(keyString.split('.').toIList());

    // TODO: inefficient lookup to find out if this is a leaf key or a folder
    final localizationProject = await ref.read(localizationProjectStateProvider.future);
    final translations = localizationProject?.translations ?? const IMap.empty();
    final parentKey = widget.parent;
    final parentIsFolderNode = widget.parent == null
        ? false
        : translations.toKeyIList().firstWhereOrNull(
                (key) => key.depth > widget.parent!.depth && key.key.startsWith(keyPrefix),
              ) !=
              null;

    if (!mounted) {
      return;
    }

    // if the parent key is a leaf node use it's parent as parent for the new key
    final safeKey = parentIsFolderNode
        ? newKey
        : parentKey!.parent.withAddedKeyParts(keyPostfix.split('.').toIList());

    ref
        .read(localizationProjectStateProvider.notifier)
        .updateTranslation(safeKey, Translation(key: safeKey));

    Navigator.pop(context, safeKey);
  }

  void _handleDelete() {
    if (widget.parent == null) {
      Navigator.pop(context);
      return;
    }

    // toasts can't be shown currently as theme is missing; so no revert option

    final deleteKeyText = widget.parent!.key;

    // delete whole "folder" of keys
    ref
        .read(localizationProjectStateProvider.notifier)
        .removeTranslationsWhere((key, _) => key.key.startsWith(deleteKeyText));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = ref.watch(appConfigStateProvider).value;
    final project = appConfig?.lastUsedProject;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 450),
      child: AlertDialog(
        title: Align(
          alignment: .centerLeft,
          child: Text(
            'Neuen Key zu Projekt ${project?.name} hinzufügen',
            overflow: .ellipsis,
            maxLines: 2,
          ),
        ),
        content: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            Text(
              widget.parent != null
                  ? "Key wird unter ${widget.parent?.key} angelegt"
                  : "Key wird auf der ersten Ebene angelegt",
            ).withPadding(vertical: 8),
            // onSubmitted does not work here on the TextField
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): () {
                  _handleSubmit();
                },
              },
              child: TextField(
                autofocus: true,
                controller: _controller,
                placeholder: const Text("ordner.key"),
              ),
            ),
          ],
        ),
        actions: [
          DestructiveButton(onPressed: _handleDelete, child: const Text("Key löschen")),
          OutlineButton(
            child: const Text('Abbrechen'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          PrimaryButton(
            child: const Text('Bestätigen'),
            onPressed: () {
              _handleSubmit();
            },
          ),
        ],
      ),
    );
  }
}

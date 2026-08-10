import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Locale;

import '../model/translation.dart';
import '../state/localization_project_state.dart';

/// Shows a dialog to rename/move [translationKey]. [isFolder] controls whether the explanatory
/// text warns that child keys will move along with it. Returns the new [TranslationKey] once
/// the rename has been applied, or `null` if the dialog was cancelled.
Future<TranslationKey?> showRenameKeyDialog(
  BuildContext context, {
  required TranslationKey translationKey,
  required bool isFolder,
}) async {
  return await showDialog<TranslationKey?>(
    context: context,
    builder: (context) {
      return RenameKeyDialog(translationKey: translationKey, isFolder: isFolder);
    },
  );
}

class RenameKeyDialog extends ConsumerStatefulWidget {
  const RenameKeyDialog({super.key, required this.translationKey, required this.isFolder});

  final TranslationKey translationKey;
  final bool isFolder;

  @override
  ConsumerState<RenameKeyDialog> createState() => _RenameKeyDialogState();
}

class _RenameKeyDialogState extends ConsumerState<RenameKeyDialog> {
  late final _controller = TextEditingController(text: widget.translationKey.key);
  String? _errorText;
  String? _infoText;
  String? _warningText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Validates the current text against the project state, updating [_errorText], [_infoText]
  /// and [_warningText]. Returns the parsed new key if valid, or `null` otherwise.
  TranslationKey? _validate() {
    final localizationProject = ref.read(localizationProjectStateProvider).value;
    final newKey = TranslationKey(_controller.text.trim().split('.').toIList());
    final error = localizationProject?.validateKeyRename(
      oldKey: widget.translationKey,
      newKey: newKey,
    );

    // display message for user as info if folders are merged or a folder will be overridden
    final mergesFolders =
        error == null &&
        (localizationProject?.renameWouldMergeFolders(
              oldKey: widget.translationKey,
              newKey: newKey,
            ) ??
            false);

    setState(() {
      _errorText = error;
      _infoText = mergesFolders && widget.isFolder
          ? "Der Ordner '${newKey.key}' existiert bereits. Vorhandene Schlüssel werden zusammengeführt."
          : null;
      _warningText = mergesFolders && !widget.isFolder
          ? "Der Ordner '${newKey.key}' existiert bereits. Beim Verschieben wird dessen gesamter Inhalt überschrieben und geht verloren."
          : null;
    });
    return error == null ? newKey : null;
  }

  void _handleSubmit() {
    final newKey = _validate();
    if (newKey == null) return;

    ref
        .read(localizationProjectStateProvider.notifier)
        .renameTranslationKey(widget.translationKey, newKey);

    Navigator.pop(context, newKey);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 450),
      child: AlertDialog(
        title: const Text('Schlüssel umbenennen / verschieben'),
        content: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            Text(
              widget.isFolder
                  ? 'Diese Aktion benennt den Schlüssel um bzw. verschiebt ihn - dabei werden '
                        'auch alle untergeordneten Schlüssel mit verschoben.'
                  : 'Diese Aktion benennt den Schlüssel um bzw. verschiebt ihn.',
            ).withPadding(vertical: 8),
            CallbackShortcuts(
              bindings: {const SingleActivator(LogicalKeyboardKey.enter): _handleSubmit},
              child: TextField(
                autofocus: true,
                controller: _controller,
                placeholder: const Text('ordner.key'),
                onChanged: (_) => _validate(),
              ),
            ),
            if (_errorText != null)
              Text(_errorText!, style: TextStyle(color: Colors.red.shade400)).withPadding(top: 8),
            if (_infoText != null)
              Text(_infoText!, style: TextStyle(color: Colors.blue.shade400)).withPadding(top: 8),
            if (_warningText != null)
              Text(
                _warningText!,
                style: TextStyle(color: Colors.amber.shade400),
              ).withPadding(top: 8),
          ],
        ),
        actions: [
          OutlineButton(
            child: const Text('Abbrechen'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          PrimaryButton(
            onPressed: _errorText == null ? _handleSubmit : null,
            child: const Text('Umbenennen'),
          ),
        ],
      ),
    );
  }
}

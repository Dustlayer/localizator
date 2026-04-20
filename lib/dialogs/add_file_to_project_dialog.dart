import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localizator/model/project.dart';
import 'package:localizator/state/app_config.dart';
import 'package:localizator/util/list_utils.dart';
import 'package:localizator/util/toast.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Locale;

import '../model/translation_locale.dart';

Future<TranslationFile?> showAddFileToProjectDialog(
  BuildContext context, {
  required String filePath,
}) async {
  return await showDialog<TranslationFile?>(
    context: context,
    builder: (context) {
      return AddFileToProjectDialog(filePath: filePath);
    },
  );
}

class AddFileToProjectDialog extends ConsumerStatefulWidget {
  const AddFileToProjectDialog({super.key, required this.filePath});

  final String filePath;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _AddFileToProjectDialogState();
}

class _AddFileToProjectDialogState extends ConsumerState<AddFileToProjectDialog> {
  TranslationLocale? _selectedLocale;

  @override
  void initState() {
    super.initState();
    _tryToFindLocale();
  }

  void _tryToFindLocale() {
    final filename = widget.filePath.split(Platform.pathSeparator).last.split('.').first
      ..trim().toLowerCase();

    TranslationLocale? locale = switch (filename) {
      'de' => TranslationLocale.deDE,
      'en' => TranslationLocale.enUS,
      _ => TranslationLocale.values.firstWhereOrNull(
        (l) => l.locale.toLowerCase().contains(filename),
      ),
    };

    if (locale != null) {
      _selectedLocale = locale;
    }
  }

  void _handleSubmit() async {
    final translationFile = _selectedLocale == null
        ? null
        : TranslationFile(locale: _selectedLocale!, path: widget.filePath);

    if (translationFile == null) {
      showToast(
        context: context,
        builder: buildToast(
          title: "Keine Sprache ausgewählt",
          subtitle: "Es muss eine Sprache für die Datei hinterlegt werden.",
        ),
      );
      return;
    }

    if (mounted) {
      Navigator.pop(context, translationFile);
    }
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
            'Datei zu Projekt ${project?.name} hinzufügen',
            overflow: .ellipsis,
            maxLines: 2,
          ),
        ),
        content: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            Text(
              "Sprache für ${widget.filePath.split(Platform.pathSeparator).last} festlegen",
            ).withPadding(vertical: 8),
            Select<TranslationLocale>(
              placeholder: const Text("Sprache auswählen"),
              popup: SelectPopup.builder(
                searchPlaceholder: const Text("Sprache suchen..."),
                builder: (context, searchQuery) {
                  final searchQueryLower = searchQuery?.toLowerCase();
                  final filteredLocales = searchQueryLower == null
                      ? TranslationLocale.values
                      : TranslationLocale.values.where(
                          (l) =>
                              l.locale.toLowerCase().contains(searchQueryLower) ||
                              l.name.toLowerCase().contains(searchQueryLower) ||
                              l.nameLocal.toLowerCase().contains(searchQueryLower),
                        );
                  return SelectItemList(
                    children: filteredLocales
                        .map(
                          (l) => SelectItemButton(value: l, child: Text("${l.locale} - ${l.name}")),
                        )
                        .toList(),
                  );
                },
              ).call,
              itemBuilder: (context, value) {
                return Text("${value.locale} - ${value.name}");
              },
              value: _selectedLocale,
              onChanged: (value) => setState(() {
                _selectedLocale = value;
              }),
              constraints: const BoxConstraints(minWidth: 200),
            ),
          ],
        ),
        actions: [
          OutlineButton(
            child: const Text('Abbrechen'),
            onPressed: () {
              // Close the dialog.
              Navigator.pop(context);
            },
          ),
          // Primary action to accept/confirm.
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

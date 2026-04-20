import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localizator/model/project.dart';
import 'package:localizator/state/app_config.dart';
import 'package:localizator/util/list_utils.dart';
import 'package:localizator/util/toast.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Locale;

import '../model/translation_locale.dart';

Future<void> showNewProjectDialog(BuildContext context, {String? filePath}) async {
  await showDialog(
    context: context,
    builder: (context) {
      return NewProjectDialog(filePath: filePath);
    },
  );
}

class NewProjectDialog extends ConsumerStatefulWidget {
  const NewProjectDialog({super.key, this.filePath});

  final String? filePath;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends ConsumerState<NewProjectDialog> {
  final _controller = TextEditingController();
  TranslationLocale? _selectedLocale;

  @override
  void initState() {
    super.initState();
    _tryToFindLocale();
    _resolveProjectNameFromFilePath();
  }

  void _tryToFindLocale() {
    // only need locale if file was given
    if (widget.filePath == null) return;

    final filename = widget.filePath!.split(Platform.pathSeparator).last.split('.').first
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

  /// Checks if there's a parent git repository and uses that folder's name as project name
  void _resolveProjectNameFromFilePath() async {
    if (widget.filePath == null) return;

    final newFile = File(widget.filePath!);

    if (!(await newFile.exists())) return;
    final gitRepoName = await _findGitRepoFolderName(newFile.parent);
    if (gitRepoName != null) {
      _controller.text = gitRepoName;
    }
  }

  Future<String?> _findGitRepoFolderName(Directory directory) async {
    final gitDir = Directory('${directory.path}${Platform.pathSeparator}.git');

    if (await gitDir.exists()) {
      // The git repo is this directory; return its name (the last segment of the path)
      return directory.path.split(Platform.pathSeparator).last;
    }

    final parentDir = directory.parent;
    if (parentDir.path == directory.path) {
      // Stop if we've reached the root (parent path equals current path)
      return null;
    }

    // Recursive call to keep searching upwards
    return _findGitRepoFolderName(parentDir);
  }

  void _handleSubmit() async {
    final projectName = _controller.text.trim();

    if (projectName.isEmpty) {
      showToast(
        context: context,
        builder: buildToast(title: "Fehler", subtitle: "Projektname muss gefüllt sein"),
      );
      return;
    }

    if (widget.filePath != null && _selectedLocale == null) {
      // there is an initial file but no locale was selected
      showToast(
        context: context,
        builder: buildToast(
          title: "Fehler",
          subtitle:
              "Wenn eine Datei angegeben wurde, muss dafür auch eine Sprache ausgewählt werden.",
        ),
      );
      return;
    }

    final translationFile = widget.filePath == null || _selectedLocale == null
        ? null
        : TranslationFile(locale: _selectedLocale!, path: widget.filePath!);

    final newProject = Project(
      name: _controller.text.trim(),
      filePaths: translationFile == null ? const IList.empty() : [translationFile].lock,
    );

    final appConfig = await ref.read(appConfigStateProvider.future);
    ref
        .read(appConfigStateProvider.notifier)
        .set(
          appConfig.copyWith(
            projects: appConfig.projects.add(newProject),
            lastUsedProject: newProject,
          ),
        );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 450),
      child: AlertDialog(
        title: Align(alignment: .centerLeft, child: const Text('Neues Projekt')),
        content: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            FormField(
              key: const InputKey("projectName"),
              label: const Text("Projektname"),
              child: TextField(controller: _controller, placeholder: const Text("Projektname")),
            ),
            if (widget.filePath != null)
              Text("Sprache für ${widget.filePath!.split(Platform.pathSeparator).last} festlegen"),
            if (widget.filePath != null)
              FormField(
                key: const InputKey("locale"),
                label: const Text("Sprache"),
                child: Select<TranslationLocale>(
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
                              (l) => SelectItemButton(
                                value: l,
                                child: Text("${l.locale} - ${l.name}"),
                              ),
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

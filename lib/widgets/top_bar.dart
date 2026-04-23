import 'package:desktop_drop/desktop_drop.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localizator/model/app_config.dart';
import 'package:localizator/state/app_config.dart';
import 'package:localizator/state/localization_project_state.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../dialogs/add_file_to_project_dialog.dart';
import '../dialogs/confirm_dialog.dart';
import '../dialogs/new_project_dialog.dart';
import '../model/project.dart';
import '../util/list_utils.dart';
import '../util/toast.dart';

class TopBar extends ConsumerStatefulWidget {
  const TopBar({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<TopBar> {
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

  void _handleSaveToFiles() {
    final localizationProject = ref.read(localizationProjectStateProvider).value;
    if (localizationProject == null || localizationProject.isDirty != true) return;

    ref.read(localizationProjectStateProvider.notifier).saveToFiles();
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = ref.watch(appConfigStateProvider).value;
    final projects = appConfig?.projects ?? const IList.empty();
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
          _handleSaveToFiles();
        },
      },
      child: Scaffold(
        headers: [
          AppBar(
            leading: [const Text("Localizator", style: TextStyle(fontSize: 18, fontWeight: .w500))],
            title: Consumer(
              builder: (context, ref, child) {
                final localizationProject = ref.watch(localizationProjectStateProvider).value;
                if (localizationProject?.isDirty != true) return SizedBox();
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _handleSaveToFiles,
                    child: Align(
                      alignment: .centerLeft,
                      child: Card(
                        padding: .all(8),
                        borderColor: Colors.yellow.shade600,
                        child: Text(
                          "Muss gespeichert werden",
                          overflow: .ellipsis,
                          style: TextStyle(color: Colors.yellow.shade600, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            trailingGap: 8,
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
              ),
              Tooltip(
                tooltip: (context) => TooltipContainer(child: const Text("Neues Projekt")),
                child: IconButton.primary(
                  icon: const Icon(Icons.add),
                  onPressed: () => showNewProjectDialog(context),
                ),
              ),
              Tooltip(
                tooltip: (context) => TooltipContainer(child: const Text("Dateien neu laden")),
                child: IconButton.primary(
                  icon: const Icon(LucideIcons.refreshCw),
                  onPressed: () async {
                    if (ref.read(localizationProjectStateProvider).value?.isDirty ?? false) {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: "Neu laden?",
                        body:
                            "Das verwirft aktuelle Änderungen, die noch nicht gespeichert wurden.",
                      );
                      if (!confirmed) return;
                    }
                    ref.invalidate(localizationProjectStateProvider);
                  },
                ),
              ),
              Tooltip(
                tooltip: (context) =>
                    TooltipContainer(child: const Text("Gesamte App-Config löschen")),
                child: IconButton.destructive(
                  icon: const Icon(Icons.settings, color: Colors.red),
                  onPressed: () async {
                    // delete config
                    final confirmed = await showConfirmDialog(
                      context,
                      title: "Einstellungen löschen?",
                      body: "Es werden alle hinterlegten Projekte und Einstellungen gelöscht.",
                    );
                    if (!confirmed) return;
                    await AppConfig.delete();
                    ref.invalidate(appConfigStateProvider);
                  },
                ),
              ),
            ],
          ),
          Divider(),
        ],
        child: DropTarget(
          enable: true,
          onDragDone: _handleFileDrop,
          child: SizedBox.expand(child: widget.child),
        ),
      ),
    );
  }
}

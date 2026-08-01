import 'dart:convert';
import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:localizator/state/app_config.dart';
import 'package:localizator/util/list_utils.dart';
import 'package:localizator/util/path_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants.dart';
import '../model/translation.dart';

part 'localization_project_state.g.dart';

@Riverpod(keepAlive: true)
class LocalizationProjectState extends _$LocalizationProjectState {
  @override
  Future<LocalizationProject?> build() async {
    final appConfig = ref.watch(appConfigStateProvider).value;
    if (appConfig?.lastUsedProject == null ||
        appConfig!.lastUsedProject!.filePaths.isEmpty ||
        appConfig.lastUsedProject?.gitRepoPath == null) {
      ref.read(currentGitBranchProvider.notifier).set(null);
      return null;
    }

    final gitRepoPath = appConfig.lastUsedProject!.gitRepoPath;
    ref
        .read(currentGitBranchProvider.notifier)
        .set(gitRepoPath == null ? null : await Directory(gitRepoPath).currentGitBranch());

    LocalizationProject? project;
    for (final translationFile in appConfig.lastUsedProject!.filePaths) {
      final file = File(translationFile.path);
      if (!(await file.exists())) continue;
      final json = jsonDecode(await file.readAsString());
      project = LocalizationProject.parseTranslationJson(
        json: json,
        locale: translationFile.locale,
        existingProject: project,
      );
    }
    return project;
  }

  /// Whether the current project's git repo is now on a different branch than when the
  /// translations were last (re)loaded.
  Future<bool> hasGitBranchChanged() async {
    final gitRepoPath = ref.read(appConfigStateProvider).value?.lastUsedProject?.gitRepoPath;
    if (gitRepoPath == null) return false;

    final currentBranch = await Directory(gitRepoPath).currentGitBranch();
    return currentBranch != ref.read(currentGitBranchProvider);
  }

  void set(LocalizationProject project) {
    state = AsyncData(project);
  }

  void updateTranslation(TranslationKey key, Translation translation) {
    final localizationProject = state.value;
    if (localizationProject == null) return;

    state = AsyncData(localizationProject.withTranslation(key: key, translation: translation));
  }

  void removeTranslation(TranslationKey key) {
    final localizationProject = state.value;
    if (localizationProject == null) return;

    state = AsyncData(localizationProject.withoutTranslation(key: key));
  }

  void removeTranslationsWhere(bool Function(TranslationKey, Translation) predicate) {
    final localizationProject = state.value;
    if (localizationProject == null) return;

    state = AsyncData(localizationProject.withoutTranslationsWhere(predicate));
  }

  Future<void> saveToFiles() async {
    final appConfig = ref.read(appConfigStateProvider).value;
    final localizationProject = state.value;
    if (appConfig?.lastUsedProject == null ||
        localizationProject == null ||
        localizationProject.isDirty != true) {
      return;
    }

    for (final locale in localizationProject.languages) {
      final translationFile = appConfig?.lastUsedProject?.filePaths.firstWhereOrNull(
        (file) => file.locale == locale,
      );
      if (translationFile == null) continue;

      final jsonString = localizationProject.toJsonString(locale);
      await translationFile.file.writeAsString(jsonString);
    }

    state = AsyncData(localizationProject.withIsDirty(false));
  }
}

/// The git branch that was checked out the last time the translations were (re)loaded, so a
/// later branch switch made outside the app (e.g. in a terminal) can be detected - see
/// [LocalizationProjectState.hasGitBranchChanged]. `null` if the current project isn't in a git
/// repo, or no project is loaded.
@Riverpod(keepAlive: true)
class CurrentGitBranch extends _$CurrentGitBranch {
  @override
  String? build() => null;

  void set(String? branch) {
    state = branch;
  }
}

/// Contains a Set of [TranslationKey]. Each of these keys means that currently there is a new key being added as new child of it.
@Riverpod(keepAlive: true)
class TranslationKeysAdding extends _$TranslationKeysAdding {
  @override
  ISet<TranslationKey> build() {
    return const ISet.empty();
  }

  void add(TranslationKey key) {
    state = state.add(key);
  }

  void remove(TranslationKey key) {
    state = state.remove(key);
  }

  void finishAdding(TranslationKey? newTranslationKey, TranslationKey virtualNodeKey) {
    // remove virtual adding tree node
    state = state.remove(virtualNodeKey.parent);

    if (newTranslationKey == null) {
      return;
    }

    ref
        .read(localizationProjectStateProvider.notifier)
        .updateTranslation(
          TranslationKey(
            newTranslationKey.keyParts.where((p) => p != Constants.addingKey).toIList(),
          ),
          Translation(key: newTranslationKey),
        );
  }
}

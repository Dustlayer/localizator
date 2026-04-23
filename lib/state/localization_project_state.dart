import 'dart:convert';
import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:localizator/state/app_config.dart';
import 'package:localizator/util/list_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants.dart';
import '../model/translation.dart';

part 'localization_project_state.g.dart';

@Riverpod(keepAlive: true)
class LocalizationProjectState extends _$LocalizationProjectState {
  @override
  Future<LocalizationProject?> build() async {
    final appConfig = ref.watch(appConfigStateProvider).value;
    if (appConfig?.lastUsedProject == null || appConfig!.lastUsedProject!.filePaths.isEmpty) {
      return null;
    }

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

  void updateTranslation(TranslationKey key, Translation translation) {
    final localizationProject = state.value;
    if (localizationProject == null) return;

    state = AsyncData(localizationProject.withTranslation(key: key, translation: translation));
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

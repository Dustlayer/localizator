import 'dart:convert';
import 'dart:io';

import 'package:localizator/state/app_config.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

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
        langCode: translationFile.locale.locale,
        existingProject: project,
      );
    }
    return project;
  }
}

@riverpod
List<TreeViewNode<TranslationKey>>? localizationTreeNodes(Ref ref) {
  final localizationProject = ref.watch(localizationProjectStateProvider).value;

  if (localizationProject == null) return null;

  return localizationProject.toTreeNodes();
}

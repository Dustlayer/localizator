import 'dart:developer';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localizator/state/app_config.dart';
import 'package:localizator/util/path_utils.dart';

import 'model/app_config.dart';

Future<void> startup(WidgetRef ref) async {
  try {
    await _addGitRepoToProjects(ref);
  } catch (e, stackTrace) {
    log(
      "Error on startup",
      error: e,
      stackTrace: stackTrace,
      name: 'app.startup', // Helps filter logs
      level: 1000, // Severe/Error level
    );
  }
}

Future<void> _addGitRepoToProjects(WidgetRef ref) async {
  final appConfig = await ref.read(appConfigStateProvider.future);
  bool updatedConfig = false;
  AppConfig newAppConfig = appConfig;
  for (final project in appConfig.projects) {
    if (project.gitRepoPath != null) continue;

    final gitRepo = await project.filePaths.first.file.parent.findGitRepoDirectory();
    if (gitRepo != null) {
      updatedConfig = true;
      final updatedProject = project.copyWith(gitRepoPath: gitRepo.path);
      newAppConfig = newAppConfig.copyWith(
        projects: newAppConfig.projects
            .map((p) => p.name == updatedProject.name ? updatedProject : p)
            .toIList(),
      );
    }
  }
  if (updatedConfig) {
    ref.read(appConfigStateProvider.notifier).set(newAppConfig);
  }
}

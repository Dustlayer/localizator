import 'dart:convert';
import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:localizator/model/project.dart';
import 'package:path_provider/path_provider.dart';

part 'app_config.g.dart';

@JsonSerializable()
class AppConfig {
  const AppConfig({required this.projects, required this.lastUsedProject});
  final IList<Project> projects;
  final Project? lastUsedProject;

  Map<String, dynamic> toJson() => _$AppConfigToJson(this);
  factory AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);

  static Future<File> _getConfigFile() async {
    final directory = await getApplicationSupportDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/config.json');
  }

  static Future<AppConfig> load() async {
    try {
      final file = await _getConfigFile();

      if (await file.exists()) {
        final String contents = await file.readAsString();
        final Map<String, dynamic> json = jsonDecode(contents);
        return AppConfig.fromJson(json);
      }
      return AppConfig(projects: const IList.empty(), lastUsedProject: null);
    } catch (e) {
      // Log error or handle corruption here
      print('Error loading config: $e');
    }

    // Return a default empty state if file doesn't exist or load fails
    return AppConfig(projects: IList(const []), lastUsedProject: null);
  }

  Future<void> save() async {
    try {
      final file = await _getConfigFile();
      final String jsonString = jsonEncode(toJson());

      // Use writeAsString with a temporary file swap for maximum safety,
      // but for a simple local config, a direct write is usually fine.
      await file.writeAsString(jsonString);
    } catch (e) {
      print('Error saving config: $e');
    }
  }

  static Future<void> delete() async {
    try {
      final file = await _getConfigFile();
      await file.delete();
    } on Exception {
      // ignore
    }
  }

  AppConfig copyWith({IList<Project>? projects, Project? lastUsedProject}) {
    return AppConfig(
      lastUsedProject: lastUsedProject ?? this.lastUsedProject,
      projects: projects ?? this.projects,
    );
  }
}

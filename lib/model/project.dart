import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:json_annotation/json_annotation.dart';

import 'translation_locale.dart';

part 'project.g.dart';

@JsonSerializable()
class TranslationFile {
  const TranslationFile({required this.path, required this.locale});
  final String path;
  final TranslationLocale locale;

  @JsonKey(includeFromJson: false, includeToJson: false)
  File get file => File(path);

  Map<String, dynamic> toJson() => _$TranslationFileToJson(this);

  factory TranslationFile.fromJson(Map<String, dynamic> json) => _$TranslationFileFromJson(json);
}

@JsonSerializable()
class Project {
  const Project({required this.name, required this.filePaths});

  final String name;
  final IList<TranslationFile> filePaths;

  Map<String, dynamic> toJson() => _$ProjectToJson(this);

  factory Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);

  Project withFiles(IList<TranslationFile> filePaths) => Project(name: name, filePaths: filePaths);
}

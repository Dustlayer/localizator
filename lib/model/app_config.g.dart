// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) => AppConfig(
  projects: IList<Project>.fromJson(
    json['projects'],
    (value) => Project.fromJson(value as Map<String, dynamic>),
  ),
  lastUsedProject: json['lastUsedProject'] == null
      ? null
      : Project.fromJson(json['lastUsedProject'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
  'projects': instance.projects.toJson((value) => value),
  'lastUsedProject': instance.lastUsedProject,
};

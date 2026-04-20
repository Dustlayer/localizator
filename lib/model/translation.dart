import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

class TranslationKey {
  const TranslationKey(this.keyParts);
  final IList<String> keyParts;

  String get key => keyParts.join('.');

  factory TranslationKey.fromKey(String key) {
    return TranslationKey(key.split('.').toIList());
  }

  @override
  String toString() => keyParts.last;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationKey && runtimeType == other.runtimeType && key == other.key;

  @override
  int get hashCode => key.hashCode;
}

class Translation {
  Translation({required this.key, this.translations = const IMap.empty()});

  final TranslationKey key;
  // Using IMap here ensures the values for each language are also immutable
  final IMap<String, String> translations;

  Translation copyWith({IMap<String, String>? translations}) {
    return Translation(key: key, translations: (translations ?? this.translations));
  }
}

class LocalizationProject {
  // We use ListMap to preserve the order in which keys were discovered
  final IMap<TranslationKey, Translation> rows;
  final ISet<String> languages;

  LocalizationProject({required this.rows, required this.languages});

  static LocalizationProject parseTranslationJson({
    required Map<String, dynamic> json,
    required String langCode,
    LocalizationProject? existingProject,
  }) {
    // Start with existing data or empty collections
    IMap<TranslationKey, Translation> translations =
        existingProject?.rows ?? const IMap<TranslationKey, Translation>.empty();
    ISet<String> languages = (existingProject?.languages ?? ISet<String>()).add(langCode);

    void recurse(Map<String, dynamic> data, List<String> path) {
      data.forEach((key, value) {
        final currentPath = [...path, key];

        if (value is Map<String, dynamic>) {
          // Continue nesting
          recurse(value, currentPath);
        } else if (value is String) {
          // We found a leaf node (a translation)
          final translationKey = TranslationKey(currentPath.toIList());

          final existingTranslation = translations[translationKey];

          if (existingTranslation != null) {
            // Key exists, add this language to it
            final updatedMap = existingTranslation.translations.add(langCode, value);
            translations = translations.add(
              translationKey,
              existingTranslation.copyWith(translations: updatedMap),
            );
          } else {
            // New key discovered
            translations = translations.add(
              translationKey,
              Translation(key: translationKey, translations: {langCode: value}.lock),
            );
          }
        }
      });
    }

    recurse(json, []);
    return LocalizationProject(rows: translations, languages: languages);
  }
}

extension LocalizationExporter on LocalizationProject {
  String toJsonString(String langCode, {bool sortByAlphabet = false}) {
    // Get the keys in the desired order
    Iterable<TranslationKey> sortedKeys = rows.keys;
    if (sortByAlphabet) {
      // Sorts by the full dot-notation string representation
      final list = sortedKeys.toList();
      list.sort((a, b) => a.key.compareTo(b.key));
      sortedKeys = list;
    }

    final Map<String, dynamic> root = {};

    for (final translationKey in sortedKeys) {
      final translation = rows[translationKey];
      final value = translation?.translations[langCode];

      // Skip if this specific language doesn't have a value for this key
      if (value == null) continue;

      _assignNested(root, translationKey.keyParts, value, sortByAlphabet);
    }

    // Use JsonEncoder.withIndent for a clean, human-readable file
    return const JsonEncoder.withIndent('  ').convert(root);
  }

  void _assignNested(
    Map<String, dynamic> currentMap,
    IList<String> parts,
    String value,
    bool sortByAlphabet,
  ) {
    final String currentPart = parts.first;

    if (parts.length == 1) {
      // Leaf node: set the actual translation string
      currentMap[currentPart] = value;
    } else {
      // Intermediate node: create a Map if it doesn't exist
      if (!currentMap.containsKey(currentPart)) {
        // If alphabetizing, we don't need to do anything special here,
        // but we ensure the child map is created.
        currentMap[currentPart] = <String, dynamic>{};
      }

      _assignNested(currentMap[currentPart], parts.sublist(1), value, sortByAlphabet);
    }

    // If alphabetizing, we sort the map keys at this level
    if (sortByAlphabet) {
      final sortedEntries = currentMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      currentMap.clear();
      currentMap.addEntries(sortedEntries);
    }
  }
}

extension LocalizationTree on LocalizationProject {
  List<TreeViewNode<TranslationKey>> toTreeNodes() {
    // Build a nested helper map
    // String (part) -> Map (children) OR TranslationKey (leaf)
    final Map<String, dynamic> structure = {};

    for (final translationKey in rows.keys) {
      Map<String, dynamic> current = structure;
      final parts = translationKey.keyParts;

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        final isLast = i == parts.length - 1;

        if (isLast) {
          // Store the actual TranslationKey object at the leaf
          current[part] = translationKey;
        } else {
          current = current.putIfAbsent(part, () => <String, dynamic>{});
        }
      }
    }

    // Recursively convert the map to TreeViewNodes
    return _mapToNodes(structure);
  }

  List<TreeViewNode<TranslationKey>> _mapToNodes(Map<String, dynamic> map) {
    return map.entries.map((entry) {
      if (entry.value is TranslationKey) {
        // This is a leaf node (a specific translation key)
        return TreeViewNode<TranslationKey>(entry.value as TranslationKey);
      } else {
        // This is a folder/group node
        // We create a "virtual" key for the group or use a null-content node if the package allows
        // Here, we'll create a dummy TranslationKey to represent the branch
        return TreeViewNode<TranslationKey>(
          TranslationKey.fromKey(entry.key),
          children: _mapToNodes(entry.value as Map<String, dynamic>),
        );
      }
    }).toList();
  }
}

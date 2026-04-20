import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:localizator/model/translation_locale.dart';
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
  // Maps the locale to the actual translated text
  final IMap<TranslationLocale, String> translations;

  Translation copyWith({IMap<TranslationLocale, String>? translations}) {
    return Translation(key: key, translations: (translations ?? this.translations));
  }

  Translation withUpdatedTranslation(TranslationLocale locale, String text) {
    return copyWith(translations: translations.update(locale, (_) => text, ifAbsent: () => text));
  }
}

class LocalizationProject {
  const LocalizationProject({
    required this.translations,
    required this.languages,
    this.isDirty = false,
  });
  final IMap<TranslationKey, Translation> translations;
  final ISet<TranslationLocale> languages;
  final bool isDirty;

  LocalizationProject withIsDirty(bool isDirty) =>
      LocalizationProject(translations: translations, languages: languages, isDirty: isDirty);

  LocalizationProject withTranslation({
    required TranslationKey key,
    required Translation translation,
  }) {
    // update translation value, adding key if not present
    final newTranslations = translations.update(
      key,
      (_) => translation,
      ifAbsent: () => translation,
    );
    return LocalizationProject(translations: newTranslations, languages: languages, isDirty: true);
  }

  static LocalizationProject parseTranslationJson({
    required Map<String, dynamic> json,
    required TranslationLocale locale,
    LocalizationProject? existingProject,
  }) {
    // Start with existing data or empty collections
    IMap<TranslationKey, Translation> translations =
        existingProject?.translations ?? const IMap<TranslationKey, Translation>.empty();
    ISet<TranslationLocale> languages = (existingProject?.languages ?? ISet<TranslationLocale>())
        .add(locale);

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
            final updatedMap = existingTranslation.translations.add(locale, value);
            translations = translations.add(
              translationKey,
              existingTranslation.copyWith(translations: updatedMap),
            );
          } else {
            // New key discovered
            translations = translations.add(
              translationKey,
              Translation(key: translationKey, translations: {locale: value}.lock),
            );
          }
        }
      });
    }

    recurse(json, []);
    return LocalizationProject(translations: translations, languages: languages);
  }
}

extension LocalizationExporter on LocalizationProject {
  String toJsonString(TranslationLocale locale, {bool sortByAlphabet = false}) {
    // Get the keys in the desired order
    Iterable<TranslationKey> sortedKeys = translations.keys;
    if (sortByAlphabet) {
      // Sorts by the full dot-notation string representation
      final list = sortedKeys.toList();
      list.sort((a, b) => a.key.compareTo(b.key));
      sortedKeys = list;
    }

    final Map<String, dynamic> root = {};

    for (final translationKey in sortedKeys) {
      final translation = translations[translationKey];
      final value = translation?.translations[locale];

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

class TranslationKeyTreeNode {
  const TranslationKeyTreeNode({required this.translationKey, required this.hasAllKeys});
  final TranslationKey translationKey;
  final bool hasAllKeys;
}

extension LocalizationTree on LocalizationProject {
  List<TreeViewNode<TranslationKeyTreeNode>> toTreeNodes() {
    // Build a nested helper map
    // String (part) -> Map (children) OR TranslationKey (leaf)
    final Map<String, dynamic> structure = {};

    for (final translationKey in translations.keys) {
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

  // List<TreeViewNode<TranslationKeyTreeNode>> _mapToNodes(Map<String, dynamic> map) {
  //   return map.entries.map((entry) {
  //     if (entry.value is TranslationKey) {
  //       // This is a leaf node (a specific translation key)
  //       final key = entry.value as TranslationKey;
  //       final translationMap = translations[key]?.translations;
  //       // only count when a translation is actually filled
  //       final countTranslationsWithContent = translationMap?.values
  //           .where((text) => text.trim().isNotEmpty)
  //           .length;
  //       return TreeViewNode<TranslationKeyTreeNode>(
  //         TranslationKeyTreeNode(
  //           translationKey: key,
  //           hasAllKeys: countTranslationsWithContent == languages.length,
  //         ),
  //       );
  //     } else {
  //       // This is a folder/group node
  //       // Here, we'll create a dummy TranslationKey to represent the branch
  //       return TreeViewNode<TranslationKeyTreeNode>(
  //         TranslationKeyTreeNode(
  //           translationKey: TranslationKey.fromKey(entry.key),
  //           hasAllKeys: true, // this needs to be false if a child has it as false
  //         ),
  //         children: _mapToNodes(entry.value as Map<String, dynamic>),
  //       );
  //     }
  //   }).toList();
  // }

  List<TreeViewNode<TranslationKeyTreeNode>> _mapToNodes(Map<String, dynamic> map) {
    return map.entries.map((entry) {
      if (entry.value is TranslationKey) {
        // leaf node
        final key = entry.value as TranslationKey;
        final translationMap = translations[key]?.translations;

        final countTranslationsWithContent =
            translationMap?.values.where((text) => text.trim().isNotEmpty).length ?? 0;

        return TreeViewNode<TranslationKeyTreeNode>(
          TranslationKeyTreeNode(
            translationKey: key,
            hasAllKeys: countTranslationsWithContent == languages.length,
          ),
        );
      } else {
        // branch node
        // Recurse first to get the children nodes
        final List<TreeViewNode<TranslationKeyTreeNode>> children = _mapToNodes(
          entry.value as Map<String, dynamic>,
        );

        // Determine if ALL children have hasAllKeys set to true
        // If any child is missing a translation, this parent is also incomplete.
        final bool allChildrenComplete = children.every((node) => node.content.hasAllKeys);

        return TreeViewNode<TranslationKeyTreeNode>(
          TranslationKeyTreeNode(
            translationKey: TranslationKey.fromKey(entry.key),
            hasAllKeys: allChildrenComplete,
          ),
          children: children,
        );
      }
    }).toList();
  }
}

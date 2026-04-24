import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:localizator/model/translation_locale.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../constants.dart';

class TranslationKey {
  const TranslationKey(this.keyParts);
  final IList<String> keyParts;

  String get key => keyParts.join('.');

  TranslationKey get parent => TranslationKey(keyParts.sublist(0, keyParts.length - 1));

  factory TranslationKey.fromKey(String key) {
    return TranslationKey(key.split('.').toIList());
  }

  TranslationKey withAddedKeyParts(IList<String> parts) {
    return TranslationKey(keyParts.addAll(parts));
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

      // Skip if this specific language doesn't have a value for this key or it's empty
      if (value == null || value.trim().isEmpty) continue;

      _assignNested(root, translationKey.keyParts, value, sortByAlphabet);
    }

    // Use JsonEncoder.withIndent for a clean, human-readable file
    return "${const JsonEncoder.withIndent('  ').convert(root)}\n";
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
  const TranslationKeyTreeNode({
    required this.translationKey,
    required this.hasAllKeys,
    this.isAddingKey = false,
  });

  final TranslationKey translationKey;

  /// Shows whether this entry (or any of its children) has a key with content for each language defined.
  /// If false, it will be shown as red to notify for empty translations.
  final bool hasAllKeys;

  /// Signals that this is a "virtual node" and a key is being added using this node.
  /// A TextField should be displayed so the user can input a new translation key.
  final bool isAddingKey;

  // Leaving out isAddingKey to not collapse the TreeViewNode
  @override
  bool operator ==(Object other) =>
      other is TranslationKeyTreeNode && translationKey == other.translationKey;

  @override
  int get hashCode => translationKey.hashCode;
}

extension LocalizationTree on LocalizationProject {
  /// [keysBeingAdded] contains a Set of keys. "Underneath" / Inside of each key there should be
  /// "virtual" node with an input field, where the user can input a new node.
  List<TreeViewNode<TranslationKeyTreeNode>> toTreeNodes({
    required ISet<TranslationKey> keysBeingAdded,
    required Set<TranslationKey> expandedKeys,
    String query = "",
  }) {
    // Build a nested helper map
    // String (part) -> Map (children) OR TranslationKey (leaf)
    final Map<String, dynamic> structure = {};
    final lowerQuery = query.trim().toLowerCase();

    for (final translationKey in translations.keys) {
      if (lowerQuery.isNotEmpty && !translationKey.key.toLowerCase().contains(lowerQuery)) continue;
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
    return _mapToNodes(structure, keysBeingAdded, const IList.empty(), expandedKeys);
  }

  List<TreeViewNode<TranslationKeyTreeNode>> _mapToNodes(
    Map<String, dynamic> map,
    ISet<TranslationKey> keysBeingAdded,
    IList<String> parentPath,
    Set<TranslationKey> expandedKeys,
  ) {
    return map.entries.map((entry) {
      final currentPath = parentPath.add(entry.key);
      final currentTranslationKey = TranslationKey(currentPath);

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
        final branchTranslationKey = currentTranslationKey;
        final List<TreeViewNode<TranslationKeyTreeNode>> children = [
          if (keysBeingAdded.contains(branchTranslationKey))
            // add virtual node for adding a new node
            TreeViewNode<TranslationKeyTreeNode>(
              TranslationKeyTreeNode(
                translationKey: branchTranslationKey.withAddedKeyParts([Constants.addingKey].lock),
                hasAllKeys: true,
                isAddingKey: true,
              ),
            ),
          ..._mapToNodes(
            entry.value as Map<String, dynamic>,
            keysBeingAdded,
            currentPath,
            expandedKeys,
          ),
        ];

        // Determine if ALL children have hasAllKeys set to true
        // If any child is missing a translation, this parent is also incomplete.
        final bool allChildrenComplete = children.every((node) => node.content.hasAllKeys);

        final nodeContent = TranslationKeyTreeNode(
          translationKey: branchTranslationKey,
          hasAllKeys: allChildrenComplete,
        );

        return TreeViewNode<TranslationKeyTreeNode>(
          nodeContent,
          children: children,
          expanded: expandedKeys.contains(nodeContent.translationKey),
        );
      }
    }).toList();
  }
}

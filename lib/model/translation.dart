import 'dart:convert';
import 'dart:math' as math;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:localizator/model/translation_locale.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../constants.dart';
import '../util/list_utils.dart';
import 'pluralization_strategy.dart';

class TranslationKey {
  const TranslationKey(this.keyParts);
  final IList<String> keyParts;

  String get key => keyParts.join('.');

  /// Depth in the tree
  int get depth => keyParts.length;

  TranslationKey get parent =>
      TranslationKey(keyParts.sublist(0, math.max(0, keyParts.length - 1)));
  bool get hasParent => keyParts.isNotEmpty;

  /// Whether this key lies within the subtree rooted at [other]. i.e. [other] is a strict,
  /// dot-bounded prefix of this key (so `foobar` is not considered a descendant of `foo`).
  bool isDescendantOf(TranslationKey other) => key.startsWith('${other.key}.');

  factory TranslationKey.fromKey(String key) {
    return TranslationKey(key.split('.').toIList());
  }

  TranslationKey withAddedKeyParts(IList<String> parts) {
    return TranslationKey(keyParts.addAll(parts));
  }

  /// Appends [suffix] to the last key part, e.g. `foo.bar` with `_one` becomes `foo.bar_one`.
  TranslationKey withSuffix(String suffix) {
    return TranslationKey(keyParts.sublist(0, keyParts.length - 1).add('${keyParts.last}$suffix'));
  }

  @override
  String toString() => key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationKey && runtimeType == other.runtimeType && key == other.key;

  @override
  int get hashCode => key.hashCode;
}

/// The plural categories used by react-i18next (and ICU) for pluralization.
enum PluralCategory { zero, one, two, few, many, other }

extension PluralCategoryLabel on PluralCategory {
  String get label => switch (this) {
    PluralCategory.zero => 'Zero',
    PluralCategory.one => 'One',
    PluralCategory.two => 'Two',
    PluralCategory.few => 'Few',
    PluralCategory.many => 'Many',
    PluralCategory.other => 'Other',
  };
}

/// A single translation key's content across all locales in the project - either a plain
/// [SimpleTranslation] or a [PluralizedTranslation] with separate forms per [PluralCategory].
///
/// The UI shows different inputs depending on whether a [SimpleTranslation] or
/// [PluralizedTranslation] is used.
sealed class Translation {
  const Translation({required this.key});

  final TranslationKey key;

  /// Whether [locale] has any non-empty content for this key - for [PluralizedTranslation],
  /// that means at least one plural form is filled in.
  bool hasContentFor(TranslationLocale locale);

  /// Combines this [Translation] with [other] for the same [key], e.g. when merging the data
  /// parsed from different locale files for that key. If the two disagree on whether the key
  /// is pluralized (e.g. one locale file was hand-edited to add `_one`/`_other` suffixes before
  /// the others), the non-pluralized side is upgraded via [SimpleTranslation.pluralized] first,
  /// so neither locale's data is silently dropped.
  Translation mergedWith(Translation other);

  /// A copy of this translation under [newKey] instead - used when renaming/moving a key via
  /// [LocalizationKeyRenaming.withRenamedKey].
  Translation withKey(TranslationKey newKey);
}

class SimpleTranslation extends Translation {
  SimpleTranslation({required super.key, this.translations = const IMap.empty()});

  /// Maps the locale to the actual translated text.
  final IMap<TranslationLocale, String> translations;

  SimpleTranslation withUpdatedTranslation(TranslationLocale locale, String text) {
    return SimpleTranslation(
      key: key,
      translations: translations.update(locale, (_) => text, ifAbsent: () => text),
    );
  }

  /// Converts this into a pluralized translation, moving each locale's existing plain value
  /// into the [PluralCategory.other] form.
  PluralizedTranslation pluralized() {
    var pluralTranslations = const IMap<TranslationLocale, IMap<PluralCategory, String>>.empty();
    for (final entry in translations.entries) {
      pluralTranslations = pluralTranslations.add(
        entry.key,
        {PluralCategory.other: entry.value}.lock,
      );
    }
    return PluralizedTranslation(key: key, pluralTranslations: pluralTranslations);
  }

  @override
  bool hasContentFor(TranslationLocale locale) {
    final value = translations[locale];
    return value != null && value.trim().isNotEmpty;
  }

  @override
  SimpleTranslation withKey(TranslationKey newKey) =>
      SimpleTranslation(key: newKey, translations: translations);

  @override
  Translation mergedWith(Translation other) {
    switch (other) {
      case PluralizedTranslation():
        return pluralized().mergedWith(other);
      case SimpleTranslation(:final translations):
        var mergedTranslations = this.translations;
        for (final entry in translations.entries) {
          mergedTranslations = mergedTranslations.add(entry.key, entry.value);
        }
        return SimpleTranslation(key: key, translations: mergedTranslations);
    }
  }
}

class PluralizedTranslation extends Translation {
  PluralizedTranslation({required super.key, this.pluralTranslations = const IMap.empty()});

  /// Maps the locale to its plural forms.
  final IMap<TranslationLocale, IMap<PluralCategory, String>> pluralTranslations;

  PluralizedTranslation withUpdatedPluralTranslation(
    TranslationLocale locale,
    PluralCategory category,
    String text,
  ) {
    final formsForLocale = (pluralTranslations[locale] ?? const IMap.empty()).update(
      category,
      (_) => text,
      ifAbsent: () => text,
    );
    return PluralizedTranslation(
      key: key,
      pluralTranslations: pluralTranslations.update(
        locale,
        (_) => formsForLocale,
        ifAbsent: () => formsForLocale,
      ),
    );
  }

  /// Converts this into a non-pluralized translation, moving each locale's [PluralCategory.other]
  /// value or, if that's empty, its first non-empty plural form into the plain value.
  SimpleTranslation depluralized() {
    var translations = const IMap<TranslationLocale, String>.empty();
    for (final entry in pluralTranslations.entries) {
      final forms = entry.value;
      final other = forms[PluralCategory.other];
      final value = (other != null && other.trim().isNotEmpty)
          ? other
          : forms.values.firstWhereOrNull((text) => text.trim().isNotEmpty) ?? '';
      translations = translations.add(entry.key, value);
    }
    return SimpleTranslation(key: key, translations: translations);
  }

  @override
  bool hasContentFor(TranslationLocale locale) {
    final forms = pluralTranslations[locale];
    return forms != null && forms.values.any((text) => text.trim().isNotEmpty);
  }

  @override
  PluralizedTranslation withKey(TranslationKey newKey) =>
      PluralizedTranslation(key: newKey, pluralTranslations: pluralTranslations);

  @override
  Translation mergedWith(Translation other) {
    final PluralizedTranslation otherPluralized = switch (other) {
      PluralizedTranslation() => other,
      SimpleTranslation() => other.pluralized(),
    };

    var merged = pluralTranslations;
    for (final entry in otherPluralized.pluralTranslations.entries) {
      merged = merged.add(entry.key, entry.value);
    }
    return PluralizedTranslation(key: key, pluralTranslations: merged);
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

  LocalizationProject withoutTranslation({required TranslationKey key}) {
    final newTranslations = translations.remove(key);
    return LocalizationProject(translations: newTranslations, languages: languages, isDirty: true);
  }

  LocalizationProject withoutTranslationsWhere(
    bool Function(TranslationKey, Translation) predicate,
  ) {
    final newTranslations = translations.removeWhere(predicate);
    return LocalizationProject(translations: newTranslations, languages: languages, isDirty: true);
  }

  /// Flattens nested JSON objects into dot-separated [TranslationKey]s, oblivious to
  /// pluralization.
  static IMap<TranslationKey, String> _flattenJson(Map<String, dynamic> json) {
    final Map<TranslationKey, String> flat = {};

    void recurse(Map<String, dynamic> data, List<String> path) {
      data.forEach((key, value) {
        final currentPath = [...path, key];

        if (value is Map<String, dynamic>) {
          recurse(value, currentPath);
        } else if (value is String) {
          flat[TranslationKey(currentPath.toIList())] = value;
        }
      });
    }

    recurse(json, []);
    return flat.lock;
  }

  static LocalizationProject parseTranslationJson({
    required Map<String, dynamic> json,
    required TranslationLocale locale,
    LocalizationProject? existingProject,
    PluralizationStrategy pluralizationStrategy = const ReactI18nextPluralizationStrategy(),
  }) {
    final flatValues = _flattenJson(json);
    final localeTranslations = pluralizationStrategy.applyTo(flatValues, locale);

    // Start with existing data or empty collections
    IMap<TranslationKey, Translation> translations =
        existingProject?.translations ?? const IMap<TranslationKey, Translation>.empty();
    ISet<TranslationLocale> languages = (existingProject?.languages ?? ISet<TranslationLocale>())
        .add(locale);

    for (final entry in localeTranslations.entries) {
      translations = translations.update(
        entry.key,
        (existingTranslation) => existingTranslation.mergedWith(entry.value),
        ifAbsent: () => entry.value,
      );
    }

    return LocalizationProject(translations: translations, languages: languages);
  }
}

/// Maps [key], which must be [oldKey] itself or lie within its subtree, onto its new location
/// once the subtree rooted at [oldKey] is renamed/moved to [newKey].
TranslationKey movedTranslationKey(
  TranslationKey key, {
  required TranslationKey oldKey,
  required TranslationKey newKey,
}) {
  if (key == oldKey) return newKey;
  return TranslationKey(newKey.keyParts.addAll(key.keyParts.sublist(oldKey.depth)));
}

extension LocalizationKeyRenaming on LocalizationProject {
  /// [oldKey] itself, plus any descendant keys. I.e. everything that would move if the
  /// subtree rooted at it (its whole "folder", if it has children) were renamed.
  Set<TranslationKey> keysRootedAt(TranslationKey oldKey) =>
      translations.keys.where((key) => key == oldKey || key.isDescendantOf(oldKey)).toSet();

  /// Whether [key] has other, untouched (not in [excluding]) descendant keys. So whether
  /// it's a "folder" once the keys in [excluding] are taken out of the picture.
  bool _hasOtherDescendants(TranslationKey key, Set<TranslationKey> excluding) =>
      translations.keys.any((k) => !excluding.contains(k) && k.isDescendantOf(key));

  /// A validation error message if renaming/moving [oldKey] to [newKey] isn't possible (an
  /// empty key, no actual change). `null` if the rename is valid.
  ///
  /// Landing exactly on an existing *plain* key is blocked. That would silently overwrite its
  /// translation with no way back. Landing on an existing *folder* (a key that still has other
  /// descendants once the moved ones are excluded) is allowed instead, see
  /// [renameWouldMergeFolders], which flags that case for the UI to warn about separately, since
  /// it merges/overwrites rather than blocks outright.
  String? validateKeyRename({required TranslationKey oldKey, required TranslationKey newKey}) {
    if (newKey.keyParts.isEmpty || newKey.keyParts.any((part) => part.trim().isEmpty)) {
      return "Schlüssel darf nicht leer sein.";
    }
    if (newKey.key == oldKey.key) {
      return "Neuer Schlüssel entspricht dem aktuellen.";
    }

    final movedKeys = keysRootedAt(oldKey);
    for (final key in movedKeys) {
      final target = movedTranslationKey(key, oldKey: oldKey, newKey: newKey);
      final collides = !movedKeys.contains(target) && translations.containsKey(target);
      if (collides && !_hasOtherDescendants(target, movedKeys)) {
        return "Schlüssel '${target.key}' existiert bereits.";
      }
    }
    return null;
  }

  /// Whether renaming/moving [oldKey] to [newKey] would land on a folder that already exists
  /// there. i.e. keys other than the ones being moved already live under [newKey]. Landing on
  /// a plain, childless key instead is a different matter, already blocked as an error by
  /// [validateKeyRename]. This is purely informational for the UI.
  bool renameWouldMergeFolders({required TranslationKey oldKey, required TranslationKey newKey}) =>
      _hasOtherDescendants(newKey, keysRootedAt(oldKey));

  /// Renames/moves [oldKey] to [newKey], carrying along its whole subtree (all descendant keys
  /// and their translations, if it's a "folder"). Callers should check [validateKeyRename]
  /// first - this doesn't re-validate.
  LocalizationProject withRenamedKey({
    required TranslationKey oldKey,
    required TranslationKey newKey,
  }) {
    var newTranslations = translations;
    for (final key in keysRootedAt(oldKey)) {
      final translation = translations[key];
      if (translation == null) continue;
      final target = movedTranslationKey(key, oldKey: oldKey, newKey: newKey);
      newTranslations = newTranslations.remove(key).add(target, translation.withKey(target));
    }
    return LocalizationProject(translations: newTranslations, languages: languages, isDirty: true);
  }
}

extension LocalizationExporter on LocalizationProject {
  String toJsonString(
    TranslationLocale locale, {
    bool sortByAlphabet = false,
    PluralizationStrategy pluralizationStrategy = const ReactI18nextPluralizationStrategy(),
  }) {
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
      if (translation == null) continue;

      // Delegates to the pluralization strategy so plural forms are turned back into their
      // flat, suffixed keys (e.g. "testSuites_one") - skipping empty values/forms.
      for (final flatEntry in pluralizationStrategy.flatten(translation, locale).entries) {
        _assignNested(root, flatEntry.key.keyParts, flatEntry.value, sortByAlphabet);
      }
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
    required ISet<TranslationKey> expandedKeys,
    String query = "",
  }) {
    // Build a nested helper map
    // String (part) -> Map (children) OR TranslationKey (leaf)
    final Map<String, dynamic> structure = {};
    final lowerQuery = query.trim().toLowerCase();

    for (final translationKey in translations.keys) {
      if (lowerQuery.isNotEmpty && !translationKey.key.toLowerCase().contains(lowerQuery)) {
        continue;
      }
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
    ISet<TranslationKey> expandedKeys,
  ) {
    return map.entries.map((entry) {
      final currentPath = parentPath.add(entry.key);
      final currentTranslationKey = TranslationKey(currentPath);

      if (entry.value is TranslationKey) {
        // leaf node
        final key = entry.value as TranslationKey;
        final translation = translations[key];

        final countLanguagesWithContent = translation == null
            ? 0
            : languages.where((locale) => translation.hasContentFor(locale)).length;

        return TreeViewNode<TranslationKeyTreeNode>(
          TranslationKeyTreeNode(
            translationKey: key,
            hasAllKeys: countLanguagesWithContent == languages.length,
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

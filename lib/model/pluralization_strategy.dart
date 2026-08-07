import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'translation.dart';
import 'translation_locale.dart';

/// Detects and (de)serializes pluralized translation keys.
///
/// Kept separate from the pluralization-agnostic JSON tree walking in [LocalizationProject] so
/// the pluralization convention can be swapped out later (e.g. for ICU MessageFormat, which
/// wouldn't group sibling keys at all but instead split a single value's syntax into forms)
/// without touching the parser/serializer. Which strategy is used is injected,
/// see `pluralizationStrategyProvider`.
abstract class PluralizationStrategy {
  /// Takes the flat `key -> value` pairs parsed from one locale's JSON file (already flattened
  /// from nested objects into dot-separated [TranslationKey]s, oblivious to pluralization) and
  /// groups the ones that represent plural forms of the same key into a single [Translation].
  /// Keys that aren't part of a plural group are passed through as plain, single-value
  /// [Translation]s.
  IMap<TranslationKey, Translation> applyTo(
    IMap<TranslationKey, String> flatValues,
    TranslationLocale locale,
  );

  /// The inverse of [applyTo] for a single [translation]/[locale] pair: produces the flat
  /// `key -> value` pairs that should be written to that locale's JSON file. Empty
  /// forms/values are omitted so they don't end up as empty strings in the output file.
  IMap<TranslationKey, String> flatten(Translation translation, TranslationLocale locale);
}

/// Groups keys following the react-i18next convention of suffixing sibling keys with `_zero`,
/// `_one`, `_two`, `_few`, `_many` and `_other`
/// (https://www.i18next.com/translation-function/plurals).
///
class ReactI18nextPluralizationStrategy implements PluralizationStrategy {
  const ReactI18nextPluralizationStrategy();

  @override
  IMap<TranslationKey, Translation> applyTo(
    IMap<TranslationKey, String> flatValues,
    TranslationLocale locale,
  ) {
    // First pass: collect all plural-suffixed siblings per base key, without emitting anything yet.
    // A group isn't complete until we've seen all of its siblings.
    final Map<TranslationKey, Map<PluralCategory, String>> pluralGroups = {};
    final Map<TranslationKey, _PluralKeyMatch> matchByKey = {};

    for (final entry in flatValues.entries) {
      final match = _matchPluralSuffix(entry.key);
      if (match == null) continue;
      pluralGroups.putIfAbsent(match.baseKey, () => {})[match.category] = entry.value;
      matchByKey[entry.key] = match;
    }

    // Second pass: walk the original entries again, in their original order, so the output
    // preserves it - each key (plain, or the first sibling of a plural group) is added at its
    // original position; later siblings of an already-emitted group are skipped.
    final Map<TranslationKey, Translation> result = {};
    final Set<TranslationKey> emittedGroups = {};

    for (final entry in flatValues.entries) {
      final match = matchByKey[entry.key];
      if (match == null) {
        result[entry.key] = SimpleTranslation(
          key: entry.key,
          translations: {locale: entry.value}.lock,
        );
        continue;
      }

      if (emittedGroups.add(match.baseKey)) {
        result[match.baseKey] = PluralizedTranslation(
          key: match.baseKey,
          pluralTranslations: {locale: pluralGroups[match.baseKey]!.lock}.lock,
        );
      }
    }

    return result.lock;
  }

  @override
  IMap<TranslationKey, String> flatten(Translation translation, TranslationLocale locale) {
    switch (translation) {
      case SimpleTranslation(:final translations):
        final value = translations[locale];
        if (value == null || value.trim().isEmpty) return const IMap.empty();
        return IMap({translation.key: value});

      case PluralizedTranslation(:final pluralTranslations):
        final forms = pluralTranslations[locale];
        if (forms == null) return const IMap.empty();

        final Map<TranslationKey, String> flat = {};
        for (final category in PluralCategory.values) {
          final value = forms[category];
          if (value == null || value.trim().isEmpty) continue;
          flat[translation.key.withSuffix('_${category.name}')] = value;
        }
        return flat.lock;
    }
  }

  _PluralKeyMatch? _matchPluralSuffix(TranslationKey key) {
    final lastPart = key.keyParts.last;
    for (final category in PluralCategory.values) {
      final suffix = '_${category.name}';
      if (lastPart.length > suffix.length && lastPart.endsWith(suffix)) {
        final basePart = lastPart.substring(0, lastPart.length - suffix.length);
        return _PluralKeyMatch(key.parent.withAddedKeyParts([basePart].lock), category);
      }
    }
    return null;
  }
}

class _PluralKeyMatch {
  const _PluralKeyMatch(this.baseKey, this.category);
  final TranslationKey baseKey;
  final PluralCategory category;
}

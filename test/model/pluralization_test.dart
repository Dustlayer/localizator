import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localizator/model/pluralization_strategy.dart';
import 'package:localizator/model/translation.dart';
import 'package:localizator/model/translation_locale.dart';

void main() {
  group('ReactI18nextPluralizationStrategy.applyTo', () {
    const strategy = ReactI18nextPluralizationStrategy();

    test('groups two or more plural-suffixed siblings into one pluralized Translation', () {
      final result = strategy.applyTo(
        {
          TranslationKey.fromKey('testSuites_one'): 'test suite',
          TranslationKey.fromKey('testSuites_other'): 'test suites',
        }.lock,
        TranslationLocale.enUS,
      );

      expect(result.keys, [TranslationKey.fromKey('testSuites')]);
      final translation = result[TranslationKey.fromKey('testSuites')];
      expect(translation, isA<PluralizedTranslation>());
      expect(
        (translation as PluralizedTranslation).pluralTranslations[TranslationLocale.enUS]!.unlock,
        {PluralCategory.one: 'test suite', PluralCategory.other: 'test suites'},
      );
    });

    test('groups all six CLDR plural categories', () {
      final result = strategy.applyTo(
        {
          TranslationKey.fromKey('items_zero'): 'no items',
          TranslationKey.fromKey('items_one'): 'one item',
          TranslationKey.fromKey('items_two'): 'two items',
          TranslationKey.fromKey('items_few'): 'a few items',
          TranslationKey.fromKey('items_many'): 'many items',
          TranslationKey.fromKey('items_other'): 'other items',
        }.lock,
        TranslationLocale.enUS,
      );

      final translation = result[TranslationKey.fromKey('items')] as PluralizedTranslation;
      expect(
        translation.pluralTranslations[TranslationLocale.enUS]!.keys,
        unorderedEquals(PluralCategory.values),
      );
    });

    test('respects nesting - only groups keys sharing the same parent', () {
      final result = strategy.applyTo(
        {
          TranslationKey.fromKey('alerts.testSuites_one'): 'test suite',
          TranslationKey.fromKey('alerts.testSuites_other'): 'test suites',
          TranslationKey.fromKey('other.testSuites_one'): 'lonely one',
        }.lock,
        TranslationLocale.enUS,
      );

      // "alerts.testSuites" is grouped from its two siblings...
      final alertsGroup =
          result[TranslationKey.fromKey('alerts.testSuites')] as PluralizedTranslation;
      expect(alertsGroup.pluralTranslations[TranslationLocale.enUS]!.unlock, {
        PluralCategory.one: 'test suite',
        PluralCategory.other: 'test suites',
      });
      // ...and "other.testSuites" is grouped separately, from its own (lone) sibling - it isn't
      // merged with "alerts.testSuites" just because they share a suffix.
      final otherGroup =
          result[TranslationKey.fromKey('other.testSuites')] as PluralizedTranslation;
      expect(otherGroup.pluralTranslations[TranslationLocale.enUS]!.unlock, {
        PluralCategory.one: 'lonely one',
      });
    });

    test('a lone plural-suffixed key is still treated as pluralized', () {
      // Otherwise a key that was just pluralized in the editor (and saved before any form but
      // "other" was filled in) would silently revert to a plain key on the next load.
      final result = strategy.applyTo(
        {TranslationKey.fromKey('greeting_other'): 'hello'}.lock,
        TranslationLocale.enUS,
      );

      final key = TranslationKey.fromKey('greeting');
      final translation = result[key];
      expect(translation, isA<PluralizedTranslation>());
      expect(
        (translation as PluralizedTranslation).pluralTranslations[TranslationLocale
            .enUS]![PluralCategory.other],
        'hello',
      );
    });

    test('plain keys without any plural suffix pass through untouched', () {
      final result = strategy.applyTo(
        {TranslationKey.fromKey('greeting'): 'hello'}.lock,
        TranslationLocale.enUS,
      );

      final translation = result[TranslationKey.fromKey('greeting')];
      expect(translation, isA<SimpleTranslation>());
      expect((translation as SimpleTranslation).translations[TranslationLocale.enUS], 'hello');
    });
  });

  group('ReactI18nextPluralizationStrategy.flatten', () {
    const strategy = ReactI18nextPluralizationStrategy();

    test('turns plural forms back into suffixed flat keys, skipping empty ones', () {
      final translation = PluralizedTranslation(
        key: TranslationKey.fromKey('testSuites'),
        pluralTranslations: {
          TranslationLocale.enUS: {
            PluralCategory.one: 'test suite',
            PluralCategory.other: 'test suites',
            PluralCategory.few: '', // empty - should be omitted
          }.lock,
        }.lock,
      );

      final flat = strategy.flatten(translation, TranslationLocale.enUS);

      expect(flat.unlock, {
        TranslationKey.fromKey('testSuites_one'): 'test suite',
        TranslationKey.fromKey('testSuites_other'): 'test suites',
      });
    });

    test('returns nothing for a locale with no plural forms at all', () {
      final translation = PluralizedTranslation(
        key: TranslationKey.fromKey('testSuites'),
        pluralTranslations: {
          TranslationLocale.enUS: {PluralCategory.other: 'test suites'}.lock,
        }.lock,
      );

      expect(strategy.flatten(translation, TranslationLocale.deDE), isEmpty);
    });

    test('flattens plain (non-pluralized) translations as a single key', () {
      final translation = SimpleTranslation(
        key: TranslationKey.fromKey('greeting'),
        translations: {TranslationLocale.enUS: 'hello'}.lock,
      );

      expect(strategy.flatten(translation, TranslationLocale.enUS).unlock, {
        TranslationKey.fromKey('greeting'): 'hello',
      });
    });

    test('omits plain translations that are empty', () {
      final translation = SimpleTranslation(
        key: TranslationKey.fromKey('greeting'),
        translations: {TranslationLocale.enUS: '   '}.lock,
      );

      expect(strategy.flatten(translation, TranslationLocale.enUS), isEmpty);
    });
  });

  group('LocalizationProject.parseTranslationJson + toJsonString roundtrip', () {
    test('parses grouped plural keys and serializes them back to the original JSON shape', () {
      final json = {
        'testSuites_one': 'test suite',
        'testSuites_other': 'test suites',
        'greeting': 'hello',
      };

      final project = LocalizationProject.parseTranslationJson(
        json: json,
        locale: TranslationLocale.enUS,
      );

      final key = TranslationKey.fromKey('testSuites');
      expect(project.translations[key], isA<PluralizedTranslation>());

      final jsonString = project.toJsonString(TranslationLocale.enUS);
      expect(jsonString, contains('"testSuites_one": "test suite"'));
      expect(jsonString, contains('"testSuites_other": "test suites"'));
      expect(jsonString, contains('"greeting": "hello"'));
    });

    test('preserves the original top-level key order, including around a plural group', () {
      // A plain key before the group, the plural siblings (as they'd actually appear -
      // adjacent to each other), and a plain key after - a naive "emit all plural groups,
      // then all plain keys" implementation would move "zzzLast" before "aaaFirst".
      final json = jsonDecode('''
        {
          "zzzLast": "z",
          "aaaFirst": "a",
          "testSuites_one": "test suite",
          "testSuites_other": "test suites",
          "mmmMiddle": "m"
        }
      ''');

      final project = LocalizationProject.parseTranslationJson(
        json: json,
        locale: TranslationLocale.enUS,
      );

      final jsonString = project.toJsonString(TranslationLocale.enUS);
      final keyOrder = [
        'zzzLast',
        'aaaFirst',
        'testSuites_one',
        'testSuites_other',
        'mmmMiddle',
      ].map((key) => jsonString.indexOf('"$key"')).toList();

      expect(keyOrder, everyElement(greaterThanOrEqualTo(0)));
      expect(keyOrder, equals(List.of(keyOrder)..sort()));
    });

    test('preserves original order across multiple locale files with different key sets', () {
      final enProject = LocalizationProject.parseTranslationJson(
        json: jsonDecode('{"b": "B en", "a": "A en"}'),
        locale: TranslationLocale.enUS,
      );
      final merged = LocalizationProject.parseTranslationJson(
        json: jsonDecode('{"b": "B de", "a": "A de", "c": "C de"}'),
        locale: TranslationLocale.deDE,
        existingProject: enProject,
      );

      // "c" only exists in the German file, so it's appended after the keys shared with English.
      expect(merged.translations.keys.map((k) => k.key), ['b', 'a', 'c']);
    });

    test('merges plural forms parsed from multiple locale files under the same key', () {
      final enProject = LocalizationProject.parseTranslationJson(
        json: {'testSuites_one': 'test suite', 'testSuites_other': 'test suites'},
        locale: TranslationLocale.enUS,
      );
      final merged = LocalizationProject.parseTranslationJson(
        json: {'testSuites_one': 'Testfall', 'testSuites_other': 'Testfälle'},
        locale: TranslationLocale.deDE,
        existingProject: enProject,
      );

      final translation =
          merged.translations[TranslationKey.fromKey('testSuites')] as PluralizedTranslation;
      expect(
        translation.pluralTranslations[TranslationLocale.enUS]![PluralCategory.one],
        'test suite',
      );
      expect(
        translation.pluralTranslations[TranslationLocale.deDE]![PluralCategory.one],
        'Testfall',
      );
    });

    test('upgrades a plain locale file to pluralized when merged with a locale that\'s already '
        'pluralized for the same key, instead of dropping its data', () {
      final deProject = LocalizationProject.parseTranslationJson(
        json: {'greeting': 'Hallo'},
        locale: TranslationLocale.deDE,
      );
      final merged = LocalizationProject.parseTranslationJson(
        json: {'greeting_one': 'Hi', 'greeting_other': 'Hello'},
        locale: TranslationLocale.enUS,
        existingProject: deProject,
      );

      final translation =
          merged.translations[TranslationKey.fromKey('greeting')] as PluralizedTranslation;
      // German's plain value survives, moved into "other"...
      expect(
        translation.pluralTranslations[TranslationLocale.deDE]![PluralCategory.other],
        'Hallo',
      );
      // ...alongside English's own plural forms.
      expect(translation.pluralTranslations[TranslationLocale.enUS]![PluralCategory.one], 'Hi');
      expect(
        translation.pluralTranslations[TranslationLocale.enUS]![PluralCategory.other],
        'Hello',
      );
    });

    test('omits an empty plural form from the saved JSON', () {
      var project = LocalizationProject.parseTranslationJson(
        json: {'testSuites_one': 'test suite', 'testSuites_other': 'test suites'},
        locale: TranslationLocale.enUS,
      );

      final key = TranslationKey.fromKey('testSuites');
      final updated = (project.translations[key] as PluralizedTranslation)
          .withUpdatedPluralTranslation(TranslationLocale.enUS, PluralCategory.few, '');
      project = project.withTranslation(key: key, translation: updated);

      final jsonString = project.toJsonString(TranslationLocale.enUS);
      expect(jsonString, isNot(contains('_few')));
    });
  });

  group('SimpleTranslation.pluralized', () {
    test('moves each locale\'s plain value into the "other" plural category', () {
      final translation = SimpleTranslation(
        key: TranslationKey.fromKey('greeting'),
        translations: {TranslationLocale.enUS: 'hello', TranslationLocale.deDE: 'hallo'}.lock,
      );

      final pluralized = translation.pluralized();

      expect(pluralized.pluralTranslations[TranslationLocale.enUS]![PluralCategory.other], 'hello');
      expect(pluralized.pluralTranslations[TranslationLocale.deDE]![PluralCategory.other], 'hallo');
    });

    test('produces a PluralizedTranslation even with no content at all', () {
      // Regression test: pluralizing a key before any locale has a value (e.g. a freshly added
      // key, or one where every field was cleared) must still be recognized as pluralized - a
      // bool-flag-style "isPluralized" derived from "is any form non-empty" would say no.
      final translation = SimpleTranslation(key: TranslationKey.fromKey('greeting'));

      expect(translation.pluralized(), isA<PluralizedTranslation>());
    });

    test('round-trips through toJsonString using the "_other" suffix', () {
      const strategy = ReactI18nextPluralizationStrategy();
      var project = LocalizationProject.parseTranslationJson(
        json: {'greeting': 'hello'},
        locale: TranslationLocale.enUS,
      );

      final key = TranslationKey.fromKey('greeting');
      project = project.withTranslation(
        key: key,
        translation: (project.translations[key] as SimpleTranslation).pluralized(),
      );

      final jsonString = project.toJsonString(
        TranslationLocale.enUS,
        pluralizationStrategy: strategy,
      );
      expect(jsonString, contains('"greeting_other": "hello"'));
    });

    test(
      'a key pluralized and saved with only "other" filled in stays pluralized on the next load',
      () {
        var project = LocalizationProject.parseTranslationJson(
          json: {'greeting': 'hello'},
          locale: TranslationLocale.enUS,
        );
        final key = TranslationKey.fromKey('greeting');
        project = project.withTranslation(
          key: key,
          translation: (project.translations[key] as SimpleTranslation).pluralized(),
        );

        // Simulates saving to disk and reading the file back.
        final jsonString = project.toJsonString(TranslationLocale.enUS);
        final reloaded = LocalizationProject.parseTranslationJson(
          json: jsonDecode(jsonString),
          locale: TranslationLocale.enUS,
        );

        final reloadedTranslation = reloaded.translations[key];
        expect(reloadedTranslation, isA<PluralizedTranslation>());
        expect(
          (reloadedTranslation as PluralizedTranslation).pluralTranslations[TranslationLocale
              .enUS]![PluralCategory.other],
          'hello',
        );
      },
    );
  });

  group('PluralizedTranslation.depluralized', () {
    test('moves the "other" form into the plain value', () {
      final translation = PluralizedTranslation(
        key: TranslationKey.fromKey('testSuites'),
        pluralTranslations: {
          TranslationLocale.enUS: {
            PluralCategory.one: '1 test suite',
            PluralCategory.other: '{{count}} test suites',
          }.lock,
        }.lock,
      );

      final depluralized = translation.depluralized();

      expect(depluralized.translations[TranslationLocale.enUS], '{{count}} test suites');
    });

    test('falls back to the first non-empty form when "other" is empty', () {
      final translation = PluralizedTranslation(
        key: TranslationKey.fromKey('testSuites'),
        pluralTranslations: {
          TranslationLocale.enUS: {
            PluralCategory.zero: '',
            PluralCategory.one: '1 test suite',
            PluralCategory.other: '',
          }.lock,
        }.lock,
      );

      final depluralized = translation.depluralized();

      expect(depluralized.translations[TranslationLocale.enUS], '1 test suite');
    });

    test('produces an empty plain value when every form is empty', () {
      final translation = PluralizedTranslation(
        key: TranslationKey.fromKey('testSuites'),
        pluralTranslations: {
          TranslationLocale.enUS: {PluralCategory.one: '', PluralCategory.other: ''}.lock,
        }.lock,
      );

      final depluralized = translation.depluralized();

      expect(depluralized.translations[TranslationLocale.enUS], '');
    });

    test('handles each locale independently', () {
      final translation = PluralizedTranslation(
        key: TranslationKey.fromKey('testSuites'),
        pluralTranslations: {
          TranslationLocale.enUS: {PluralCategory.other: 'test suites'}.lock,
          TranslationLocale.deDE: {PluralCategory.other: 'Testfälle'}.lock,
        }.lock,
      );

      final depluralized = translation.depluralized();

      expect(depluralized.translations[TranslationLocale.enUS], 'test suites');
      expect(depluralized.translations[TranslationLocale.deDE], 'Testfälle');
    });

    test('round-trips through the editor: pluralize then depluralize restores the plain value', () {
      final original = SimpleTranslation(
        key: TranslationKey.fromKey('greeting'),
        translations: {TranslationLocale.enUS: 'hello'}.lock,
      );

      final roundTripped = original.pluralized().depluralized();

      expect(roundTripped.translations[TranslationLocale.enUS], 'hello');
    });
  });
}

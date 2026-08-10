import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localizator/model/translation.dart';
import 'package:localizator/model/translation_locale.dart';

TranslationKey _k(String key) => TranslationKey.fromKey(key);

SimpleTranslation _leaf(String key, [String text = 'value']) =>
    SimpleTranslation(key: _k(key), translations: {TranslationLocale.enUS: text}.lock);

/// Builds a project from `key -> text` pairs, so each test can spell out its fixture as a flat
/// map instead of constructing [Translation]s by hand.
LocalizationProject _project(Map<String, String> entries) {
  final translations = <TranslationKey, Translation>{
    for (final entry in entries.entries) _k(entry.key): _leaf(entry.key, entry.value),
  };
  return LocalizationProject(
    translations: translations.lock,
    languages: {TranslationLocale.enUS}.lock,
  );
}

void main() {
  group('TranslationKey.isDescendantOf', () {
    test('true for a direct child', () {
      expect(_k('foo.bar').isDescendantOf(_k('foo')), isTrue);
    });

    test('true for a deep descendant', () {
      expect(_k('foo.bar.baz').isDescendantOf(_k('foo')), isTrue);
    });

    test('false for the key itself', () {
      expect(_k('foo').isDescendantOf(_k('foo')), isFalse);
    });

    test('false for a sibling that merely shares a text prefix', () {
      // "foobar" starts with "foo" as a string, but isn't nested under it - the check must be
      // dot-bounded, not a plain string prefix match.
      expect(_k('foobar').isDescendantOf(_k('foo')), isFalse);
    });

    test('false for an unrelated key', () {
      expect(_k('foo.bar').isDescendantOf(_k('baz')), isFalse);
    });
  });

  group('movedTranslationKey', () {
    test('maps the moved key itself straight onto the new key', () {
      expect(movedTranslationKey(_k('foo'), oldKey: _k('foo'), newKey: _k('baz')), _k('baz'));
    });

    test('swaps the prefix on a descendant, keeping its suffix', () {
      expect(
        movedTranslationKey(_k('foo.bar.baz'), oldKey: _k('foo'), newKey: _k('qux')),
        _k('qux.bar.baz'),
      );
    });
  });

  group('LocalizationKeyRenaming.keysRootedAt', () {
    test('a plain leaf returns just itself', () {
      final project = _project({'foo': 'a', 'bar': 'b'});
      expect(project.keysRootedAt(_k('foo')), {_k('foo')});
    });

    test('a folder returns its descendants, not the (nonexistent) folder key itself', () {
      final project = _project({'foo.a': '1', 'foo.b': '2', 'bar': '3'});
      expect(project.keysRootedAt(_k('foo')), {_k('foo.a'), _k('foo.b')});
    });

    test('excludes unrelated keys, including ones with a similar text prefix', () {
      final project = _project({'foo.a': '1', 'foobar': '2'});
      expect(project.keysRootedAt(_k('foo')), {_k('foo.a')});
    });
  });

  group('LocalizationKeyRenaming.validateKeyRename', () {
    test('rejects an empty new key', () {
      final project = _project({'foo': 'a'});
      expect(project.validateKeyRename(oldKey: _k('foo'), newKey: _k('')), isNotNull);
    });

    test('rejects a new key with an empty segment', () {
      final project = _project({'foo': 'a'});
      expect(project.validateKeyRename(oldKey: _k('foo'), newKey: _k('bar..baz')), isNotNull);
    });

    test('rejects a new key identical to the current one', () {
      final project = _project({'foo.bar': 'a'});
      expect(project.validateKeyRename(oldKey: _k('foo.bar'), newKey: _k('foo.bar')), isNotNull);
    });

    test('blocks an exact collision with an existing plain (childless) leaf', () {
      final project = _project({'foo': 'a', 'bar': 'b'});
      expect(project.validateKeyRename(oldKey: _k('foo'), newKey: _k('bar')), isNotNull);
    });

    test('allows a plain rename with no collision', () {
      final project = _project({'foo': 'a'});
      expect(project.validateKeyRename(oldKey: _k('foo'), newKey: _k('baz')), isNull);
    });

    test('allows moving a folder into another folder that already exists', () {
      final project = _project({'foo.a': '1', 'foo.b': '2', 'bar.c': '3'});
      expect(project.validateKeyRename(oldKey: _k('foo'), newKey: _k('bar')), isNull);
    });

    test('allows moving a leaf onto its own direct parent folder', () {
      // Regression: this used to only be checked against the whole subtree rooted at oldKey,
      // which never includes oldKey's own ancestors - renaming a leaf up into its immediate
      // parent must be recognized as landing on an (about to be vacated) folder too.
      final project = _project({
        'mainMenu.sidePanel.error.titleUpdateFailed': 'Title update failed',
        'mainMenu.sidePanel.error.descriptionUpdateFailed': 'Description update failed',
      });
      expect(
        project.validateKeyRename(
          oldKey: _k('mainMenu.sidePanel.error.titleUpdateFailed'),
          newKey: _k('mainMenu.sidePanel.error'),
        ),
        isNull,
      );
    });

    test('allows landing on a folder that also carries its own leaf translation '
        '(e.g. from mismatched locale files)', () {
      // Regression: a locale file can flatten a path to a plain string while another locale's
      // file has it properly nested, so the same key can exist both as a leaf and as a folder
      // at once. That must still be treated as a mergeable folder, not hard-blocked as if it
      // were an ordinary plain-key collision.
      final project = _project({
        'settings.profile': 'Profile', // flat in one locale
        'settings.profile.bio': 'Bio', // nested in another
        'settings.notifications': 'Notifications',
      });
      expect(
        project.validateKeyRename(
          oldKey: _k('settings.notifications'),
          newKey: _k('settings.profile'),
        ),
        isNull,
      );
    });
  });

  group('LocalizationKeyRenaming.renameWouldMergeFolders', () {
    test('false when the destination does not exist at all', () {
      final project = _project({'foo': 'a'});
      expect(project.renameWouldMergeFolders(oldKey: _k('foo'), newKey: _k('bar')), isFalse);
    });

    test('false when the destination is a plain, childless leaf', () {
      // Not a folder-merge concern - validateKeyRename hard-blocks this case separately.
      final project = _project({'foo': 'a', 'bar': 'b'});
      expect(project.renameWouldMergeFolders(oldKey: _k('foo'), newKey: _k('bar')), isFalse);
    });

    test('true when moving a leaf onto an existing folder', () {
      final project = _project({
        'settings.account.name': 'Name',
        'settings.notifications': 'Notifications',
      });
      expect(
        project.renameWouldMergeFolders(
          oldKey: _k('settings.notifications'),
          newKey: _k('settings.account'),
        ),
        isTrue,
      );
    });

    test('true when moving a folder onto an existing folder', () {
      final project = _project({'foo.a': '1', 'foo.b': '2', 'bar.c': '3'});
      expect(project.renameWouldMergeFolders(oldKey: _k('foo'), newKey: _k('bar')), isTrue);
    });

    test('true for a leaf onto its own parent folder that has other children', () {
      final project = _project({
        'mainMenu.sidePanel.error.titleUpdateFailed': 'a',
        'mainMenu.sidePanel.error.descriptionUpdateFailed': 'b',
      });
      expect(
        project.renameWouldMergeFolders(
          oldKey: _k('mainMenu.sidePanel.error.titleUpdateFailed'),
          newKey: _k('mainMenu.sidePanel.error'),
        ),
        isTrue,
      );
    });

    test('true even when the destination folder also carries its own leaf translation', () {
      final project = _project({
        'settings.profile': 'Profile',
        'settings.profile.bio': 'Bio',
        'settings.notifications': 'Notifications',
      });
      expect(
        project.renameWouldMergeFolders(
          oldKey: _k('settings.notifications'),
          newKey: _k('settings.profile'),
        ),
        isTrue,
      );
    });
  });

  group('LocalizationKeyRenaming.withRenamedKey', () {
    test('renames a plain leaf, moving its content and updating the key it carries', () {
      final project = _project({'foo': 'hello'});

      final renamed = project.withRenamedKey(oldKey: _k('foo'), newKey: _k('bar'));

      expect(renamed.translations.containsKey(_k('foo')), isFalse);
      final translation = renamed.translations[_k('bar')] as SimpleTranslation;
      expect(translation.translations[TranslationLocale.enUS], 'hello');
      // The Translation's own key must be updated too, not just its position in the map -
      // otherwise it resurfaces at the wrong path on export (see toJsonString/flatten).
      expect(translation.key, _k('bar'));
    });

    test('moves an entire folder subtree, keeping each key\'s relative suffix', () {
      final project = _project({'foo.a': '1', 'foo.b.c': '2', 'untouched': '3'});

      final renamed = project.withRenamedKey(oldKey: _k('foo'), newKey: _k('baz'));

      expect(renamed.translations.keys.toSet(), {_k('baz.a'), _k('baz.b.c'), _k('untouched')});
      expect(
        (renamed.translations[_k('baz.a')] as SimpleTranslation).translations[TranslationLocale
            .enUS],
        '1',
      );
      expect(
        (renamed.translations[_k('baz.b.c')] as SimpleTranslation).translations[TranslationLocale
            .enUS],
        '2',
      );
    });

    test('merges into an existing folder, combining both sides\' keys', () {
      final project = _project({'foo.a': '1', 'bar.c': '3'});

      final renamed = project.withRenamedKey(oldKey: _k('foo'), newKey: _k('bar'));

      expect(renamed.translations.keys.toSet(), {_k('bar.a'), _k('bar.c')});
    });

    test('moving a leaf onto an existing folder root overwrites that exact path, '
        'leaving sibling descendants untouched', () {
      final project = _project({
        'settings.account.name': 'Name',
        'settings.account.email': 'Email',
        'settings.notifications': 'Notifications',
      });

      final renamed = project.withRenamedKey(
        oldKey: _k('settings.notifications'),
        newKey: _k('settings.account'),
      );

      expect(renamed.translations.containsKey(_k('settings.notifications')), isFalse);
      expect(
        (renamed.translations[_k('settings.account')] as SimpleTranslation)
            .translations[TranslationLocale.enUS],
        'Notifications',
      );
      // The pre-existing children are still there in the in-memory model - the loss (the
      // renamed leaf's value silently winning over the folder's contents) only happens once
      // this gets flattened back to JSON via toJsonString, which is what the dialog's warning
      // is about.
      expect(renamed.translations.containsKey(_k('settings.account.name')), isTrue);
      expect(renamed.translations.containsKey(_k('settings.account.email')), isTrue);
    });

    test('exporting after such an overwrite drops the folder\'s content, matching the warning', () {
      final project = _project({
        'settings.account.name': 'Name',
        'settings.account.email': 'Email',
        'settings.notifications': 'Notifications',
      });

      final renamed = project.withRenamedKey(
        oldKey: _k('settings.notifications'),
        newKey: _k('settings.account'),
      );

      final jsonString = renamed.toJsonString(TranslationLocale.enUS);
      expect(jsonString, contains('"account": "Notifications"'));
      expect(jsonString, isNot(contains('"name"')));
      expect(jsonString, isNot(contains('"email"')));
    });
  });
}

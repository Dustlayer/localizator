import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localizator/model/translation.dart';
import 'package:localizator/state/selected_translation_key.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../state/localization_project_state.dart';

class MainEditArea extends ConsumerStatefulWidget {
  const MainEditArea({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MainEditAreaState();
}

class _MainEditAreaState extends ConsumerState<MainEditArea> {
  @override
  Widget build(BuildContext context) {
    final localizationProject = ref.watch(localizationProjectStateProvider);
    final selectedKey = ref.watch(selectedTranslationKeyProvider);
    return switch (localizationProject) {
      AsyncError(error: final error) => Center(child: Text("Fehler: $error")),
      AsyncData(value: final localizationProject?) => Center(
        child: selectedKey == null
            ? const Text("Key auswählen")
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: _TranslationsEditor(
                  localizationProject: localizationProject,
                  translationKey: selectedKey,
                ),
              ),
      ),
      AsyncData() => Center(child: Text("Noch keine Dateien")),
      _ => Center(child: CircularProgressIndicator()),
    };
  }
}

class _TranslationsEditor extends ConsumerStatefulWidget {
  const _TranslationsEditor({required this.localizationProject, required this.translationKey});

  final LocalizationProject localizationProject;
  final TranslationKey translationKey;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => __TranslationsEditorState();
}

class __TranslationsEditorState extends ConsumerState<_TranslationsEditor> {
  void _handleAddMissingKey() {
    ref
        .read(localizationProjectStateProvider.notifier)
        .updateTranslation(widget.translationKey, SimpleTranslation(key: widget.translationKey));
  }

  void _handlePluralize() {
    final translation = widget.localizationProject.translations[widget.translationKey];
    if (translation is! SimpleTranslation) return;

    ref
        .read(localizationProjectStateProvider.notifier)
        .updateTranslation(widget.translationKey, translation.pluralized());
  }

  void _handleDepluralize() {
    final translation = widget.localizationProject.translations[widget.translationKey];
    if (translation is! PluralizedTranslation) return;

    ref
        .read(localizationProjectStateProvider.notifier)
        .updateTranslation(widget.translationKey, translation.depluralized());
  }

  @override
  Widget build(BuildContext context) {
    final locales = widget.localizationProject.languages;
    final translation = widget.localizationProject.translations[widget.translationKey];
    // Folded into the TextFields' keys below so a reload from disk (which bumps this) forces
    // them to drop their stale displayed value and pick up initialValue fresh - see the
    // provider's doc comment for why a local edit doesn't also trigger this.
    final reloadGeneration = ref.watch(localizationProjectReloadGenerationProvider);
    if (translation == null) {
      return Center(
        child: Column(
          mainAxisSize: .min,
          spacing: 8,
          children: [
            SelectableText("Schlüssel '${widget.translationKey.key}' nicht gefunden"),
            PrimaryButton(
              onPressed: _handleAddMissingKey,
              child: const Text("Schlüssel hinzufügen"),
            ),
          ],
        ),
      );
    }
    final isPluralized = translation is PluralizedTranslation;
    return Align(
      alignment: .topCenter,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: .start,
          crossAxisAlignment: .stretch,
          spacing: 8,
          children: [
            Row(
              spacing: 8,
              children: [
                Flexible(
                  child: SelectableText(
                    widget.translationKey.key,
                    style: const TextStyle(fontSize: 18, fontWeight: .w500),
                    maxLines: 2,
                  ),
                ),

                Button.secondary(
                  onPressed: isPluralized ? _handleDepluralize : _handlePluralize,
                  child: Text(isPluralized ? "Depluralisieren" : "Pluralisieren"),
                ),
              ],
            ),
            ...switch (translation) {
              PluralizedTranslation(:final pluralTranslations) => locales.map((locale) {
                final forms = pluralTranslations[locale] ?? const IMap.empty();
                return Card(
                  child: Column(
                    crossAxisAlignment: .stretch,
                    spacing: 8,
                    children: [
                      Text(locale.name, style: const TextStyle(fontWeight: .w500)),
                      ...PluralCategory.values.map((category) {
                        return FormField(
                          key: InputKey(
                            "${widget.translationKey.key}-${locale.locale}-${category.name}-$reloadGeneration",
                          ),
                          label: Text(category.label),
                          child: TextField(
                            initialValue: forms[category],
                            onChanged: (value) {
                              ref
                                  .read(localizationProjectStateProvider.notifier)
                                  .updateTranslation(
                                    widget.translationKey,
                                    translation.withUpdatedPluralTranslation(
                                      locale,
                                      category,
                                      value,
                                    ),
                                  );
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
              SimpleTranslation(translations: final plainTranslations) => locales.map((locale) {
                final translatedText = plainTranslations[locale];
                return FormField(
                  key: InputKey("${widget.translationKey.key}-${locale.locale}-$reloadGeneration"),
                  label: Text(locale.name),
                  child: TextField(
                    initialValue: translatedText,
                    onChanged: (value) {
                      ref
                          .read(localizationProjectStateProvider.notifier)
                          .updateTranslation(
                            widget.translationKey,
                            translation.withUpdatedTranslation(locale, value),
                          );
                    },
                  ),
                );
              }),
            },
          ],
        ),
      ),
    );
  }
}

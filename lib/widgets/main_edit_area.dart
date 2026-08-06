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
        .updateTranslation(widget.translationKey, Translation(key: widget.translationKey));
  }

  @override
  Widget build(BuildContext context) {
    final locales = widget.localizationProject.languages;
    final translations = widget.localizationProject.translations[widget.translationKey];
    if (translations == null) {
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
    return Column(
      mainAxisAlignment: .start,
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        SelectableText(
          widget.translationKey.key,
          style: const TextStyle(fontSize: 18, fontWeight: .w500),
        ),
        ...locales.map((locale) {
          final translatedText = translations.translations[locale];
          return FormField(
            key: InputKey("${widget.translationKey.key}-${locale.locale}"),
            label: Text(locale.name),
            child: TextField(
              initialValue: translatedText,
              onChanged: (value) {
                ref
                    .read(localizationProjectStateProvider.notifier)
                    .updateTranslation(
                      widget.translationKey,
                      translations.withUpdatedTranslation(locale, value),
                    );
              },
            ),
          );
        }),
      ],
    );
  }
}

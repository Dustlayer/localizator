import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../model/translation.dart';

part 'selected_translation_key.g.dart';

@Riverpod(keepAlive: true)
class SelectedTranslationKey extends _$SelectedTranslationKey {
  @override
  TranslationKey? build() {
    return null;
  }

  void set(TranslationKey? key) {
    state = key;
  }
}

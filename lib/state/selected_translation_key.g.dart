// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selected_translation_key.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SelectedTranslationKey)
final selectedTranslationKeyProvider = SelectedTranslationKeyProvider._();

final class SelectedTranslationKeyProvider
    extends $NotifierProvider<SelectedTranslationKey, TranslationKey?> {
  SelectedTranslationKeyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedTranslationKeyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedTranslationKeyHash();

  @$internal
  @override
  SelectedTranslationKey create() => SelectedTranslationKey();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranslationKey? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranslationKey?>(value),
    );
  }
}

String _$selectedTranslationKeyHash() =>
    r'23fa672336d72b0a7479a8ef55233a4184d7cb67';

abstract class _$SelectedTranslationKey extends $Notifier<TranslationKey?> {
  TranslationKey? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TranslationKey?, TranslationKey?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TranslationKey?, TranslationKey?>,
              TranslationKey?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

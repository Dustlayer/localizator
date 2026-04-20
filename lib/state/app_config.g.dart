// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppConfigState)
final appConfigStateProvider = AppConfigStateProvider._();

final class AppConfigStateProvider
    extends $AsyncNotifierProvider<AppConfigState, AppConfig> {
  AppConfigStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appConfigStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appConfigStateHash();

  @$internal
  @override
  AppConfigState create() => AppConfigState();
}

String _$appConfigStateHash() => r'9c57a79588a13993f103809ffc049f361483cd28';

abstract class _$AppConfigState extends $AsyncNotifier<AppConfig> {
  FutureOr<AppConfig> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AppConfig>, AppConfig>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppConfig>, AppConfig>,
              AsyncValue<AppConfig>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

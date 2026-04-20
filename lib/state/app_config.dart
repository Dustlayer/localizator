import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:localizator/model/app_config.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_config.g.dart';

@Riverpod(keepAlive: true)
class AppConfigState extends _$AppConfigState {
  @override
  FutureOr<AppConfig> build() async {
    try {
      return await AppConfig.load();
    } on Exception {
      await AppConfig.delete();
      return AppConfig(projects: const IList.empty(), lastUsedProject: null);
    }
  }

  void set(AppConfig config) {
    config.save();
    state = AsyncData(config);
  }
}

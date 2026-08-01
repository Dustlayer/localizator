import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:localizator/state/app_config.dart';
import 'package:localizator/state/localization_project_state.dart';
import 'package:localizator/state/selected_translation_key.dart';
import 'package:localizator/util/list_utils.dart';
import 'package:localizator/util/path_utils.dart';
import 'package:localizator/util/reload_localization_project.dart';
import 'package:localizator/util/toast.dart';
import 'package:localizator/widgets/translation_key_tree.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logging.dart';
import 'model/translation.dart';
import 'startup.dart';

void main() {
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  final _rootKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    startup(ref);
    initDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check the git branch whenever the window becomes active again so the translations reload
    // if the branch changed while the app wasn't focused.
    if (state == AppLifecycleState.resumed) {
      _reloadIfGitBranchChanged();
    }
  }

  Future<void> _reloadIfGitBranchChanged() async {
    final hasChanged = await ref
        .read(localizationProjectStateProvider.notifier)
        .hasGitBranchChanged();
    if (!hasChanged ||
        _rootKey.currentContext == null ||
        !(_rootKey.currentContext?.mounted ?? false)) {
      return;
    }

    Log.d("Git branch changed while unfocused, reloading translations");
    await reloadLocalizationProjectWithConfirmation(
      _rootKey.currentContext!,
      ref,
      body:
          "Der Git-Branch wurde gewechselt. Das verwirft aktuelle Änderungen, die noch nicht gespeichert wurden.",
    );
  }

  void initDeepLinks() {
    // Subscribe to incoming link events
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        // unknown action
        if (uri.authority != "open") return;
        Log.d("Open key link: $uri");

        // await as on a cold start this fires before the config is done loading
        final appConfig = await ref.read(appConfigStateProvider.future);

        final openedFromFilePath = uri.queryParameters["file"];
        if (openedFromFilePath == null) return;

        final gitRepo = await File(openedFromFilePath).parent.findGitRepoDirectory();
        if (gitRepo == null) return;

        final translationKeyPostfix = uri.queryParameters["key"];
        final translationKeyPrefix = uri.queryParameters["prefix"];

        String translationKey = "$translationKeyPostfix";
        if (translationKeyPrefix?.isNotEmpty ?? false) {
          translationKey = "$translationKeyPrefix.$translationKey";
        }

        final project = appConfig.projects.firstWhereOrNull((p) => p.gitRepoPath == gitRepo.path);

        Log.d("Open key '$translationKey'");

        if (project == null) {
          Log.d("Can't find project with gitRepoPath '${gitRepo.path}'");
          if (mounted) {
            showToast(
              context: context,
              builder: buildToast(
                title: "Übersetzung nicht gefunden",
                subtitle:
                    "Kein Projekt gefunden. Die Datei mit der Übersetzung muss in einem git Repo liegen.",
              ),
            );
          }
          return;
        }

        // set correct project if necessary
        if (appConfig.lastUsedProject != project) {
          ref
              .read(appConfigStateProvider.notifier)
              .set(appConfig.copyWith(lastUsedProject: project));
        }
        ref
            .read(selectedTranslationKeyProvider.notifier)
            .set(TranslationKey.fromKey(translationKey));
      },
      onError: (err) {
        if (kDebugMode) {
          debugPrint('Deep Link Error: $err');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'Flutter Demo',
      home: TranslationKeyTree(key: _rootKey),
      theme: ThemeData(colorScheme: ColorSchemes.darkSlate),
    );
  }
}

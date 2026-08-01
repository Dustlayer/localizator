import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localizator/state/localization_project_state.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../dialogs/confirm_dialog.dart';

/// Reloads the translation files from disk, prompting for confirmation first if there are
/// unsaved changes that would be lost.
Future<void> reloadLocalizationProjectWithConfirmation(
  BuildContext context,
  WidgetRef ref, {
  String body = "Das verwirft aktuelle Änderungen, die noch nicht gespeichert wurden.",
}) async {
  if (ref.read(localizationProjectStateProvider).value?.isDirty ?? false) {
    final confirmed = await showConfirmDialog(context, title: "Neu laden?", body: body);
    if (!confirmed) return;
  }
  ref.invalidate(localizationProjectStateProvider);
}

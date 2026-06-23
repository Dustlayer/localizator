import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';

Widget Function(BuildContext context, ToastOverlay overlay) buildToast({
  required String title,
  required String subtitle,
  FutureOr<void> Function()? onActionClick,
  String? actionLabel,
}) {
  assert(
    onActionClick == null && actionLabel == null || onActionClick != null && actionLabel != null,
    "Either both onActionClick & actionLabel have to be null or filled.",
  );
  return (BuildContext context, ToastOverlay overlay) {
    return SurfaceCard(
      child: Basic(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: actionLabel == null
            ? null
            : PrimaryButton(
                size: ButtonSize.small,
                onPressed: () async {
                  await onActionClick?.call();
                  // Close the toast programmatically when clicking Undo.
                  overlay.close();
                },
                child: Text(actionLabel),
              ),
        trailingAlignment: Alignment.center,
      ),
    );
  };
}

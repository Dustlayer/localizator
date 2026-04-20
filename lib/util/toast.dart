import 'package:shadcn_flutter/shadcn_flutter.dart';

Widget Function(BuildContext context, ToastOverlay overlay) buildToast({
  required String title,
  required String subtitle,
}) {
  return (BuildContext context, ToastOverlay overlay) {
    return SurfaceCard(
      child: Basic(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: PrimaryButton(
          size: ButtonSize.small,
          onPressed: () {
            // Close the toast programmatically when clicking Undo.
            overlay.close();
          },
          child: const Text('Undo'),
        ),
        trailingAlignment: Alignment.center,
      ),
    );
  };
}

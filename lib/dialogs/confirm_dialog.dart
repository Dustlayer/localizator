import 'package:shadcn_flutter/shadcn_flutter.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              OutlineButton(
                child: const Text('Abbrechen'),
                onPressed: () {
                  Navigator.pop(context, false);
                },
              ),
              PrimaryButton(
                child: const Text('Bestätigen'),
                onPressed: () {
                  Navigator.pop(context, true);
                },
              ),
            ],
          );
        },
      ) ??
      false;
}

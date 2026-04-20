import 'dart:convert';
import 'dart:io';

enum Locales {
  deDE("de-DE", "German", "Deutsch");

  const Locales(this.locale, this.name, this.nameLocal);
  final String locale;
  final String name;
  final String nameLocal;
}

class Locale {
  const Locale(this.locale, this.name, this.nameLocal);
  final String locale;
  final String name;
  final String nameLocal;
}

void main() async {
  final File localesFile = File("/Users/dustinburstinghaus/Downloads/locales.json");
  if (await localesFile.exists()) {
    final String content = await localesFile.readAsString();
    final List<dynamic> json = jsonDecode(content);

    final List<Locale> locales = [];

    for (final o in json) {
      if (!o.containsKey("locale") || !o.containsKey("language")) {
        continue;
      }

      final locale = o["locale"] as String;
      final languageObject = o["language"] as Map<String, dynamic>;
      final name = languageObject["name"];
      final nameLocal = languageObject["name_local"];
      locales.add(Locale(locale, name, nameLocal));
    }

    for (final locale in locales) {
      print(
        '${locale.locale.replaceAll('-', '')}("${locale.locale}", "${locale.name}", "${locale.nameLocal}"),',
      );
    }
  } else {
    print("de.json doesnt exist");
  }
}

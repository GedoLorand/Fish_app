import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SpeciesName {
  final String key;
  final String en;
  final String hu;
  final String ro;
  final List<String> aliases;

  const SpeciesName({
    required this.key,
    required this.en,
    required this.hu,
    required this.ro,
    this.aliases = const [],
  });

  String labelFor(String languageCode) {
    switch (languageCode) {
      case 'hu':
        return hu;
      case 'ro':
        return ro;
      default:
        return en;
    }
  }

  Iterable<String> get allNames sync* {
    yield en;
    yield hu;
    yield ro;
    yield* aliases;
  }
}

const List<SpeciesName> knownSpeciesNames = [
  SpeciesName(
    key: 'carp',
    en: 'Carp',
    hu: 'Ponty',
    ro: 'Crap',
    aliases: ['common carp'],
  ),
  SpeciesName(
    key: 'pike',
    en: 'Pike',
    hu: 'Csuka',
    ro: 'Știucă',
    aliases: ['northern pike', 'stiuca', 'stiuca nordica'],
  ),
  SpeciesName(
    key: 'zander',
    en: 'Zander',
    hu: 'Süllő',
    ro: 'Șalău',
    aliases: ['sander', 'pike-perch', 'süllő', 'șalău', 'salau'],
  ),
  SpeciesName(
    key: 'catfish',
    en: 'Catfish',
    hu: 'Harcsa',
    ro: 'Somn',
    aliases: ['wels catfish'],
  ),
  SpeciesName(
    key: 'grass_carp',
    en: 'Grass carp',
    hu: 'Amur',
    ro: 'Cosaș',
    aliases: ['white amur', 'cosas', 'cosaș'],
  ),
];

class SpeciesNameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = titleCaseSpeciesName(newValue.text);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

Map<String, dynamic> speciesStorageFields(String raw) {
  final trimmed = raw.trim();
  final key = speciesKeyFor(trimmed);
  if (key == null) {
    final display = titleCaseSpeciesName(trimmed);
    return {'species': display, 'speciesSearch': normalizeSpeciesText(display)};
  }

  final display = localizedSpeciesNameForKey(key);
  return {
    'species': display,
    'speciesKey': key,
    'speciesSearch': normalizeSpeciesText(display),
  };
}

String displaySpeciesName(Map<String, dynamic> doc) {
  final speciesKey = doc['speciesKey'] as String?;
  return localizedSpeciesName(doc['species'], speciesKey: speciesKey);
}

String localizedSpeciesName(dynamic value, {String? speciesKey}) {
  if (speciesKey != null && speciesKey.trim().isNotEmpty) {
    final known = _speciesByKey(speciesKey);
    if (known != null) return known.labelFor(_languageCode);
  }

  final key = speciesKeyFor(value?.toString() ?? '');
  if (key != null) return localizedSpeciesNameForKey(key);

  return titleCaseSpeciesName(value?.toString() ?? '');
}

String localizedSpeciesNameForKey(String key) {
  final known = _speciesByKey(key);
  if (known == null) return titleCaseSpeciesName(key.replaceAll('_', ' '));
  return known.labelFor(_languageCode);
}

List<String> localizedKnownSpeciesSuggestions() {
  final lang = _languageCode;
  return knownSpeciesNames.map((s) => s.labelFor(lang)).toList()..sort();
}

String? speciesKeyFor(String value) {
  final normalized = normalizeSpeciesText(value);
  if (normalized.isEmpty) return null;

  for (final species in knownSpeciesNames) {
    for (final name in species.allNames) {
      if (normalizeSpeciesText(name) == normalized) return species.key;
    }
  }
  return null;
}

bool speciesMatchesDocument(
  Map<String, dynamic> doc, {
  String? query,
  String? queryKey,
}) {
  final docKey =
      (doc['speciesKey'] as String?) ??
      speciesKeyFor('${doc['species'] ?? ''}');
  if (queryKey != null && queryKey.trim().isNotEmpty && docKey == queryKey) {
    return true;
  }

  final normalizedQuery = normalizeSpeciesText(query ?? '');
  if (normalizedQuery.isEmpty) return true;

  final normalizedDoc = normalizeSpeciesText('${doc['species'] ?? ''}');
  if (normalizedDoc.contains(normalizedQuery) ||
      normalizedQuery.contains(normalizedDoc)) {
    return true;
  }

  final keyFromQuery = speciesKeyFor(query ?? '');
  return keyFromQuery != null && docKey == keyFromQuery;
}

String titleCaseSpeciesName(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map(_capitalizeWord)
      .join(' ');
}

String normalizeSpeciesText(String value) {
  var text = value.trim().toLowerCase();
  const replacements = {
    'á': 'a',
    'ă': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'í': 'i',
    'î': 'i',
    'ó': 'o',
    'ö': 'o',
    'ő': 'o',
    'ú': 'u',
    'ü': 'u',
    'ű': 'u',
    'ș': 's',
    'ş': 's',
    'ț': 't',
    'ţ': 't',
  };
  replacements.forEach((from, to) {
    text = text.replaceAll(from, to);
  });
  return text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

SpeciesName? _speciesByKey(String key) {
  for (final species in knownSpeciesNames) {
    if (species.key == key) return species;
  }
  return null;
}

String _capitalizeWord(String word) {
  if (word.isEmpty) return word;
  return word[0].toUpperCase() + word.substring(1).toLowerCase();
}

String get _languageCode => Get.locale?.languageCode ?? 'en';

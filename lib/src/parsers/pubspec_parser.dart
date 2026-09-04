import 'dart:io';

/// Reads the declared dependency constraints from the current package's
/// [pubspec.yaml].
///
/// This parser intentionally tracks top-level dependency entries and nested
/// map-style dependency declarations like `sdk: flutter` or `version: ^1.2.3`.
Map<String, String> readDeclaredDependencyConstraints() {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) return const {};

  final constraints = <String, String>{};
  String? section;
  int? sectionIndent;
  String? currentDependency;
  int? currentDependencyIndent;

  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.split('#').first;
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    final indent = line.length - line.trimLeft().length;
    final topLevelMatch = RegExp(r'^([A-Za-z0-9_]+):\s*$').firstMatch(trimmed);

    if (indent == 0 && topLevelMatch != null) {
      final key = topLevelMatch.group(1)!;
      if (key == 'dependencies' || key == 'dev_dependencies') {
        section = key;
        sectionIndent = indent;
        currentDependency = null;
        currentDependencyIndent = null;
        continue;
      }

      section = null;
      sectionIndent = null;
      currentDependency = null;
      currentDependencyIndent = null;
      continue;
    }

    if (section == null || sectionIndent == null) continue;

    if (indent <= sectionIndent) {
      section = null;
      sectionIndent = null;
      currentDependency = null;
      currentDependencyIndent = null;
      continue;
    }

    final match = RegExp(r'^([A-Za-z0-9_]+)\s*:\s*(.*)$').firstMatch(trimmed);
    if (match == null) continue;

    final name = match.group(1)!;
    final value = match.group(2)!.trim();

    final isTopLevelDependencyEntry = indent == sectionIndent + 2;
    if (isTopLevelDependencyEntry) {
      currentDependency = name;
      currentDependencyIndent = indent;

      if (value.isNotEmpty) {
        constraints[name] = value;
      }
      continue;
    }

    final isNestedForCurrentDependency = currentDependency != null &&
        currentDependencyIndent != null &&
        indent > currentDependencyIndent;
    if (!isNestedForCurrentDependency) continue;

    final dependencyName = currentDependency;

    if (name == 'version' && value.isNotEmpty) {
      constraints[dependencyName] = value;
      continue;
    }

    if ((name == 'sdk' || name == 'flutter') && value.isNotEmpty) {
      constraints[dependencyName] = name;
      continue;
    }

    if (value.isNotEmpty && currentDependency == name) {
      constraints[name] = value;
    }
  }

  return constraints;
}

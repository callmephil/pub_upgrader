import 'dart:io';

/// pub_bump
///
/// 1. Runs `dart pub outdated`.
/// 2. Parses the table into direct / dev / transitive rows (dependency
///    overrides and global packages are ignored).
/// 3. For direct + dev deps that are NOT pinned on purpose, runs:
///      `dart pub add <direct deps>`
///      `dart pub add --dev <dev deps>`
///    Re-adding a package with no version constraint rewrites its
///    constraint in pubspec.yaml to the latest resolvable version, which
///    is the usual trick to force-upgrade past a stale constraint.
/// 4. For transitive deps, runs:
///      `dart pub upgrade <transitive deps>`
///    which unlocks them in pubspec.lock without touching pubspec.yaml.
///
/// A direct/dev dep is treated as intentionally pinned when the declared
/// constraint in pubspec.yaml is an exact pin (for example `1.2.3`) or an
/// equality constraint. Caret and tilde ranges are not treated as pins,
/// because they intentionally allow the package to move within a major/minor
/// compatibility range.
Future<void> runPubBump(List<String> args) async {
  final dryRun = args.contains('--dry-run');

  stdout.writeln('Running `dart pub outdated`...\n');
  final result = await Process.run(
    'dart',
    ['pub', 'outdated'],
    runInShell: true,
  );

  final combinedOutput = (result.stdout as String) + (result.stderr as String);
  stdout.writeln(combinedOutput);

  if (combinedOutput.trim().isEmpty) {
    stderr.writeln('No output from `dart pub outdated`. Aborting.');
    exit(result.exitCode == 0 ? 1 : result.exitCode);
  }

  final declaredConstraints = readDeclaredDependencyConstraints();
  final parsed = parseOutdated(
    combinedOutput,
    declaredConstraints: declaredConstraints,
  );

  final direct = parsed.direct.names;
  final dev = parsed.dev.names;
  final transitive = parsed.transitive.names;

  stdout
    ..writeln('\nDirect dependencies (${direct.length}): ${direct.join(', ')}')
    ..writeln('Dev dependencies (${dev.length}): ${dev.join(', ')}')
    ..writeln(
      'Transitive dependencies (${transitive.length}): '
      '${transitive.join(', ')}',
    );

  if (parsed.pinned.isNotEmpty) {
    stdout.writeln(
      '\nSkipping ${parsed.pinned.length} pinned dependencies'
      '${parsed.pinned.length == 1 ? 'y' : 'ies'} '
      '(declared constraint is exact / intentionally pinned):',
    );
    for (final row in parsed.pinned) {
      stdout.writeln(
        '  ${row.name}: upgradable ${row.upgradable} -> '
        'resolvable ${row.resolvable} (latest ${row.latest})',
      );
    }
  }

  if (direct.isEmpty && dev.isEmpty && transitive.isEmpty) {
    stdout.writeln('\nNothing to bump.');
    return;
  }

  if (dryRun) {
    stdout.writeln('\n--dry-run set. Commands that would run:');
    if (direct.isNotEmpty) {
      stdout.writeln('dart pub add ${direct.join(' ')}');
    }
    if (dev.isNotEmpty) {
      stdout.writeln('dart pub add --dev ${dev.join(' ')}');
    }
    if (transitive.isNotEmpty) {
      stdout.writeln('dart pub upgrade ${transitive.join(' ')}');
    }
    return;
  }

  if (direct.isNotEmpty) {
    await runCommand('dart', ['pub', 'add', ...direct]);
  }

  if (dev.isNotEmpty) {
    await runCommand('dart', ['pub', 'add', '--dev', ...dev]);
  }

  if (transitive.isNotEmpty) {
    final code = await runCommand(
      'dart',
      ['pub', 'upgrade', ...transitive],
      fatal: false,
    );
    if (code != 0) {
      stderr.writeln(
        'Targeted transitive upgrade failed; falling back to '
        '`dart pub upgrade`.',
      );
      await runCommand('dart', ['pub', 'upgrade']);
    }
  }

  stdout.writeln('\nDone.');
}

class PackageRow {
  const PackageRow({
    required this.name,
    required this.current,
    required this.upgradable,
    required this.resolvable,
    required this.latest,
  });

  final String name;
  final String current;
  final String upgradable;
  final String resolvable;
  final String latest;

  static String _bare(String version) =>
      version.startsWith('*') ? version.substring(1) : version;

  bool get isPinned =>
      upgradable == '-' ||
      resolvable == '-' ||
      _bare(upgradable) != _bare(resolvable);

  static bool constraintLooksPinned(String? constraint) {
    if (constraint == null || constraint.trim().isEmpty) return false;

    final trimmed = constraint.trim();
    if (trimmed == 'any' || trimmed == 'sdk' || trimmed == 'flutter') {
      return false;
    }
    if (trimmed.startsWith('^') || trimmed.startsWith('~')) return false;
    if (trimmed.startsWith('>') ||
        trimmed.startsWith('<') ||
        trimmed.startsWith('>=') ||
        trimmed.startsWith('<=') ||
        trimmed.contains(' ')) {
      return false;
    }

    if (trimmed.startsWith('=') || trimmed.startsWith('==')) return true;
    return RegExp(r'^\d+(\.\d+){1,3}([+-].+)?$').hasMatch(trimmed);
  }
}

class ParsedDeps {
  const ParsedDeps({
    required this.direct,
    required this.dev,
    required this.transitive,
    required this.pinned,
  });

  final List<PackageRow> direct;
  final List<PackageRow> dev;
  final List<PackageRow> transitive;
  final List<PackageRow> pinned;
}

extension on List<PackageRow> {
  List<String> get names => [for (final row in this) row.name];
}

enum _Section { none, direct, dev, transitive, ignore }

final _ansiEscape = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]');
final _packageNamePattern = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
final _versionColumnPattern = RegExp(r'^-$|^\*?\d+(\.\d+)*([+\-].*)?$');

const Map<String, _Section> _kSectionHeaders = {
  'direct dependencies:': _Section.direct,
  'dev dependencies:': _Section.dev,
  'transitive dependencies:': _Section.transitive,
  'transitive dev dependencies:': _Section.transitive,
  'dependency overrides:': _Section.ignore,
  'global packages:': _Section.ignore,
};

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

    // Dependency maps can declare a version under the `version` key.
    if (name == 'version' && value.isNotEmpty) {
      constraints[dependencyName] = value;
      continue;
    }

    // Keep sdk/flutter markers explicit so they are treated as non-pinned.
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

ParsedDeps parseOutdated(
  String raw, {
  Map<String, String> declaredConstraints = const {},
}) {
  final direct = <PackageRow>[];
  final dev = <PackageRow>[];
  final transitive = <PackageRow>[];
  final pinned = <PackageRow>[];
  var section = _Section.none;

  for (final rawLine in raw.split('\n')) {
    final line = rawLine.replaceAll(_ansiEscape, '');
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final headerKey = trimmed.toLowerCase().replaceAll('_', ' ');
    if (_kSectionHeaders.containsKey(headerKey)) {
      section = _kSectionHeaders[headerKey]!;
      continue;
    }

    if (trimmed.startsWith('Package Name')) continue;
    if (section == _Section.none || section == _Section.ignore) continue;

    if (trimmed.contains('(overridden)')) continue;

    final row = parseRow(trimmed);
    if (row == null) continue;

    final declaredConstraint = declaredConstraints[row.name];
    final explicitlyPinned = declaredConstraint != null
        ? PackageRow.constraintLooksPinned(declaredConstraint)
        : row.isPinned;

    switch (section) {
      case _Section.direct:
        (explicitlyPinned ? pinned : direct).add(row);
      case _Section.dev:
        (explicitlyPinned ? pinned : dev).add(row);
      case _Section.transitive:
        if (row.resolvable != '-') transitive.add(row);
      case _Section.none || _Section.ignore:
        break;
    }
  }

  return ParsedDeps(
    direct: direct,
    dev: dev,
    transitive: transitive,
    pinned: pinned,
  );
}

PackageRow? parseRow(String trimmed) {
  final columns = trimmed.split(RegExp(r'\s+'));
  if (columns.length < 5) return null;

  final name = columns[0];
  if (!_packageNamePattern.hasMatch(name)) return null;

  final versions = columns.sublist(1, 5);
  if (!versions.every(_versionColumnPattern.hasMatch)) return null;

  return PackageRow(
    name: name,
    current: versions[0],
    upgradable: versions[1],
    resolvable: versions[2],
    latest: versions[3],
  );
}

Future<int> runCommand(
  String executable,
  List<String> args, {
  bool fatal = true,
}) async {
  stdout.writeln('\n\$ $executable ${args.join(' ')}');
  final process = await Process.start(
    executable,
    args,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    stderr.writeln(
      'Command failed (exit $exitCode): $executable ${args.join(' ')}',
    );
    if (fatal) exit(exitCode);
  }
  return exitCode;
}

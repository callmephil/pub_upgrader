import 'package:pub_upgrader/src/models/package_row.dart';
import 'package:pub_upgrader/src/models/parsed_deps.dart';

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

/// Parses the output of `dart pub outdated` into direct, dev, and transitive
/// dependency buckets.
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

/// Parses a single dependency row from the outdated table.
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

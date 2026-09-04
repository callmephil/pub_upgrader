import 'package:pub_upgrader/src/models/package_row.dart';

/// Parsed dependency groups extracted from a `dart pub outdated` report.
class ParsedDeps {
  /// Creates a container for the dependency buckets returned by the parser.
  const ParsedDeps({
    required this.direct,
    required this.dev,
    required this.transitive,
    required this.pinned,
  });

  /// Dependencies declared in the root `dependencies` section.
  final List<PackageRow> direct;

  /// Dependencies declared in the root `dev_dependencies` section.
  final List<PackageRow> dev;

  /// Dependencies discovered under the transitive dependency sections.
  final List<PackageRow> transitive;

  /// Dependencies that are intentionally pinned and should be skipped.
  final List<PackageRow> pinned;
}

/// Convenience accessors for package rows grouped by dependency section.
extension PackageRowList on List<PackageRow> {
  /// Returns the names for the packages represented in this list.
  List<String> get names => [for (final row in this) row.name];
}

/// A single dependency row in the output of `dart pub outdated`.
class PackageRow {
  /// Creates a row describing the dependency state for a package.
  const PackageRow({
    required this.name,
    required this.current,
    required this.upgradable,
    required this.resolvable,
    required this.latest,
  });

  /// The package name.
  final String name;

  /// The currently declared version.
  final String current;

  /// The version that can be upgraded without changing the lockfile.
  final String upgradable;

  /// The version that is resolvable while preserving the current constraints.
  final String resolvable;

  /// The latest available version.
  final String latest;

  static String _bare(String version) =>
      version.startsWith('*') ? version.substring(1) : version;

  /// Whether this dependency appears to be intentionally pinned.
  bool get isPinned =>
      upgradable == '-' ||
      resolvable == '-' ||
      _bare(upgradable) != _bare(resolvable);

  /// Returns true when the declared version constraint is an exact pin.
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

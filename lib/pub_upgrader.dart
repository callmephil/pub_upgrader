import 'dart:io';

/// A typedef representing a record of dependencies.
typedef DependenciesRecord = ({String dependencies, String devDependencies});

/// Retrieves the dependencies from the pubspec.yaml file.
///
/// Reads the pubspec.yaml file and extracts the dependencies and devDependencies.
/// Returns a [DependenciesRecord] containing the dependencies and devDependencies as strings.
DependenciesRecord getDependencies() {
  final file = File('pubspec.yaml');
  var dependencies = '';
  var devDependencies = '';
  var devFlag = 0;
  final lines = file.readAsLinesSync();
  for (final line in lines) {
    // checks if the line end or starts with dev_dependencies to separate blocks
    if (line.startsWith('dev_dependencies')) {
      devFlag = 1;
      continue;
    }
    // extracts only the dependency name
    final regex = RegExp(r'^([\sa-zA-Z0-9_]+)(?=: *\^)');
    final match = regex.firstMatch(line);
    if (match != null) {
      final dependency = match.group(1);
      if (devFlag == 0) {
        dependencies += '$dependency ';
      } else {
        devDependencies += '$dependency ';
      }
    }
  }

  return (dependencies: dependencies, devDependencies: devDependencies);
}

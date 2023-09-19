import 'dart:io';

import 'package:pub_upgrader/pub_upgrader.dart';
import 'package:test/test.dart';

void main() {
  test('can_match_getDependencies', () {
    final file = File('pubspec.yaml');
    var dependencies = '';
    var devDependencies = '';
    var devFlag = 0;
    final lines = file.readAsLinesSync();
    for (final line in lines) {
      if (line.startsWith('dev_dependencies')) {
        devFlag = 1;
        continue;
      }
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

    expect(
      getDependencies(),
      (dependencies: dependencies, devDependencies: devDependencies),
    );
  });
}

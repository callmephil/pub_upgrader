import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('example/main.dart', () {
    test('runs successfully and prints expected package groups', () async {
      final result = await Process.run(
        'dart',
        ['run', 'example/main.dart'],
        runInShell: true,
      );

      expect(result.exitCode, 0,
          reason: 'Example should run without errors. stderr: ${result.stderr}');

      final output = (result.stdout as String).trim();
      expect(output, contains('Direct packages to bump: http'));
      expect(output, contains('Dev packages to bump: test'));
      expect(output, contains('Transitive packages to bump: meta'));
    });
  });
}

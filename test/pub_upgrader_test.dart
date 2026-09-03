import 'package:pub_upgrader/pub_upgrader.dart';
import 'package:test/test.dart';
import 'dart:io';

void main() {
  group('parseOutdated', () {
    test('splits sections and keeps only exact pins out of the upgrade set',
        () {
      const raw = '''
Direct dependencies:
Package Name  Current  Upgradable  Resolvable  Latest
intl          *0.18.1  *0.18.1     0.19.0      0.19.0
path          1.9.0    1.9.0       1.10.0     1.10.0

Dev dependencies:
Package Name  Current  Upgradable  Resolvable  Latest
test          *1.24.0  *1.24.0     1.25.0      1.25.0
mocktail      1.0.0    1.0.0       1.0.0      1.1.0

Transitive dependencies:
Package Name  Current  Upgradable  Resolvable  Latest
meta          1.12.0   1.12.0      1.13.0     1.13.0

Transitive dev_dependencies:
Package Name  Current  Upgradable  Resolvable  Latest
pool          1.6.0    1.6.0       1.7.0      1.7.0

Dependency overrides:
Package Name  Current  Upgradable  Resolvable  Latest
sealed_unions *0.5.0 *0.5.0 0.6.0 0.6.0
''';

      final parsed = parseOutdated(raw, declaredConstraints: {
        'intl': '^0.18.0',
        'path': '^1.9.0',
        'test': '^1.24.0',
        'mocktail': '1.0.0',
      });

      expect(parsed.direct.map((row) => row.name), ['intl', 'path']);
      expect(parsed.dev.map((row) => row.name), ['test']);
      expect(parsed.transitive.map((row) => row.name), ['meta', 'pool']);
      expect(parsed.pinned.map((row) => row.name), ['mocktail']);
    });

    test('caret ranges are not treated as pinned in pubspec.yaml', () {
      const raw = '''
Dev dependencies:
Package Name  Current  Upgradable  Resolvable  Latest
lints        6.1.0    6.1.0      6.1.0      6.1.0
''';

      final parsed = parseOutdated(raw, declaredConstraints: {
        'lints': '^6.1.0',
      });

      expect(parsed.dev.map((row) => row.name), ['lints']);
      expect(parsed.pinned, isEmpty);
    });

    test('exact pins remain pinned even when the package is still upgradeable',
        () {
      const raw = '''
Direct dependencies:
Package Name  Current  Upgradable  Resolvable  Latest
http         0.13.0   0.14.0      0.13.0      0.14.0
''';

      final parsed = parseOutdated(raw, declaredConstraints: {
        'http': '0.13.0',
      });

      expect(parsed.direct.map((row) => row.name), isEmpty);
      expect(parsed.pinned.map((row) => row.name), ['http']);
    });

    test('overridden packages are ignored instead of upgraded', () {
      const raw = '''
Dev dependencies:
Package Name  Current  Upgradable  Resolvable  Latest
lints        *6.1.0 (overridden)  *6.1.0 (overridden)  *6.1.0 (overridden)  6.1.0
''';

      final parsed = parseOutdated(raw, declaredConstraints: {
        'lints': '^6.1.0',
      });

      expect(parsed.dev, isEmpty);
      expect(parsed.pinned, isEmpty);
    });
  });

  group('readDeclaredDependencyConstraints', () {
    test('keeps parsing dev constraints after map-style sdk entries', () {
      final dir = Directory.systemTemp.createTempSync('pub_upgrader_test_');
      final previous = Directory.current;

      try {
        Directory.current = dir;
        File('pubspec.yaml').writeAsStringSync('''
name: sample
environment:
  sdk: ^3.0.0

dependencies:
  http: ^1.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  lints: ^6.1.0
  mocktail:
    version: ^1.0.4
''');

        final constraints = readDeclaredDependencyConstraints();
        expect(constraints['http'], '^1.2.0');
        expect(constraints['flutter_test'], 'sdk');
        expect(constraints['lints'], '^6.1.0');
        expect(constraints['mocktail'], '^1.0.4');
      } finally {
        Directory.current = previous;
        dir.deleteSync(recursive: true);
      }
    });
  });
}

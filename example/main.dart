import 'package:pub_upgrader/pub_upgrader.dart';

void main() {
  const sampleOutdatedOutput = '''
Direct dependencies:
Package Name  Current  Upgradable  Resolvable  Latest
http          1.2.0    1.2.1       1.3.0       1.3.0

Dev dependencies:
Package Name  Current  Upgradable  Resolvable  Latest
test          1.25.2   1.25.2      1.26.0      1.26.0

Transitive dependencies:
Package Name  Current  Upgradable  Resolvable  Latest
meta          1.12.0   1.12.0      1.13.0      1.13.0
''';

  final parsed = parseOutdated(
    sampleOutdatedOutput,
    declaredConstraints: {
      'http': '^1.2.0',
      'test': '^1.25.0',
    },
  );

  print('Direct packages to bump: ${parsed.direct.names.join(', ')}');
  print('Dev packages to bump: ${parsed.dev.names.join(', ')}');
  print('Transitive packages to bump: ${parsed.transitive.names.join(', ')}');
}

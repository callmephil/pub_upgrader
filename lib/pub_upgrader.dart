import 'dart:io';

import 'package:pub_upgrader/src/models/parsed_deps.dart';
import 'package:pub_upgrader/src/parsers/outdated_parser.dart';
import 'package:pub_upgrader/src/parsers/pubspec_parser.dart';
import 'package:pub_upgrader/src/runner.dart';

export 'src/models/package_row.dart';
export 'src/models/parsed_deps.dart';
export 'src/parsers/outdated_parser.dart';
export 'src/parsers/pubspec_parser.dart';
export 'src/runner.dart';

/// The package-upgrade utility for dependency management in a Dart project.
///
/// This library provides the public API used by the command-line executable and
/// exposes the helpers needed to reason about the current dependency state.
///
/// The workflow is:
/// 1. Run `dart pub outdated`.
/// 2. Parse the table into direct, dev, transitive, and intentionally pinned
///    buckets.
/// 3. Upgrade unpinned direct and dev dependencies with `dart pub add`.
/// 4. Upgrade transitive dependencies with `dart pub upgrade` without changing
///    the declared constraints in `pubspec.yaml`.
///
/// A direct or dev dependency is considered intentionally pinned when its
/// declared constraint is an exact version, such as `1.2.3`, or an equality
/// constraint like `=1.2.3`. Caret and tilde ranges are not treated as pins
/// because they deliberately allow updates within a compatible range.
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

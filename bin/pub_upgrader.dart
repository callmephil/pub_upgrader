import 'dart:io';

import 'package:pub_upgrader/pub_upgrader.dart' as pub_upgrader;

void main(List<String> arguments) async {
  final record = pub_upgrader.getDependencies();

  if (record.dependencies.isNotEmpty) {
    final dep = record.dependencies.split(' ').where(
          (element) => element.isNotEmpty,
        );

    print('Dependencies: $dep\n\n');
    Process.runSync(
      'flutter',
      ['pub', 'add', ...dep],
      runInShell: true,
    );
  }
  await Future.delayed(Duration(seconds: 1));
  if (record.devDependencies.isNotEmpty) {
    final devDep = record.devDependencies.split(' ').where(
          (element) => element.isNotEmpty,
        );

    print('Dev Dependencies: $devDep\n');
    Process.runSync(
      'flutter',
      ['pub', 'add', '--dev', ...devDep],
      runInShell: true,
    );
  }
}

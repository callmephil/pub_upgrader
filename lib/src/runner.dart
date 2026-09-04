import 'dart:io';

/// Executes a command and optionally terminates the process when the exit code is
/// non-zero.
Future<int> runCommand(
  String executable,
  List<String> args, {
  bool fatal = true,
}) async {
  stdout.writeln('\n\$ $executable ${args.join(' ')}');
  final process = await Process.start(
    executable,
    args,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    stderr.writeln(
      'Command failed (exit $exitCode): $executable ${args.join(' ')}',
    );
    if (fatal) exit(exitCode);
  }
  return exitCode;
}

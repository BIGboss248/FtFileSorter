import 'dart:io';

/// Validates that git commit messages adhere to Conventional Commits specification.
/// Types supported: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert.
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('[commit-msg] Error: No commit message file path provided.');
    exit(1);
  }

  final commitMsgFile = File(args[0]);
  if (!commitMsgFile.existsSync()) {
    stderr.writeln('[commit-msg] Error: Commit message file does not exist: ${args[0]}');
    exit(1);
  }

  final lines = commitMsgFile.readAsLinesSync();
  // Filter out comments (lines starting with #) and empty leading lines
  final contentLines = lines
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList();

  if (contentLines.isEmpty) {
    stderr.writeln('[commit-msg] Error: Commit message cannot be empty.');
    exit(1);
  }

  final firstLine = contentLines.first;

  // Conventional Commits regex:
  // type(scope)!: description OR type!: description OR type: description
  final conventionalCommitPattern = RegExp(
    r'^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-zA-Z0-9_\-\.\/]+\))?(!)?: (.+)$',
  );

  final match = conventionalCommitPattern.firstMatch(firstLine);

  if (match == null) {
    stderr.writeln('''
================================================================================
COMMIT REJECTED: Invalid Conventional Commit Message!
================================================================================
Your commit message was:
  "$firstLine"

It must follow the Conventional Commits specification:
  <type>[optional scope]: <description>

Examples:
  feat: add file sorting by extension
  fix(parser): resolve null pointer when sorting empty directory
  docs: update readme with quickstart guide
  chore!: drop support for older platform versions

Allowed types:
  feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
================================================================================
''');
    exit(1);
  }

  exit(0);
}

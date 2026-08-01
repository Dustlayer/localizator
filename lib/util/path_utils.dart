import 'dart:io';

extension DirectoryUtils on Directory {
  Future<Directory?> findGitRepoDirectory() async {
    return _findGitRepoDirectory(this);
  }

  Future<Directory?> _findGitRepoDirectory(Directory directory) async {
    final gitDir = Directory('${directory.path}${Platform.pathSeparator}.git');

    if (await gitDir.exists()) {
      // The git repo is this directory; return its name (the last segment of the path)
      return directory;
    }

    final parentDir = directory.parent;
    if (parentDir.path == directory.path) {
      // Stop if we've reached the root (parent path equals current path)
      return null;
    }

    // Recursive call to keep searching upwards
    return _findGitRepoDirectory(parentDir);
  }

  /// The name of the currently checked out branch of the git repo at this directory, or `null`
  /// if it can't be determined (not a repo, detached HEAD, `git` not on PATH, ...).
  Future<String?> currentGitBranch() async {
    try {
      final result = await Process.run('git', ['branch', '--show-current'], workingDirectory: path);
      if (result.exitCode != 0) return null;
      final branch = (result.stdout as String).trim();
      return branch.isEmpty ? null : branch;
    } catch (_) {
      return null;
    }
  }
}

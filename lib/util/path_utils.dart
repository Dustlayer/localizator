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
}

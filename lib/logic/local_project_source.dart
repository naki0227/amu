
import 'dart:io';
import 'package:amu/logic/project_source.dart';

class LocalProjectSource implements ProjectSource {
  final Directory rootDir;

  LocalProjectSource(String path) : rootDir = Directory(path);

  @override
  Future<List<String>> getFilePaths() async {
    if (!await rootDir.exists()) {
      throw Exception('Directory not found: ${rootDir.path}');
    }

    final List<String> paths = [];
    
    // Recursive listing
    await for (final entity in rootDir.list(recursive: true)) {
      if (entity is File) {
        // Store relative path for consistency with GitHub
        final relativePath = entity.path.replaceFirst('${rootDir.path}/', '');
        paths.add(relativePath);
      }
    }
    
    return paths;
  }

  @override
  Future<String> readFile(String path) async {
    // Construct absolute path
    final file = File('${rootDir.path}/$path');
    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }
    return file.readAsString();
  }
}

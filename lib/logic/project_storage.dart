import 'dart:io';
import 'dart:convert';

/// Project Storage Service
/// Handles saving and loading project data including storyboards
class ProjectStorage {
  static const String _baseDir = 'amu_output/projects';
  
  /// Get the project directory path
  static String getProjectPath(String projectName) {
    // Sanitize project name for filesystem
    final safeName = projectName.replaceAll(RegExp(r'[^\w\-]'), '_');
    return '$_baseDir/$safeName';
  }
  
  /// Create project directory structure
  static Future<void> createProjectStructure(String projectName) async {
    final projectPath = getProjectPath(projectName);
    
    // Create directories
    await Directory('$projectPath/frames').create(recursive: true);
    await Directory('$projectPath/output').create(recursive: true);
  }
  
  /// Save storyboard JSON
  static Future<String> saveStoryboard(String projectName, Map<String, dynamic> storyboard) async {
    await createProjectStructure(projectName);
    
    final projectPath = getProjectPath(projectName);
    final file = File('$projectPath/storyboard.json');
    
    // Pretty print JSON
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(storyboard));
    
    return file.path;
  }
  
  /// Load storyboard JSON
  static Future<Map<String, dynamic>?> loadStoryboard(String projectName) async {
    final projectPath = getProjectPath(projectName);
    final file = File('$projectPath/storyboard.json');
    
    if (!await file.exists()) return null;
    
    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading storyboard: $e');
      return null;
    }
  }
  
  /// Get all saved projects
  static Future<List<String>> listProjects() async {
    final dir = Directory(_baseDir);
    if (!await dir.exists()) return [];
    
    final projects = <String>[];
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        projects.add(entity.path.split('/').last);
      }
    }
    return projects;
  }
  
  /// Get frames directory path
  static String getFramesPath(String projectName) {
    return '${getProjectPath(projectName)}/frames';
  }
  
  /// Get output directory path
  static String getOutputPath(String projectName) {
    return '${getProjectPath(projectName)}/output';
  }
  
  /// Get video output file path
  static String getVideoPath(String projectName) {
    return '${getOutputPath(projectName)}/video.mp4';
  }
  
  /// Delete all frames (for re-render)
  static Future<void> clearFrames(String projectName) async {
    final framesDir = Directory(getFramesPath(projectName));
    if (await framesDir.exists()) {
      await for (final file in framesDir.list()) {
        if (file is File) await file.delete();
      }
    }
  }
}

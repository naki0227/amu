import 'package:amu/logic/project_source.dart';

class UiDetector {
  
  /// Finds the file path of the Main Screen widget or entry point.
  /// Works with both local and remote (GitHub) sources.
  Future<String?> findMainScreenPath(ProjectSource source) async {
    final allPaths = await source.getFilePaths();
    
    // Priority 1: Flutter (lib/main.dart)
    final mainDart = allPaths.firstWhere(
        (p) => p == 'lib/main.dart' || p.endsWith('/lib/main.dart'),
        orElse: () => '');
    if (mainDart.isNotEmpty) {
       return _findFlutterHome(source, allPaths, mainDart);
    }

    // Priority 2: React (src/App.tsx or src/App.js)
    final appTsx = allPaths.firstWhere(
        (p) => p == 'src/App.tsx' || p.endsWith('/src/App.tsx'),
        orElse: () => '');
    if (appTsx.isNotEmpty) return appTsx;
    
    final appJs = allPaths.firstWhere(
        (p) => p == 'src/App.js' || p.endsWith('/src/App.js'),
        orElse: () => '');
    if (appJs.isNotEmpty) return appJs;

    // Priority 3: Web (index.html)
    final indexHtml = allPaths.firstWhere(
        (p) => p == 'index.html' || p.endsWith('/index.html'),
        orElse: () => '');
    if (indexHtml.isNotEmpty) return indexHtml;

    return null;
  }

  Future<String?> _findFlutterHome(ProjectSource source, List<String> allPaths, String mainDartPath) async {
    final mainContent = await source.readFile(mainDartPath);
    
    // 1. Try to find 'home:' widget name (Most specific)
    final homeRegex = RegExp(r'home:\s*(?:const\s+)?([A-Z]\w+)\(');
    var match = homeRegex.firstMatch(mainContent);
    
    // 2. If no 'home:', try 'runApp' widget (Entry point)
    if (match == null) {
        final runAppRegex = RegExp(r'runApp\(\s*(?:const\s+)?([A-Z]\w+)\(');
        match = runAppRegex.firstMatch(mainContent);
    }

    if (match == null) {
        return mainDartPath; 
    }
    
    final className = match.group(1);
    if (className == null) return mainDartPath;

    // Check if it's in main.dart first
    if (mainContent.contains('class $className')) {
       return mainDartPath;
    }

    // Otherwise scan lib/ files
    final libFiles = allPaths.where((p) => 
        (p.startsWith('lib/') || p.contains('/lib/')) && p.endsWith('.dart')
    ).toList();

    for (var filePath in libFiles) {
        try {
            final content = await source.readFile(filePath);
            if (content.contains('class $className')) {
                print("UI Detector: Found main screen at $filePath");
                return filePath;
            }
        } catch (_) { continue; }
    }
    
    return mainDartPath;
  }
}

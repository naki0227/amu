/// Funnel Strategy Logic for Context Weaver
/// 
/// This logic simulates the filtering process:
/// 1. Scout Phase: Accept a list of file paths.
/// 2. Heuristic Filter: Score each file based on its likelihood of being a "Hero File".
/// 3. Deep Dive: Select the top N files for LLM analysis.

class FunnelStrategy {
  // Config
  static const int maxFilesToAnalyze = 5;
  
  // Heuristic Weights
  static const Map<String, int> _pathKeywords = {
    'ui': 10,
    'screen': 10,
    'page': 10,
    'view': 8,
    'widget': 5,
    'component': 5,
    'dashboard': 15, // High value target
    'home': 12,
    'main': 10,
    'hero': 20, // Explicit hero naming
  };

  static const Map<String, int> _extensionWeights = {
    '.dart': 10,
    '.js': 5,
    '.tsx': 8,
    '.xml': -5, // Config files
    '.json': -2,
    '.g.dart': -20, // Generated files
    '.freezed.dart': -20,
  };

  static const List<String> _ignoredDirectories = [
    'test',
    'android',
    'ios',
    'linux',
    'macos',
    'windows',
    'web',
    'build',
    '.git',
    '.idea',
    '.vscode',
  ];

  /// Main Entry: Filter and Sort files
  List<String> identifyHeroFiles(List<String> filePaths) {
    final Map<String, int> scores = {};

    for (final path in filePaths) {
      if (_shouldIgnore(path)) {
        continue;
      }
      scores[path] = _calculateScore(path);
    }

    // Sort by score descending
    final sortedFiles = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Return top N
    return sortedFiles
        .take(maxFilesToAnalyze)
        .map((e) => e.key)
        .toList();
  }

  bool _shouldIgnore(String path) {
    for (final dir in _ignoredDirectories) {
      if (path.contains('/$dir/') || path.startsWith('$dir/')) {
        return true;
      }
    }
    return false;
  }

  int _calculateScore(String path) {
    int score = 0;
    final lowerPath = path.toLowerCase();

    // Extension Check
    bool validExt = false;
    for (final entry in _extensionWeights.entries) {
      if (lowerPath.endsWith(entry.key)) {
        score += entry.value;
        validExt = true;
        break;
      }
    }
    if (!validExt) return 0; // Skip unknown extensions for now

    // Keyword Check
    for (final entry in _pathKeywords.entries) {
      if (lowerPath.contains(entry.key)) {
        score += entry.value;
      }
    }
    
    // Penalize deep nesting
    final depth = path.split('/').length;
    if (depth > 5) score -= 5;

    // Boost "Root" UI files
    if (lowerPath.contains('lib/main.dart') || lowerPath.contains('lib/app.dart')) {
      score += 15;
    }

    return score;
  }
}

// Example Usage
void main() {
  final strategy = FunnelStrategy();
  
  final mockRepoFiles = [
    'lib/main.dart',
    'lib/app.dart',
    'lib/ui/dashboard/dashboard_screen.dart',
    'lib/ui/dashboard/widgets/chart_widget.dart',
    'lib/data/repository/auth_repository.dart',
    'lib/utils/constants.dart',
    'test/widget_test.dart',
    'android/app/build.gradle',
    'lib/models/user.g.dart',
    'lib/ui/profile/profile_page.dart',
  ];

  print("Scouting Repo with ${mockRepoFiles.length} files...");
  
  final heroes = strategy.identifyHeroFiles(mockRepoFiles);
  
  print("\n--- Identified Hero Files ---");
  heroes.asMap().forEach((index, file) {
    print("${index + 1}. $file");
  });
}

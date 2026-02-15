
import 'dart:convert';
import 'package:http/http.dart' as http;

abstract class ProjectSource {
  Future<List<String>> getFilePaths();
  Future<String> readFile(String path);
}

class GitHubProjectSource implements ProjectSource {
  final String owner;
  final String repo;
  final String branch;
  
  // Cache for file tree to avoid repetitive API calls
  List<String>? _cachedPaths;

  GitHubProjectSource({
    required this.owner, 
    required this.repo, 
    this.branch = 'main'
  });

  static GitHubProjectSource? fromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host != 'github.com') return null;
      
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length < 2) return null;
      
      return GitHubProjectSource(owner: segments[0], repo: segments[1]);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<String>> getFilePaths() async {
    if (_cachedPaths != null) return _cachedPaths!;

    final apiUrl = Uri.parse('https://api.github.com/repos/$owner/$repo/git/trees/$branch?recursive=1');
    final response = await http.get(apiUrl);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch file tree: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final tree = data['tree'] as List;

    _cachedPaths = tree
        .where((node) => node['type'] == 'blob') // Files only
        .map((node) => node['path'] as String)
        .toList();
        
    return _cachedPaths!;
  }

  @override
  Future<String> readFile(String path) async {
    // raw.githubusercontent.com is faster and has higher rate limits than API
    final rawUrl = Uri.parse('https://raw.githubusercontent.com/$owner/$repo/$branch/$path');
    final response = await http.get(rawUrl);

    if (response.statusCode != 200) {
      throw Exception('Failed to read file: $path (${response.statusCode})');
    }

    return response.body;
  }
}

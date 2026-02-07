import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

class GeminiService {
  final String apiKey;
  final String modelName;

  GeminiService(this.apiKey, {this.modelName = 'gemini-2.5-pro'});

  Future<Map<String, dynamic>> analyzeProject(String sourcePath, {String language = 'English'}) async {
    final dir = Directory(sourcePath);
    if (!await dir.exists()) {
      throw Exception("Source directory not found: $sourcePath");
    }

    // 1. Weave Context (Read Files)
    final buffer = StringBuffer();
    buffer.writeln("Analyze the following Flutter project code and extract the Product DNA.");
    buffer.writeln("Output ONLY valid JSON matching this schema: { \"product_name\": string, \"appName\": string, \"ui_type\": \"dashboard\" | \"feed\" | \"chat\" | \"landing\" | \"profile\" | \"list\", \"platform\": \"mobile\" | \"web\" | \"desktop\", \"brandPalette\": { \"background\": string, \"surface\": string, \"primary\": string, \"onPrimary\": string }, \"hook_main\": string, \"hook_sub\": string, \"features\": string[], \"primary_action\": string, \"widget_tree\": { \"type\": \"Scaffold\", \"appBar\": { \"title\": string }, \"body\": { \"type\": string, \"children\": [], \"child\": {}, \"text\": string, \"style\": {}, \"decoration\": {}, \"src\": string, \"icon\": string }, \"floatingActionButton\": {}, \"bottomNavigationBar\": {} }, \"overlay_broll\": string, \"overlay_feature1\": string, \"overlay_feature2\": string, \"outro_sub\": string }");
    
    // ONE-SHOT EXAMPLE
    buffer.writeln("IMPORTANT: The 'widget_tree' MUST be a high-fidelity JSON representation of the main screen's widget tree. Use these keys: type ('Column', 'Row', 'ListView', 'Container', 'Card', 'Text', 'Image', 'Icon', 'Stack', 'Center', 'Padding'), children (array), child (object), text, style ({fontSize, fontWeight, color}), decoration ({color, borderRadius, border, boxShadow}), padding (int or 'x,y'), margin, mainAxisAlignment, crossAxisAlignment.");
    buffer.writeln("EXAMPLE widget_tree: { \"type\": \"Scaffold\", \"appBar\": { \"title\": \"My App\" }, \"body\": { \"type\": \"Column\", \"children\": [ { \"type\": \"Container\", \"height\": 200, \"color\": \"#FF0000\", \"child\": { \"type\": \"Center\", \"child\": { \"type\": \"Text\", \"text\": \"Hello\", \"style\": { \"color\": \"white\", \"fontSize\": 24, \"fontWeight\": \"bold\" } } } } ] } }");
    
    buffer.writeln("IMPORTANT: All text in the JSON (hook_main, hook_sub, features, widget_tree text) MUST be in $language.");
    buffer.writeln("\n--- SOURCE CODE ---\n");

    print("Analyzing Project at: $sourcePath");

    final files = dir.listSync(recursive: true).whereType<File>().where((f) {
      final p = f.path.toLowerCase();
      // Heuristic: Read main code files
      if (p.contains('test/')) return false; // Skip tests
      if (p.contains('.dart_tool/') || p.contains('build/') || p.contains('.git/')) return false; // Skip build/git

      if (p.endsWith('.dart') || p.endsWith('pubspec.yaml') || 
          p.endsWith('.xml') || p.endsWith('.gradle') || 
          p.endsWith('.swift') || p.endsWith('.kt') ||
          p.endsWith('.json') || p.endsWith('.md')) return true;
      return false;
    }).take(20); // Limit context window for speed

    print("Found ${files.length} context files.");

    if (files.isEmpty) {
       print("No context files found. Returning fallback.");
       return {
        "product_name": "Project Analysis",
        "appName": "App Generated",
        "platform": "mobile",
        "brandPalette": { "background": "#1E293B" },
        "hook_main": "Analysis Failed",
        "hook_sub": "No source files found at $sourcePath",
        "features": ["Source directory appeared empty"]
      };
    }

    for (var f in files) {
       try {
         final content = await f.readAsString();
         buffer.writeln("File: ${f.path.split('/').last}");
         buffer.writeln("```${f.path.split('.').last}"); // Use extension as lang
         buffer.writeln(content.length > 2000 ? content.substring(0, 2000) + "... [truncated]" : content);
         buffer.writeln("```\n");
       } catch (e) {
         // Skip binary or unreadable
       }
    }

      // 2. Discover Assets (Images for B-Roll)
      final List<String> assets = [];
      try {
        final allFiles = dir.listSync(recursive: true).whereType<File>();
        for (var f in allFiles) {
          final p = f.path.toLowerCase();
          if (p.endsWith('.png') || p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.webp')) {

            // Store ABSOLUTE path for Image.file() loading
            assets.add(f.path);
          }
          if (assets.length >= 10) break;
        }
      } catch (e) {
        print("Asset scan error: $e");
      }

      // 3. Call Gemini
      final model = GenerativeModel(model: modelName, apiKey: apiKey);
      final content = [Content.text(buffer.toString())];
      
      try {
        final response = await model.generateContent(content);
      final text = response.text;
      
      if (text == null) throw Exception("Empty response from AI");
      
      // Clean JSON (remove markdown fences)
      final jsonString = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> dna = jsonDecode(jsonString);
      
      // Add discovered assets to DNA
      dna['discovered_assets'] = assets;
      return dna;
    } catch (e) {
      print("Gemini Error: $e");
      // Fallback Generic if AI fails
      return {
        "product_name": "Project Analysis",
        "appName": "App Generated",
        "platform": "mobile",
        "brandPalette": { "background": "#1E293B" },
        "hook_main": "Analysis Failed",
        "hook_sub": "Check your source code or API key.",
        "features": ["Feature Analysis Empty"]
      };
    }
  }
}

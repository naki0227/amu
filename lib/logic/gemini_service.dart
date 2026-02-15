import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:amu/logic/ui_detector.dart';
import 'package:amu/logic/project_source.dart';

class GeminiService {
  final String apiKey;
  final String modelName;

  GeminiService(this.apiKey, {this.modelName = 'gemini-2.5-pro'});

  Future<Map<String, dynamic>> analyzeProject(ProjectSource source, {String language = 'English'}) async {

    // 1. Smarter Context Collection (Platform Agnostic)
    final allPaths = await source.getFilePaths();
    
    List<String> priorityPaths = [];
    List<String> otherPaths = [];

    for (var p in allPaths) {
       final lower = p.toLowerCase();
       if (lower.contains('test/') || lower.contains('.dart_tool/') || lower.contains('build/') || lower.contains('.git/') || lower.contains('/checkouts/') || lower.contains('amu_output/')) continue;
       
       if (lower.endsWith('pubspec.yaml')) {
          priorityPaths.insert(0, p);
       } else if (lower.endsWith('main.dart')) {
          priorityPaths.add(p);
       } else if (lower.endsWith('.dart') && (lower.contains('/models/') || lower.contains('/ui/') || lower.contains('/screens/'))) {
          priorityPaths.add(p);
       } else if (lower.endsWith('.dart') || lower.endsWith('.tsx') || lower.endsWith('.jsx') || lower.endsWith('.vue') || lower.endsWith('.html') || lower.endsWith('.css')) {
          otherPaths.add(p);
       }
    }
    
    // Take top 50 files
    final totalPaths = [...priorityPaths, ...otherPaths].take(50).toList();
    final buffer = StringBuffer();
    for (var path in totalPaths) {
       try {
         final content = await source.readFile(path);
         final basename = path.split('/').last;
         final ext = path.split('.').last;
         buffer.writeln("File: $basename");
         buffer.writeln("```$ext");
         buffer.writeln(content.length > 5000 ? content.substring(0, 5000) + "... [truncated]" : content);
         buffer.writeln("```\n");
       } catch (e) {}
    }
    final sourceContext = buffer.toString();

    // 3. Discover Assets
    final List<String> assets = [];
    try {
      for (var p in allPaths) {
        final lower = p.toLowerCase();
        if (lower.contains('/checkouts/') || lower.contains('amu_output/')) continue;
        if (lower.contains('icon.png')) continue; // Skip icon
        if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
          assets.add(p);
        }
        if (assets.length >= 10) break;
      }
    } catch (e) {
      print("Asset scan error: $e");
    }

    // 3. TARGETED UI EXTRACTION (Polyglot)
    String uiSourceContext = "";
    String detectedStack = "Unknown";
    
    try {
        final detector = UiDetector();
        final mainScreenPath = await detector.findMainScreenPath(source);
        
        if (mainScreenPath != null) {
            uiSourceContext = await source.readFile(mainScreenPath);
            print("UI Detector: Found main screen at $mainScreenPath");
            
            if (mainScreenPath.endsWith('.dart')) detectedStack = "Flutter";
            else if (mainScreenPath.endsWith('.tsx') || mainScreenPath.endsWith('.jsx')) detectedStack = "React";
            else if (mainScreenPath.endsWith('.html')) detectedStack = "Web/HTML";
            else if (mainScreenPath.endsWith('.vue')) detectedStack = "Vue";
        } else {
            uiSourceContext = sourceContext;
            detectedStack = "General Codebase";
        }
    } catch (e) {
        uiSourceContext = sourceContext;
    }

    // --- PHASE 1: PARALLEL INVESTIGATION ---
    
    // Agent A: CTO (Technology & Logic) + [NEW] QA Fact Sheet
    final ctoPrompt = '''
Analyze the following project (Stack: $detectedStack).
Role: CTO / Technical Auditor.
Goal: Identify the App Type, Tech Stack, Core Features, AND generate a "Fact Sheet" (Q&A).

Output ONLY valid JSON: 
{ 
  "product_name": string, 
  "app_type": "dashboard" | "feed" | "chat" | "tool" | "game", 
  "tech_stack": string[], 
  "core_features": string[],
  "primary_benefit": string,
  "qa_context": {
      "core_question": string,
      "core_answer": string,
      "technical_highlight": string
  }
}
\n--- SOURCE CODE ---\n$sourceContext
''';

    // Agent B: UI Architect (Visuals & Structure)
    // Tailored prompt based on stack
    String uiInstructions = "";
    if (detectedStack == "Flutter") {
       uiInstructions = "Transpile this Flutter Widget Tree 1:1 into JSON. Map 'Column' to 'Column', 'Text' to 'Text'.";
    } else if (detectedStack == "React") {
       uiInstructions = "Transpile this React Component Tree into a generic JSON Widget Tree. Map 'div' to 'Column', 'span/p' to 'Text', 'img' to 'Image'.";
    } else {
       uiInstructions = "Transpile this HTML/Code structure into a generic JSON Widget Tree. Approximate layout using 'Column' and 'Row'.";
    }

    final uiPrompt = '''
Analyze the following $detectedStack UI Code.
Role: Adaptive UI Transpiler.
Goal: Recreate the source UI visuals in Flutter JSON.
Rules:
1. FIDELITY: Prioritize exact matching of structure (Row/Column/Grid) and content (Text/Images).
2. STYLE: Extract EXACT HEX CODES (#RRGGBB) from source (e.g. CSS vars, const Color). If missing, use "Apple Human Interface" guidelines.
3. RECOVERY: If the source is partial/broken, INFER the intended layout (e.g. a list of items -> ListView).
4. SAFETY: Do not generate "Unknown" widgets. Stick to the standard list.

Output ONLY valid JSON:
{
  "brandPalette": { "background": "#hex", "surface": "#hex", "primary": "#hex", "onPrimary": "#hex", "secondary": "#hex" },
  "widget_tree": { 
      "type": "Scaffold", 
      "appBar": { "title": string, "elevation": 0, "centerTitle": true }, 
      "body": { 
          "type": "Column/Row/Stack/ListView/GridView/Wrap/Container/Text/Image/Icon/Button/Input", 
          "children": [], 
          "child": {}, 
          "text": string, 
          "src": string, 
          "icon": string, 
          "style": { "color": "#hex", "fontSize": 16, "fontWeight": "bold/normal", "opacity": 1.0 }, 
          "decoration": { 
              "color": "#hex", 
              "gradient": { "colors": ["#hex", "#hex"], "begin": "topLeft", "end": "bottomRight" },
              "borderRadius": 0, 
              "boxShadow": [{ "color": "#00000022", "blur": 4, "offset": [0, 2] }],
              "border": { "color": "#hex", "width": 1 }
          },
          "crossAxisCount": 2, 
          "mainAxisAlignment": "start/center/end/spaceBetween",
          "crossAxisAlignment": "start/center/end/stretch"
      }
  }
}
IMPORTANT: 
- Replicate the VISUAL RESULT, not just the code structure.
- If text is missing in source, use placeholders like "Lorem Ipsum".
- **CRITICAL**: The "Target UI File" might just be an entry point. SEARCH "FULL PROJECT CONTEXT" for the actual widget definitions.
\n--- TARGET UI FILE SOURCE ---\n$uiSourceContext
\n--- FULL PROJECT CONTEXT (Look here for definitions) ---\n$sourceContext
''';

    // Execute Parallel
    final results = await Future.wait([
      _generateJson(ctoPrompt, temperature: 0.2), 
      _generateJson(uiPrompt, temperature: 0.2)
    ]);
    
    final ctoData = results[0];
    final uiData = results[1];
    
    // --- PHASE 2: STRATEGIC SYNTHESIS (The "Four Divisions") ---
    
    final masterPrompt = '''
Role: Creative Director & Product Strategist.
Input Data:
- Product: ${ctoData['product_name']} (${ctoData['app_type']})
- Stack: ${ctoData['tech_stack']}
- Features: ${ctoData['core_features']}
- UI Style: ${uiData['brandPalette']}
- Technical Fact (Q&A): ${ctoData['qa_context']}
- Available Image Assets: ${assets.join(', ')} (PRIORITIZE USING THESE EXACT PATHS IN storyboard/scenes logic)

Task: Generate a Master Plan for the product launch, divided into 4 strategies.

Output ONLY valid JSON matching this schema:
{
  "marketing_angle": {
      "hook_main": string,
      "hook_sub": string,
      "overlay_broll": string,
      "overlay_feature1": string,
      "overlay_feature2": string,
      "outro_sub": string
  },
  "cm_storyboard": {
      "scenes": [
        {
          "id": string,
          "type": "title" | "image_display" | "text_overlay" | "widget",
          "duration": number,
          "text": string,
          "subtext?": string,
          "overlayText?": string,
          "assetPath?": string,
          "camera?": { "start": {}, "end": {} }
        }
      ],
      "missing_assets_instruction": string[]
  },
  "article_context": {
      "topic": string,
      "target_audience": string,
      "key_takeaways": string[]
  },
  "slide_context": {
      "title": string,
      "chapters": string[]
  }
}
IMPORTANT: 'missing_assets_instruction' should list specific assets the user needs to provide based on the storyboard (e.g., "Screenshot of Login Screen", "Demo Video of Feature X").
IMPORTANT: All text MUST be in $language.
''';

    final masterPlan = await _generateJson(masterPrompt, temperature: 0.7);

    // --- FINAL MERGE ---
    return {
      ...ctoData,
      ...uiData,
      ...masterPlan['marketing_angle'],
      "scenes": masterPlan['cm_storyboard']?['scenes'] ?? [],
      "missing_assets_instruction": masterPlan['cm_storyboard']?['missing_assets_instruction'] ?? [],
      "article_context": masterPlan['article_context'],
      "slide_context": masterPlan['slide_context'],
      "qa_context": ctoData['qa_context'], // Now comes from CTO (Fact Sheet)
      "language": language,
      "discovered_assets": assets
    };
  }

  Future<Map<String, dynamic>> _generateJson(String prompt, {double temperature = 0.5}) async {
      final model = GenerativeModel(model: modelName, apiKey: apiKey, generationConfig: GenerationConfig(temperature: temperature));
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      // Extract JSON from response (may be wrapped in ```json ... ```)
      final jsonStr = text.replaceAll(RegExp(r'^```json\s*', multiLine: true), '').replaceAll(RegExp(r'^```\s*$', multiLine: true), '').trim();
      try {
        return jsonDecode(jsonStr);
      } catch (e) {
        print("JSON Parse Error: $e\nRaw: ${jsonStr.substring(0, (jsonStr.length > 200 ? 200 : jsonStr.length))}");
        return {};
      }
  }

  // Utility for direct text generation
  Future<String> generateContent(String prompt) async {
      final model = GenerativeModel(model: modelName, apiKey: apiKey, generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 8192,
      ));
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? '';
  }
}

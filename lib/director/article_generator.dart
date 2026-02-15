import 'package:amu/logic/gemini_service.dart';

class ArticleGenerator {
  final GeminiService _gemini;
  
  ArticleGenerator(String apiKey) : _gemini = GeminiService(apiKey);

  Future<String> generateArticle(Map<String, dynamic> dna, String sourceSummary, {String language = 'English'}) async {
    final buffer = StringBuffer();
    
    // Zenn Guildeline Context
    buffer.writeln("You are a skilled Tech Writer contributing to Zenn. Write in $language.");
    buffer.writeln("""
### Core Philosophy
"Solve a personal PAIN using technology's OVER-ENGINEERING."
Don't just explain 'How to use X'. Explain 'Why I summoned X to defeat the demon of boredom'.

### Structure
1. **Pain (Problem)**: 10% - Emotional hook. Why was the old way unbearable?
2. **Goal (Ideal)**: 10% - What is the dream state?
3. **Solution (Architecture)**: 20% - The 'Over-engineered' approach. (e.g., "I used AI agents instead of a shell script").
    - **MUST INCLUDE**: A Mermaid diagram explaining the system architecture.
    ```mermaid
    graph TD;
      A[User] --> B[Flutter App];
      B --> C[Gemini API];
    ```
4. **Implementation (Tech)**: 40% - Concrete code, "Gotchas", and specific libraries (Flutter, Gemini, etc.).
5. **Result (Demo)**: 20% - Before/After comparison.
    - **MUST INCLUDE**: A placeholder for a YouTube video or GIF.
    - `@[youtube](VIDEO_ID)` or `![](https://storage.googleapis.com/...)`

### Tone
- **IMPORTANT**: Do NOT act like an AI Assistant or Butler. Do NOT use polite, subservient language (e.g., "AI執事です", "お手伝いします").
- Act like a **Senior Interface Engineer** or **Hacker**.
- Tone: Technical, Confident, slightly cynical but passionate about code.
- "だ・である" style (or casual "です・ます" with engineering slang).
- Use formatting (Bold, Code Blocks) aggressively.
- Target Audience: Developers who are tired of boring tutorials.
    """);

    buffer.writeln("\n--- Product DNA ---");
    buffer.writeln("Name: ${dna['product_name']}");
    buffer.writeln("Hook: ${dna['hook_main']}");
    buffer.writeln("Features: ${dna['features']}");
    buffer.writeln("Tech Stack: ${dna['tech_stack'] ?? 'Flutter, Gemini API'}"); // Use specific stack
    
    // Inject Strategy if available
    if (dna['article_context'] != null) {
       final ctx = dna['article_context'];
       buffer.writeln("\n--- Article Strategy (from Creative Director) ---");
       buffer.writeln("Topic: ${ctx['topic']}");
       buffer.writeln("Target Audience: ${ctx['target_audience']}");
       buffer.writeln("Key Takeaways: ${ctx['key_takeaways']}");
    }
    
    buffer.writeln("\n--- Source Code Context ---");
    buffer.writeln(sourceSummary);

    buffer.writeln("\n\nWrite a Zenn-style technical article (Markdown) about building this product.");
    
    // Call Gemini
    final content = await _gemini.generateContent(buffer.toString());
    return content ?? "# Error Generating Article";
  }
}

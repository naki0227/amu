import 'package:amu/logic/gemini_service.dart';

class SpecGenerator {
  final GeminiService _gemini;

  SpecGenerator(String apiKey) : _gemini = GeminiService(apiKey);

  Future<String> generateSpec(Map<String, dynamic> dna, String sourceSummary, {String language = 'English'}) async {
    final buffer = StringBuffer();
    
    // Master Spec Context
    buffer.writeln("You are the CTO and Lead Architect. Write a 'Master Specification' document in $language.");
    buffer.writeln("""
### Purpose
This document is the "Bible" of the project. If the user reads this, they should be able to answer ANY question in a technical interview or investor meeting.

### Content Requirements
1. **Origin Story (Why)**:
   - What was the spark? (Infer from 'hook' or guess a compelling narrative based on the problem solved).
   - Why is this solution better than existing ones?
   
2. **Technical Architecture (How)**:
   - High-level overview (Diagrammatic description).
   - Key technology choices (Flutter, Gemini, etc.) and *why* they were chosen.
   - "Secret Sauce": What is the most complex/clever part of the implementation? (Infer from code context).

3. **Core Features & Implementation Details**:
   - Deep dive into how the main features work under the hood.

4. **Future Roadmap**:
   - What's missing? What's next?

5. **FAQ / Interview Prep**:
   - Q: "What was the hardest bug you squashed?"
   - Q: "How does this scale?"
   - Q: "Why didn't you use [Alternative X]?" (Generate strictly logical answers).

### Tone
- Professional, confident, yet authentic.
- Detailed and specific. No fluff.
    """);

    buffer.writeln("\n--- Product DNA ---");
    buffer.writeln("Name: ${dna['product_name']}");
    buffer.writeln("Hook: ${dna['hook_main']}");
    buffer.writeln("Features: ${dna['features']}");
    
    if (dna['qa_context'] != null) {
       final ctx = dna['qa_context'];
       buffer.writeln("\n--- Q&A Strategy (from Creative Director) ---");
       buffer.writeln("Core Question: ${ctx['core_question']}");
       buffer.writeln("Core Answer Key: ${ctx['core_answer']}");
    }
    
    buffer.writeln("\n--- Source Code Context ---");
    buffer.writeln(sourceSummary);

    buffer.writeln("\nGenerate the Master Specification (Markdown).");
    
    // Call Gemini
    final content = await _gemini.generateContent(buffer.toString());
    return content ?? "# Error Generating Spec";
  }
}

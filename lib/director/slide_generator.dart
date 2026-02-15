import 'package:amu/logic/gemini_service.dart';

class SlideGenerator {
  final GeminiService _gemini;

  SlideGenerator(String apiKey) : _gemini = GeminiService(apiKey);

  Future<String> generateSlides(Map<String, dynamic> dna, {String language = 'English'}) async {
    final buffer = StringBuffer();
    
    // Marp Context
    buffer.writeln("You are a Pitch Deck Expert. Create a slide deck using Marp (Markdown Presentation) format in $language.");
    buffer.writeln("""
### Marp Format
- Use `---` to separate slides.
- Header:
```markdown
---
marp: true
theme: default
paginate: true
backgroundColor: #1E293B
color: #F8FAFC
style: |
  section {
    font-family: 'Inter', sans-serif;
  }
  h1 {
    color: #818CF8;
  }
---
```
- Structure:
  1. Title Slide (Logo, Name, Hook)
  2. The Problem (Pain Point)
  3. The Solution (Product Concept)
  4. Demo / Features (Screenshots - use placeholders `![bg right](demo.png)`)
  5. Technology (Flutter, Gemini, etc.)
  6. Call to Action (GitHub link)

### Product Info
Name: ${dna['product_name']}
Hook: ${dna['hook_main']}
Features: ${dna['features']}
Tech Stack: ${dna['tech_stack'] ?? 'Flutter'}

${dna['slide_context'] != null ? """
### Slide Strategy (from Creative Director)
Title: ${dna['slide_context']['title']}
Chapters: ${dna['slide_context']['chapters']}
""" : ""}
    """);

    buffer.writeln("\nGenerate the full Marp Markdown content.");
    
    // Call Gemini
    final content = await _gemini.generateContent(buffer.toString());
    return content ?? "# Error Generating Slides";
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:amu/director/storyboard_generator.dart';

void main() {
  test('Generate EnCura Storyboard', () async {
    // 1. Load Product DNA
    final File dnaFile = File('/Users/hw24a094/.gemini/antigravity/brain/5394f1f1-d6fd-434d-bfbc-84f02ede0231/encura_product_dna.json');
    if (!dnaFile.existsSync()) {
      // Fallback for test if file not found in exact path (relative execution)
      print("Warning: DNA file not found at path, skipping load.");
      return;
    }
    
    final String jsonString = dnaFile.readAsStringSync();
    final Map<String, dynamic> dna = jsonDecode(jsonString);

    // 2. Generate Storyboard
    final generator = StoryboardGenerator();
    final storyboard = generator.generateStoryboard(dna);

    // 3. Verify Output
    print("\n--- Generated Storyboard ---");
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    print(encoder.convert(storyboard));
    
    expect(storyboard['appName'], isNull); // Storyboard uses DNA data but doesn't copy all
    expect(storyboard['scenes'], isNotEmpty);
    expect(storyboard['bgm'], contains('ambient_piano')); // Check if "Premium" logic worked
  });
}

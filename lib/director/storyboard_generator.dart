import 'dart:convert';
import 'package:flutter/material.dart';

/// Creative Director Logic (Prototype)
/// 
/// In the full system, this would call Gemini API with `prompts/creative_director.md` and `ProductDNA`.
/// Here, we implement a manual "Rule-Based" director that acts as a placeholder for the AI response.

class StoryboardGenerator {
  
  Map<String, dynamic> generateStoryboard(Map<String, dynamic> dna) {
    final List<dynamic> assets = dna['discovered_assets'] ?? [];
    final String bgm = "assets/audio/ambient_piano.mp3"; // This is a system asset
    
    // Helper to get an asset or fallback
    String getAsset(int index, String fallback) {
      if (assets.length > index) return assets[index];
      return fallback;
    }

    // --- Phase 1: Hook ---
    final scene1 = {
      "id": "p1_hook",
      "duration": 4.0,
      "type": "text_overlay",
      "text": dna['hook_main'] ?? "Code into Stories",
      "subtext": dna['hook_sub'] ?? "Automated CM Generation",
      "backgroundColor": "#000000"
    };

    // --- Phase 2: B-Roll (Real Project Asset) ---
    final scene2 = {
      "id": "p2_broll",
      "duration": 5.0,
      "type": assets.isNotEmpty ? "image_display" : "title",
      "assetPath": getAsset(0, ""),
      "text": dna['product_name'] ?? "Project",
      "subtext": dna['overlay_broll'] ?? "Visualized by Amu", // Dynamic
      "camera": {
        "start": {"zoom": 1.2, "dx": -0.1, "dy": 0.0},
        "end": {"zoom": 1.0, "dx": 0.0, "dy": 0.0}
      },
      "overlayText": dna['overlay_broll'] ?? "Authentic Spirit"
    };

    // --- Phase 3: Solution ---
    final scene3 = {
      "id": "p3_solution",
      "duration": 3.0,
      "type": "title",
      "text": dna['appName'] ?? "Amu Generated",
      "subtext": dna['hook_sub'] ?? "Native Reconstruction",
      "backgroundColor": dna['brandPalette']?['background'] ?? "#1E293B"
    };

    // --- Phase 4: Feature 1 ---
    final scene4 = {
      "id": "p4_feature_1",
      "duration": 5.0,
      "type": assets.length > 1 ? "image_display" : "text_overlay",
      "assetPath": getAsset(1, ""),
      "text": dna['features']?.isNotEmpty == true ? dna['features'][0] : "Key Feature",
      "overlayText": dna['overlay_feature1'] ?? "Core Performance",
      "camera": {
        "start": {"zoom": 1.0, "dx": 0.0, "dy": 0.0},
        "end": {"zoom": 1.1, "dx": 0.0, "dy": 0.0}
      }
    };

    // --- Phase 5: Feature 2 ---
    final scene5 = {
      "id": "p5_feature_2",
      "duration": 5.0,
      "type": assets.length > 2 ? "image_display" : "title",
      "assetPath": getAsset(2, ""),
      "text": assets.length > 2 ? "" : (dna['features']?.length == 2 ? dna['features'][1] : "Innovation"),
      "overlayText": dna['overlay_feature2'] ?? "Global Reach",
      "camera": {
        "start": {"zoom": 1.0, "dx": 0.0, "dy": 0.0},
        "end": {"zoom": 1.3, "dx": 0.1, "dy": 0.1}
      }
    };

    // --- Phase 6: Outro ---
    final scene6 = {
      "id": "p6_outro",
      "duration": 4.0,
      "type": "title",
      "text": dna['appName'] ?? "Done",
      "subtext": dna['outro_sub'] ?? "Powered by Amu Engine",
      "backgroundColor": "#000000"
    };

    return {
      "fps": 60,
      "width": 1920,
      "height": 1080,
      "durationSeconds": 26,
      "bgm": bgm,
      "brandPalette": dna['brandPalette'] ?? {"background": "#1E293B"}, // Pass global palette
      "platform": dna['platform'] ?? "mobile",
      "scenes": [scene1, scene2, scene3, scene4, scene5, scene6]
    };
  }
}

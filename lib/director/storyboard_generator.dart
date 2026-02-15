import 'dart:convert';
import 'dart:io';
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

    // --- If Gemini provided Scenes, use them ---
    if (dna['scenes'] != null && (dna['scenes'] as List).isNotEmpty) {
       final aiScenes = (dna['scenes'] as List).map((s) {
          // Robustness: Ensure required keys
          final type = s['type'] ?? 'title';
          final duration = (s['duration'] as num?)?.toDouble() ?? 5.0;
          
          // Asset Logic: If 'assetPath' is "asset_0" or missing, try to resolve
          String asset = s['assetPath'] ?? "";
          if (type == 'image_display' && (asset.isEmpty || !asset.startsWith('/'))) {
              // Fallback to discovered assets
             asset = getAsset(0, ""); // Simple fallback
             // Better: Iterate?
          }
          
          return {
             ...s as Map<String, dynamic>,
             "duration": duration,
             "type": type,
             "assetPath": asset,
          };
       }).toList();
       
       return {
         "fps": 60,
         "width": 1920,
         "height": 1080,
         "durationSeconds": aiScenes.fold<double>(0, (sum, s) => sum + (s['duration'] as num).toDouble()).toInt(),
         "bgm": bgm,
         "brandPalette": dna['brandPalette'] ?? {"background": "#1E293B"},
         "platform": dna['platform'] ?? "mobile",
         "language": dna['language'] ?? "English",
         "widget_tree": dna['widget_tree'],
         "scenes": aiScenes
       };
    }

    // --- Fallback: Rule-Based Logic (Asset-First Mode) ---
    
    // Attempt to find absolute icon path from discovered assets or current directory
    String iconPath = "assets/photo/icon.png";
    try {
      // Find absolute path of icon in assets
      final iconFile = assets.firstWhere((a) => a.contains('assets/photo/icon.png'), orElse: () => "");
      if (iconFile.isNotEmpty) iconPath = iconFile;
      else {
          // Construct absolute path assuming we are in project root
          final absIcon = "${Directory.current.path}/assets/photo/icon.png";
          if (File(absIcon).existsSync()) iconPath = absIcon;
      }
    } catch (_) {}

    final photoAssets = assets.where((a) => a.contains('assets/photo') && !a.contains('icon.png')).toList();
    final int assetCount = photoAssets.length;
    final List<Map<String, dynamic>> finalScenes = [];
    final List<String> missingAssetsInstructions = [];

    // --- GAP ANALYSIS ---
    if (assetCount == 0) {
        missingAssetsInstructions.add("Add screenshots to 'assets/photo' to make the video more engaging.");
    } else if (assetCount < 3) {
        missingAssetsInstructions.add("Adding at least 3 screenshots enables the 'Dynamic Montage' mode.");
    }

    // Helper to cycle through assets if we have few
    String getPhoto(int index) {
        if (photoAssets.isEmpty) return "";
        return photoAssets[index % photoAssets.length];
    }

    // --- PHASE 0: INTRO ---
    finalScenes.add({
      "id": "p0_intro",
      "duration": 3.0,
      "type": "image_display",
      "assetPath": iconPath, 
      "text": "",
      "subtext": "",
      "overlayText": dna['appName']?.toUpperCase() ?? "AMU APP",
      "camera": {"start": {"zoom": 0.8}, "end": {"zoom": 1.0}}
    });

    // --- PHASE 1: HOOK ---
    finalScenes.add({
      "id": "p1_hook",
      "duration": 3.0,
      "type": "text_overlay",
      "text": (dna['hook_main'] ?? "Code into Stories").toUpperCase(),
      "subtext": dna['hook_sub'] ?? "Automated CM Generation",
      "backgroundColor": "#000000"
    });

    // --- PHASE 2-5: DYNAMIC BODY ---
    if (assetCount == 0) {
        // Mode A: Typography Only (No Assets)
        finalScenes.add({
            "id": "p2_typo_1", "duration": 4.0, "type": "title",
            "text": (dna['features']?.isNotEmpty == true ? dna['features'][0] : "INNOVATION").toUpperCase(),
            "subtext": "Core Feature", "backgroundColor": "#1E293B"
        });
        finalScenes.add({
            "id": "p3_typo_2", "duration": 4.0, "type": "title",
            "text": (dna['features'] != null && dna['features'].length > 1 ? dna['features'][1] : "PERFORMANCE").toUpperCase(),
            "subtext": "Optimized", "backgroundColor": "#0F172A"
        });
    } else {
        // Mode B: Asset Showcase (Aggressive Slideshow)
        
        // 1. Hero Scene (First Asset)
        finalScenes.add({
            "id": "p2_hero", 
            "duration": 5.0, 
            "type": "image_display",
            "assetPath": getPhoto(0),
            "text": "",
            "overlayText": (dna['product_name'] ?? "PROJECT").toUpperCase(),
            "camera": {"start": {"zoom": 1.1, "dx": -0.05}, "end": {"zoom": 1.0}}
        });

        // 2. Dynamic Loop for ALL remaining assets (Limit 10 to avoid too long video)
        // If we have more assets, we create a rapid-fire sequence
        int remainingStart = 1;
        int maxSlides = 10;
        
        for (int i = remainingStart; i < assetCount && i < maxSlides; i++) {
            // Alternate Camera Movements
            bool isEven = i % 2 == 0;
            finalScenes.add({
                "id": "p3_slide_$i", 
                "duration": 3.0, // Fast paced
                "type": "image_display",
                "assetPath": photoAssets[i], // Direct access
                "text": "",
                "overlayText": "", // Clean visual
                "camera": {
                    "start": isEven ? {"zoom": 1.0} : {"zoom": 1.2}, 
                    "end": isEven ? {"zoom": 1.1, "dx": 0.05} : {"zoom": 1.0}
                }
            });
        }
        
        // 3. Feature Highlight (Text Intermission if we have many slides)
        if (assetCount > 3) {
             finalScenes.insert(3, {
                "id": "p2_intermission", 
                "duration": 3.0, 
                "type": "title",
                "text": (dna['features']?.isNotEmpty == true ? dna['features'][0] : "FEATURES").toUpperCase(),
                "subtext": "Visual Overview", 
                "backgroundColor": "#1E293B"
            });
        }
    }

    // --- PHASE 6: OUTRO ---
    finalScenes.add({
      "id": "p6_outro",
      "duration": 5.0,
      "type": "image_display",
      "assetPath": iconPath,
      "text": "",
      "overlayText": "DOWNLOAD NOW",
      "subtext": dna['appName'] ?? "Amu App",
      "camera": {"start": {"zoom": 1.5}, "end": {"zoom": 1.0}}
    });

    final int totalDuration = finalScenes.fold<double>(0, (sum, s) => sum + (s['duration'] as num).toDouble()).toInt();

    return {
      "fps": 60,
      "width": 1920,
      "height": 1080,
      "durationSeconds": totalDuration,
      "bgm": bgm,
      "brandPalette": dna['brandPalette'] ?? {"background": "#1E293B"},
      "platform": dna['platform'] ?? "mobile",
      "language": dna['language'] ?? "English",
      "widget_tree": dna['widget_tree'],
      "scenes": finalScenes,
      "missing_assets_instruction": missingAssetsInstructions // New Field
    };
  }
}

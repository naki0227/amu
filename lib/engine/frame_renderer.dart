import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:amu/logic/project_storage.dart';

/// Frame Renderer Service
/// Captures rendered frames as PNG images for video export
class FrameRenderer {
  /// Render a frame from a RenderRepaintBoundary and save as PNG
  static Future<void> captureFrame({
    required RenderRepaintBoundary boundary,
    required String projectName,
    required int frameNumber,
    double pixelRatio = 2.0,
  }) async {
    try {
      // Capture the image
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Failed to capture frame $frameNumber');
      }
      
      // Save to file
      final framesPath = ProjectStorage.getFramesPath(projectName);
      await Directory(framesPath).create(recursive: true);
      
      final fileName = 'frame_${frameNumber.toString().padLeft(4, '0')}.png';
      final file = File('$framesPath/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      
    } catch (e) {
      print('Error capturing frame $frameNumber: $e');
      rethrow;
    }
  }
  
  /// Render all frames for a storyboard
  /// 
  /// [captureCallback] - Function to render and capture each frame
  /// [totalFrames] - Total number of frames to render
  /// [onProgress] - Progress callback (0.0 - 1.0)
  static Future<void> renderAllFrames({
    required String projectName,
    required int totalFrames,
    required Future<void> Function(int frameNumber) captureCallback,
    Function(double progress, int currentFrame)? onProgress,
  }) async {
    // Clear existing frames
    await ProjectStorage.clearFrames(projectName);
    await ProjectStorage.createProjectStructure(projectName);
    
    for (int i = 0; i < totalFrames; i++) {
      await captureCallback(i);
      onProgress?.call((i + 1) / totalFrames, i + 1);
    }
  }
  
  /// Get the count of rendered frames
  static Future<int> getFrameCount(String projectName) async {
    final framesDir = Directory(ProjectStorage.getFramesPath(projectName));
    if (!await framesDir.exists()) return 0;
    
    int count = 0;
    await for (final file in framesDir.list()) {
      if (file.path.endsWith('.png')) count++;
    }
    return count;
  }
}

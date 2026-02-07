import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// AmuRenderer Prototype
/// 
/// Deterministically renders frames by manually controlling the frame policy.
/// 
/// Usage:
/// ```dart
/// final renderer = AmuRenderer(
///   outputDirectory: Directory('output'),
///   fps: 60,
/// );
/// await renderer.renderSequence(
///   widget: MovingBoxScene(),
///   frameCount: 60,
/// );
/// ```

class AmuRenderer {
  final Directory outputDirectory;
  final int fps;

  AmuRenderer({
    required this.outputDirectory,
    this.fps = 60,
  });

  Future<void> renderSequence({
    required Widget widget,
    required int frameCount,
    required WidgetTester tester,
  }) async {
    // Ensure output directory exists
    if (!outputDirectory.existsSync()) {
      outputDirectory.createSync(recursive: true);
    }
    
    // Set surface size to something smaller for quick testing
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;

    // Defines a key to capture the RepaintBoundary
    final GlobalKey containerKey = GlobalKey();

    // Wrap the scene in a RepaintBoundary
    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black, // Dark background
        body: RepaintBoundary(
          key: containerKey,
          child: Center(
            child: SizedBox(
              width: 360,
              height: 640,
              child: widget,
            ),
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pumpWidget(app);
    await tester.pump();

    final Duration frameDuration = Duration(microseconds: (1000000 / fps).round());

    for (int i = 0; i < frameCount; i++) {
      // 1. Advance time
      print('Pumping frame $i...');
      await tester.pump(frameDuration);

      // 2. Capture Image
      print('Capturing frame $i...');
      final RenderRepaintBoundary? boundary = containerKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) {
        print('Error: Boundary not found at frame $i');
        continue;
      }

      // Capture image
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      print('Image captured $i');
      
      // 3. Export to File
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
          print('Error: ByteData is null at frame $i');
          continue;
      }
      
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      print('Got ${pngBytes.lengthInBytes} bytes for frame $i');
      
      final String fileName = 'frame_${i.toString().padLeft(4, '0')}.png';
      final File file = File('${outputDirectory.path}/$fileName');
      file.writeAsBytesSync(pngBytes);
      
      print('Rendered: $fileName');
      
      // Cleanup image memory
      image.dispose();
    }
  }
}

/// A simple sample scene: A red box moving from left to right.
class MovingBoxScene extends StatefulWidget {
  const MovingBoxScene({super.key});

  @override
  State<MovingBoxScene> createState() => _MovingBoxSceneState();
}

class _MovingBoxSceneState extends State<MovingBoxScene> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Use a long duration, but we will step through it manually
    _controller = AnimationController(
      duration: const Duration(seconds: 2), // Loops every 2 seconds
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Linear movement: x goes from 0 to 1820 (1920 - 100 box width)
        final double x = _controller.value * (1920 - 100);
        
        return Stack(
          children: [
            Positioned(
              left: x,
              top: 540 - 50, // Center Y
              child: Container(
                width: 100,
                height: 100,
                color: Colors.red,
                child: const Center(
                  child: Text("Amu", style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            // Add a frame counter for debugging
            Positioned(
              bottom: 20,
              right: 20,
              child: Text(
                "Progress: ${(_controller.value * 100).toStringAsFixed(1)}%",
                style: const TextStyle(fontSize: 24, color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Entry point to run the renderer.
/// NOTE: This file is intended to be run via `flutter test` to access `TestWidgetsFlutterBinding`.
/// e.g. `flutter test lib/engine/amu_renderer.dart`
void main() {
  testWidgets('Amu Renderer - Render 60 Frames', (WidgetTester tester) async {
    final renderer = AmuRenderer(
      outputDirectory: Directory('amu_output'),
      fps: 30, // Using 30fps for the prototype
    );

    await renderer.renderSequence(
      widget: const MovingBoxScene(),
      frameCount: 60, // 2 seconds at 30fps
      tester: tester,
    );
  });
}

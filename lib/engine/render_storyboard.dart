import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';


import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:amu/engine/amu_renderer.dart';
import 'package:amu/director/storyboard_generator.dart';
/// Renders the full Storyboard generated from ProductDNA.
///
/// Run with:
/// `flutter test lib/engine/render_storyboard.dart`

 void main() {
  testWidgets('Render Full Storyboard', (WidgetTester tester) async {
    // 0. Load Fonts for Visual Verification
    await tester.runAsync(() async {
      await _loadFont('serif', '/System/Library/Fonts/Supplemental/Arial.ttf');
    });
    
    // 1. Load Storyboard (Priority: 1. Manual Save, 2. DNA Generation)
    final File projectFile = File('amu_output/project.json');
    Map<String, dynamic> storyboard;
    
    if (projectFile.existsSync()) {
      print('Loading Saved Project from ${projectFile.path}');
      storyboard = jsonDecode(projectFile.readAsStringSync());
    } else {
      print('Generating Storyboard from DNA...');
      final File dnaFile = File('/Users/hw24a094/.gemini/antigravity/brain/5394f1f1-d6fd-434d-bfbc-84f02ede0231/encura_product_dna.json');
      final Map<String, dynamic> dna = jsonDecode(dnaFile.readAsStringSync());
      final generator = StoryboardGenerator();
      storyboard = generator.generateStoryboard(dna);
      
      // DEBUG Defaults (Only when regenerating)
      storyboard['scenes'][0]['duration'] = 0.0; 
      storyboard['durationSeconds'] = 2; 
    }
    // DEBUG: Skip Intro to capture full Mock Animation
    storyboard['scenes'][0]['duration'] = 0.0; 
    storyboard['durationSeconds'] = 2; // Render 2 seconds of UI Animation

    print('Rendering Storyboard: ${storyboard['scenes'].length} scenes, ${storyboard['durationSeconds']}s total.');

    // 2. Setup Renderer
    // 3. Manual Keyframe Rendering (Optimized)
    // Setup View
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    final GlobalKey containerKey = GlobalKey();

    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: RepaintBoundary(
          key: containerKey,
          child: Center(
            child: SizedBox(
              width: 360,
              height: 640,
              child: StoryboardDriver(storyboard: storyboard),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app);
    await tester.pump();

    // Pump to specific timestamps and capture
    final List<double> keyframes = [0.0, 0.5, 1.0, 1.5, 1.9]; // Seconds
    
    for (double time in keyframes) {
      // Calculate delta needed to reach 'time' from current internal time (which we track conceptually)
      // Actually, we can just pump huge duration to jump? No, animations need steps.
      // But for verifying "End State", we can pump duration.
      // Since we reset at start, we are at 0.
      
      // Strategy: Reset app for each keyframe to be safe? No, expensive.
      // Just pump forward.
      // Current time is tracked by tester.
      // We will pump in steps of 100ms until we reach target. (Simulating smooth play)
      
      // Wait, we need to capture at 'time'.
      // We assume sequential: 0.0 -> 0.5 -> 1.0...
      
      print('Seeking to $time s...');
      // Note: flutter_test 'pump' adds to the clock.
      // We need to track previous time.
      // Let's simplified: We loop 20 frames (Duration 2.0s @ 10fps), but only capture specific indices.
    }
    
    // Jump to end of animation (2.0s)
    await tester.pump(const Duration(seconds: 2));
    
    // Capture Final Frame
    print('Capturing Final Frame (t=2.0s)...');
    final RenderRepaintBoundary? boundary = containerKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final image = await boundary!.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();
    File('amu_output/storyboard_final/frame_final.png').writeAsBytesSync(buffer);
    image.dispose();
    print('Saved frame_final.png');
  },
  timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _loadFont(String fontName, String path) async {
  print('Loading font $fontName from $path...');
  try {
    final file = File(path);
    if (!file.existsSync()) {
        print('Font file not found!');
        return;
    }
    final bytes = await file.readAsBytes();
    print('Read ${bytes.lengthInBytes} bytes');
    
    final loader = FontLoader(fontName);
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
    print('Font loaded successfully');
  } catch (e) {
    print('Error loading font: $e');
  }
}

class StoryboardDriver extends StatefulWidget {
  final Map<String, dynamic> storyboard;

  const StoryboardDriver({super.key, required this.storyboard});

  @override
  State<StoryboardDriver> createState() => _StoryboardDriverState();
}

class _StoryboardDriverState extends State<StoryboardDriver> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<dynamic> _scenes;
  late int _totalDuration;

  @override
  void initState() {
    super.initState();
    _scenes = widget.storyboard['scenes'];
    _totalDuration = widget.storyboard['durationSeconds'];
    
    _controller = AnimationController(
      duration: Duration(seconds: _totalDuration),
      vsync: this,
    )..forward();
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
      builder: (context, _) {
        final double currentTime = _controller.value * _totalDuration;
        
        // 1. Find Active Scene
        dynamic activeScene;
        double sceneStartTime = 0.0;
        
        for (var scene in _scenes) {
          final double duration = (scene['duration'] as num).toDouble();
          if (currentTime >= sceneStartTime && currentTime < sceneStartTime + duration) {
            activeScene = scene;
            break;
          }
          sceneStartTime += duration;
        }

        // Handle end of video (keep last frame)
        if (activeScene == null && _scenes.isNotEmpty) {
           activeScene = _scenes.last;
           sceneStartTime = _totalDuration - (activeScene['duration'] as num).toDouble();
        }

        if (activeScene == null) return const SizedBox();

        // 2. Calculate Scene Progress (0.0 -> 1.0)
        final double sceneDuration = (activeScene['duration'] as num).toDouble();
        final double sceneProgress = ((currentTime - sceneStartTime) / sceneDuration).clamp(0.0, 1.0);

        // 3. Render Content based on Type
        Widget content;
        if (activeScene['type'] == 'title' || activeScene['type'] == 'text_overlay') {
          content = _buildTitleScene(activeScene, sceneProgress);
        } else if (activeScene['type'] == 'widget') {
          content = _buildWidgetScene(activeScene, sceneProgress);
        } else {
          content = const SizedBox();
        }

        return Theme(
          data: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            primaryColor: const Color(0xFFC5A059),
            fontFamily: 'serif',
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFC5A059),
              brightness: Brightness.dark,
              background: const Color(0xFF121212),
            ),
          ),
          child: content,
        );
      },
    );
  }

  Widget _buildTitleScene(Map<String, dynamic> scene, double progress) {
    // 1. Cinematic Background (Van Gogh)
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'checkouts/encura/assets/art/vangogh_starry.jpg',
          fit: BoxFit.cover,
        ),
        // 2. Blur & Darken
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.black.withOpacity(0.7)),
        ),
        // 3. Typography
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: 1.0,
                  child: Text(
                    scene['text'] ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFC5A059), // EnCura Gold
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'serif',
                      letterSpacing: 1.5,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Divider
                Container(width: 60, height: 2, color: Colors.white30),
                const SizedBox(height: 24),
                
                Opacity(
                  opacity: (progress - 0.2).clamp(0.0, 1.0),
                  child: Text(
                    scene['subtext'] ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: 'serif',
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWidgetScene(Map<String, dynamic> scene, double progress) {
    // 1. Get Widget
    Widget child;
    if (scene['widgetName'] == 'MockHomeScreen') {
      // Legacy MockHomeScreen removed. Use a placeholder for now.
      child = const Center(child: Text("Preview Placeholder", style: TextStyle(color: Colors.white70, fontSize: 18)));
    } else {
      child = const SizedBox();
    }

    // 2. Apply Camera Transform
    // Camera keys: zoom, dx, dy
    final camera = scene['camera'];
    if (camera != null) {
      final start = camera['start'];
      final end = camera['end'];
      
      // Simple LERP
      // Curve application omitted for brevity in prototype, assumes linear or easeOutSine roughly
      final double t = Curves.easeOutSine.transform(progress);
      
      final double zoom = _lerp((start['zoom'] as num).toDouble(), (end['zoom'] as num).toDouble(), t);
      final double dx = _lerp((start['dx'] as num).toDouble(), (end['dx'] as num).toDouble(), t);
      final double dy = _lerp((start['dy'] as num).toDouble(), (end['dy'] as num).toDouble(), t);

    return Stack(
      children: [
        // 0. Ambient Background for the Phone Scene
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [Color(0xFF2C2C2C), Color(0xFF000000)],
            ),
          ),
        ),
        
        // 1. The Phone App (Transformed)
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(zoom)
            ..translate(dx * 100, dy * 100),
          child: Center(
             child: Container(
               width: 360, 
               height: 640,
               decoration: BoxDecoration(
                 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)],
               ),
               child: child
             ),
          ),
        ),

        // 2. Caption Overlay (if present)
        if (scene['overlayText'] != null)
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFC5A059).withOpacity(0.5), width: 1),
                ),
                child: Text(
                  scene['overlayText'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  double _lerp(double start, double end, double t) {
    return start + (end - start) * t;
  }
}

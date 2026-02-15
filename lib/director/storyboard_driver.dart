import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:io';
// Removed Mock Import


class StoryboardDriver extends StatefulWidget {
  final Map<String, dynamic> storyboard;
  final AnimationController controller;

  const StoryboardDriver({
    super.key, 
    required this.storyboard,
    required this.controller,
  });

  @override
  State<StoryboardDriver> createState() => _StoryboardDriverState();
}


class _StoryboardDriverState extends State<StoryboardDriver> {
  // Cache for image aspect ratios (Path -> Ratio)
  final Map<String, double> _aspectRatios = {};

  @override
  void initState() {
    super.initState();
    _preloadImageMetadata();
  }

  Future<void> _preloadImageMetadata() async {
    final List<dynamic> scenes = widget.storyboard['scenes'] ?? [];
    for (var scene in scenes) {
      if (scene['type'] == 'image_display') {
        final String path = scene['assetPath'] ?? '';
        if (path.isNotEmpty && File(path).existsSync()) {
          try {
            final bytes = await File(path).readAsBytes();
            final codec = await ui.instantiateImageCodec(bytes);
            final frameInfo = await codec.getNextFrame();
            final image = frameInfo.image;
            if (mounted) {
              setState(() {
                _aspectRatios[path] = image.width / image.height;
              });
            }
            image.dispose();
            codec.dispose();
          } catch (e) {
            print("Error loading metadata for $path: $e");
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final List<dynamic> scenes = widget.storyboard['scenes'] ?? [];
        final int totalDuration = widget.storyboard['durationSeconds'] ?? 30;
        final double currentTime = widget.controller.value * totalDuration;
        
        // 1. Find Active Scene
        dynamic activeScene;
        double sceneStartTime = 0.0;
        
        for (var scene in scenes) {
          final double duration = (scene['duration'] as num).toDouble();
          if (currentTime >= sceneStartTime && currentTime < sceneStartTime + duration) {
            activeScene = scene;
            break;
          }
          sceneStartTime += duration;
        }

        // Handle end of video (keep last frame)
        if (activeScene == null && scenes.isNotEmpty) {
           activeScene = scenes.last;
           sceneStartTime = totalDuration - (activeScene['duration'] as num).toDouble();
        }

        if (activeScene == null) return const SizedBox();

        // 2. Calculate Scene Progress (0.0 -> 1.0)
        final double sceneDuration = (activeScene['duration'] as num?)?.toDouble() ?? 5.0;
        // Avoid division by zero
        final double sceneProgress = sceneDuration > 0 
           ? ((currentTime - sceneStartTime) / sceneDuration).clamp(0.0, 1.0)
           : 1.0;

        // 3. Render Content based on Type
        Widget content;
        if (activeScene['type'] == 'title' || activeScene['type'] == 'text_overlay') {
          content = _buildTitleScene(activeScene, sceneProgress);
        } else if (activeScene['type'] == 'widget') {
          content = _buildWidgetScene(activeScene, sceneProgress);
        } else if (activeScene['type'] == 'image_display') {
          content = _buildImageScene(activeScene, sceneProgress);
        } else {
          content = const SizedBox();
        }

        // Logic to force Fixed Resolution Rendering (Canvas Mode)
        final double targetW = (widget.storyboard['width'] ?? 1920).toDouble();
        final double targetH = (widget.storyboard['height'] ?? 1080).toDouble();

        // BRANDING: Extract Colors
        final palette = widget.storyboard['brandPalette'] ?? {};
        final String bgHex = palette['background'] ?? '#0F172A';
        final Color bgColor = _parseColor(bgHex);
        final Color primaryColor = Colors.indigoAccent; // Default accent

        // Wrap in Dynamic Theme & SCALER
        return FittedBox(
          fit: BoxFit.contain,
          child: Container(
             width: targetW,
             height: targetH,
             clipBehavior: Clip.hardEdge,
             decoration: BoxDecoration(color: bgColor),
             child: Theme(
              data: ThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: bgColor,
                primaryColor: primaryColor,
                fontFamily: 'serif',
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: primaryColor,
                  brightness: Brightness.dark,
                  background: bgColor,
                ),
              ),
              child: content,
            ),
          ),
        );
      },
    );
  }
  
  Color _parseColor(String hex) {
      if (hex.isEmpty) return const Color(0xFF0F172A);
      try {
          return Color(int.parse(hex.replaceAll('#', '0xFF')));
      } catch (_) {
          return const Color(0xFF0F172A);
      }
  }

  Widget _buildAmbientBackground() {
    // Extract dynamic background color
    final palette = widget.storyboard['brandPalette'] ?? {};
    final String bgHex = palette['background'] ?? '#0F172A';
    final Color bgColor = _parseColor(bgHex);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Base Project Texture (Try to find an image in storyboard)
        _buildDynamicSplashImage(),
        // 2. Heavy Blur for Abstraction
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.transparent),
        ),
        // 3. Vignette (Dynamic)
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                bgColor.withOpacity(0.6), // Center
                Colors.black.withOpacity(0.95), // Edges
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleScene(Map<String, dynamic> scene, double progress) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildAmbientBackground(), // Unified Background
        
        // Typography
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 120.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: 1.0,
                  child: Text(
                    (scene['text'] ?? '').toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 100,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'serif',
                      letterSpacing: 4.0,
                      height: 1.2,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))]
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                Container(width: 120, height: 4, color: Colors.white30),
                const SizedBox(height: 60),
                Opacity(
                  opacity: (progress - 0.2).clamp(0.0, 1.0),
                  child: Text(
                    (scene['subtext'] ?? '').toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontFamily: 'serif',
                      letterSpacing: 2.0,
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
    // Generic reconstruction placeholder (if we had one)
    // Generic reconstruction placeholder (if we had one)
    Widget child = Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
            // Mock App Bar
            Container(
                height: 48,
                decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
            ),
            // Mock Content
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Container(width: 120, height: 24, color: Colors.white12),
                            const SizedBox(height: 16),
                            Container(width: double.infinity, height: 120, color: Colors.white10),
                            const SizedBox(height: 16),
                            Container(width: 200, height: 16, color: Colors.white12),
                            const SizedBox(height: 8),
                            Container(width: 160, height: 16, color: Colors.white12),
                        ],
                    ),
                ),
            ),
        ],
      ),
    );

    // 2. Apply Camera
    final camera = scene['camera'];
    Widget transformedChild = child;
    if (camera != null) {
      final start = camera['start'];
      final end = camera['end'];
      final double t = Curves.easeInOutCubic.transform(progress);
      
      final double startZoom = (start['zoom'] as num?)?.toDouble() ?? 1.0;
      final double endZoom = (end['zoom'] as num?)?.toDouble() ?? 1.0;
      final double startDx = (start['dx'] as num?)?.toDouble() ?? 0.0;
      final double endDx = (end['dx'] as num?)?.toDouble() ?? 0.0;
      final double startDy = (start['dy'] as num?)?.toDouble() ?? 0.0;
      final double endDy = (end['dy'] as num?)?.toDouble() ?? 0.0;

      final double zoom = _lerp(startZoom, endZoom, t);
      final double dx = _lerp(startDx, endDx, t);
      final double dy = _lerp(startDy, endDy, t);

      transformedChild = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(zoom)..translate(dx * 1920, dy * 1080), 
        child: child,
      );
    }

    return Stack(
      children: [
        _buildAmbientBackground(), // Unified Background
        transformedChild,
        if (scene['overlayText'] != null || scene['text'] != null)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Opacity(
               opacity: (progress > 0.1 && progress < 0.9) ? 1.0 : 0.0,
               child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8), // Reduced radius for "strict" look? Or keep it round? Keep it clean.
                    border: Border.symmetric(horizontal: BorderSide(color: Colors.white38, width: 1)),
                  ),
                  child: Text(
                    (scene['overlayText'] ?? scene['text'] ?? '').toUpperCase(),
                    style: const TextStyle(
                       color: Colors.white, fontSize: 32, fontWeight: FontWeight.w500,
                       letterSpacing: 2.0, fontFamily: 'serif',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }



  // ... (inside class)

  Widget _buildImageScene(Map<String, dynamic> scene, double progress) {
    final String path = scene['assetPath'] ?? '';
    final bool isScreenshot = path.toLowerCase().contains('screenshot');
    Widget child;
    
    // Determine valid image provider
    ImageProvider? imageProvider;
    if (path.isNotEmpty) {
      if (File(path).existsSync()) {
        imageProvider = FileImage(File(path));
      } else {
        imageProvider = AssetImage(path);
      }
    }

    if (imageProvider == null) {
       child = Container(
           color: Colors.black, 
           child: const Center(child: Text("NO IMAGE ASSET", style: TextStyle(color: Colors.white24, fontSize: 10)))
       );
    } else if (isScreenshot) {
      // ADAPTIVE FRAMING LOGIC
      // 1. Check Metadata (Platform)
      final String platform = widget.storyboard['platform'] ?? 'mobile';
      
      // 2. Check Physical Aspect Ratio (Preloaded)
      double? ratio = _aspectRatios[path];
      bool isLandscape = false;
      
      if (ratio != null) {
        // Trust the image
        isLandscape = ratio > 1.2; // Tolerance for square-ish apps
      } else {
        // Fallback to platform hint
        isLandscape = (platform == 'web' || platform == 'desktop');
      }

      if (isLandscape) {
        if (platform == 'mobile') {
           // Mobile + Landscape Image = Landscape Phone
           child = _buildPhoneFrame(imageProvider, isLandscape: true);
        } else {
           // Web/Desktop + Landscape Image = Laptop
           child = _buildLaptopFrame(imageProvider);
        }
      } else {
        // Portrait Image = Portrait Phone (regardless of platform usually)
        child = _buildPhoneFrame(imageProvider, isLandscape: false);
      }
    } else {
      child = Image(
        image: imageProvider, fit: BoxFit.cover, width: 1920, height: 1080,
        errorBuilder: (_,__,___) => Container(color: Colors.black, child: const Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 64))),
      );
    }
    // ... (rest of method same)
    
    final camera = scene['camera'];
    if (camera != null) {
      final start = camera['start'];
      final end = camera['end'];
      final double t = Curves.easeInOutSine.transform(progress);
      final double startZoom = (start['zoom'] as num?)?.toDouble() ?? 1.0;
      final double endZoom = (end['zoom'] as num?)?.toDouble() ?? 1.0;
      final double startDx = (start['dx'] as num?)?.toDouble() ?? 0.0;
      final double endDx = (end['dx'] as num?)?.toDouble() ?? 0.0;
      final double startDy = (start['dy'] as num?)?.toDouble() ?? 0.0;
      final double endDy = (end['dy'] as num?)?.toDouble() ?? 0.0;

      final double zoom = _lerp(startZoom, endZoom, t);
      final double dx = _lerp(startDx, endDx, t);
      final double dy = _lerp(startDy, endDy, t);

      child = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(zoom)..translate(dx * 1920, dy * 1080), 
        child: child,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (isScreenshot) _buildAmbientBackground(),

        child,
        
        if (scene['overlayText'] != null || scene['text'] != null)
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Opacity(
               opacity: (progress > 0.1 && progress < 0.9) ? 1.0 : 0.0,
               child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.symmetric(horizontal: BorderSide(color: Colors.white38, width: 1)),
                  ),
                  child: Text(
                    (scene['overlayText'] ?? scene['text'] ?? '').toUpperCase(),
                    style: const TextStyle(
                       color: Colors.white, fontSize: 32, fontWeight: FontWeight.w500,
                       letterSpacing: 2.0, fontFamily: 'serif',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ...

  double _lerp(double start, double end, double t) {
    return start + (end - start) * t;
  }

  Widget _buildPhoneFrame(ImageProvider imageProvider, {bool isLandscape = false}) {
    return Center(
      child: Container(
        // Swap dimensions for landscape
        width: isLandscape ? 1000 : 500,
        height: isLandscape ? 500 : double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(50),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 60, spreadRadius: 10, offset: Offset(0, 20)),
            BoxShadow(color: Colors.white10, blurRadius: 4, spreadRadius: 0, offset: Offset(0, 0)) 
          ],
          border: Border.all(color: const Color(0xFF333333), width: 12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(38),
          child: Image(image: imageProvider, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Center(child: Icon(Icons.broken_image, color: Colors.white24))),
        ),
      ),
    );
  }

  Widget _buildLaptopFrame(ImageProvider imageProvider) {
    return Center(
      child: Container(
        width: 1400,
        height: 900,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 80, spreadRadius: 20, offset: Offset(0, 40)),
          ],
        ),
        child: Column(
          children: [
            // Lid / Screen
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border.all(color: const Color(0xFF444444), width: 2),
                ),
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image(image: imageProvider, fit: BoxFit.cover, alignment: Alignment.topCenter),
                ),
              ),
            ),
            // Hinge / Base
            Container(
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFCCCCCC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                gradient: LinearGradient(
                  colors: [Color(0xFF888888), Color(0xFFEEEEEE), Color(0xFF888888)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter
                )
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicSplashImage() {
    final List<dynamic> scenes = widget.storyboard['scenes'] ?? [];
    String? path;
    for (var scene in scenes) {
      if (scene['type'] == 'image_display' && scene['assetPath'] != null) {
        path = scene['assetPath'];
        break;
      }
    }

    if (path != null) {
       if (File(path).existsSync()) {
          return Image.file(File(path), fit: BoxFit.cover);
       }
       return Image.asset(path, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: const Color(0xFF1E293B)));
    }
    return Container(color: const Color(0xFF1E293B));
  }
}

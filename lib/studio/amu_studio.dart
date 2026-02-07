import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'package:amu/director/storyboard_driver.dart';
// Removed Mock Import

import 'package:amu/director/storyboard_generator.dart';
import 'package:amu/studio/timeline_logic.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:amu/logic/project_storage.dart';
import 'package:amu/engine/video_exporter.dart';
import 'package:amu/logic/localization.dart';
import 'package:amu/ui/preview/interactive_app.dart';
import 'package:amu/ui/wizard/project_wizard.dart';

void main() {
  runApp(const AmuStudioApp());
}

class AmuStudioApp extends StatelessWidget {
  const AmuStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Amu Studio',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        primaryColor: const Color(0xFF6366F1), // Indigo 500
        useMaterial3: true,
      ),
      home: const AmuStudio(),
    );
  }
}

class AmuStudio extends StatefulWidget {
  final Map<String, dynamic>? initialStoryboard;
  const AmuStudio({super.key, this.initialStoryboard});

  @override
  State<AmuStudio> createState() => _AmuStudioState();
}

class _AmuStudioState extends State<AmuStudio> with TickerProviderStateMixin {
  // Device Config
  DeviceType _deviceType = DeviceType.mobile;
  Orientation _orientation = Orientation.portrait;

  // Studio State
  bool _showInteractivePanel = true; 
  int _activeTabIndex = 0; // 0: Compose, 1: Analyze
  int _selectedToolIndex = 1; // 0: Folder, 1: Layers, etc.
  
  // Project State
  bool _hasProject = false; 
  Map<String, dynamic>? _storyboard;
  bool _isLoading = false;

  // Timeline State
  List<TimelineTrack> _tracks = [];
  DateTime? _recordingStartTime;
  String? _selectedClipId;

  // Viewport State
  double _aspectRatio = 16 / 9;
  bool _isLandscape = true;
  
  // Recording State
  bool _isRecording = false;

  // Playback State
  late AnimationController _controller;
  bool _isPlaying = true;
  double _volume = 0.5; // Default volume
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Frame Capture State
  final GlobalKey _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       duration: const Duration(seconds: 33), // Default
       vsync: this,
    );
    _controller.addStatusListener((status) {
       if (status == AnimationStatus.completed) {
         setState(() => _isPlaying = false);
         _audioPlayer.pause();
       }
    });
    
    // Setup Audio
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _audioPlayer.setVolume(_volume); // Apply initial volume
    
    _loadInitialProject(); 
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        if (_controller.isCompleted) _controller.reset();
        _controller.forward();
        _audioPlayer.play(AssetSource('audio/ambient_piano.mp3'));
      } else {
        _controller.stop();
        _audioPlayer.pause();
      }
    });
  }



  Future<void> _openWizard() async {
      final result = await Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => const ProjectWizard())
      );

      if (result != null && result is Map<String, dynamic>) {
          _initializeProject(result);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✨ New Project DNA Loaded!"), backgroundColor: Colors.amber, duration: Duration(seconds: 2))
          );
      }
  }

  Future<void> _saveProject() async {
    if (_storyboard == null) return;
    
    // Show export options dialog
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ExportDialog(
        storyboard: _storyboard!,
        previewKey: _previewKey,
        controller: _controller,
        volume: _volume, // Pass current volume setting
      ),
    );
    
    if (result == 'success' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('studio.save_success')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'フォルダを開く',
            textColor: Colors.white,
            onPressed: () => VideoExporter.openOutputFolder(_getProjectName()),
          ),
        ),
      );
    }
  }
  
  String _getProjectName() {
    if (_storyboard == null) return 'untitled';
    final title = _storyboard!['scenes']?[0]?['narration']?.toString() ?? 'untitled';
    // Take first 20 chars and sanitize
    return title.substring(0, title.length > 20 ? 20 : title.length).replaceAll(RegExp(r'[^\w\-]'), '_');
  }


  Future<void> _loadInitialProject() async {
    if (widget.initialStoryboard == null) {
      // In a real app, we might redirect to Wizard or show "No Project"
      setState(() {
        _isLoading = false;
        _hasProject = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    _initializeProject(widget.initialStoryboard!);
  }

  void _initializeProject(Map<String, dynamic> sb) {
    setState(() {
      _storyboard = sb;
      _hasProject = true;
      _isLoading = false;
      
      // Update Controller Duration
      final int duration = sb['durationSeconds'] ?? 33;
      _controller.duration = Duration(seconds: duration);
      if (_isPlaying) {
        _controller.forward();
        _audioPlayer.play(AssetSource('audio/ambient_piano.mp3'));
      }
      
      // Explode Scenes into Clips
      List<TimelineClip> videoClips = [];
      double currentStartTime = 0;
      final scenes = sb['scenes'] as List<dynamic>;
      
      for (var scene in scenes) {
        final double dur = (scene['duration'] as num).toDouble();
        final Color clipColor = _getSceneColor(scene['type']);
        
        videoClips.add(TimelineClip(
          id: scene['id'],
          label: scene['type'].toString().toUpperCase(),
          start: Duration(milliseconds: (currentStartTime * 1000).toInt()),
          duration: Duration(milliseconds: (dur * 1000).toInt()),
          color: clipColor,
          metadata: scene,
        ));
        
        currentStartTime += dur; // Stack them sequentially
      }

      // Initialize Tracks
      _tracks = [
        TimelineTrack(
          id: "t1", 
          label: "VIDEO 1", 
          type: TrackType.video, 
          baseColor: const Color(0xFF3B82F6),
          clips: videoClips,
        ),
        TimelineTrack(
          id: "t2", 
          label: "AUDIO 1", 
          type: TrackType.audio, 
          baseColor: const Color(0xFF10B981),
          clips: [
             TimelineClip(id: "c2", label: "ambient_piano.mp3", start: Duration.zero, duration: Duration(seconds: duration), color: const Color(0xFF10B981))
          ]
        ),
        TimelineTrack(
          id: "t3", 
          label: "REC 1", 
          type: TrackType.recording, 
          baseColor: const Color(0xFFEF4444),
          clips: []
        ),
      ];
    });
  }

  Color _getSceneColor(String type) {
    switch (type) {
      case 'title': return Colors.purpleAccent;
      case 'widget': return Colors.blueAccent;
      case 'text_overlay': return Colors.orangeAccent;
      default: return Colors.grey;
    }
  }

  void _onClipTap(String clipId) {
    setState(() {
       _selectedClipId = clipId;
       _selectedToolIndex = 2; // Switch to Properties/Text Tool
       _showInteractivePanel = true;
       _activeTabIndex = 0; // Ensure Compose Tab
    });
  }

  void _onClipDragUpdate(TimelineClip clip, DragUpdateDetails details) {
    // 1 sec = 20px
    final double deltaSeconds = details.delta.dx / 20.0;
    final int deltaMs = (deltaSeconds * 1000).toInt();
    
    setState(() {
      final newStart = clip.start + Duration(milliseconds: deltaMs);
      if (newStart.inMilliseconds >= 0) { // Limit to 0
         clip.start = newStart;
      }
    });
  }

  void _toggleAspectRatio() {
    setState(() {
      _isLandscape = !_isLandscape;
      _aspectRatio = _isLandscape ? 16 / 9 : 9 / 16;
    });
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
    
    if (_isRecording) {
      _recordingStartTime = DateTime.now();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Recording Interactive UI..."), backgroundColor: Colors.redAccent, duration: Duration(seconds: 1)),
      );
    } else {
      // Create Clip
      if (_recordingStartTime != null) {
        final duration = DateTime.now().difference(_recordingStartTime!);
        final startPos = _controller.value * _controller.duration!.inSeconds.toDouble();
        
        final newClip = TimelineClip(
          id: "rec_${DateTime.now().millisecondsSinceEpoch}", 
          label: "Clip ${DateTime.now().second}", 
          start: Duration(seconds: startPos.toInt()), 
          duration: duration, 
          color: const Color(0xFFEF4444)
        );
        
        // Add to REC track
        final recTrackIndex = _tracks.indexWhere((t) => t.type == TrackType.recording);
        if (recTrackIndex != -1) {
            final track = _tracks[recTrackIndex];
            _tracks[recTrackIndex] = TimelineTrack(
              id: track.id, 
              label: track.label, 
              type: track.type, 
              baseColor: track.baseColor,
              clips: [...track.clips, newClip]
            );
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Clip Saved to Timeline!"), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Extract Brand Palette
    Color bgColor = const Color(0xFF0F172A); // Default Slate 900
    Color accentColor = const Color(0xFF6366F1); // Default Indigo 500
    
    if (_storyboard != null && _storyboard!['brandPalette'] != null) {
       final bgHex = _storyboard!['brandPalette']['background'];
       if (bgHex != null) {
         try {
           bgColor = Color(int.parse(bgHex.replaceAll('#', '0xFF')));
           // Simple complement or fixed accent for now, or extract if available
           // accentColor = Colors.white; 
         } catch (e) {
           // Ignore parse error
         }
       }
    }

    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgColor,
        primaryColor: accentColor,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: accentColor, brightness: Brightness.dark, background: bgColor),
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: Row(
          children: [
            // LEFT TOOLBAR
            _buildToolbar(bgColor, accentColor),
            
            // MAIN CONTENT
            Expanded(
              child: Column(
                children: [
                  // Header / Top Bar
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text("amu", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const Spacer(),
                        if (_hasProject)
                           Text(_getProjectName(), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                        if (!_hasProject)
                           Text(t('studio.no_project'), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
                        const Spacer(),
                        if (_isLoading)
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 16),
                        const Icon(Icons.help_outline, size: 16, color: Colors.white30),
                      ],
                    ),
                  ),
                  
                  // Main Workspace
                  Expanded(
                    child: Row(
                      children: [
                        // CENTER: PREVIEW & TIMELINE
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              // Preview Area
                              Expanded(
                                flex: 2,
                                child: Container(
                                  color: Colors.black, // Always black for video contrast? Or brand?
                                  // Let's use brand but darker
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Render Storyboard Driver
                                      if (_storyboard != null)
                                        Center(
                                          child: AspectRatio(
                                            aspectRatio: 16/9,
                                            child: RepaintBoundary(
                                              key: _previewKey,
                                              child: StoryboardDriver(
                                                storyboard: _storyboard!,
                                                controller: _controller,
                                              ),
                                            ),
                                          ),
                                        ),
                                        
                                      if (!_hasProject && !_isLoading)
                                        Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.movie_creation_outlined, size: 48, color: Colors.white.withOpacity(0.2)),
                                              const SizedBox(height: 16),
                                              Text(t('studio.waiting'), style: TextStyle(color: Colors.white.withOpacity(0.3))),
                                            ],
                                          ),
                                        ),
                                        
                                      // Transport Controls Overlay (if hovering?)
                                      Positioned(
                                        bottom: 16,
                                        left: 16,
                                        right: 16,
                                        child: _buildTransportControls(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Timeline Area
                              _buildTimeline(),
                            ],
                          ),
                        ),
                        
                        // RIGHT PANEL: INSPECTOR / ATTRIBUTE EDITOR
                        if (_showInteractivePanel)
                          Container(
                            width: 320,
                            decoration: BoxDecoration(
                              color: bgColor, // Match brand
                              border: Border(left: BorderSide(color: Colors.white.withOpacity(0.1))),
                            ),
                            child: Column(
                              children: [
                                 // Tab Bar
                                 SizedBox(
                                   height: 48,
                                   child: Row(
                                     children: [
                                       _buildTab("Compose", 0),
                                       _buildTab("Analyze", 1),
                                     ],
                                   ),
                                 ),
                                 // Content
                                 Expanded(
                                   child: _activeTabIndex == 0 ? _buildComposeView() : _buildAnalyzeView(),
                                 ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(Color bgColor, Color accentColor) {
    return Container(
      width: 56,
      color: bgColor, // Dynamic
      child: Column(
        children: [
          const SizedBox(height: 16),
          IconButton(
             icon: const Icon(Icons.auto_fix_high, color: Colors.amberAccent),
             tooltip: "Project Wizard",
             onPressed: _openWizard,
          ),
          const SizedBox(height: 16),
          Icon(Icons.space_dashboard_rounded, color: accentColor, size: 28),
          const SizedBox(height: 24),
          
          _buildSideIcon(Icons.folder_open, 0),
          _buildSideIcon(Icons.layers, 1),
          _buildSideIcon(Icons.text_fields, 2),
          _buildSideIcon(Icons.audiotrack, 3),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.output, color: Colors.greenAccent),
            tooltip: "Save & Export",
            onPressed: _saveProject,
          ),
          const SizedBox(height: 16),
          _buildSideIcon(Icons.settings, 4),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTransportControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            onPressed: _togglePlayback,
          ),
          const SizedBox(width: 8),
          Text(
            "${_formatDuration(_controller.value * _controller.duration!.inSeconds)} / ${_formatDuration(_controller.duration?.inSeconds.toDouble() ?? 0)}",
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.replay, color: Colors.white70, size: 20),
            onPressed: () {
               _controller.value = 0;
               if (_isPlaying) _audioPlayer.seek(Duration.zero);
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final int s = seconds.toInt();
    final int m = s ~/ 60;
    final int remS = s % 60;
    return "$m:${remS.toString().padLeft(2, '0')}";
  }

  Widget _buildSideIcon(IconData icon, int index) {
    bool isSelected = _selectedToolIndex == index;
    // Extract primary from theme context if needed, or use logic
    final primary = Theme.of(context).primaryColor;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedToolIndex = index;
          _showInteractivePanel = true; // Open panel when tool selected
        });
      },
      child: Container(
        width: 40, height: 40,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: isSelected ? BoxDecoration(
          color: primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ) : null,
        child: Icon(
          icon, 
          color: isSelected ? primary : Colors.white38,
          size: 20
        ),
      ),
    );
  }
  
  Widget _buildTab(String label, int index) {
    bool isActive = _activeTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTabIndex = index),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isActive ? Colors.blueAccent : Colors.transparent, width: 2)),
          ),
          child: Text(label, style: TextStyle(
            color: isActive ? Colors.white : Colors.white54, 
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal
          )),
        ),
      ),
    );
  }
  
  Widget _buildAnalyzeView() {
      // Dummy Dashboard for "Product DNA" Analysis
      return ListView(
          padding: const EdgeInsets.all(16),
          children: [
              const Text("PERFORMANCE PREDICTION", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildMetricCard("Predicted CTR", "4.2%", "+0.8%", Colors.green),
              _buildMetricCard("Retention Rate", "68%", "-2.1%", Colors.red),
              _buildMetricCard("Viral Score", "8.5/10", "High", Colors.amber),
              
              const SizedBox(height: 24),
              const Text("AUDIENCE INSIGHTS", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                  height: 120,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (i) => Expanded(
                          child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 20.0 + (i * 15) % 80,
                              color: Theme.of(context).primaryColor.withOpacity(0.5)
                          )
                      )),
                  ),
              ),
              const SizedBox(height: 8),
              const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text("18-24", style: TextStyle(color: Colors.white30, fontSize: 10)), Text("45+", style: TextStyle(color: Colors.white30, fontSize: 10))],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                  onPressed: (){}, 
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text("Sync Live Data"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                  ),
              )
          ],
      );
  }

  Widget _buildMetricCard(String label, String value, String delta, Color deltaColor) {
      return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.05))
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                  ),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: deltaColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text(delta, style: TextStyle(color: deltaColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
              ],
          ),
      );
  }


  Widget _buildComposeView() {
    return Container(
       decoration: const BoxDecoration(
         color: Color(0xFF0F172A),
         border: Border(top: BorderSide(color: Colors.white10)),
       ),
       child: _buildCurrentToolPanel(),
    );
  }

  Widget _buildCurrentToolPanel() {
    switch (_selectedToolIndex) {
      case 0: // Folder
        return _buildFileBrowser();
      case 1: // Layers (Recording)
        return _buildLayersPanel();
      case 2: // Text
        return _buildTextPanel();
      case 3: // Audio
        return _buildAudioPanel();
      case 4: // Settings
        return const Center(child: Text("Settings Placeholder", style: TextStyle(color: Colors.white24)));
      default:
        return const Center(child: Text("Select a tool", style: TextStyle(color: Colors.white24)));
    }
  }
  
  // --- Tool Panels ---
  
  Widget _buildFileBrowser() {
      return ListView(
          padding: const EdgeInsets.all(16),
          children: [
              const Text("PROJECTS", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildFileItem("My First Ad", true),
              _buildFileItem("Summer Campaign", false),
              _buildFileItem("Tech Launch", false),
              const SizedBox(height: 24),
              const Text("ASSETS", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildFileItem("logo_transparent.png", false),
              _buildFileItem("background_loop.mp4", false),
          ],
      );
  }
  
  Widget _buildFileItem(String name, bool isSelected) {
      return InkWell(
        onTap: () {
           // Demo interaction
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Selected $name"), duration: const Duration(milliseconds: 500)));
        },
        child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(4)
            ),
            child: Row(
                children: [
                    Icon(name.endsWith(".png") ? Icons.image : name.endsWith(".mp4") ? Icons.movie : Icons.folder, size: 16, color: Colors.white54),
                    const SizedBox(width: 8),
                    Text(name, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12)),
                ],
            ),
        ),
      );
  }
  
  Widget _buildAudioPanel() {
      return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  const Text("AUDIO MIXER", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Row(
                      children: [
                          const Icon(Icons.music_note, color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text("BGM: ambient_piano.mp3", style: const TextStyle(color: Colors.white70, fontSize: 12))),
                      ],
                  ),
                  Slider(
                    value: _volume, 
                    onChanged: (v) {
                       setState(() => _volume = v);
                       _audioPlayer.setVolume(v);
                    }, 
                    activeColor: Colors.greenAccent
                  ),
              ],
          )
      );
  }

  Widget _buildTextPanel() {
    if (_selectedClipId == null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               const Icon(Icons.text_fields, size: 48, color: Colors.white10),
               const SizedBox(height: 16),
               const Text("Select a clip to edit text", style: TextStyle(color: Colors.white24)),
            ],
          )
      );
    }
    
    // Find Clip
    final track = _tracks.firstWhere((t) => t.type == TrackType.video, orElse: () => _tracks[0]);
    final clip = track.clips.firstWhere((c) => c.id == _selectedClipId, orElse: () => track.clips[0]);
    
    // Determine editable fields based on metadata
    // Scenes usually use: title_main, title_sub OR hook_main, hook_sub OR problem_main
    // Determine editable fields based on real keys used in generator
    final meta = clip.metadata ?? {};
    final String mainKey = meta.containsKey('text') ? 'text' : (meta.containsKey('overlayText') ? 'overlayText' : 'title_main');
    final String subKey = meta.containsKey('subtext') ? 'subtext' : 'title_sub';
    
    return ListView(
        padding: const EdgeInsets.all(24),
        children: [
            Text("EDIT CLIP: ${clip.label}", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            if (meta.containsKey(mainKey) || meta.containsKey('overlayText'))
               _buildTextField("Main Text", meta[mainKey] ?? "", (val) => _updateClipText(clip, mainKey, val)),
            const SizedBox(height: 16),
            if (meta.containsKey(subKey))
                _buildTextField("Sub Text", meta[subKey] ?? "", (val) => _updateClipText(clip, subKey, val)),
                
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            const Text("PROPERTIES", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    const Text("Duration", style: TextStyle(color: Colors.white30, fontSize: 12)),
                    // Make Duration Editable
                    SizedBox(
                      width: 60,
                      child: TextFormField(
                        initialValue: clip.duration.inSeconds.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(4), border: OutlineInputBorder()),
                        onChanged: (val) {
                           final int? newDur = int.tryParse(val);
                           if (newDur != null && newDur > 0) {
                             // Update Clip Duration
                             setState(() {
                               clip.duration = Duration(seconds: newDur);
                               clip.metadata!['duration'] = newDur;
                               // Need to recalculate timeline positions (start times of subsequent clips)
                               // For now, this just updates the local clip model and the source metadata.
                               // A full re-layout would be needed for a robust timeline.
                             });
                           }
                        },
                      ),
                    ),
                    const Text("s", style: TextStyle(color: Colors.white30, fontSize: 12)),
                ],
            )
        ],
    );
  }
  
  Widget _buildTextField(String label, String value, Function(String) onChanged) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text(label, style: const TextStyle(color: Colors.blueAccent, fontSize: 11)),
              const SizedBox(height: 4),
              TextFormField(
                  initialValue: value,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black12,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: onChanged,
              )
          ],
      );
  }
  
  void _updateClipText(TimelineClip clip, String key, String value) {
      // 1. Update Metadata
      if (clip.metadata != null) {
          clip.metadata![key] = value;
      }
      
      // 2. Update Storyboard State (for Renderer) - Deep update
      // Find scene index
      if (_storyboard != null) {
           final scenes = _storyboard!['scenes'] as List<dynamic>;
           final index = scenes.indexWhere((s) => s['id'] == clip.id);
           if (index != -1) {
               scenes[index][key] = value;
               setState(() {
                   // Trigger rebuild
                   // StoryboardDriver receives the map reference, so simple setState is enough if map is mutated
               });
           }
      }
  }

  IconData _getToolIcon(int index) {
    switch(index) {
        case 0: return Icons.folder_open;
        case 2: return Icons.text_fields;
        case 3: return Icons.audiotrack;
        case 4: return Icons.settings;
        default: return Icons.build;
    }
  }
  

  
  Widget _buildLayersPanel() {
    return Column(
      children: [
         // TOP: Interactive Device Area (Primary Focus)
         Expanded(
            child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: DeviceFrame(
                    isRecording: _isRecording,
                    deviceType: _deviceType,
                    orientation: _orientation,
                    child: InteractiveApp(
                      dna: _storyboard ?? {},
                      isRecording: _isRecording,
                      deviceType: _deviceType,
                      orientation: _orientation,
                    ),
                  ),
                ),
            ),
         ),
         
         // BOTTOM: Recording Controls & Config
         Container(
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
           decoration: BoxDecoration(
             color: Colors.white.withOpacity(0.02),
             border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
           ),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
                 const Text("Interactive Studio", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                 const SizedBox(height: 12),
                 
                 // Device Toggles
                 Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     _buildToggle(Icons.phone_iphone, "Mobile", _deviceType == DeviceType.mobile, () => setState(() => _deviceType = DeviceType.mobile)),
                     const SizedBox(width: 8),
                     _buildToggle(Icons.laptop_mac, "Desktop", _deviceType == DeviceType.desktop, () => setState(() {
                        _deviceType = DeviceType.desktop;
                        _orientation = Orientation.landscape; // Desktop usually landscape
                     })),
                   ],
                 ),
                 const SizedBox(height: 8),
                 if (_deviceType == DeviceType.mobile)
                   Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       _buildToggle(Icons.crop_portrait, "Portrait", _orientation == Orientation.portrait, () => setState(() => _orientation = Orientation.portrait)),
                       const SizedBox(width: 8),
                       _buildToggle(Icons.crop_landscape, "Landscape", _orientation == Orientation.landscape, () => setState(() => _orientation = Orientation.landscape)),
                     ],
                   ),
                 
                 const SizedBox(height: 16),
                 
                 ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: _isRecording ? Colors.redAccent : Colors.blueAccent,
                     foregroundColor: Colors.white,
                     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                   ),
                   onPressed: _toggleRecording,
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record, size: 16),
                       const SizedBox(width: 8),
                       Text(_isRecording ? "STOP RECORDING" : "START RECORDING"),
                     ],
                   ),
                 ),
                 
                 if (!_isRecording) ...[
                     const SizedBox(height: 8),
                     TextButton(
                         onPressed: () {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Redirecting to GitHub...")));
                         },
                         child: const Text("GitHub (OAuth)", style: TextStyle(fontSize: 11, color: Colors.white30))
                     )
                 ]
             ],
           ),
         ),
      ],
    );
  }

  Widget _buildToggle(IconData icon, String label, bool isActive, VoidCallback onTap) {
      return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
                  border: Border.all(color: isActive ? Colors.blueAccent : Colors.white10),
                  borderRadius: BorderRadius.circular(8)
              ),
              child: Row(
                  children: [
                      Icon(icon, size: 16, color: isActive ? Colors.white : Colors.white54),
                      const SizedBox(width: 4),
                      Text(label, style: TextStyle(fontSize: 12, color: isActive ? Colors.white : Colors.white54))
                  ],
              )
          ),
      );
  }

  Widget _buildTimeline() {
    String format(int totalSeconds) {
       final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
       final s = (totalSeconds % 60).toString().padLeft(2, '0');
       return "00:$m:$s";
    }
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        height: 200, 
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Column(
          children: [
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.black12,
              child: Row(
                 children: [
                   IconButton(
                     icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 16, color: Colors.white70),
                     onPressed: _togglePlayback,
                     tooltip: _isPlaying ? "Pause" : "Play",
                   ),
                   const SizedBox(width: 8),
                   Text(
                     format((_controller.value * (_controller.duration?.inSeconds ?? 0)).toInt()), 
                     style: const TextStyle(fontFamily: 'monospace', color: Colors.white70, fontSize: 12)
                   ),
                   const Spacer(),
                   const Icon(Icons.zoom_in, size: 16, color: Colors.white30),
                 ],
              ),
            ),
            Container(
              height: 24,
              width: double.infinity,
              color: Colors.white.withOpacity(0.02),
              padding: const EdgeInsets.only(left: 88), 
              alignment: Alignment.centerLeft,
              child: ClipRect(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    children: List.generate(20, (i) => 
                      Container(
                        width: 100, // Roughly 5 seconds
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.white.withOpacity(0.1)))),
                        padding: const EdgeInsets.only(left: 2),
                        child: Text("00:${(i*5).toString().padLeft(2, '0')}", style: const TextStyle(color: Colors.white24, fontSize: 10))
                      )
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _tracks.length,
                itemBuilder: (context, index) => _buildTrack(_tracks[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrack(TimelineTrack track) {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Track Header
          Container(
            width: 80,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 12),
            color: Colors.white.withOpacity(0.03),
            child: Row(
              children: [
                Icon(
                  track.type == TrackType.video ? Icons.videocam : 
                  track.type == TrackType.audio ? Icons.audiotrack : Icons.fiber_manual_record, 
                  size: 12, 
                  color: Colors.white30
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(track.label, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          // Track Content
          Expanded(
            child: Container(
              color: Colors.white.withOpacity(0.01),
              child: SingleChildScrollView( // Allow scrolling (but hidden) to match header space
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: 2000, // Explicit width for timeline canvas (20 * 100)
                  child: Stack(
                    children: [
                      // Grid Lines (Fixed width now)
                      Row(
                         children: List.generate(20, (index) => Container(
                           width: 100, 
                           decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withOpacity(0.02))))
                         )),
                      ),
                      // Clips
                      ...track.clips.map((clip) {
                        final double left = clip.start.inSeconds * 20.0;
                        final double width = clip.duration.inSeconds * 20.0;
                        final bool isSelected = _selectedClipId == clip.id;
                        
                        return Positioned(
                          left: left + 20, 
                          width: width < 20 ? 20 : width, 
                          top: 4,
                          bottom: 4,
                          child: GestureDetector(
                            onTap: () => _onClipTap(clip.id),
                            onHorizontalDragUpdate: (details) => _onClipDragUpdate(clip, details),
                            child: Tooltip(
                              message: "${clip.label} (${clip.duration.inSeconds}s)\n${clip.id}",
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  color: clip.color.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isSelected ? Colors.yellowAccent : clip.color.withOpacity(0.8),
                                    width: isSelected ? 2 : 1
                                  ),
                                  boxShadow: isSelected ? [
                                    const BoxShadow(color: Colors.yellowAccent, blurRadius: 4)
                                  ] : null,
                                ),
                                child: Text(
                                  clip.label, 
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      
                      // Playhead
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final pos = (_controller.value * _controller.duration!.inSeconds) * 20.0;
                          return Positioned(
                            left: 20 + pos, 
                            top: 0,
                            bottom: 0,
                            width: 2,
                            child: Container(color: Colors.redAccent, child: Align(alignment: Alignment.topCenter, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)))),
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum DeviceType { mobile, desktop }

class DeviceFrame extends StatelessWidget {
  final Widget child;
  final bool isRecording;
  final DeviceType deviceType;
  final Orientation orientation;

  const DeviceFrame({
    super.key,
    required this.child,
    this.isRecording = false,
    this.deviceType = DeviceType.mobile,
    this.orientation = Orientation.portrait,
  });

  @override
  Widget build(BuildContext context) {
    if (deviceType == DeviceType.desktop) {
        return _buildLaptopFrame();
    }
    return _buildPhoneFrame();
  }

  Widget _buildPhoneFrame() {
    // iPhone 14 Pro Ratio (19.5:9) approx
    final double aspectRatio = orientation == Orientation.portrait ? 9.0 / 19.5 : 19.5 / 9.0;
    
    return Container(
       width: orientation == Orientation.portrait ? 280 : 280 * (19.5/9.0), 
       height: orientation == Orientation.portrait ? 280 / aspectRatio : 280, 
       decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(44),
          border: Border.all(
             color: isRecording ? Colors.redAccent : const Color(0xFF2B2B2B),
             width: isRecording ? 4 : 8,
          ),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20)),
             if (isRecording)
               BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)
          ]
       ),
       child: Stack(
         alignment: Alignment.center,
         children: [
           // Screen Content
           Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: Container(
                    color: Colors.white, // App bg
                    child: child,
                  ),
                ),
              ),
           ),
           
           // Dynamic Island / Notch
           Positioned(
             top: orientation == Orientation.portrait ? 20 : null,
             left: orientation == Orientation.landscape ? 20 : null,
             child: Container(
               width: orientation == Orientation.portrait ? 96 : 28,
               height: orientation == Orientation.portrait ? 28 : 96,
               decoration: BoxDecoration(
                 color: Colors.black,
                 borderRadius: BorderRadius.circular(14),
               ),
             ),
           ),
           
           // Home Indicator
           Positioned(
             bottom: 12,
             child: Container(
               width: 100,
               height: 4,
               decoration: BoxDecoration(
                 color: Colors.white.withOpacity(0.4),
                 borderRadius: BorderRadius.circular(4),
               ),
             ),
           ),
         ],
       ),
    );
  }

  Widget _buildLaptopFrame() {
      // 16:10 Laptop Ratio
      const double aspectRatio = 16.0 / 10.0;
      const double width = 600;
      const double height = width / aspectRatio;
      
      return Column(
          children: [
              // Screen (Lid)
              Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16), bottom: Radius.circular(4)),
                      border: Border.all(color: const Color(0xFF2B2B2B), width: 8),
                      boxShadow: [
                         BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20)),
                         if (isRecording)
                           BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)
                      ]
                  ),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                          color: Colors.white,
                          child: child,
                      ),
                  ),
              ),
              // Hinge / Base
              Container(
                  width: width + 40,
                  height: 16,
                  decoration: const BoxDecoration(
                      color: Color(0xFF3B3B3B), // Dark Grey Aluminum
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                      boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))]
                  ),
                  child: Center(
                      child: Container(
                          width: 80, height: 4, 
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2))
                      ),
                  ),
              )
          ],
      );
  }
}

/// Export Dialog Widget
/// Handles storyboard save, frame rendering, and video export
class _ExportDialog extends StatefulWidget {
  final Map<String, dynamic> storyboard;
  final GlobalKey previewKey;
  final AnimationController controller;
  final double volume;
  
  const _ExportDialog({
    required this.storyboard,
    required this.previewKey,
    required this.controller,
    required this.volume,
  });
  
  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  String _status = 'ready'; // ready, saving, rendering, exporting, done, error
  double _progress = 0.0;
  String _errorMessage = '';
  String _projectName = 'my_project';
  int _currentFrame = 0;
  int _totalFrames = 0;
  
  @override
  void initState() {
    super.initState();
    // Generate project name from storyboard
    final title = widget.storyboard['scenes']?[0]?['narration']?.toString() ?? 'my_project';
    _projectName = title.substring(0, title.length > 20 ? 20 : title.length)
        .replaceAll(RegExp(r'[^\w\-]'), '_')
        .replaceAll('__', '_');
  }
  
  Future<void> _startExport() async {
    setState(() {
      _status = 'saving';
      _progress = 0.0;
    });
    
    try {
      // Step 1: Save Storyboard JSON
      await ProjectStorage.saveStoryboard(_projectName, widget.storyboard);
      setState(() {
        _progress = 0.1;
        _status = 'rendering';
      });
      
      // Step 2: Capture Frames from RepaintBoundary
      final durationSeconds = widget.storyboard['durationSeconds'] ?? 10;
      const fps = 30;
      _totalFrames = durationSeconds * fps;
      
      final framesPath = ProjectStorage.getFramesPath(_projectName);
      await Directory(framesPath).create(recursive: true);
      
      // Clear existing frames
      await ProjectStorage.clearFrames(_projectName);
      
      // Stop the animation controller for manual stepping
      final wasPlaying = widget.controller.isAnimating;
      widget.controller.stop();
      
      // Capture each frame
      for (int i = 0; i < _totalFrames; i++) {
        _currentFrame = i;
        
        // Set animation to specific frame position
        final frameProgress = i / _totalFrames;
        widget.controller.value = frameProgress;
        
        // Wait for frame to render
        await Future.delayed(const Duration(milliseconds: 16));
        
        // Capture frame from RepaintBoundary
        await _captureFrame(i, framesPath);
        
        setState(() {
          _progress = 0.1 + (0.6 * (i / _totalFrames));
        });
      }
      
      // Restore animation state
      if (wasPlaying) {
        widget.controller.repeat();
      }
      
      setState(() {
        _progress = 0.7;
        _status = 'exporting';
      });
      
      // Step 3: Export Video with FFmpeg
      final hasFFmpeg = await VideoExporter.isFFmpegAvailable();
      if (!hasFFmpeg) {
        setState(() {
          _status = 'done';
          _progress = 1.0;
          _errorMessage = 'FFmpegがインストールされていないため、動画書き出しをスキップしました。\nフレームは $framesPath に保存されました。\n\n動画書き出しには: brew install ffmpeg';
        });
        return;
      }
      
      await VideoExporter.exportVideo(
        projectName: _projectName,
        audioPath: widget.storyboard['bgm'], // Extract BGM from storyboard
        volume: widget.volume, // Pass volume to exporter
        fps: fps,
        onProgress: (p) {
          setState(() {
            _progress = 0.7 + (0.3 * p);
          });
        },
      );
      
      setState(() {
        _status = 'done';
        _progress = 1.0;
      });
      
    } catch (e) {
      setState(() {
        _status = 'error';
        _errorMessage = e.toString();
      });
    }
  }
  
  Future<void> _captureFrame(int frameNumber, String framesPath) async {
    try {
      final boundary = widget.previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Preview widget not found');
      }
      
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode frame');
      }
      
      final frameFile = File('$framesPath/frame_${frameNumber.toString().padLeft(4, '0')}.png');
      await frameFile.writeAsBytes(byteData.buffer.asUint8List());
    } catch (e) {
      print('Frame capture error: $e');
      rethrow;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.movie_creation, color: Colors.indigoAccent, size: 28),
                const SizedBox(width: 12),
                const Text('プロジェクトをエクスポート', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_status == 'ready')
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Content based on status
            if (_status == 'ready') ...[
              // Project Name Input
              const Text('プロジェクト名', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: _projectName),
                onChanged: (v) => _projectName = v,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              
              // Export Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('フレームレート', '30 FPS'),
                    _infoRow('解像度', '1920 x 1080'),
                    _infoRow('出力形式', 'MP4 (H.264)'),
                    _infoRow('保存先', 'amu_output/projects/$_projectName/'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Export Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: const Text('エクスポート開始', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: _startExport,
                ),
              ),
            ] else if (_status == 'done') ...[
              // Success
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage.isNotEmpty ? 'エクスポート完了（警告あり）' : 'エクスポート完了！',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_errorMessage, style: const TextStyle(color: Colors.orange, fontSize: 12), textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('フォルダを開く'),
                          onPressed: () => VideoExporter.openOutputFolder(_projectName),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                          onPressed: () => Navigator.pop(context, 'success'),
                          child: const Text('閉じる', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (_status == 'error') ...[
              // Error
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                    const SizedBox(height: 16),
                    const Text('エクスポート失敗', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('閉じる'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Progress
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: Colors.indigoAccent),
                    const SizedBox(height: 24),
                    Text(
                      _status == 'saving' ? 'ストーリーボードを保存中...' :
                      _status == 'rendering' ? 'フレームをレンダリング中...' :
                      '動画を生成中...',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation(Colors.indigoAccent),
                    ),
                    const SizedBox(height: 8),
                    Text('${(_progress * 100).toInt()}%', style: const TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

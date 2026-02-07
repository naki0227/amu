import 'dart:io';
import 'package:amu/logic/project_storage.dart';

/// Video Exporter Service
/// Uses FFmpeg to combine rendered frames into a video
class VideoExporter {
  /// Check if FFmpeg is installed
  static Future<bool> isFFmpegAvailable() async {
    try {
      final result = await Process.run('which', ['ffmpeg']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
  
  /// Export frames to video using FFmpeg
  /// 
  /// [projectName] - Name of the project
  /// [fps] - Frames per second (default: 30)
  /// [onProgress] - Progress callback (0.0 - 1.0)
  /// 
  /// Returns the path to the output video file
  static Future<String> exportVideo({
    required String projectName,
    String? audioPath,
    double volume = 1.0,
    int fps = 30,
    Function(double)? onProgress,
  }) async {
    // Check FFmpeg availability
    if (!await isFFmpegAvailable()) {
      throw Exception('FFmpegがインストールされていません。\n実行: brew install ffmpeg');
    }
    
    final framesPath = ProjectStorage.getFramesPath(projectName);
    final outputPath = ProjectStorage.getVideoPath(projectName);
    
    // Ensure output directory exists
    await Directory(ProjectStorage.getOutputPath(projectName)).create(recursive: true);
    
    // Count frames for progress
    final framesDir = Directory(framesPath);
    if (!await framesDir.exists()) {
      throw Exception('フレームが見つかりません。先にレンダリングを実行してください。');
    }
    
    final frameCount = await framesDir.list().where((f) => f.path.endsWith('.png')).length;
    if (frameCount == 0) {
      throw Exception('フレームが見つかりません。先にレンダリングを実行してください。');
    }
    
    onProgress?.call(0.1);
    
    // Build FFmpeg arguments
    final List<String> args = [
      '-y',
      '-framerate', '$fps',
      '-i', '$framesPath/frame_%04d.png',
    ];

    // Add audio if provided
    if (audioPath != null && audioPath.isNotEmpty) {
      args.addAll(['-i', audioPath]);
    }

    args.addAll([
      '-vf', 'pad=ceil(iw/2)*2:ceil(ih/2)*2', // Ensure even dimensions for H.264
      '-c:v', 'libx264',
      '-pix_fmt', 'yuv420p',
      '-crf', '18', // Quality
    ]);

    // Audio codec and volume if audio input exists
    if (audioPath != null && audioPath.isNotEmpty) {
      args.addAll(['-c:a', 'aac']);
      if (volume != 1.0) {
        args.addAll(['-af', 'volume=$volume']);
      }
      args.add('-shortest');
    }

    args.add(outputPath);

    final result = await Process.run('ffmpeg', args);
    
    onProgress?.call(0.9);
    
    if (result.exitCode != 0) {
      print('FFmpeg stderr: ${result.stderr}');
      throw Exception('動画生成に失敗しました: ${result.stderr}');
    }
    
    onProgress?.call(1.0);
    
    return outputPath;
  }
  
  /// Open the output folder in Finder
  static Future<void> openOutputFolder(String projectName) async {
    final outputPath = ProjectStorage.getOutputPath(projectName);
    await Process.run('open', [outputPath]);
  }
  
  /// Open the video file
  static Future<void> openVideo(String projectName) async {
    final videoPath = ProjectStorage.getVideoPath(projectName);
    await Process.run('open', [videoPath]);
  }
}

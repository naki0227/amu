import 'package:flutter/material.dart';

enum TrackType { video, audio, recording }

class TimelineClip {
  final String id;
  final String label;
  Duration start; // Not final for editing
  Duration duration; // Not final for editing
  final Color color;
  final Map<String, dynamic>? metadata;

  TimelineClip({
    required this.id, 
    required this.label, 
    required this.start, 
    required this.duration,
    required this.color,
    this.metadata,
  });
  
  double get endSeconds => (start.inMilliseconds + duration.inMilliseconds) / 1000.0;
}

class TimelineTrack {
  final String id;
  final String label;
  final TrackType type;
  final List<TimelineClip> clips;
  final Color baseColor;

  TimelineTrack({
    required this.id, 
    required this.label, 
    required this.type, 
    this.clips = const [],
    required this.baseColor,
  });
}

import 'package:flutter/material.dart';
import 'package:amu/studio/amu_studio.dart'; // For DeviceType enum

class InteractiveApp extends StatefulWidget {
  final Map<String, dynamic> dna;
  final bool isRecording;
  final DeviceType deviceType;
  final Orientation orientation;

  const InteractiveApp({
    super.key,
    required this.dna,
    this.isRecording = false,
    this.deviceType = DeviceType.mobile,
    this.orientation = Orientation.portrait,
  });

  @override
  State<InteractiveApp> createState() => _InteractiveAppState();
}

class _InteractiveAppState extends State<InteractiveApp> {
  int _selectedIndex = 0;

  Color get _brandColor {
    final hex = widget.dna['brandPalette']?['background'];
    if (hex != null) {
      try {
        return Color(int.parse(hex.replaceAll('#', '0xFF')));
      } catch (_) {}
    }
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    // Extract DNA
    final widgetTree = widget.dna['widget_tree'];

    // Fallback if no tree (or legacy generic DNA)
    if (widgetTree == null) {
       return _buildLegacyBody();
    }
    
    // SDUI Rendering
    Widget body = _buildSDUIWidget(widgetTree['body'] ?? {});
    
    // Wrap for NavigationRail (Desktop)
    final bool useNavRail = widget.deviceType == DeviceType.desktop || widget.orientation == Orientation.landscape;

    if (useNavRail) {
        return Scaffold(
             body: Row(
                 children: [
                     NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                        labelType: NavigationRailLabelType.selected,
                        destinations: const [
                            NavigationRailDestination(icon: Icon(Icons.home), label: Text("Home")),
                            NavigationRailDestination(icon: Icon(Icons.explore), label: Text("Explore")),
                            NavigationRailDestination(icon: Icon(Icons.person), label: Text("Profile")),
                        ],
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(
                        child: Scaffold(
                            appBar: widgetTree['appBar'] != null ? AppBar(
                                title: Text(widgetTree['appBar']['title'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold)),
                                backgroundColor: _brandColor,
                                foregroundColor: Colors.white,
                            ) : null,
                            body: widget.isRecording ? _buildRecordingOverlay(body) : body,
                            floatingActionButton: _buildSDUIWidget(widgetTree['floatingActionButton'] ?? {}),
                        )
                    )
                 ]
             )
        );
    }
    
    return Scaffold(
        appBar: widgetTree['appBar'] != null ? AppBar(
            title: Text(widgetTree['appBar']['title'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: _brandColor,
            foregroundColor: Colors.white,
            centerTitle: true,
        ) : null,
        body: widget.isRecording ? _buildRecordingOverlay(body) : body,
        floatingActionButton: _buildSDUIWidget(widgetTree['floatingActionButton'] ?? {}),
        bottomNavigationBar: widgetTree['bottomNavigationBar'] != null ? BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            selectedItemColor: _brandColor,
            items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
                BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Explore"),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
            ] 
        ) : null,
    );
  }

  // --- SDUI Renderer ---

  Widget _buildSDUIWidget(Map<String, dynamic> data) {
      if (data.isEmpty) return const SizedBox.shrink();

      final String type = data['type'] ?? 'Container';
      
      switch (type) {
          case 'Column':
             return Column(
                 mainAxisAlignment: _parseMainAxis(data['mainAxisAlignment']),
                 crossAxisAlignment: _parseCrossAxis(data['crossAxisAlignment']),
                 children: _buildChildren(data['children']),
             );
          case 'Row':
             return Row(
                 mainAxisAlignment: _parseMainAxis(data['mainAxisAlignment']),
                 crossAxisAlignment: _parseCrossAxis(data['crossAxisAlignment']),
                 children: _buildChildren(data['children']),
             );
          case 'ListView':
             return ListView(
                 padding: _parsePadding(data['padding']),
                 children: _buildChildren(data['children']),
             );
          case 'Container':
             return Container(
                 width: _parseDouble(data['width']),
                 height: _parseDouble(data['height']),
                 padding: _parsePadding(data['padding']),
                 margin: _parsePadding(data['margin']),
                 decoration: _parseDecoration(data['decoration'], data['color']),
                 child: data['child'] != null ? _buildSDUIWidget(data['child']) : null,
             );
          case 'Center':
             return Center(child: data['child'] != null ? _buildSDUIWidget(data['child']) : null);
          case 'Padding':
             return Padding(
                 padding: _parsePadding(data['padding']),
                 child: data['child'] != null ? _buildSDUIWidget(data['child']) : null,
             );
          case 'Card':
             return Card(
                 elevation: _parseDouble(data['elevation'] ?? 2),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_parseDouble(data['borderRadius']) ?? 12.0)),
                 margin: _parsePadding(data['margin']),
                 child: data['child'] != null ? _buildSDUIWidget(data['child']) : null,
             );
          case 'Text':
             return Text(
                 data['text'] ?? "",
                 style: _parseTextStyle(data['style']),
                 textAlign: _parseTextAlign(data['textAlign']),
             );
          case 'Image':
             return _buildImage(data['src']);
          case 'Icon':
             return Icon(
                 _parseIcon(data['icon']),
                 size: _parseDouble(data['size'] ?? 24),
                 color: _parseColor(data['color']),
             );
          case 'ListTile':
             return ListTile(
                 leading: data['leading'] != null ? _buildSDUIWidget(data['leading']) : null,
                 title: data['title'] != null ? _buildSDUIWidget(data['title']) : null,
                 subtitle: data['subtitle'] != null ? _buildSDUIWidget(data['subtitle']) : null,
                 trailing: data['trailing'] != null ? _buildSDUIWidget(data['trailing']) : null,
             );
          case 'FloatingActionButton':
             return FloatingActionButton(
                 onPressed: () {},
                 backgroundColor: _parseColor(data['backgroundColor']) ?? _brandColor,
                 child: data['child'] != null ? _buildSDUIWidget(data['child']) : const Icon(Icons.add),
             );
          default:
             return const SizedBox.shrink();
      }
  }

  List<Widget> _buildChildren(dynamic children) {
      if (children is! List) return [];
      return children.map((c) => _buildSDUIWidget(c as Map<String, dynamic>)).toList();
  }
  
  // --- Parsers ---

  MainAxisAlignment _parseMainAxis(String? val) {
      switch(val) {
          case 'center': return MainAxisAlignment.center;
          case 'end': return MainAxisAlignment.end;
          case 'spaceBetween': return MainAxisAlignment.spaceBetween;
          case 'spaceAround': return MainAxisAlignment.spaceAround;
          default: return MainAxisAlignment.start;
      }
  }

  CrossAxisAlignment _parseCrossAxis(String? val) {
      switch(val) {
          case 'center': return CrossAxisAlignment.center;
          case 'end': return CrossAxisAlignment.end;
          case 'stretch': return CrossAxisAlignment.stretch;
          default: return CrossAxisAlignment.start;
      }
  }
  
  TextAlign _parseTextAlign(String? val) {
      switch(val) {
          case 'center': return TextAlign.center;
          case 'right': return TextAlign.right;
          default: return TextAlign.start;
      }
  }

  EdgeInsets _parsePadding(dynamic val) {
      if (val is num) return EdgeInsets.all(val.toDouble());
      if (val is String) {
          final parts = val.split(',').map((e) => double.tryParse(e.trim()) ?? 0.0).toList();
          if (parts.length == 2) return EdgeInsets.symmetric(horizontal: parts[0], vertical: parts[1]);
          if (parts.length == 4) return EdgeInsets.fromLTRB(parts[0], parts[1], parts[2], parts[3]);
      }
      return EdgeInsets.zero;
  }

  BoxDecoration _parseDecoration(Map<String, dynamic>? decoration, String? color) {
      if (decoration == null && color == null) return const BoxDecoration();
      
      return BoxDecoration(
          color: _parseColor(decoration?['color'] ?? color),
          borderRadius: BorderRadius.circular(_parseDouble(decoration?['borderRadius']) ?? 0.0),
          border: decoration?['border'] != null ? Border.all(color: Colors.black12) : null,
          boxShadow: decoration?['boxShadow'] != null ? [
               BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0,4))
          ] : null
      );
  }

  TextStyle _parseTextStyle(Map<String, dynamic>? style) {
      return TextStyle(
          color: _parseColor(style?['color']),
          fontSize: _parseDouble(style?['fontSize']),
          fontWeight: style?['fontWeight'] == 'bold' ? FontWeight.bold : FontWeight.normal,
      );
  }

  Color? _parseColor(String? hex) {
      if (hex == null) return null;
      if (hex == 'primary') return _brandColor;
      if (hex == 'white') return Colors.white;
      if (hex == 'black') return Colors.black;
      if (hex == 'grey') return Colors.grey;
      try {
          return Color(int.parse(hex.replaceAll('#', '0xFF')));
      } catch (_) { return null; }
  }

  double? _parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
  }

  IconData _parseIcon(String? name) {
      switch(name) {
          case 'home': return Icons.home;
          case 'person': return Icons.person;
          case 'settings': return Icons.settings;
          case 'favorite': return Icons.favorite;
          case 'add': return Icons.add;
          case 'search': return Icons.search;
          case 'menu': return Icons.menu;
          case 'arrow_forward': return Icons.arrow_forward;
          default: return Icons.widgets;
      }
  }

  Widget _buildImage(String? src) {
      if (src == null) return const Icon(Icons.image, size: 48, color: Colors.grey);
      if (src.startsWith('http')) return Image.network(src, fit: BoxFit.cover);
      return Container(
          color: Colors.grey[300],
          child: const Center(child: Icon(Icons.image, color: Colors.white)),
      );
  }



  Widget _buildLegacyBody() {
    // Legacy Template Logic (Fallback)
    final appName = widget.dna['appName'] ?? "My App";
    final features = (widget.dna['features'] as List?)?.cast<String>() ?? ["Feature 1", "Feature 2", "Feature 3"];
    
    return Scaffold(
      appBar: AppBar(
        title: Text(appName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: widget.isRecording 
          ? _buildRecordingOverlay(_buildBodyOld(features)) 
          : _buildBodyOld(features),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: _brandColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBodyOld(List<String> features) {
     return const Center(child: Text("Analysis Incomplete. Please re-run analysis to generate UI.", textAlign: TextAlign.center));
  }
 
  // Recording Overlay reused
  Widget _buildRecordingOverlay(Widget child) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 16, right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                SizedBox(width: 8),
                Text("REC", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

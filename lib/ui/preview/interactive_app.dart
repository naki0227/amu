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
    // FIX: Prioritize 'primary' color for brand elements, not 'background'.
    final palette = widget.dna['brandPalette'];
    if (palette == null) return Colors.blue;

    final primary = palette['primary'];
    final secondary = palette['secondary'];
    final background = palette['background'];

    if (primary != null) return _parseColor(primary) ?? Colors.blue;
    if (secondary != null) return _parseColor(secondary) ?? Colors.blue;
    
    // Last resort
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
    
    // Auto-Scroll Wrapper: Prevent Vertical Overflow for non-scrollable roots
    final String rootType = widgetTree['body']?['type'] ?? 'Container';
    // SDUI Rendering
    // We calculate shouldWrap FIRST, then build the widget.
    final bool isSelfScrolling = ['ListView', 'GridView', 'SingleChildScrollView'].contains(rootType);
    final bool isRootExpanded = rootType == 'Expanded';
    // FIX: Only check for VERTICAL expansion (Column/Flex).
    final bool willFillVerticalSpace = _willFillVerticalSpace(widgetTree['body'] ?? {});

    // If root is Expanded, wrap in Column (fixed previously) - this changes the root widget structure effectively
    Map<String, dynamic> bodyData = widgetTree['body'] ?? {};
    if (isRootExpanded) {
        bodyData = {'type': 'Column', 'children': [bodyData]};
    }

    // DECISION:
    // 1. If self-scrolling (ListView), don't wrap.
    // 2. If it is designed to fill vertical space (Column->Expanded), don't wrap.
    // 3. Otherwise (Flow content, Row->Expanded, Wrap), wrap in SingleChildScrollView for safety.
    final bool shouldWrap = !isSelfScrolling && !willFillVerticalSpace;

    // Build Body (Pass disableExpanded=shouldWrap because if we wrap in ScrollView, Expanded is forbidden)
    Widget bodyContent = _buildSDUIWidget(bodyData, disableExpanded: shouldWrap);
    
    Widget body = shouldWrap ? SingleChildScrollView(
        child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height), // Ensure full height for background
            child: bodyContent
        )
    ) : bodyContent;
    
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
    
    return RepaintBoundary(
        child: Scaffold(
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
        )
    );
  }

  // --- SDUI Renderer ---

  Widget _buildSDUIWidget(Map<String, dynamic> data, {bool disableExpanded = false}) {
      if (data.isEmpty) return const SizedBox.shrink();

      final String type = data['type'] ?? 'Container';
      
      switch (type) {
          case 'Column':
             final childrenData = (data['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
             final hasExpanded = childrenData.any((c) => c['type'] == 'Expanded');
             
             // If we are in a ScrollView (disableExpanded=true), then Column cannot support Vertical Expansion.
             // We pass disableExpanded=true to children.
             // Exception: If this Column is wrapped in a defined height container (not tracked here), we might be safe?
             // Safest bet: propagate the flag.
             final col = Column(
                 mainAxisAlignment: _parseMainAxis(data['mainAxisAlignment']),
                 crossAxisAlignment: _parseCrossAxis(data['crossAxisAlignment']),
                 mainAxisSize: MainAxisSize.min, 
                 children: _buildChildren(childrenData, disableExpanded: disableExpanded),
             );
             
             if (!hasExpanded) {
                 return SingleChildScrollView(
                     physics: const ClampingScrollPhysics(),
                     child: col,
                 );
             }
             return col;
          case 'Row':
             final childrenData = (data['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
             final hasExpanded = childrenData.any((c) => c['type'] == 'Expanded');
             
             // Row is Horizontal. Vertical ScrollView doesn't affect Horizontal Expansion.
             // So we RESET disableExpanded to false for Row children.
             List<Widget> childrenWidgets = _buildChildren(childrenData, disableExpanded: false);
             
             if (hasExpanded) {
                 childrenWidgets = childrenData.asMap().entries.map((entry) {
                     final index = entry.key;
                     final childData = entry.value;
                     final widget = childrenWidgets[index];
                     
                     if (childData['type'] != 'Expanded' && childData['type'] != 'Spacer') {
                         return Flexible(fit: FlexFit.loose, child: widget);
                     }
                     return widget;
                 }).toList();
             }

             final row = Row(
                 mainAxisAlignment: _parseMainAxis(data['mainAxisAlignment']),
                 crossAxisAlignment: _parseCrossAxis(data['crossAxisAlignment']),
                 children: childrenWidgets,
             );
             
             if (!hasExpanded) {
                 return SingleChildScrollView(scrollDirection: Axis.horizontal, child: row);
             }
             return row;
          case 'ListView':
             final childrenData = (data['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
             return ListView(
                 padding: _parsePadding(data['padding']),
                 shrinkWrap: true, 
                 physics: const ClampingScrollPhysics(), 
                 children: _buildChildren(childrenData, disableExpanded: true), 
             );
          case 'Container':
             // If height is specified, we break the "Unconstrained" chain -> Expanded is safe again?
             // Implementing checks:
             final hasHeight = data['height'] != null;
             final nextDisableExpanded = hasHeight ? false : disableExpanded;

             return Container(
                 width: _parseDouble(data['width']),
                 height: _parseDouble(data['height']),
                 padding: _parsePadding(data['padding']),
                 margin: _parsePadding(data['margin']),
                 decoration: _parseDecoration(data['decoration'], data['color']),
                 child: data['child'] != null ? _buildSDUIWidget(data['child'], disableExpanded: nextDisableExpanded) : null,
             );
          case 'Center':
             return Center(child: data['child'] != null ? _buildSDUIWidget(data['child'], disableExpanded: disableExpanded) : null);
          case 'SingleChildScrollView':
             return SingleChildScrollView(
                 child: data['child'] != null ? _buildSDUIWidget(data['child'], disableExpanded: true) : null,
             );
          case 'Padding':
             return Padding(
                 padding: _parsePadding(data['padding']),
                 child: data['child'] != null ? _buildSDUIWidget(data['child'], disableExpanded: disableExpanded) : null,
             );
          case 'Card':
             return Card(
                 elevation: _parseDouble(data['elevation'] ?? 2),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_parseDouble(data['borderRadius']) ?? 12.0)),
                 margin: _parsePadding(data['margin']),
                 child: data['child'] != null ? _buildSDUIWidget(data['child'], disableExpanded: disableExpanded) : null,
             );
          case 'Image':
             return _buildImage(data['src']);
          case 'Icon':
             return Icon(
                 _parseIcon(data['icon']),
                 size: _parseDouble(data['size']),
                 color: _parseColor(data['color']),
             );
          case 'SizedBox':
             return SizedBox(
                 width: _parseDouble(data['width']),
                 height: _parseDouble(data['height']),
                 child: data['child'] != null ? _buildSDUIWidget(data['child'], disableExpanded: disableExpanded) : null,
             );
          case 'Expanded':
             // CRITICAL FIX: If disableExpanded is true, we unwrap the Expanded widget.
             final childWidget = data['child'] != null ? _buildSDUIWidget(data['child'], disableExpanded: disableExpanded) : const SizedBox();
             if (disableExpanded) {
                 return childWidget;
             }
             return Expanded(
                 flex: data['flex'] ?? 1,
                 child: childWidget,
             );
          case 'Wrap':
             final childrenData = (data['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
             return Wrap(
                 spacing: _parseDouble(data['spacing']) ?? 0.0,
                 runSpacing: _parseDouble(data['runSpacing']) ?? 0.0,
                 alignment: _parseWrapAlignment(data['alignment']),
                 children: _buildChildren(childrenData, disableExpanded: true), // Expanded cannot be in Wrap
             );
          case 'Stack':
             final childrenData = (data['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
             return Stack(
                 children: _buildChildren(childrenData, disableExpanded: true), // Expanded cannot be in Stack directly (Positioned is ok but handled differently)
             );
          case 'Positioned':
             return Positioned(
                 top: _parseDouble(data['top']),
                 bottom: _parseDouble(data['bottom']),
                 left: _parseDouble(data['left']),
                 right: _parseDouble(data['right']),
                 child: data['child'] != null ? _buildSDUIWidget(data['child'], disableExpanded: true) : const SizedBox(),
             );
          case 'ListTile':
             return ListTile(
                 leading: data['leading'] != null ? _buildSDUIWidget(data['leading'], disableExpanded: true) : null,
                 title: data['title'] != null ? _buildSDUIWidget(data['title'], disableExpanded: true) : const Text("Title"),
                 subtitle: data['subtitle'] != null ? _buildSDUIWidget(data['subtitle'], disableExpanded: true) : null,
                 trailing: data['trailing'] != null ? _buildSDUIWidget(data['trailing'], disableExpanded: true) : null,
             );
          case 'Button':
             final style = data['style'] ?? {};
             final bool isOutlined = style['type'] == 'outlined';
             return Container(
                 margin: _parsePadding(data['margin']),
                 child: isOutlined ? OutlinedButton(
                     onPressed: () {},
                     style: OutlinedButton.styleFrom(
                         side: BorderSide(color: _parseColor(style['borderColor']) ?? _brandColor),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_parseDouble(style['borderRadius']) ?? 8)),
                         padding: _parsePadding(style['padding'] ?? [16, 24]),
                     ),
                     child: _buildSDUIWidget(data['child'] ?? {'type': 'Text', 'text': data['text'] ?? 'Button', 'style': {'color': style['color'] ?? _brandColor.toString()}})
                 ) : ElevatedButton(
                     onPressed: () {},
                     style: ElevatedButton.styleFrom(
                         backgroundColor: _parseColor(style['backgroundColor']) ?? _brandColor,
                         foregroundColor: _parseColor(style['color']) ?? Colors.white,
                         elevation: _parseDouble(style['elevation']),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_parseDouble(style['borderRadius']) ?? 8)),
                         padding: _parsePadding(style['padding'] ?? [16, 24]),
                     ),
                     child: _buildSDUIWidget(data['child'] ?? {'type': 'Text', 'text': data['text'] ?? 'Button', 'style': {'color': '#ffffff'}})
                 ),
             );
          case 'Input':
             return Container(
                 margin: _parsePadding(data['margin']),
                 child: TextField(
                     decoration: InputDecoration(
                         filled: true,
                         fillColor: _parseColor(data['decoration']?['color']) ?? Colors.grey.withOpacity(0.1),
                         hintText: data['text'] ?? "Enter text...",
                         border: OutlineInputBorder(
                             borderRadius: BorderRadius.circular(_parseDouble(data['decoration']?['borderRadius']) ?? 8),
                             borderSide: BorderSide.none,
                         ),
                         contentPadding: _parsePadding(data['padding'] ?? [16, 16]),
                     ),
                 ),
             );
          case 'GridView':
             return GridView.count(
                 crossAxisCount: data['crossAxisCount'] ?? 2,
                 mainAxisSpacing: _parseDouble(data['mainAxisSpacing']) ?? 8.0,
                 crossAxisSpacing: _parseDouble(data['crossAxisSpacing']) ?? 8.0,
                 childAspectRatio: _parseDouble(data['childAspectRatio']) ?? 1.0,
                 padding: _parsePadding(data['padding']),
                 shrinkWrap: true,
                 physics: const ClampingScrollPhysics(),
                 children: _buildChildren(data['children']),
             );
          case 'Text':
             return Text(
                 data['text'] ?? "",
                 style: _parseTextStyle(data['style']),
                 textAlign: _parseTextAlign(data['textAlign']),
                 overflow: TextOverflow.ellipsis,
             );
          default:
             return const SizedBox.shrink();
      }
  }

  List<Widget> _buildChildren(List<Map<String, dynamic>> children, {bool disableExpanded = false}) {
      return children.map((data) => _buildSDUIWidget(data, disableExpanded: disableExpanded)).toList();
  }

  MainAxisAlignment _parseMainAxis(dynamic val) {
      if (val is! String) return MainAxisAlignment.start;
      switch(val) {
          case 'center': return MainAxisAlignment.center;
          case 'end': return MainAxisAlignment.end;
          case 'spaceBetween': return MainAxisAlignment.spaceBetween;
          case 'spaceAround': return MainAxisAlignment.spaceAround;
          default: return MainAxisAlignment.start;
      }
  }

  CrossAxisAlignment _parseCrossAxis(dynamic val) {
      if (val is! String) return CrossAxisAlignment.center;
      switch(val) {
          case 'start': return CrossAxisAlignment.start;
          case 'end': return CrossAxisAlignment.end;
          case 'stretch': return CrossAxisAlignment.stretch;
          default: return CrossAxisAlignment.center;
      }
  }

  EdgeInsets _parsePadding(dynamic val) {
      if (val == null) return EdgeInsets.zero;
      if (val is num) return EdgeInsets.all(val.toDouble());
      if (val is List) {
          if (val.length == 2) return EdgeInsets.symmetric(vertical: (val[0] as num).toDouble(), horizontal: (val[1] as num).toDouble());
          if (val.length == 4) return EdgeInsets.fromLTRB(
              (val[0] as num).toDouble(), (val[1] as num).toDouble(), (val[2] as num).toDouble(), (val[3] as num).toDouble());
      }
      return EdgeInsets.zero;
  }
  
  double? _parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
  }
  
  Color? _parseColor(dynamic val) {
      if (val is! String) return null;
      String hex = val.replaceAll('#', '');
      if (hex.length == 3) {
          hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
      }
      if (hex.length == 6) {
          hex = 'FF$hex'; // Add Alpha
      }
      try {
          return Color(int.parse('0x$hex'));
      } catch (_) { return null; }
  }
  
  TextStyle _parseTextStyle(Map<String, dynamic>? style) {
      if (style == null) return const TextStyle();
      return TextStyle(
          color: _parseColor(style['color']),
          fontSize: _parseDouble(style['fontSize']),
          fontWeight: style['fontWeight'] == 'bold' ? FontWeight.bold : FontWeight.normal,
          height: _parseDouble(style['height']),
          letterSpacing: _parseDouble(style['letterSpacing']),
          fontStyle: style['fontStyle'] == 'italic' ? FontStyle.italic : FontStyle.normal,
      );
  }
  
  TextAlign _parseTextAlign(String? align) {
      switch(align) {
          case 'center': return TextAlign.center;
          case 'right': return TextAlign.right;
          default: return TextAlign.left;
      }
  }
  
  IconData _parseIcon(String? name) {
      switch(name) {
          case 'home': return Icons.home;
          case 'search': return Icons.search;
          case 'person': return Icons.person;
          case 'settings': return Icons.settings;
          case 'menu': return Icons.menu;
          case 'notifications': return Icons.notifications;
          case 'dashboard': return Icons.dashboard;
          case 'email': case 'mail': return Icons.email;
          case 'chat': case 'message': return Icons.chat;
          case 'calendar_today': case 'calendar': return Icons.calendar_today;
          case 'map': return Icons.map;
          case 'camera_alt': case 'camera': return Icons.camera_alt;
          case 'upload': case 'cloud_upload': return Icons.cloud_upload;
          case 'delete': return Icons.delete;
          case 'edit': return Icons.edit;
          case 'save': return Icons.save;
          case 'star': return Icons.star;
          case 'share': return Icons.share;
          case 'more_vert': return Icons.more_vert;
          case 'arrow_forward': return Icons.arrow_forward;
          case 'arrow_back': return Icons.arrow_back;
          case 'check': return Icons.check;
          case 'close': return Icons.close;
          case 'add': return Icons.add;
          default: return Icons.widgets;
      }
  }
  
  BoxDecoration _parseDecoration(Map<String, dynamic>? deco, String? color) {
      if (deco == null && color == null) return const BoxDecoration();
      
      return BoxDecoration(
          color: _parseColor(color ?? deco?['color']),
          borderRadius: deco?['borderRadius'] != null ? BorderRadius.circular(_parseDouble(deco!['borderRadius'])!) : null,
          gradient: _parseGradient(deco?['gradient']),
          border: deco?['border'] != null ? Border.all(
              color: _parseColor(deco!['border']['color']) ?? Colors.white24,
              width: _parseDouble(deco['border']['width']) ?? 1.0,
          ) : null,
          boxShadow: deco?['boxShadow'] != null ? (deco!['boxShadow'] as List).map((s) => BoxShadow(
              color: _parseColor(s['color']) ?? Colors.black26,
              blurRadius: _parseDouble(s['blur']) ?? 4.0,
              offset: Offset(
                  _parseDouble(s['offset']?[0]) ?? 0, 
                  _parseDouble(s['offset']?[1]) ?? 2
              ),
          )).toList() : null,
      );
  }

  Gradient? _parseGradient(Map<String, dynamic>? grad) {
      if (grad == null) return null;
      final colors = (grad['colors'] as List?)?.map((c) => _parseColor(c) ?? Colors.transparent).toList();
      if (colors == null || colors.isEmpty) return null;
      
      return LinearGradient(
          colors: colors,
          begin: _parseAlignment(grad['begin']) ?? Alignment.topLeft,
          end: _parseAlignment(grad['end']) ?? Alignment.bottomRight,
      );
  }

  Alignment? _parseAlignment(String? val) {
      switch(val) {
          case 'topLeft': return Alignment.topLeft;
          case 'topCenter': return Alignment.topCenter;
          case 'topRight': return Alignment.topRight;
          case 'centerLeft': return Alignment.centerLeft;
          case 'center': return Alignment.center;
          case 'centerRight': return Alignment.centerRight;
          case 'bottomLeft': return Alignment.bottomLeft;
          case 'bottomCenter': return Alignment.bottomCenter;
          case 'bottomRight': return Alignment.bottomRight;
          default: return null;
      }
  }
  
  Widget _buildImage(String? src) {
      if (src == null || src.isEmpty) return const Icon(Icons.image, size: 48, color: Colors.grey);
      if (src.startsWith('assets/')) return Image.asset(src, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image));
      return Image.network(src, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image));
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

  WrapAlignment _parseWrapAlignment(String? val) {
      switch(val) {
          case 'center': return WrapAlignment.center;
          case 'end': return WrapAlignment.end;
          case 'spaceBetween': return WrapAlignment.spaceBetween;
          case 'spaceAround': return WrapAlignment.spaceAround;
          case 'spaceEvenly': return WrapAlignment.spaceEvenly;
          default: return WrapAlignment.start;
      }
  }

  bool _willFillVerticalSpace(Map<String, dynamic> data) {
      if (data.isEmpty) return false;
      
      final type = data['type'];
      
      // 1. Explicit Vertical Expansion Found
      if (type == 'Expanded' || type == 'Spacer') return true;
      
      // 2. Stop Recursion on Widgets that break the Vertical Flex Chain
      if (type == 'Row' || type == 'Wrap' || type == 'Stack' || 
          type == 'ListView' || type == 'GridView' || type == 'SingleChildScrollView' ||
          type == 'Center' || type == 'Card' || type == 'Positioned') {
          return false; 
      }
      
      // 3. Stop Recursion if Height is Explicitly Constrained
      if ((type == 'Container' || type == 'SizedBox') && data['height'] != null) {
          return false;
      }
      
      // 4. Recurse for Children (only for Column, Container, Padding, etc.)
      final children = (data['children'] as List?)?.cast<Map<String, dynamic>>();
      if (children != null) {
          for (var child in children) {
              if (_willFillVerticalSpace(child)) return true;
          }
      }
      
      final child = data['child'] as Map<String, dynamic>?;
      if (child != null) {
          if (_willFillVerticalSpace(child)) return true;
      }
      
      return false;
  }
}

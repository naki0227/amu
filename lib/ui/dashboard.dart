import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:amu/ui/wizard/project_wizard.dart';
import 'package:amu/logic/localization.dart';
import 'package:amu/studio/amu_studio.dart';

/// Amu Dashboard
/// 
/// Design Philosophy: "Premium, Glassmorphism, Deep Space"
/// A dark-themed dashboard that feels like a futuristic control center for weaving code into video.

void main() {
  runApp(const AmuApp());
}

class AmuApp extends StatelessWidget {
  const AmuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amu Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        primaryColor: const Color(0xFF6366F1), // Indigo 500
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _hasLastProject = false;
  Map<String, dynamic>? _lastProjectDna;

  @override
  void initState() {
    super.initState();
    _checkLastProject();
  }

  Future<void> _checkLastProject() async {
    // Check if amu_output/project.json exists (mocking the persistent storage for now)
    // Actually, ProjectWizard saves to shared preferences or file?
    // ProjectStorage logic suggests keeping things in memory or minimal file.
    // Let's check for the existence of `amu_output/config.json` or similar as a heuristic.
    // Ideally, we should use `ProjectStorage` logic.
    // For now, let's just leave it simple: if the user just created one, they are in Studio.
    // If they restart app, maybe clean slate is fine for MVP, but user said "too mock".
    // I will replace the "Recent Weaves" with an empty state or "No Projects Yet".
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Mesh
          Positioned(
            top: -100,
            right: -100,
            child: _buildGlowOrb(const Color(0xFF6366F1), 400),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: _buildGlowOrb(const Color(0xFFEC4899), 400),
          ),
          
          // Main Content
          Row(
            children: [
              // Sidebar
              _buildSidebar(context),
              
              // Main Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 32),
                      _buildStatsRow(),
                      const SizedBox(height: 32),
                      Expanded(child: _buildRecentProjectsList()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlowOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 100,
            spreadRadius: 20,
          ),
        ],
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Logo placeholder
          const Text(
            "Amu",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 48),
          _buildNavItem(Icons.dashboard_rounded, "Overview", true),
          _buildNavItem(Icons.movie_creation_outlined, "Projects", false),
          _buildNavItem(Icons.layers_outlined, "Templates", false),
          _buildNavItem(Icons.settings_outlined, "Settings", false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: isSelected
          ? BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
            )
          : null,
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF818CF8) : Colors.grey,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {},
      ),
    );
  }
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('dashboard.welcome'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('dashboard.subtitle'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProjectWizard())
            );
            
            if (result != null && result is Map<String, dynamic> && context.mounted) {
               // Navigate to Studio with the generated project
               Navigator.of(context).push(
                 MaterialPageRoute(builder: (_) => AmuStudio(initialStoryboard: result))
               );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(t('dashboard.new_project'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard("Active Projects", "0", Icons.motion_photos_auto, Colors.grey),
        const SizedBox(width: 16),
        _buildStatCard("Total Generated", "0", Icons.video_library, Colors.grey),
        const SizedBox(width: 16),
        _buildStatCard("Render Time (Avg)", "--", Icons.timer, Colors.grey),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.9)),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentProjectsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Recent Weaves",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
             width: double.infinity,
             padding: const EdgeInsets.all(32),
             decoration: BoxDecoration(
               color: Colors.white.withOpacity(0.03),
               borderRadius: BorderRadius.circular(16),
               border: Border.all(color: Colors.white.withOpacity(0.05)),
             ),
             child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.layers_clear, size: 64, color: Colors.white.withOpacity(0.2)),
                   const SizedBox(height: 16),
                   Text(
                     "No Projects Yet",
                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.5)),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     "Start a new project to see it here.",
                     style: TextStyle(color: Colors.white.withOpacity(0.3)),
                   ),
                ],
             ),
          ),
        ),
      ],
    );
  }
}

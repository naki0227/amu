import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:amu/ui/wizard/project_wizard.dart';
import 'package:amu/logic/localization.dart';

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

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProjectWizard())
            );
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
        _buildStatCard("Active Projects", "3", Icons.motion_photos_auto, Colors.orange),
        const SizedBox(width: 16),
        _buildStatCard("Total Generated", "128", Icons.video_library, Colors.blue),
        const SizedBox(width: 16),
        _buildStatCard("Render Time (Avg)", "14s", Icons.timer, Colors.green),
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
          child: ListView.separated(
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.indigo.withOpacity(0.4), Colors.purple.withOpacity(0.4)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: Icon(Icons.movie, color: Colors.white54, size: 20)),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Project Alpha - Marketing V1",
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9)),
                        ),
                        Text(
                          "Last edited 2h ago",
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: const Text(
                        "Completed",
                        style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.more_vert, color: Colors.white.withOpacity(0.5)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

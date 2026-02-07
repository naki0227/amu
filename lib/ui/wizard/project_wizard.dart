import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:amu/studio/amu_studio.dart';
import 'package:amu/director/storyboard_generator.dart';
import 'package:amu/logic/gemini_service.dart';
import 'package:amu/logic/localization.dart';
import 'package:file_picker/file_picker.dart';

class ProjectWizard extends StatefulWidget {
  const ProjectWizard({super.key});

  @override
  State<ProjectWizard> createState() => _ProjectWizardState();
}

class _ProjectWizardState extends State<ProjectWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
  // Data State
  String _apiKey = "";
  String _selectedLanguage = "Japanese";
  String _sourceUrl = "";
  bool _isAnalyzing = false;
  bool _showApiKey = false; // Toggle for API key visibility

  final int _totalSteps = 4; // 0: API, 1: Lang, 2: Source, 3: Generation

  void _nextPage() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
      final file = File('amu_output/config.json');
      if (await file.exists()) {
          try {
             final data = jsonDecode(await file.readAsString());
             setState(() {
                 // API Key
                 final key = data['apiKey'] as String?;
                 if (key != null && key.isNotEmpty) {
                     _apiKey = key;
                     _apiKeyController.text = key;
                 }
                 // Language
                 final lang = data['language'] as String?;
                 if (lang != null && lang.isNotEmpty) {
                     _selectedLanguage = lang;
                 }
                 // Source Path
                 final src = data['sourcePath'] as String?;
                 if (src != null && src.isNotEmpty) {
                     _sourceUrl = src;
                     _sourceController.text = src;
                 }
             });
          } catch (e) {
              print("Failed to load config: $e");
          }
      }
  }
  
  Future<void> _saveProfile() async {
      final dir = Directory('amu_output');
      if (!await dir.exists()) await dir.create(recursive: true);
      
      final file = File('amu_output/config.json');
      await file.writeAsString(jsonEncode({
          "apiKey": _apiKey.trim(),
          "language": _selectedLanguage,
          "sourcePath": _sourceUrl.trim(),
      }));
  }

  void _onStepComplete() {
      // API Key Step (0)
      if (_currentStep == 0) {
          if (_apiKey.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid API Key.")));
              return;
          }
          _saveProfile(); // Save all profile data
          _nextPage();
      }
      // Language Step (1)
      else if (_currentStep == 1) {
          _saveProfile(); // Save language selection
          _nextPage();
      }
      // Source Step (2) - Final step before analysis
      else if (_currentStep == 2) {
          _saveProfile(); // Save source path
          _startAnalysis();
      } else {
          _nextPage();
      }
  }
  
  Future<void> _startAnalysis() async {
      _nextPage(); // Go to loading screen
      setState(() => _isAnalyzing = true);
      
      try {
          // 1. Get DNA from Gemini
          // Use gemini-2.5-pro
          final service = GeminiService(_apiKey, modelName: 'gemini-2.5-pro');
          
          // Use current directory if source is empty (for demo)
          final targetPath = _sourceUrl.isEmpty ? Directory.current.path : _sourceUrl;
          
          final dna = await service.analyzeProject(targetPath, language: _selectedLanguage);
          
          // 2. Generate Storyboard
          final generator = StoryboardGenerator();
          final sb = generator.generateStoryboard(dna);
          
          if (mounted) {
              // Return Data to Studio
              Navigator.of(context).pop(sb);
          }
      } catch (e) {
          // Show Error and go back
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
              setState(() {
                  _isAnalyzing = false;
                  _currentStep = 2; // Go back to source input
                  _pageController.jumpToPage(2);
              });
          }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildApiKeyStep(),
                  _buildLanguageStep(),
                  _buildSourceStep(),
                  _buildGenerationStep(),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
      return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
              children: [
                  if (_currentStep > 0 && _currentStep < 3)
                    IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: _prevPage)
                  else
                    const SizedBox(width: 48), // Spacer
                    
                  const Spacer(),
                  // Step Indicator
                  Row(
                      children: List.generate(_totalSteps, (index) {
                          bool isActive = index == _currentStep;
                          bool isPast = index < _currentStep;
                          return Container(
                              width: 12, height: 12,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive ? Colors.indigoAccent : (isPast ? Colors.indigoAccent.withOpacity(0.5) : Colors.white10)
                              ),
                          );
                      }),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
              ],
          ),
      );
  }
  
  Widget _buildFooter() {
      if (_currentStep == 3) return const SizedBox(); // No footer on loading
      
      return Padding(
          padding: const EdgeInsets.all(32),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _onStepComplete,
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Text(_currentStep == 2 ? t('wizard.generate') : t('wizard.next'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Icon(_currentStep == 2 ? Icons.auto_awesome : Icons.arrow_forward, color: Colors.white, size: 20),
                          ],
                      ),
                  ),
              ],
          ),
      );
  }

  // --- STEPS ---

  Widget _buildApiKeyStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.vpn_key, size: 64, color: Colors.indigoAccent),
          const SizedBox(height: 32),
          Text(t('wizard.api.title'), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(
            t('wizard.api.description'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 48),
          TextField(
            controller: _apiKeyController,
            onChanged: (v) => _apiKey = v,
            obscureText: !_showApiKey,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              hintText: t('wizard.api.hint'),
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              prefixIcon: const Icon(Icons.key, color: Colors.white30),
              suffixIcon: IconButton(
                icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility, color: Colors.white30),
                onPressed: () => setState(() => _showApiKey = !_showApiKey),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          Text(t('wizard.api.note'), style: const TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLanguageStep() {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 64),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Text(t('wizard.lang.title'), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(t('wizard.lang.description'), style: const TextStyle(color: Colors.white54, fontSize: 16)),
                  const SizedBox(height: 48),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          _buildSelectionCard("Japanese", "日本語"),
                          const SizedBox(width: 24),
                          _buildSelectionCard("English", "English"),
                      ],
                  )
              ],
          ),
      );
  }

  Widget _buildSelectionCard(String id, String label) {
      bool isSelected = _selectedLanguage == id;
      return InkWell(
          onTap: () => setState(() => _selectedLanguage = id),
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 160, height: 120,
              decoration: BoxDecoration(
                  color: isSelected ? Colors.indigoAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                  border: Border.all(color: isSelected ? Colors.indigoAccent : Colors.transparent, width: 2),
                  borderRadius: BorderRadius.circular(16)
              ),
              child: Center(
                  child: Text(label, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              ),
          ),
      );
  }

  Widget _buildSourceStep() {
      return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 24),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  const Icon(Icons.code, size: 48, color: Colors.pinkAccent),
                   const SizedBox(height: 24),
                  Text(t('wizard.source.title'), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(t('wizard.source.description'), style: const TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sourceController,
                          onChanged: (v) => _sourceUrl = v,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            hintText: t('wizard.source.hint'),
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                            prefixIcon: const Icon(Icons.folder_open, color: Colors.white30),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _pickFolder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.folder_open, color: Colors.white, size: 18),
                        label: Text(t('wizard.source.browse'), style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
              ],
          ),
      );
  }

  Future<void> _pickFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: t('wizard.source.select_folder'),
    );
    if (selectedDirectory != null) {
      setState(() {
        _sourceUrl = selectedDirectory;
        _sourceController.text = selectedDirectory;
      });
    }
  }

  Widget _buildGenerationStep() {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  const SizedBox(
                      width: 80, height: 80,
                      child: CircularProgressIndicator(color: Colors.indigoAccent, strokeWidth: 6),
                  ),
                  const SizedBox(height: 48),
                  Text(t('wizard.analyzing'), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(t('wizard.analyzing.sub'), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16)),
              ],
          ),
      );
  }
}

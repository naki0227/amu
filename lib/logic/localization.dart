/// Amu Localization Service
/// Default: Japanese (JP), switchable to English (EN)

class AmuLocalization {
  static String _currentLocale = 'ja'; // Default Japanese
  
  static String get locale => _currentLocale;
  
  static void setLocale(String locale) {
    _currentLocale = locale;
  }
  
  static String get(String key) {
    final map = _currentLocale == 'ja' ? _ja : _en;
    return map[key] ?? key;
  }
  
  // Japanese Translations
  static const Map<String, String> _ja = {
    // Wizard
    'wizard.api.title': 'Gemini API 設定',
    'wizard.api.description': 'AmuはGoogle Gemini 2.5 Proを使用してコードを解析します。\nAPIキーを入力してください。',
    'wizard.api.hint': 'Gemini APIキーを入力 (AIza...)',
    'wizard.api.note': 'キーはこのセッション中のみ保存されます。',
    'wizard.lang.title': 'ターゲット言語',
    'wizard.lang.description': '動画のナレーションとテキストの言語を選択してください。',
    'wizard.source.title': 'プロジェクトソース',
    'wizard.source.description': 'ローカルリポジトリまたはアセットフォルダを指定してください。',
    'wizard.source.hint': '/Users/username/projects/my_app',
    'wizard.source.dragdrop': 'フォルダをここにドラッグ＆ドロップ',
    'wizard.source.browse': '参照',
    'wizard.source.select_folder': 'プロジェクトフォルダを選択',
    'wizard.generate': '生成開始',
    'wizard.next': '次へ',
    'wizard.analyzing': 'コンテキストを解析中...',
    'wizard.analyzing.sub': 'Gemini 2.5 ProでプロジェクトDNAを分析しています...',
    
    // Common
    'common.or': 'または',
    'common.error': 'エラー',
    'common.save': '保存',
    'common.export': 'エクスポート',
    'common.cancel': 'キャンセル',
    
    // Dashboard
    'dashboard.welcome': 'おかえりなさい、Weaver。',
    'dashboard.subtitle': 'コードから新しいストーリーを紡ぎましょう。',
    'dashboard.new_project': '新規プロジェクト',
    'dashboard.recent': '最近のプロジェクト',
    
    // Studio
    'studio.save_success': 'プロジェクトを保存しました！レンダリング準備完了。',
  };
  
  // English Translations
  static const Map<String, String> _en = {
    // Wizard
    'wizard.api.title': 'Gemini API Setup',
    'wizard.api.description': 'Amu uses Google Gemini 2.5 Pro to analyze your code.\nPlease enter your API key.',
    'wizard.api.hint': 'Enter Gemini API Key (AIza...)',
    'wizard.api.note': 'Your key is stored only in memory for this session.',
    'wizard.lang.title': 'Target Language',
    'wizard.lang.description': 'Select the language for video narration and text.',
    'wizard.source.title': 'Project Source',
    'wizard.source.description': 'Point Amu to your local repository or asset folder.',
    'wizard.source.hint': '/Users/username/projects/my_app',
    'wizard.source.dragdrop': 'Drag & Drop Folder Here',
    'wizard.generate': 'Generate',
    'wizard.next': 'Next',
    'wizard.analyzing': 'Weaving Context...',
    'wizard.analyzing.sub': 'Analyzing project DNA using Gemini 2.5 Pro...',
    
    // Common
    'common.or': 'OR',
    'common.error': 'Error',
    'common.save': 'Save',
    'common.export': 'Export',
    'common.cancel': 'Cancel',
    
    // Dashboard
    'dashboard.welcome': 'Welcome back, Weaver.',
    'dashboard.subtitle': 'Ready to weave new stories from code?',
    'dashboard.new_project': 'New Project',
    'dashboard.recent': 'Recent Projects',
    
    // Studio
    'studio.save_success': 'Project Saved! Ready to Render.',
  };
}

// Shorthand for easy access
String t(String key) => AmuLocalization.get(key);

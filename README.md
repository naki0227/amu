# 🎬 Amu Studio

**コードから、プロモーション動画へ。**

Amu は、Flutterアプリのソースコードを AI で解析し、自動的にプロモーション動画を生成するスタジオ環境です。

---

## ✨ 主な機能

| 機能 | 説明 |
|---|---|
| **Code-to-Video** | Gemini AI がコードを解析し、アプリの「DNA」(ブランドカラー、UI構造、キーメッセージ) を抽出。 |
| **Server-Driven UI (SDUI)** | 解析された Widget Tree を元に、アプリのUIを忠実に再現するインタラクティブプレビュー。 |
| **タイムライン編集** | シーンの追加・削除、ナレーションテキストの編集、カメラアニメーション設定。 |
| **動画エクスポート** | レンダリングした静止画から MP4/GIF を自動生成 (ffmpeg 利用)。 |

---

## 🚀 セットアップ

### 前提条件

- Flutter SDK 3.x+
- macOS (デスクトップアプリとして動作)
- ffmpeg (`brew install ffmpeg`)
- Gemini API Key ([Google AI Studio](https://aistudio.google.com/) で取得)

### インストール

```bash
git clone https://github.com/naki0227/amu.git
cd amu
flutter pub get
```

### 起動

```bash
# Dashboard から起動
flutter run lib/ui/dashboard.dart -d macos

# または直接 Studio を起動
flutter run lib/preview.dart -d macos
```

---

## 📂 プロジェクト構成

```
lib/
├── director/       # ストーリーボード生成ロジック
├── engine/         # フレームレンダラー、動画エクスポーター
├── logic/          # Gemini AI サービス、ローカライズ
├── studio/         # Amu Studio 本体 (UI + タイムライン)
├── ui/             # Dashboard, Wizard, Preview
└── preview.dart    # エントリポイント
```

---

## 🔑 環境変数

API キーは Wizard 画面で入力するか、`amu_output/config.json` に保存されます。  
ハードコードは **厳禁** です。

---

## 📄 ライセンス

MIT License

---

## 🤝 コントリビューション

Issue や Pull Request 歓迎です！

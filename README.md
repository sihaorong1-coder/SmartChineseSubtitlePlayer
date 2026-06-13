# 智能中文字幕视频播放器

基于 SwiftUI 开发的 iOS 视频播放器，自动为视频生成中文字幕。

> 🖥️ **Windows 开发模式**：本项目为 Windows 用户设计，使用 **GitHub Actions** 远程构建 iOS App。

---

## 📋 目录

- [一、项目功能说明](#一项目功能说明)
- [二、项目目录结构](#二项目目录结构)
- [三、关键实现逻辑](#三关键实现逻辑)
- [四、🖥️ Windows 开发流程（必读）](#四️-windows-开发流程必读)
- [五、代码质量说明](#五代码质量说明)
- [六、接入真实 API](#六接入真实-api)

---

## 一、项目功能说明

### 核心功能

| 功能 | 描述 |
|------|------|
| 🎬 视频播放 | 支持 MP4/MOV/M4V，播放/暂停/拖动进度/全屏 |
| 📝 内嵌字幕提取 | 自动检测并提取视频内嵌字幕轨道 |
| 🌐 字幕翻译 | 自动检测语言，非中文自动翻译为简体中文 |
| 🎤 语音识别 | 无字幕视频自动提取音频并进行语音识别 |
| 🎨 字幕样式 | 白色文字+半透明黑底，支持大小/位置/偏移调整 |
| ⚙️ 灵活设置 | 字幕开关、位置、大小、时间偏移均可配置 |

### 字幕处理流程

```
视频加载
  ├─ 有内嵌字幕？
  │   ├─ 是 → 解析字幕 → 检测语言
  │   │         ├─ 中文 → 直接显示
  │   │         └─ 非中文 → 翻译 → 显示中文
  │   └─ 否 → 语音识别开启？
  │           ├─ 是 → 提取音频 → 语音识别 → 检测语言 → 翻译（如需）→ 显示
  │           └─ 否 → 提示无字幕
  └─ 用户可选：手动调整时间偏移、大小、位置
```

---

## 二、项目目录结构

```
SmartChineseSubtitlePlayer/
├── README.md
├── project.yml                       ← XcodeGen 项目描述（替代 .xcodeproj）
├── codemagic.yaml                    ← Codemagic CI 配置
├── .github/workflows/
│   └── ios-build.yml                 ← GitHub Actions CI 配置
├── .gitignore
│
└── SmartChineseSubtitlePlayer/
    ├── App/
    │   ├── SmartChineseSubtitlePlayerApp.swift   ← @main 入口
    │   └── Info.plist                            ← 权限声明
    ├── Models/
    │   ├── SubtitleItem.swift          ← 字幕数据模型
    │   ├── VideoItem.swift             ← 视频历史模型
    │   └── AppSettings.swift           ← 全局响应式设置
    ├── Services/
    │   ├── SubtitleParserService.swift  ← SRT/VTT/内嵌轨道解析
    │   ├── LanguageDetectionService.swift ← NL 语言检测
    │   ├── TranslationService.swift     ← 翻译（Mock + API 预留）
    │   ├── SpeechRecognitionService.swift ← 语音识别
    │   └── SubtitleSyncManager.swift    ← 字幕-播放同步
    ├── ViewModels/
    │   ├── VideoPlayerViewModel.swift   ← 播放器核心逻辑
    │   └── SettingsViewModel.swift      ← 设置管理
    ├── Views/
    │   ├── HomeView.swift               ← 首页
    │   ├── VideoPlayerView.swift        ← 播放器页面
    │   ├── SettingsView.swift           ← 设置页面
    │   ├── SubtitleOverlayView.swift    ← 字幕叠加组件
    │   └── SubtitleControlPanel.swift   ← 字幕控制面板
    ├── Utils/
    │   ├── FileManager+Extensions.swift ← 文件工具
    │   └── String+LanguageDetection.swift ← 语言检测
    └── Resources/
        └── LaunchScreen.storyboard      ← 启动画面
```

---

## 三、关键实现逻辑

### 1. 字幕同步机制

- `AVPlayer.addPeriodicTimeObserver` 每 0.1 秒获取播放时间
- **二分查找**在排序字幕数组中定位当前字幕
- 支持时间偏移：`adjustedTime = currentTime - timeOffset`
- 去抖动优化：变化小于 0.05 秒不更新

### 2. 翻译服务

接口遵循 `TranslationServiceProtocol`，当前 Mock 实现，替换真实 API 无需改调用代码：

```swift
protocol TranslationServiceProtocol {
    func translate(_ text: String, from sourceLanguage: String) async throws -> String
    func translateBatch(_ texts: [String], from sourceLanguage: String) async throws -> [String]
}
```

### 3. 数据流架构 (MVVM)

```
User Action → View → ViewModel → Service → Model
                  ↑                        ↓
                  └── @Published ◄── async/await
```

---

## 四、🖥️ Windows 开发流程（必读）

### 4.1 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    你的 Windows 电脑                             │
│                                                                 │
│   VS Code / Cursor / Notepad++                                  │
│        │                                                        │
│        │ 编辑 Swift 代码                                         │
│        │                                                        │
│        ▼                                                        │
│   git push ──────────────────────────────────────┐              │
│                                                  │              │
└──────────────────────────────────────────────────┼──────────────┘
                                                   │
                                                   ▼
┌─────────────────────────────────────────────────────┐           │
│           GitHub Actions (macOS Runner)              │           │
│                                                     │           │
│   1. Checkout 代码                                   │           │
│   2. 安装 XcodeGen                                   │           │
│   3. xcodegen generate → 生成 .xcodeproj            │           │
│   4. xcodebuild → 编译 → .app / .ipa                │           │
│   5. 上传 Artifact                                   │           │
│                                                     │           │
│   ⏱️  每次构建约 5-15 分钟                            │           │
│   🆓 公开仓库免费 / 私有仓库 2000 分钟/月              │           │
└─────────────────────────────────────────────────────┘           │
```

### 4.2 第一步：初始化 Git 仓库

```bash
# 在项目目录下
cd e:\桌面\软件\SmartChineseSubtitlePlayer

# 初始化 Git
git init

# 添加所有文件
git add -A

# 提交
git commit -m "初始提交：智能中文字幕视频播放器"

# 推送到 GitHub
# （先在 GitHub.com 创建仓库，用 https:// 地址替换下面）
git remote add origin https://github.com/你的用户名/SmartChineseSubtitlePlayer.git
git branch -M main
git push -u origin main
```

### 4.3 第二步：推送即构建

推送代码后，GitHub Actions 自动：

1. `git push` → 触发 `.github/workflows/ios-build.yml`
2. 在 macOS 虚拟机中安装 XcodeGen + 生成项目
3. 编译 Debug 版本（模拟器用）
4. 在 **Actions → Artifacts** 中可下载 `.app.zip`

每次 push 到 main 分支都会自动构建，你可以在 GitHub Actions 页面看到实时日志。

### 4.4 第三步：手动触发构建

1. 在 GitHub 仓库 → **Actions** → **iOS Build** → **Run workflow**
2. 可选择构建类型（simulator / archive）
3. 构建完成后，在 Summary 页面下载产物

### 4.5 第四步：查看构建日志

如果构建失败：
1. GitHub Actions → 点击失败的 job
2. 查看编译错误信息
3. 在 Windows 上修复代码 → push → 自动重新构建

### 4.6 日常开发循环

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│ 1. 编辑代码  │ ──→ │ 2. git push  │ ──→ │ 3. 查看构建   │
│   (VS Code)  │     │   (几分钟)    │     │   (GitHub)    │
└─────────────┘     └──────────────┘     └──────┬───────┘
      ↑                                         │
      │          ┌──────────────┐               │
      └──────────│ 5. 修复问题   │ ←─────────────┘
                 │   (VS Code)  │   4. 下载产物/查看错误
                 └──────────────┘
```

### 4.7 安装到 iPhone 真机

真机构建需要 Apple ID（年报费 ¥688 的开发者账号，或个人免费账号仅支持 7 天签名的开发证书）：

1. 配置 GitHub Secrets（Settings → Secrets and variables → Actions）：
   - `P12_CERTIFICATE_BASE64` — 开发证书
   - `P12_PASSWORD` — 证书密码
   - `MOBILEPROVISION_BASE64` — 描述文件
   - `KEYCHAIN_PASSWORD` — 临时密码（可任意设置）
   - `DEVELOPMENT_TEAM` — 你的 Team ID

2. 将 `ios-build.yml` 中 `build-archive` job 的 `if: false` 改为 `if: true`

3. Push → Build → 下载 .ipa → 通过 TestFlight 或 OTA 安装

---

## 五、代码质量说明

- ✅ **MVVM 架构**：清晰的层次分离
- ✅ **Protocol-Oriented**：服务通过协议定义接口
- ✅ **async/await**：现代 Swift 并发模型
- ✅ **@MainActor**：UI 操作主线程安全
- ✅ **错误处理**：明确的错误类型 + 用户提示
- ✅ **权限声明**：Info.plist 完整权限描述
- ✅ **安全范围访问**：Security-Scoped Bookmark
- ✅ **多编码兼容**：UTF-8/UTF-16/GBK
- ✅ **模块化设计**：单一职责，便于扩展
- ✅ **CI/CD 自动化**：push 即构建

---

## 六、接入真实 API

| 文件 | TODO 位置 | 替换方案 |
|------|-----------|---------|
| `TranslationService.swift` | `mockTranslate()` | Google Translate / DeepL API |
| `SpeechRecognitionService.swift` | `performSpeechRecognition()` | OpenAI Whisper / Google STT |
| `SubtitleParserService.swift` | `readTextFromBlockBuffer()` | 完善 CMBlockBuffer 提取 |
| `Info.plist` | NSAppTransportSecurity | 添加 API 域名白名单 |

代码中已为这些位置标注了完整的 `TODO` 注释和 API 调用示例。

---

## 七、许可

本项目仅供学习和参考使用。

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

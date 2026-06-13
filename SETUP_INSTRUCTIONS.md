# Xcode 项目创建详细步骤

## 方法一：手动创建 Xcode 项目（推荐）

### 1. 创建 Xcode 项目
1. 打开 Xcode 15.0+
2. 菜单栏 → **File → New → Project...**
3. 选择 **iOS → App** → Next
4. 填写：
   ```
   Product Name: SmartChineseSubtitlePlayer
   Team: (选择你的开发者账号，模拟器测试可选 None)
   Organization Identifier: com.yourcompany (可自定义)
   Interface: SwiftUI
   Language: Swift
   Storage: None (不需要 Core Data)
   Include Tests: (可选)
   Minimum Deployment: iOS 17.0
   ```
5. 选择保存路径 → Create

### 2. 删除默认文件
- 在 Xcode 项目导航器中删除 `ContentView.swift` → Move to Trash

### 3. 创建目录结构
在 Xcode 项目导航器中，右键点击 `SmartChineseSubtitlePlayer` 文件夹 → **New Group**，创建以下分组：
```
App
Models
Services
ViewModels
Views
Utils
Resources
```

### 4. 添加源文件
将本项目中 `SmartChineseSubtitlePlayer/` 下各子目录的 `.swift` 文件拖入 Xcode 对应的 Group 中：
- 确保勾选 **"Copy items if needed"**
- 确保勾选 **"Add to targets: SmartChineseSubtitlePlayer"**

### 5. 替换 Info.plist
- 方法 A：在 Xcode 中选中 Target → Info 标签页，手动添加需要的权限键值
- 方法 B：将项目的 Info.plist 拖入 Xcode，然后在 Build Settings 中设置 `INFOPLIST_FILE` 路径

### 6. 运行
- 选择模拟器（iPhone 15 Pro 推荐）
- `Cmd + R` 运行

---

## 方法二：通过命令行创建（高级）

```bash
# 1. 创建项目目录
mkdir -p ~/SmartChineseSubtitlePlayer
cd ~/SmartChineseSubtitlePlayer

# 2. 复制所有源文件
# 将本项目的 SmartChineseSubtitlePlayer/ 目录内容复制到此

# 3. 使用 xcodebuild 创建项目（需要先手动创建 .xcodeproj）
# 或者在 Xcode 中打开文件夹，创建项目后关联文件
```

---

## 必需的权限配置 (Info.plist)

以下键必须添加到 Info.plist 中（已在项目提供的 Info.plist 中配置）：

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>智能中文字幕需要使用语音识别功能，将视频中的音频转换为字幕文字。您的音频数据仅在本地设备处理。</string>

<key>NSMicrophoneUsageDescription</key>
<string>智能中文字幕需要访问麦克风以进行实时语音识别（仅在您主动开启此功能时使用）。</string>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

---

## 常见问题

### Q: 编译错误 "Cannot find 'AVPlayer' in scope"
A: 确保导入了 `AVKit` 和 `AVFoundation` 框架。在 Xcode 中：
- Target → General → Frameworks, Libraries, and Embedded Content
- 添加 `AVKit.framework` 和 `AVFoundation.framework`

实际上 SwiftUI 项目默认已链接这些框架，如果仍然报错：
- Target → Build Phases → Link Binary With Libraries → 添加上述框架

### Q: 语音识别崩溃
A: 模拟器上语音识别功能受限，建议在真机上测试语音识别功能。

### Q: 文件选择器不显示
A: 确保在 iOS 模拟器中添加了测试视频文件：
```bash
xcrun simctl addmedia booted /path/to/video.mp4
```

### Q: 需要设置最小部署目标
A: 在 Xcode 中：
- 选择项目 → Target → General → Minimum Deployments → 设置为 iOS 17.0

### Q: 如何在真机上测试？
A: 
1. 拥有 Apple Developer Program 会员资格
2. 在 Xcode → Preferences → Accounts 中添加 Apple ID
3. 在 Target → Signing & Capabilities 中选择 Team
4. 通过 USB 连接 iPhone
5. 在 iPhone 上：设置 → 通用 → VPN与设备管理 → 信任开发者证书

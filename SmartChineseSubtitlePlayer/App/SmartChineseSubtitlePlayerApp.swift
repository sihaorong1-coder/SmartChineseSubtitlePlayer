import SwiftUI
import AVFoundation

/// App 入口
///
/// ## 架构说明
/// 本 App 采用 MVVM 架构设计：
/// - **Models**: 数据模型层（SubtitleItem, VideoItem, AppSettings）
/// - **Services**: 业务服务层（字幕解析、翻译、语音识别、同步管理）
/// - **ViewModels**: 视图模型层（状态管理、业务逻辑编排）
/// - **Views**: 视图层（SwiftUI 界面）
///
/// ## 权限说明
/// 本 App 需要以下权限（按需请求）：
/// - **语音识别权限** (`NSSpeechRecognitionUsageDescription`):
///   用于将无字幕视频的音频转换为文字
/// - **文件访问权限**: 用于读取用户选择的视频文件（通过系统文件选择器）
/// - **网络使用权限** (`NSAppTransportSecurity`):
///   用于翻译服务和可能的云端语音识别
///
/// ## 隐私保护
/// - 视频文件仅在本地处理，不会上传到任何服务器
/// - 翻译功能仅将字幕文本发送到翻译服务（需要网络）
/// - 语音识别默认使用 Apple 本地引擎，数据不会离开设备
/// - 不收集任何用户数据或使用统计
@main
struct SmartChineseSubtitlePlayerApp: App {

    // MARK: - State

    @StateObject private var settings = AppSettings.shared

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(settings)
                .preferredColorScheme(.none)  // 跟随系统
                .onAppear {
                    configureApp()
                }
        }
    }

    // MARK: - Configuration

    private func configureApp() {
        // 配置音频会话
        configureAudioSession()

        // 配置导航栏外观
        configureNavigationBarAppearance()

        // 配置 TabBar 外观
        configureTabBarAppearance()

        // 打印 App 信息
        logAppInfo()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.allowAirPlay, .allowBluetooth]
            )
        } catch {
            print("[SmartPlayer] Failed to configure audio session: \(error)")
        }
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private func logAppInfo() {
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        print("""
        ┌──────────────────────────────────────┐
        │  智能中文字幕视频播放器                 │
        │  Version: \(version) (Build \(build))       │
        │  Platform: iOS                        │
        │  Min Deployment: iOS 17.0             │
        └──────────────────────────────────────┘
        """)
    }
}

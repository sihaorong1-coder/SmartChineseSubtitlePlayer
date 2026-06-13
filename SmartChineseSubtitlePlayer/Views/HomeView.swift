import SwiftUI
import UniformTypeIdentifiers

/// 首页视图
/// 显示 App 标题、选择视频按钮和最近播放列表
struct HomeView: View {

    // MARK: - Properties

    @StateObject private var viewModel = HomeViewModel()
    @State private var showFilePicker = false
    @State private var showSettings = false
    @State private var selectedVideoURL: URL?
    @State private var navigateToPlayer = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 主内容
                    ScrollView {
                        VStack(spacing: 24) {
                            // App 标题区域
                            headerSection
                                .padding(.top, 20)

                            // 选择视频按钮
                            selectVideoButton
                                .padding(.horizontal, 20)

                            // 最近播放列表
                            recentVideosSection
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToPlayer) {
                if let url = selectedVideoURL {
                    VideoPlayerView(videoURL: url)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            // App 图标
            Image(systemName: "captions.bubble.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, 4)

            // App 标题
            Text("智能中文字幕")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("视频播放器")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            // 功能简述
            Text("自动识别字幕 · 智能翻译 · 语音识别")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Select Video Button

    private var selectVideoButton: some View {
        Button(action: {
            showFilePicker = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("选择视频文件")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Videos Section

    private var recentVideosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Text("最近播放")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if !viewModel.recentVideos.isEmpty {
                    Button("清除") {
                        viewModel.clearHistory()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)

            if viewModel.recentVideos.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("暂无播放记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("选择一个视频文件开始播放")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // 视频列表
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.recentVideos) { video in
                        recentVideoRow(video)
                            .onTapGesture {
                                selectedVideoURL = video.url
                                navigateToPlayer = true
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Recent Video Row

    private func recentVideoRow(_ video: VideoItem) -> some View {
        HStack(spacing: 14) {
            // 缩略图占位
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)

                Image(systemName: "play.rectangle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }

            // 视频信息
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(video.formattedFileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let duration = video.duration {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if video.lastPlaybackPosition > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("已看至 \(video.formattedPlaybackPosition)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(video.lastPlayedDate, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.primary)
            }
        }
    }

    // MARK: - Helpers

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedVideoURL = url
            viewModel.addToRecent(url: url)
            navigateToPlayer = true
        case .failure(let error):
            // 用户取消选择不算错误
            if (error as NSError).code != NSUserCancelledError {
                viewModel.errorMessage = "文件选择失败: \(error.localizedDescription)"
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recentVideos: [VideoItem] = []
    @Published var errorMessage: String?

    private let storageKey = "com.smartplayer.recentVideos"

    init() {
        loadRecentVideos()
    }

    func addToRecent(url: URL) {
        // 检查是否已存在
        if let existingIndex = recentVideos.firstIndex(where: { $0.url == url }) {
            var updated = recentVideos[existingIndex]
            updated.lastPlayedDate = Date()
            recentVideos.remove(at: existingIndex)
            recentVideos.insert(updated, at: 0)
        } else {
            let video = VideoItem(
                url: url,
                title: url.lastPathComponent,
                lastPlayedDate: Date()
            )
            recentVideos.insert(video, at: 0)
        }

        // 最多保留 20 条记录
        if recentVideos.count > 20 {
            recentVideos = Array(recentVideos.prefix(20))
        }

        saveRecentVideos()
    }

    func clearHistory() {
        recentVideos = []
        saveRecentVideos()
    }

    private func loadRecentVideos() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoder = JSONDecoder()
            recentVideos = try decoder.decode([VideoItem].self, from: data)
        } catch {
            // 数据损坏，清除
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    private func saveRecentVideos() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(recentVideos)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            errorMessage = "保存播放记录失败"
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}

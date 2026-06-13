import SwiftUI

/// 字幕控制面板
/// 提供字幕开关、大小调整、位置切换、时间偏移等功能
struct SubtitleControlPanel: View {

    // MARK: - Properties

    @ObservedObject var viewModel: VideoPlayerViewModel
    @ObservedObject var settings: AppSettings

    @State private var showOffsetPresets = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 面板标题
            HStack {
                Image(systemName: "captions.bubble")
                    .foregroundColor(.blue)
                Text("字幕设置")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.showControlPanel = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // 内容区域
            ScrollView {
                VStack(spacing: 20) {
                    // 字幕开关
                    subtitleToggleRow

                    // 字幕大小调整
                    fontSizeRow

                    // 字幕位置
                    positionRow

                    // 时间偏移
                    offsetRow

                    // 预设偏移
                    offsetPresetsRow
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }

            // 底部按钮
            VStack(spacing: 8) {
                Divider()

                Button(action: {
                    Task {
                        await viewModel.reloadSubtitles()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("重新加载字幕")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .frame(maxHeight: 420)
    }

    // MARK: - Subtitle Toggle

    private var subtitleToggleRow: some View {
        HStack {
            Label("显示字幕", systemImage: "captions.bubble")
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Toggle("", isOn: $settings.subtitlesEnabled)
                .labelsHidden()
                .onChange(of: settings.subtitlesEnabled) { newValue in
                    viewModel.subtitleSyncManager.setEnabled(newValue)
                }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground).opacity(0.5))
        )
    }

    // MARK: - Font Size

    private var fontSizeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("字幕大小", systemImage: "textformat.size")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(Int(settings.subtitleFontSize))pt")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            HStack {
                Text("A")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(
                    value: $settings.subtitleFontSize,
                    in: 12...36,
                    step: 1
                )
                .tint(.blue)
                .onChange(of: settings.subtitleFontSize) { newValue in
                    viewModel.subtitleSyncManager.objectWillChange.send()
                }

                Text("A")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground).opacity(0.5))
        )
    }

    // MARK: - Position

    private var positionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("字幕位置", systemImage: "rectangle.topthird.inset.filled")
                .font(.subheadline)
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                ForEach(SubtitlePosition.allCases, id: \.self) { position in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            settings.subtitlePosition = position
                        }
                    }) {
                        Text(position.displayName)
                            .font(.caption)
                            .fontWeight(settings.subtitlePosition == position ? .semibold : .regular)
                            .foregroundColor(settings.subtitlePosition == position ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        settings.subtitlePosition == position
                                        ? Color.blue
                                        : Color(.systemGray5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground).opacity(0.5))
        )
    }

    // MARK: - Offset

    private var offsetRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("时间偏移", systemImage: "clock.arrow.circlepath")
                .font(.subheadline)
                .foregroundColor(.primary)

            HStack {
                Text("\(String(format: "%+.1f", settings.subtitleOffset))秒")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 60, alignment: .leading)

                Spacer()

                // 微调按钮
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.adjustSubtitleOffset(by: -0.5)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }

                    Text("0.5s")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button(action: {
                        viewModel.adjustSubtitleOffset(by: 0.5)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }

            if settings.subtitleOffset != 0 {
                Button("重置偏移") {
                    viewModel.resetSubtitleOffset()
                }
                .font(.caption)
                .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground).opacity(0.5))
        )
    }

    // MARK: - Offset Presets

    private var offsetPresetsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("快捷偏移", systemImage: "clock.badge")
                .font(.subheadline)
                .foregroundColor(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SubtitleOffsetPreset.allCases) { preset in
                        Button(action: {
                            settings.subtitleOffset = preset.timeInterval
                            viewModel.subtitleSyncManager.setTimeOffset(preset.timeInterval)
                        }) {
                            Text(preset.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            abs(settings.subtitleOffset - preset.timeInterval) < 0.01
                                            ? Color.blue.opacity(0.2)
                                            : Color(.systemGray5)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            abs(settings.subtitleOffset - preset.timeInterval) < 0.01
                                            ? Color.blue
                                            : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground).opacity(0.5))
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        SubtitleControlPanel(
            viewModel: VideoPlayerViewModel(),
            settings: AppSettings.shared
        )
        .padding(.horizontal, 20)
    }
}

import SwiftUI

/// 设置页面
/// 管理 App 所有可配置项
struct SettingsView: View {

    // MARK: - Properties

    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirmation = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // MARK: 字幕设置
                Section {
                    // 字幕开关
                    HStack {
                        Label {
                            Text("显示字幕")
                                .foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "captions.bubble")
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        Toggle("", isOn: $viewModel.subtitlesEnabled)
                            .labelsHidden()
                    }

                    // 字幕大小
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("默认字幕大小")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(Int(viewModel.subtitleFontSize))pt")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $viewModel.subtitleFontSize, in: 12...36, step: 1)
                            .tint(.blue)
                    }

                    // 字幕位置
                    Picker(selection: $viewModel.subtitlePosition) {
                        ForEach(SubtitlePosition.allCases, id: \.self) { position in
                            Text(position.displayName).tag(position)
                        }
                    } label: {
                        Label {
                            Text("默认字幕位置")
                        } icon: {
                            Image(systemName: "rectangle.split.3x1")
                                .foregroundColor(.blue)
                        }
                    }

                    // 时间偏移
                    Picker(selection: Binding(
                        get: {
                            SubtitleOffsetPreset.allCases.first { abs($0.timeInterval - viewModel.subtitleOffset) < 0.01 } ?? .normal
                        },
                        set: { viewModel.setOffsetPreset($0) }
                    )) {
                        ForEach(SubtitleOffsetPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    } label: {
                        Label {
                            Text("字幕时间偏移")
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("字幕显示")
                } footer: {
                    Text("字幕将显示在视频画面的指定位置")
                }

                // MARK: 翻译设置
                Section {
                    Toggle(isOn: $viewModel.autoTranslateEnabled) {
                        Label {
                            Text("自动翻译外语字幕")
                        } icon: {
                            Image(systemName: "translate")
                                .foregroundColor(.orange)
                        }
                    }

                    Toggle(isOn: $viewModel.preferLocalSubtitles) {
                        Label {
                            Text("优先使用本地字幕")
                        } icon: {
                            Image(systemName: "doc.text.below.ecg")
                                .foregroundColor(.green)
                        }
                    }
                } header: {
                    Text("翻译设置")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("开启后，App 会自动将检测到的外语字幕翻译为简体中文")
                        if !viewModel.autoTranslateEnabled {
                            Text("关闭后，将直接显示原始字幕语言")
                                .foregroundColor(.orange)
                        }
                    }
                }

                // MARK: 语音识别设置
                Section {
                    Toggle(isOn: $viewModel.speechRecognitionEnabled) {
                        Label {
                            Text("语音识别生成字幕")
                        } icon: {
                            Image(systemName: "waveform.circle")
                                .foregroundColor(.purple)
                        }
                    }
                } header: {
                    Text("语音识别")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("当视频无字幕时，自动通过语音识别生成字幕")
                        Text("注意：语音识别需要网络连接，且可能消耗较长时间")
                            .foregroundColor(.orange)
                        Text("Apple Speech Framework 权限需要在首次使用时授权")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: 隐私与权限
                Section {
                    // 语音识别权限状态
                    PermissionStatusRow(
                        icon: "waveform",
                        color: .purple,
                        title: "语音识别",
                        status: "按需授权"
                    )

                    // 文件访问
                    PermissionStatusRow(
                        icon: "folder",
                        color: .blue,
                        title: "文件访问",
                        status: "按需授权"
                    )

                    // 网络使用
                    PermissionStatusRow(
                        icon: "network",
                        color: .green,
                        title: "网络使用",
                        status: "翻译功能需要"
                    )
                } header: {
                    Text("隐私与权限")
                } footer: {
                    Text("所有权限仅在功能需要时才会请求。我们不会收集或上传您的视频内容。")
                }

                // MARK: 缓存
                Section {
                    HStack {
                        Label {
                            Text("临时文件缓存")
                        } icon: {
                            Image(systemName: "internaldrive")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(viewModel.cacheSizeDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button(role: .destructive) {
                        viewModel.clearCache()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("清除缓存")
                        }
                    }
                } header: {
                    Text("存储")
                } footer: {
                    Text("缓存包括音频提取的临时文件等")
                }

                // MARK: 关于
                Section {
                    HStack {
                        Text("App 名称")
                        Spacer()
                        Text("智能中文字幕视频播放器")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("版本")
                        Spacer()
                        Text("\(viewModel.appVersion) (\(viewModel.buildNumber))")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("关于")
                }

                // MARK: 重置
                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("恢复默认设置")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
            .alert("恢复默认设置", isPresented: $showResetConfirmation) {
                Button("取消", role: .cancel) {}
                Button("确认重置", role: .destructive) {
                    viewModel.resetAllSettings()
                }
            } message: {
                Text("所有设置将恢复为默认值，此操作不可撤销。")
            }
        }
    }
}

// MARK: - Permission Status Row

struct PermissionStatusRow: View {
    let icon: String
    let color: Color
    let title: String
    let status: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 28)

            Text(title)
                .foregroundColor(.primary)

            Spacer()

            Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}

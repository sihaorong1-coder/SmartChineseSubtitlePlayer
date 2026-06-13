import SwiftUI

/// 字幕叠加视图
/// 在视频播放画面上方叠加显示字幕
/// 支持自定义位置、大小和样式
struct SubtitleOverlayView: View {

    // MARK: - Properties

    /// 当前要显示的字幕
    let subtitle: SubtitleItem?

    /// 字幕显示位置
    let position: SubtitlePosition

    /// 字体大小
    let fontSize: CGFloat

    /// 是否显示字幕
    let isVisible: Bool

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            if isVisible, let subtitle = subtitle {
                let displayText = subtitle.displayText
                if !displayText.isEmpty {
                    subtitleTextView(displayText)
                        .frame(maxWidth: geometry.size.width * 0.9)
                        .frame(maxHeight: .infinity, alignment: alignmentForPosition(position))
                        .padding(.horizontal, 20)
                        .padding(.bottom, position == .bottom ? geometry.safeAreaInsets.bottom + 16 : 0)
                        .padding(.top, position == .top ? geometry.safeAreaInsets.top + 16 : 0)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.easeInOut(duration: 0.2), value: subtitle.id)
                }
            }
        }
    }

    // MARK: - Subtitle Text View

    private func subtitleTextView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
    }

    // MARK: - Alignment

    private func alignmentForPosition(_ position: SubtitlePosition) -> Alignment {
        switch position {
        case .top:
            return .top
        case .middle:
            return .center
        case .bottom:
            return .bottom
        }
    }
}

// MARK: - Subtitle Overlay Modifier

/// 视频播放器字幕叠加 ViewModifier
/// 提供便捷的字幕叠加接口
struct SubtitleOverlayModifier: ViewModifier {

    let subtitle: SubtitleItem?
    let position: SubtitlePosition
    let fontSize: CGFloat
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                SubtitleOverlayView(
                    subtitle: subtitle,
                    position: position,
                    fontSize: fontSize,
                    isVisible: isVisible
                )
            }
    }
}

// MARK: - View Extension

extension View {
    /// 为视频播放器添加字幕叠加层
    /// - Parameters:
    ///   - subtitle: 当前字幕
    ///   - position: 字幕位置
    ///   - fontSize: 字体大小
    ///   - isVisible: 是否可见
    func subtitleOverlay(
        subtitle: SubtitleItem?,
        position: SubtitlePosition = .bottom,
        fontSize: CGFloat = 18,
        isVisible: Bool = true
    ) -> some View {
        modifier(SubtitleOverlayModifier(
            subtitle: subtitle,
            position: position,
            fontSize: fontSize,
            isVisible: isVisible
        ))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        SubtitleOverlayView(
            subtitle: SubtitleItem(
                startTime: 0,
                endTime: 3,
                originalText: "Hello, welcome to this video!",
                translatedText: "你好，欢迎观看本视频！",
                language: "en"
            ),
            position: .bottom,
            fontSize: 20,
            isVisible: true
        )
    }
}

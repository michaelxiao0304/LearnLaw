import SwiftUI

extension Color {
    static let actionGreen = Color(red: 0.16, green: 0.48, blue: 0.33)
    static let bamboo = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.37, green: 0.78, blue: 0.60, alpha: 1) : UIColor(red: 0.16, green: 0.48, blue: 0.33, alpha: 1) })
    static let paper = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.06, green: 0.09, blue: 0.08, alpha: 1) : UIColor(red: 0.985, green: 0.985, blue: 0.968, alpha: 1) })
    static let cardSurface = Color(uiColor: .secondarySystemGroupedBackground)
}

struct Page<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { content }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(20)
                .frame(maxWidth: .infinity)
        }.background(Color.paper)
    }
}

struct PaperCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.06)))
    }
}

struct SectionHeading: View {
    let title: String
    var caption: String? = nil
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
            if let caption { Text(caption).font(.subheadline).foregroundStyle(.secondary) }
        }
    }
}

struct ReadingText: View {
    @Environment(Preferences.self) private var preferences
    @ScaledMetric(relativeTo: .body) private var baseSize = 17.0
    let text: String
    var emphasized = false
    var body: some View {
        Text(text)
            .font(.system(size: baseSize * (preferences.largerText ? 1.18 : 1) * (emphasized ? 1.12 : 1)))
            .lineSpacing(baseSize * 0.45)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }
}

enum LegalNotice {
    static let text = "本 App 内容仅为法律知识普及，不构成法律意见。具体法律问题请咨询执业律师或前往法律援助机构（12348 热线）。"
}
struct DisclaimerFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Label("知识普及，不替代专业意见", systemImage: "info.circle").font(.footnote.bold())
            Text(LegalNotice.text).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 12)
    }
}
struct DevelopmentBanner: View {
    var body: some View {
        #if DEVELOPMENT_CONTENT
        Text("开发演示 · 非法律内容")
            .font(.caption.weight(.medium)).foregroundStyle(Color.bamboo)
            .frame(maxWidth: .infinity).padding(.vertical, 6)
            .background(Color.bamboo.opacity(0.08))
            .accessibilityIdentifier("development-banner")
        #endif
    }
}
struct PrimaryAction: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(16)
            .foregroundStyle(.white)
            .background(Color.actionGreen.opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.35), in: RoundedRectangle(cornerRadius: 16))
    }
}

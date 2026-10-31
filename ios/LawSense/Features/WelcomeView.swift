import SwiftUI

struct WelcomeView: View {
    @Environment(Preferences.self) private var preferences
    @State private var agreed = false
    var body: some View {
        Page {
            VStack(alignment: .leading, spacing: 20) {
                Image("BrandIcon").resizable().frame(width: 84, height: 84).clipShape(RoundedRectangle(cornerRadius: 22)).accessibilityHidden(true)
                Text("欢迎来到识法").font(.largeTitle.bold())
                Text("看得懂的法律常识\n从每天一点开始。")
                    .font(.title3).foregroundStyle(.secondary).lineSpacing(8)
            }.padding(.top, 30).padding(.bottom, 12)
            PaperCard {
                Label("开始前，请了解", systemImage: "leaf").font(.headline).foregroundStyle(Color.bamboo)
                ReadingText(text: LegalNotice.text)
                Text("内容随应用版本更新。阅读时请关注来源、施行版本和复核日期；应用不提供咨询、案件评估或个案建议。")
                    .font(.body).foregroundStyle(.secondary)
                Text("学习记录保存在本机，无账号、无上报。您可以自行决定是否使用系统分享等功能。")
                    .font(.body).foregroundStyle(.secondary)
            }
            #if DEVELOPMENT_CONTENT
            Label("当前为开发演示。所有阅读内容均为合成样例，不是法律原文或法律结论。", systemImage: "info.circle")
                .font(.footnote).foregroundStyle(.secondary)
            #endif
            Toggle("我已阅读并知悉以上说明", isOn: $agreed)
                .accessibilityIdentifier("acknowledge-toggle")
            Button("开启学习") { preferences.acknowledge() }
                .buttonStyle(PrimaryAction()).disabled(!agreed).accessibilityIdentifier("start-learning")
            Text("识法 LawSense · 日日拾法，点滴积累")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        }
    }
}

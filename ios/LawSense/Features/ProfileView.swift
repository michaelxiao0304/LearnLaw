import SwiftUI

struct ProfileView: View {
    @Environment(UserStore.self) private var user
    let catalog: ContentCatalog
    var body: some View {
        Page(lazy: true) {
            HStack(spacing: 20) {
                Image("BrandIcon").resizable().frame(width: 68, height: 68).clipShape(RoundedRectangle(cornerRadius: 18)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text("做生活里的明白人").font(.title2.bold())
                    Text("无需账号，学习留在本机").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            HStack {
                StatView(value: "\(user.completed.count)", label: "学过的卡片")
                StatView(value: "\(user.attempts.count)", label: "完成练习")
                StatView(value: "\(user.bookmarks.count)", label: "我的收藏")
            }.padding(.vertical, 18)
            PaperCard {
                profileLink("我的收藏", symbol: "bookmark", route: .bookmarks)
                Divider()
                profileLink("错题本", symbol: "arrow.counterclockwise", route: .wrongQuestions)
                Divider()
                profileLink("阅读与设置", symbol: "slider.horizontal.3", route: .settings)
            }
            SectionHeading(title: "学习足迹", caption: "每一次认真阅读，都是积累")
            let learned = catalog.cards.filter { user.completed.contains("\($0.id):\($0.revision)") }
            if learned.isEmpty { Text("完成一张知识卡的小测验，再点击“完成学习”，它就会留在这里。").foregroundStyle(.secondary) }
            ForEach(learned) { card in NavigationLink(value: Route.card(card.id)) { KnowledgeCardRow(card: card) }.buttonStyle(.plain) }
        }.navigationTitle("我的")
    }
    private func profileLink(_ title: String, symbol: String, route: Route) -> some View {
        NavigationLink(value: route) {
            HStack { Label(title, systemImage: symbol); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                .padding(.vertical, 10).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

struct BookmarksView: View {
    @Environment(UserStore.self) private var user
    let catalog: ContentCatalog
    var body: some View {
        Page(lazy: true) {
            if user.bookmarks.isEmpty { ContentUnavailableView("把想重读的，留在这里", systemImage: "bookmark", description: Text("在知识卡或原文页面点一下收藏。")) }
            ForEach(user.bookmarks) { bookmark in
                if bookmark.kind == "card", let card = catalog.card(bookmark.target) {
                    NavigationLink(value: Route.card(card.id)) { KnowledgeCardRow(card: card) }.buttonStyle(.plain)
                } else if let article = catalog.articles.first(where: { $0.id == bookmark.target }) { ArticleLink(article: article) }
                else { PaperCard { Text(bookmark.title); Text("原收藏内容已更新，记录仍保留。").font(.footnote).foregroundStyle(.secondary) } }
            }
        }.navigationTitle("我的收藏")
    }
}

struct SettingsView: View {
    @Environment(UserStore.self) private var user
    @Environment(AppModel.self) private var app
    @State private var clearingLearning = false
    @State private var clearingBookmarks = false
    @Environment(Preferences.self) private var preferences
    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section("舒适阅读") {
                Toggle("更大的正文", isOn: $preferences.largerText)
                Text("与系统动态字号共同生效。").font(.footnote).foregroundStyle(.secondary)
            }
            Section("每日一题") { NavigationLink("每日提醒") { ReminderSettingsView() } }
            Section("语音朗读") {
                Slider(value: $preferences.speechRate, in: 0.3...0.6, step: 0.05) { Text("朗读语速") }
                HStack { Text("慢一些"); Spacer(); Text("快一些") }.font(.caption).foregroundStyle(.secondary)
                SpeechControls(text: "欢迎来到识法。日日拾法，点滴积累。")
            }
            Section("隐私说明") {
                NavigationLink("隐私政策与本地数据说明") { PrivacyPolicyView() }
            }
            Section("本地记录管理") {
                Toggle("记录学习日期与连续天数", isOn: $preferences.recordsStudyDays)
                    .onChange(of: preferences.recordsStudyDays) { _, enabled in user.recordsStudyDays = enabled }
                Text("关闭后不再新增学习日期；收藏、答题、错题和关卡进度仍按功能需要在本机保存。已有记录可在下方清除。").font(.footnote)
                Button("清除学习记录", role: .destructive) { clearingLearning = true }
                    .disabled(user.isReadOnly)
                Button("清除全部收藏", role: .destructive) { clearingBookmarks = true }
                    .disabled(user.isReadOnly)
                Text("两项分别清除，执行前会再次确认。不会改变字号、语速或免责声明确认。").font(.footnote)
            }
            Section("使用声明") { Text(LegalNotice.text); Text("声明版本：\(Preferences.disclaimerVersion)").font(.caption).foregroundStyle(.secondary) }
            Section { HStack { Text("识法 LawSense"); Spacer(); Text("0.1.0").foregroundStyle(.secondary) } }
        }.scrollContentBackground(.hidden).background(Color.paper).navigationTitle("阅读与设置")
        .alert("清除答题、错题及学习进度？", isPresented: $clearingLearning) {
            Button("取消", role: .cancel) { }
            Button("确认清除学习记录", role: .destructive) { app.perform { try user.clearLearning() }; app.refreshDay() }
        } message: { Text("此操作无法撤销，收藏会保留。") }
        .alert("清除全部收藏？", isPresented: $clearingBookmarks) {
            Button("取消", role: .cancel) { }
            Button("确认清除全部收藏", role: .destructive) { app.perform { try user.clearBookmarks() } }
        } message: { Text("此操作无法撤销，学习记录会保留。") }
    }
}

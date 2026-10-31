import SwiftUI
import AVFoundation

@main struct LawSenseApp: App {
    @State private var app = AppModel()
    @State private var preferences = Preferences()
    @State private var speech = SpeechService()
    @State private var reminder = ReminderService()
    @State private var notificationRouter = NotificationRouter()
    var body: some Scene {
        WindowGroup {
            LaunchView().environment(app).environment(preferences).environment(speech).environment(reminder).environment(notificationRouter)
                .tint(.bamboo)
        }
    }
}

struct LaunchView: View {
    @Environment(AppModel.self) private var app
    @Environment(Preferences.self) private var preferences
    @Environment(SpeechService.self) private var speech
    @Environment(ReminderService.self) private var reminder
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        @Bindable var app = app
        Group {
            if !preferences.acknowledged { WelcomeView() }
            else if let catalog = app.catalog, let user = app.user {
                RootTabs(catalog: catalog).environment(user)
            } else {
                VStack(spacing: 24) {
                    Image("BrandIcon").resizable().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 18)).accessibilityHidden(true)
                    if let error = app.loadError {
                        Text("暂时无法打开内容").font(.title2.bold())
                        Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("重试") { Task { await app.load() } }.buttonStyle(.borderedProminent)
                    } else { ProgressView("正在准备识法…") }
                }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.paper)
            }
        }
        .task(id: preferences.acknowledged) {
            if preferences.acknowledged {
                if app.catalog == nil { await app.load() }
                await reminder.synchronize(preferences.reminderSettings)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { app.refreshDay(); Task { await reminder.synchronize(preferences.reminderSettings) } } else { speech.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in speech.stop() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in app.refreshDay() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in app.refreshDay() }
        .alert("请再试一次", isPresented: Binding(get: { app.actionError != nil }, set: { if !$0 { app.actionError = nil } })) {
            Button("知道了") { app.actionError = nil }
        } message: { Text(app.actionError ?? "") }
    }
}

enum Route: Hashable {
    case card(String)
    case article(ArticleReference)
    case quiz(String, String)
    case bookmarks
    case wrongQuestions
    case settings
}

struct RootTabs: View {
    @Environment(NotificationRouter.self) private var notificationRouter
    @State private var dailyPresented = false
    @Environment(AppModel.self) private var app
    let catalog: ContentCatalog
    var body: some View {
        VStack(spacing: 0) {
            DevelopmentBanner()
            if app.userStorageError != nil {
                VStack {
                    Text("只读模式：用户记录暂时无法打开，原数据已保留。")
                    Button("重试打开记录") { Task { await app.load() } }
                }.font(.footnote).padding(8)
            }
            TabView {
                FeatureNavigation { HomeView(catalog: catalog) }.tabItem { Label("今日", systemImage: "leaf") }
                FeatureNavigation { LearnView(catalog: catalog) }.tabItem { Label("学法堂", systemImage: "book") }
                if let index = app.searchIndex { LawLibraryView(catalog: catalog, index: index).tabItem { Label("查法条", systemImage: "text.magnifyingglass") } }
                FeatureNavigation { PracticeView(catalog: catalog) }.tabItem { Label("练习场", systemImage: "checkmark.circle") }
                FeatureNavigation { ProfileView(catalog: catalog) }.tabItem { Label("我的", systemImage: "person.crop.circle") }
            }
        }.background(Color.paper)
        .onChange(of: notificationRouter.openDaily, initial: true) { _, open in
            if open { app.refreshDay(); dailyPresented = true; notificationRouter.openDaily = false }
        }
        .sheet(isPresented: $dailyPresented) {
            NavigationStack {
                Group {
                    if let question = app.todayQuestion { QuizView(question: question, mode: "daily", catalog: catalog) }
                    else { ContentUnavailableView("今日内容已更新", systemImage: "book.closed", description: Text("请返回目录查看当前内容。")) }
                }.navigationDestination(for: Route.self) { DestinationView(route: $0) }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dailyPresented = false } } }
            }
        }
    }
}

struct FeatureNavigation<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var path: [Route] = []
    var body: some View {
        NavigationStack(path: $path) {
            content.navigationDestination(for: Route.self) { DestinationView(route: $0) }
        }
    }
}

struct DestinationView: View {
    @Environment(AppModel.self) private var app
    let route: Route
    var body: some View {
        if let catalog = app.catalog {
            switch route {
            case .card(let id):
                if let card = catalog.card(id) { CardDetailView(card: card, catalog: catalog) } else { missing }
            case .article(let ref):
                if let article = catalog.article(ref) { ArticleDetailView(article: article, catalog: catalog) } else { missing }
            case .quiz(let id, let mode):
                if let question = catalog.question(id) { QuizView(question: question, mode: mode, catalog: catalog) } else { missing }
            case .bookmarks: BookmarksView(catalog: catalog)
            case .wrongQuestions: WrongQuestionsView(catalog: catalog)
            case .settings: SettingsView()
            }
        }
    }
    private var missing: some View { ContentUnavailableView("内容已更新", systemImage: "book.closed", description: Text("请返回目录查看当前版本。")) }
}

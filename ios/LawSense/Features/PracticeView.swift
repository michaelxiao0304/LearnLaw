import SwiftUI

struct PracticeView: View {
    @Environment(AppModel.self) private var app
    @Environment(UserStore.self) private var user
    let catalog: ContentCatalog
    var body: some View {
        Page(lazy: true) {
            SectionHeading(title: "把读过的，变成懂得的", caption: "认真想一想，答错也有收获")
            if let question = app.todayQuestion {
                PaperCard {
                    Label("今日一题", systemImage: "sun.max").foregroundStyle(Color.bamboo)
                    Text(question.prompt).font(.title2.bold())
                    NavigationLink("开始练习", value: Route.quiz(question.id, "daily")).buttonStyle(PrimaryAction())
                }
            }
            NavigationLink(value: Route.wrongQuestions) {
                PaperCard {
                    HStack {
                        Label("错题本", systemImage: "arrow.counterclockwise").font(.headline)
                        Spacer()
                        Text("\(user.wrongQuestions(in: catalog, onlyPending: true).count) 题待复习").font(.subheadline).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption)
                    }
                }
            }.buttonStyle(.plain)
            if let plan = app.coursePlan {
                NavigationLink("学习路径与称号") { CourseListView(plan: plan, catalog: catalog) }
                    .buttonStyle(.borderedProminent)
            }
            SectionHeading(title: "随时练一练")
            ForEach(catalog.questions) { question in
                NavigationLink(value: Route.quiz(question.id, "practice")) {
                    PaperCard {
                        Text(catalog.card(question.cardId)?.topic ?? "阅读练习").font(.caption).foregroundStyle(Color.bamboo)
                        Text(question.prompt).font(.headline)
                        Label("单选 · 查看依据", systemImage: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                    }
                }.buttonStyle(.plain)
            }
        }.navigationTitle("练习场")
    }
}

struct QuizView: View {
    @Environment(AppModel.self) private var app
    @Environment(UserStore.self) private var user
    let question: Question
    let mode: String
    let catalog: ContentCatalog
    private let cardID: String?
    private let onSelection: ((String) -> Void)?
    private let onContinue: (() -> Void)?
    @State private var attemptID: String
    @State private var selected: String?
    @State private var saved: SavedAttempt?
    @State private var completed = false
    @AccessibilityFocusState private var resultFocused: Bool

    init(question: Question, mode: String, catalog: ContentCatalog, cardID: String? = nil, attemptID: String? = nil,
         initialSelection: String? = nil, onSelection: ((String) -> Void)? = nil, onContinue: (() -> Void)? = nil) {
        self.question = question; self.mode = mode; self.catalog = catalog
        self.cardID = cardID
        self.onSelection = onSelection; self.onContinue = onContinue
        _selected = State(initialValue: initialSelection)
        _attemptID = State(initialValue: attemptID ?? (mode == "daily" ? "daily:\(LearningRules.dayKey(.now, timeZone: .current)):\(question.identity)" : UUID().uuidString))
    }
    var body: some View {
        Page(lazy: true) {
            Text(mode == "daily" ? "今日一题" : mode == "review" ? "错题复习" : "巩固理解")
                .font(.subheadline.bold()).foregroundStyle(Color.bamboo)
            Text(question.prompt).font(.title.bold()).fixedSize(horizontal: false, vertical: true)
            Text("选择一个答案").font(.subheadline).foregroundStyle(.secondary)
            ForEach(question.options) { option in
                Button { selected = option.id; onSelection?(option.id) } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: selected == option.id ? "checkmark.circle.fill" : "circle").foregroundStyle(Color.bamboo)
                        Text(option.text).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                    }.font(.body).padding(20)
                        .background(selected == option.id ? Color.bamboo.opacity(0.10) : Color.cardSurface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected == option.id ? Color.bamboo : Color.primary.opacity(0.08)))
                }.disabled(saved != nil).accessibilityIdentifier("option-\(option.id)")
                    .accessibilityAddTraits(selected == option.id ? .isSelected : [])
            }
            if let saved {
                PaperCard {
                    Label(saved.correct ? "答对了，继续保持" : "没关系，看看依据", systemImage: saved.correct ? "checkmark.circle.fill" : "arrow.counterclockwise")
                        .font(.headline).foregroundStyle(Color.bamboo).accessibilityFocused($resultFocused)
                    ReadingText(text: question.explanation)
                    Text("正确答案：\(question.options.first { $0.id == question.correctOptionId }?.text ?? "")").font(.subheadline.bold())
                    ForEach(question.articleRefs, id: \.self) { ref in
                        if let article = catalog.article(ref) {
                            if !saved.correct { ReadingText(text: article.text) }
                            ArticleLink(article: article)
                        }
                    }
                }.accessibilityIdentifier("answer-explanation")
                if let card = catalog.card(cardID ?? question.cardId) {
                    Button(completed ? "已完成学习" : "完成学习") {
                        app.perform { try user.complete(card: card, question: question, attemptID: attemptID); completed = true }
                    }.buttonStyle(PrimaryAction()).disabled(completed).accessibilityIdentifier("finish-learning")
                    NavigationLink("回到知识卡复习", value: Route.card(card.id)).frame(maxWidth: .infinity).padding(12)
                }
                if let onContinue { Button("继续关卡", action: onContinue).buttonStyle(PrimaryAction()).accessibilityIdentifier("course-next") }
                if let reviewed = question.reviewedAt { Text("复核至 " + String(reviewed.prefix(7))).font(.footnote) }
                NavigationLink("内容纠错") { FeedbackView(contentID: "\(question.id):\(question.revision)", packageID: catalog.packageId) }
                DisclaimerFooter()
            } else {
                Button("提交答案", action: submit).buttonStyle(PrimaryAction()).disabled(selected == nil).accessibilityIdentifier("submit-answer")
            }
        }.navigationTitle("小测验").navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let attempt = user.attempts.first(where: { $0.id == attemptID }) { saved = attempt; selected = attempt.selected }
                if let card = catalog.card(cardID ?? question.cardId) { completed = user.completed.contains("\(card.id):\(card.revision)") }
            }
    }
    private func submit() {
        guard let selected, saved == nil else { return }
        app.perform {
            saved = try user.submit(id: attemptID, question: question, selected: selected, mode: mode)
            resultFocused = true
        }
    }
}

struct WrongQuestionsView: View {
    @Environment(UserStore.self) private var user
    let catalog: ContentCatalog
    @State private var onlyPending = true
    var body: some View {
        Page(lazy: true) {
            Toggle("只看待复习", isOn: $onlyPending)
            if user.unavailableWrongCount(in: catalog) > 0 {
                Text("另有 \(user.unavailableWrongCount(in: catalog)) 道旧版本错题，记录仍保留；当前内容包不再包含原题，未计作新版已掌握。").font(.footnote).foregroundStyle(.secondary)
            }
            let questions = user.wrongQuestions(in: catalog, onlyPending: onlyPending)
            if questions.isEmpty {
                ContentUnavailableView("这里暂时没有错题", systemImage: "checkmark.seal", description: Text("答错的题会自动收录，在这里回看依据。"))
            }
            ForEach(questions) { question in
                NavigationLink(value: Route.quiz(question.id, "review")) {
                    PaperCard { Text(question.prompt).font(.headline); Text("重新练习，回到依据").font(.subheadline).foregroundStyle(.secondary) }
                }.buttonStyle(.plain)
            }
        }.navigationTitle("错题本")
    }
}

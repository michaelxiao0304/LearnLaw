import SwiftUI

struct CourseListView: View {
    @Environment(UserStore.self) private var user
    let plan: CoursePlan
    let catalog: ContentCatalog
    var body: some View {
        Page(lazy: true) {
            Text("当前称号：\(plan.rank(passed: user.passedLevels(in: plan))?.title ?? "正在起步")").font(.title2.bold())
            Text("称号仅记录学习进度，不代表法律专业能力。每关正确率达到 80% 后解锁后续关卡。").foregroundStyle(.secondary)
            #if DEVELOPMENT_CONTENT
            Text("开发关卡使用合成阅读题，每关 2 题；正式课程每关至少 10 题，并须完成内容审核。").font(.footnote)
            #endif
            ForEach(plan.levels) { level in
                let unlocked = plan.isUnlocked(level, passed: user.passedLevels(in: plan))
                NavigationLink {
                    CourseSessionView(level: level, plan: plan, catalog: catalog)
                } label: {
                    PaperCard {
                        Label(level.title, systemImage: user.passedLevels(in: plan).contains(level.id) ? "checkmark.seal" : unlocked ? "book" : "lock")
                        Text(level.rank.title + " · \(level.questionIDs.count) 题").font(.subheadline).foregroundStyle(.secondary)
                    }
                }.buttonStyle(.plain).disabled(!unlocked || user.isReadOnly)
                    .accessibilityIdentifier("course-\(level.id)")
            }
        }.navigationTitle("学习路径")
    }
}

struct CourseSessionView: View {
    @Environment(UserStore.self) private var user
    @Environment(AppModel.self) private var app
    let level: CourseLevel
    let plan: CoursePlan
    let catalog: ContentCatalog
    @State private var session: CourseSession?
    @State private var restart = false
    var body: some View {
        Group {
            if let session {
                if session.finished {
                    Page {
                        let correct = user.score(session)
                        Text(LearningRules.isPassing(correct: correct, total: session.questions.count) ? "本关已通过" : "再读一读，再试一次").font(.title.bold())
                        Text("答对 \(correct) / \(session.questions.count) 题")
                        Text("当前称号：\(plan.rank(passed: user.passedLevels(in: plan))?.title ?? "正在起步")")
                        Button("重新练习") { restart = true }.buttonStyle(.borderedProminent)
                        DisclaimerFooter()
                    }
                } else if let question = currentQuestion(session) {
                    VStack(spacing: 0) {
                        Text("第 \(session.position + 1) / \(session.questions.count) 题 · 进度自动保存在本机").font(.footnote).padding(8)
                        QuizView(question: question, mode: "course", catalog: catalog,
                            attemptID: session.attemptID(at: session.position), initialSelection: session.selected,
                            onSelection: { choice in
                                var updated = session; updated.selected = choice
                                app.perform { try user.saveSession(updated); self.session = updated }
                            }, onContinue: {
                                app.perform { self.session = try user.advanceCourse(session) }
                            }).id(session.position)
                    }
                } else {
                    Page {
                        Text("本关内容版本已更新，旧答题记录仍保留。")
                        Button("使用当前内容重新开始") { restart = true }
                    }
                }
            } else {
                ContentUnavailableView("尚未开始本关", systemImage: "book", description: Text("学习进度会保存在本机。"))
                Button("开始本关") { start() }.buttonStyle(.borderedProminent).disabled(user.isReadOnly)
            }
        }.navigationTitle(level.title)
            .onAppear { if session == nil { session = user.sessions[CourseSession.key(planID: plan.id, levelID: level.id)] } }
            .alert("重新开始本关？", isPresented: $restart) {
                Button("取消", role: .cancel) { }
                Button("重新开始") { start(restarting: true) }
            } message: { Text("当前会话将被替换，以前的答题及通关记录保留。") }
    }
    private func currentQuestion(_ session: CourseSession) -> Question? {
        guard session.questions.indices.contains(session.position) else { return nil }
        let version = session.questions[session.position]
        guard let question = catalog.question(version.id), question.revision == version.revision else { return nil }
        return question
    }
    private func start(restarting: Bool = false) {
        app.perform { session = try user.startCourse(level, plan: plan, catalog: catalog, restart: restarting) }
    }
}

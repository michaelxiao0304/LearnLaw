import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(UserStore.self) private var user
    let catalog: ContentCatalog
    var body: some View {
        Page {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide))).font(.subheadline).foregroundStyle(.secondary)
                    Text("日日识法，\n慢慢懂得。").font(.largeTitle.weight(.semibold)).lineSpacing(6)
                }
                Spacer()
                Image("BrandMark").resizable().scaledToFit().frame(width: 88, height: 88).accessibilityHidden(true)
            }
            if let question = app.todayQuestion {
                PaperCard {
                    Label("今日一题", systemImage: "sun.max").font(.subheadline.bold()).foregroundStyle(Color.bamboo)
                    Text(question.prompt).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                    Text("花一分钟，让理解再深一点。").foregroundStyle(.secondary)
                    NavigationLink(value: Route.quiz(question.id, "daily")) {
                        HStack { Text("开始今日练习"); Spacer(); Image(systemName: "arrow.right") }
                    }.buttonStyle(PrimaryAction()).accessibilityIdentifier("daily-question")
                }
            }
            HStack {
                StatView(value: "\(user.completed.count)", label: "已学知识卡")
                Divider()
                StatView(value: "\(LearningRules.streak(days: user.studyDays, now: .now, timeZone: .current))", label: "连续学习天")
            }.padding(20).background(Color.bamboo.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
            SectionHeading(title: "从生活里，认识法律", caption: "读一个场景，再看它的依据")
            ForEach(catalog.cards.prefix(3)) { card in
                NavigationLink(value: Route.card(card.id)) { KnowledgeCardRow(card: card) }.accessibilityIdentifier("card-link-\(card.id)")
                    .buttonStyle(.plain)
            }
            Text("每一点理解，都算数。")
                .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 8)
        }.navigationTitle("识法").navigationBarTitleDisplayMode(.inline)
    }
}

struct StatView: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 6) {
            Text(value).font(.title.bold()).foregroundStyle(Color.bamboo)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
}

struct KnowledgeCardRow: View {
    let card: KnowledgeCard
    var body: some View {
        PaperCard {
            HStack {
                Text(card.topic).font(.caption.weight(.medium)).foregroundStyle(Color.bamboo)
                Spacer()
                Text("\(card.minutes) 分钟").font(.caption).foregroundStyle(.secondary)
            }
            Text(card.title).font(.headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top) {
                Text(card.conclusion).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(Color.bamboo).accessibilityHidden(true)
            }
        }.accessibilityElement(children: .combine)
    }
}

import SwiftUI

struct CardDetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(UserStore.self) private var user
    @Environment(SpeechService.self) private var speech
    let card: KnowledgeCard
    let catalog: ContentCatalog
    private var conclusionLabel: String {
        switch card.category { case "unlawful": "违法"; case "possibly_unlawful": "可能违法"; case "attention": "注意"; default: "先记住这一点" }
    }
    var body: some View {
        Page {
            Text(card.topic).font(.subheadline.bold()).foregroundStyle(Color.bamboo)
            Text(card.title).font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
            PaperCard {
                Label {
                    Text(conclusionLabel).foregroundStyle(.primary)
                } icon: { Image(systemName: card.category == "unlawful" ? "exclamationmark.octagon" : card.category == "possibly_unlawful" ? "exclamationmark.triangle" : "leaf.fill").foregroundStyle(card.category == "unlawful" ? Color.orange : card.category == "possibly_unlawful" ? Color.yellow : Color.bamboo) }
                    .font(.subheadline.bold())
                ReadingText(text: card.conclusion, emphasized: true)
            }
            SectionHeading(title: "一个小场景", caption: card.scenarioLabel ?? "典型情境示例 · 开发阅读练习")
            ReadingText(text: card.story)
            SectionHeading(title: "拆开来看")
            ForEach(Array(card.points.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: 14) {
                    Text(String(index + 1)).font(.subheadline.bold()).foregroundStyle(Color.bamboo).padding(8).background(Color.bamboo.opacity(0.08), in: Circle())
                    VStack(alignment: .leading) {
                        ReadingText(text: point)
                        if let refs = card.pointReferences, refs.indices.contains(index) {
                            ForEach(refs[index], id: \.self) { ref in
                                if let article = catalog.article(ref) { ArticleLink(article: article) }
                            }
                        }
                    }
                }
            }
            SpeechControls(text: ([card.title, card.conclusion, card.story] + card.points + [card.misconception]).joined(separator: "。"))
            if let consequences = card.consequences {
                ForEach(Array(consequences.enumerated()), id: \.offset) { _, consequence in
                    PaperCard {
                        Text("法条后果原文").font(.headline)
                        ReadingText(text: consequence.quote)
                        if let article = catalog.article(consequence.articleRef) { ArticleLink(article: article) }
                    }
                }
            }
            SectionHeading(title: "看看依据")
            ForEach(card.articleRefs, id: \.self) { ref in
                if let article = catalog.article(ref) { ArticleLink(article: article) }
            }
            PaperCard {
                Label("容易忽略的地方", systemImage: "lightbulb").font(.headline)
                ReadingText(text: card.misconception)
            }
            NavigationLink(value: Route.quiz(card.questionId, "card", cardID: card.id)) {
                Label("用一道题巩固理解", systemImage: "checkmark.circle")
            }.buttonStyle(PrimaryAction()).accessibilityIdentifier("card-quiz")
            ForEach(card.quizIDs.dropFirst(), id: \.self) { id in
                if let question = catalog.question(id) { NavigationLink(question.prompt, value: Route.quiz(id, "card", cardID: card.id)) }
            }
            if let reviewed = card.reviewedAt { Text("复核至 " + String(reviewed.prefix(7))).font(.footnote) }
            Text("来源：" + (card.source ?? "识法开发阅读样例 · 非法律内容")).font(.footnote).foregroundStyle(.secondary)
            NavigationLink("内容纠错") { FeedbackView(contentID: "\(card.id):\(card.revision)", packageID: catalog.packageId) }
            DisclaimerFooter()
        }
        .navigationTitle("知识卡").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BookmarkButton(saved: user.isBookmarked(kind: "card", target: card.id)) {
                    app.perform { try user.toggleBookmark(kind: "card", target: card.id, title: card.title, revision: card.revision) }
                }
            }
        }.onDisappear { speech.stop() }
    }
}

struct ArticleLink: View {
    let article: Article
    var body: some View {
        NavigationLink(value: Route.article(article.reference)) {
            HStack {
                Image(systemName: "text.book.closed").foregroundStyle(Color.bamboo)
                VStack(alignment: .leading) { Text(article.number + " · " + article.title).font(.subheadline.bold()); Text(article.versionLabel).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Image(systemName: "chevron.right").font(.caption)
            }.padding(16).background(Color.bamboo.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
    }
}

struct ArticleDetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(UserStore.self) private var user
    @Environment(SpeechService.self) private var speech
    let article: Article
    let catalog: ContentCatalog
    @State private var copied = false
    var body: some View {
        Page {
            Text(catalog.laws.first { $0.id == article.reference.lawId }?.title ?? "内容").font(.subheadline.bold()).foregroundStyle(Color.bamboo)
            Text(article.number).font(.largeTitle.bold())
            Text(article.title).font(.title2)
            Label(article.versionLabel, systemImage: "clock").font(.footnote).foregroundStyle(.secondary)
            PaperCard { ReadingText(text: article.text, emphasized: true).accessibilityIdentifier("article-original") }
            HStack {
                Button { UIPasteboard.general.string = article.text; copied = true } label: { Label(copied ? "已复制" : "复制原文", systemImage: copied ? "checkmark" : "doc.on.doc") }.buttonStyle(.bordered)
                Spacer()
                BookmarkButton(saved: user.isBookmarked(kind: "article", target: article.id)) {
                    app.perform { try user.toggleBookmark(kind: "article", target: article.id, title: article.number + " · " + article.title) }
                }
            }
            SpeechControls(text: article.text)
            Text("来源：\(article.source)").font(.footnote).foregroundStyle(.secondary)
            if !catalog.cards.filter({ $0.articleRefs.contains(article.reference) }).isEmpty {
                DisclosureGroup("关联白话解读") {
                    ForEach(catalog.cards.filter { $0.articleRefs.contains(article.reference) }) { card in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(card.title).font(.headline)
                            ForEach(Array(card.points.enumerated()), id: \.offset) { _, point in ReadingText(text: point) }
                        }.padding(.vertical, 8)
                    }
                }
            }
            SectionHeading(title: "一起读，更好懂")
            ForEach(catalog.cards.filter { $0.articleRefs.contains(article.reference) }) { card in
                NavigationLink(value: Route.card(card.id)) { KnowledgeCardRow(card: card) }.buttonStyle(.plain)
            }
            NavigationLink("生成原文分享图") { ShareArticleView(article: article) }
            NavigationLink("内容纠错") { FeedbackView(contentID: article.id, packageID: catalog.packageId) }
            DisclaimerFooter()
        }.navigationTitle("原文阅读").navigationBarTitleDisplayMode(.inline).onDisappear { speech.stop() }
    }
}

struct BookmarkButton: View {
    let saved: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) { Label(saved ? "取消收藏" : "收藏", systemImage: saved ? "bookmark.fill" : "bookmark").labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44) }
            .accessibilityIdentifier("bookmark-button")
    }
}

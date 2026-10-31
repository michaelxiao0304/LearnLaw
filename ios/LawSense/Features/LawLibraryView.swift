import SwiftUI

struct LawLibraryView: View {
    let catalog: ContentCatalog
    let index: ContentSearch
    @State private var query = ""
    @State private var lawId = ""
    @State private var selection: ArticleReference?
    @State private var results: [Article] = []
    @State private var searching = false
    private var requestKey: String { lawId + "\n" + query }
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    Picker("篇目", selection: $lawId) {
                        Text("全部篇目").tag("")
                        ForEach(catalog.laws) { Text($0.title).tag($0.id) }
                    }
                }
                if !query.isEmpty {
                    ForEach(index.suggestions(for: query), id: \.self) { suggestion in
                        Button(suggestion) { query = suggestion }
                    }
                }
                Section(query.isEmpty ? "按篇目阅读" : "检索结果") {
                    if query.count > 100 { Text("关键词请控制在 100 字以内。").foregroundStyle(.secondary) }
                    else if searching { ProgressView("查找中…") }
                    else if results.isEmpty {
                        ContentUnavailableView.search(text: query)
                    } else {
                        ForEach(results) { article in
                            NavigationLink(value: article.reference) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(article.number + " · " + article.title).font(.headline)
                                    Text((catalog.laws.first { $0.id == article.reference.lawId }?.title ?? "") + " · 开发阅读样例")
                                        .font(.caption).foregroundStyle(.secondary)
                                }.padding(.vertical, 6)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Color.paper)
            .navigationTitle("查法条")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "输入关键词或条号")
            .task(id: requestKey) { await search() }
        } detail: {
            NavigationStack {
                Group {
                    if let selection, let article = catalog.article(selection) { ArticleDetailView(article: article, catalog: catalog) }
                    else { ContentUnavailableView("读原文，也读懂它", systemImage: "text.book.closed", description: Text("从左侧选择一条内容，开始阅读。")) }
                }.navigationDestination(for: Route.self) { DestinationView(route: $0) }
            }
        }
    }
    private func search() async {
        searching = true
        do {
            try await Task.sleep(for: .milliseconds(150))
            let found = await Self.find(index: index, query: query, lawId: lawId)
            try Task.checkCancellation()
            results = found; searching = false
        } catch is CancellationError { }
        catch { searching = false }
    }
    @concurrent private static func find(index: ContentSearch, query: String, lawId: String) async -> [Article] {
        guard query.count <= 100 else { return [] }
        return index.articles(query: query, lawId: lawId.isEmpty ? nil : lawId)
    }
}

import SwiftUI

struct ShareArticleView: View {
    let article: Article
    @State private var files: [URL] = []
    @State private var error: String?
    @State private var preparing = false
    @State private var selectedPage = 0
    @State private var preview: UIImage?
    var body: some View {
        List {
            Section("原文分享") {
                Text("逐页生成完整原文，每页保留版本、来源和免责声明。请分享全部页面，避免遗漏条件。")
                Text(article.number + " · " + article.versionLabel).font(.subheadline)
            }
            if preparing { ProgressView("正在生成分享图片…") }
            if let error { Text(error); Button("重试") { Task { await prepare() } } }
            if !files.isEmpty {
                Text("共 \(files.count) 页，原文未删节。")
                if files.count > 1 {
                    Picker("预览页", selection: $selectedPage) {
                        ForEach(files.indices, id: \.self) { Text("第 \($0 + 1) 页").tag($0) }
                    }
                }
                if let preview { Image(uiImage: preview).resizable().scaledToFit().accessibilityLabel("原文分享图预览，第 \(selectedPage + 1) 页") }
                ShareLink(items: files) { Label("分享全部图片", systemImage: "square.and.arrow.up") }
            }
        }.navigationTitle("分享原文").task { await prepare() }
            .onChange(of: files) { _, _ in loadPreview() }
            .onChange(of: selectedPage) { _, _ in loadPreview() }
    }
    private func loadPreview() {
        guard files.indices.contains(selectedPage) else { preview = nil; return }
        preview = UIImage(contentsOfFile: files[selectedPage].path)
    }
    @MainActor private func prepare() async {
        guard files.isEmpty, !preparing else { return }
        preparing = true; error = nil
        defer { preparing = false }
        do {
            let pages = SharePagination.pages(text: article.text)
            guard !pages.isEmpty, pages.count <= 100 else { throw ContentError.invalid("原文过长，暂不支持图片分享；请返回原文页复制完整文本。") }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LawSenseShare-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var generated: [URL] = []
            do {
                for (index, text) in pages.enumerated() {
                    try Task.checkCancellation()
                    let file = folder.appendingPathComponent(String(format: "识法-%03d.png", index + 1))
                    try autoreleasepool {
                        let renderer = ImageRenderer(content: SharePage(article: article, text: text, page: index + 1, total: pages.count))
                        renderer.scale = 2
                        guard let data = renderer.uiImage?.pngData() else { throw ContentError.invalid("图片生成失败") }
                        try data.write(to: file, options: .atomic)
                    }
                    generated.append(file)
                    await Task.yield()
                }
                files = generated
            } catch {
                try? FileManager.default.removeItem(at: folder)
                throw error
            }
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}

private struct SharePage: View {
    let article: Article
    let text: String
    let page: Int
    let total: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Image("BrandIcon").resizable().frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 12))
                Text("识法 LawSense").font(.system(size: 28, weight: .bold))
                Spacer(); Text("\(page)/\(total)")
            }
            #if DEVELOPMENT_CONTENT
            Text("开发阅读样例 · 非法律原文").foregroundStyle(.orange)
            #endif
            Text(article.number + " · " + article.title).font(.system(size: 26, weight: .bold))
            Text(text).font(.system(size: 24)).lineSpacing(10).fixedSize(horizontal: false, vertical: true)
            Divider()
            Text("版本：\(article.versionLabel)\n来源：\(article.source)").font(.system(size: 17))
            Text(LegalNotice.text).font(.system(size: 16)).fixedSize(horizontal: false, vertical: true)
        }.padding(36).frame(width: 720, alignment: .leading).background(Color(red: 0.985, green: 0.985, blue: 0.968))
            .foregroundStyle(Color.black).environment(\.colorScheme, .light)
    }
}

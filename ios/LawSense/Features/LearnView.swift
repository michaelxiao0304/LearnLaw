import SwiftUI

struct LearnView: View {
    let catalog: ContentCatalog
    @State private var selectedLaw: String?
    var body: some View {
        Page {
            SectionHeading(title: "生活有疑问，学法有方向", caption: "选择一个主题，从小处开始")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    filter("全部", id: nil)
                    ForEach(catalog.laws) { law in filter(law.title, id: law.id) }
                }
            }
            if selectedLaw == nil {
                ForEach(catalog.laws) { law in
                    Button { selectedLaw = law.id } label: {
                        HStack(spacing: 16) {
                            Image(systemName: law.symbol).font(.title2).frame(width: 48, height: 48).background(Color.bamboo.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading) { Text(law.title).font(.headline); Text(law.subtitle).font(.subheadline).foregroundStyle(.secondary) }
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote)
                        }.padding(16).background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                }
            }
            SectionHeading(title: "场景阅读")
            ForEach(catalog.cards.filter { selectedLaw == nil || $0.lawId == selectedLaw }) { card in
                NavigationLink(value: Route.card(card.id)) { KnowledgeCardRow(card: card) }.accessibilityIdentifier("card-link-\(card.id)").buttonStyle(.plain)
            }
        }.navigationTitle("学法堂")
    }
    private func filter(_ title: String, id: String?) -> some View {
        Button { selectedLaw = id } label: {
            Text(title).font(.subheadline.weight(.medium)).padding(.horizontal, 18).frame(minHeight: 44)
                .foregroundStyle(selectedLaw == id ? Color.white : Color.bamboo)
                .background(selectedLaw == id ? Color.actionGreen : Color.bamboo.opacity(0.08), in: Capsule())
        }.accessibilityAddTraits(selectedLaw == id ? .isSelected : [])
    }
}

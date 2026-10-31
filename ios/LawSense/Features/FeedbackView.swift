import SwiftUI

struct FeedbackView: View {
    @Environment(\.openURL) private var openURL
    let contentID: String
    let packageID: String
    @State private var explanation = ""
    @State private var status = ""
    private var draft: FeedbackDraft {
        FeedbackDraft(contentID: contentID, packageID: packageID, version: ReleaseConfiguration.appVersion, explanation: explanation)
    }
    var body: some View {
        Form {
            Section("内容信息") { Text(contentID).textSelection(.enabled); Text(packageID).textSelection(.enabled) }
            Section("发现的问题") {
                TextEditor(text: $explanation).frame(minHeight: 150).accessibilityLabel("纠错说明")
                Text("请描述内容错误，避免填写姓名、电话或具体案件材料。本入口不提供法律咨询。").font(.footnote)
            }
            Section("发送前预览") { Text(draft.body).textSelection(.enabled) }
            Section {
                if let url = draft.emailURL(recipient: ReleaseConfiguration.supportEmail) {
                    Button("打开邮件草稿") {
                        openURL(url) { accepted in if !accepted { status = "无法打开邮件客户端，请复制草稿后使用自己的邮箱发送。" } }
                    }
                    Text("收件人：\(ReleaseConfiguration.supportEmail)").textSelection(.enabled)
                } else {
                    Text("纠错邮箱尚未配置。你可以先复制草稿，待联系信息补齐后发送。")
                }
                Button("复制纠错草稿") { UIPasteboard.general.string = draft.body; status = "已复制草稿" }
                if !ReleaseConfiguration.supportEmail.isEmpty {
                    Button("复制收件地址") { UIPasteboard.general.string = ReleaseConfiguration.supportEmail; status = "已复制收件地址" }
                }
                if !status.isEmpty { Text(status).font(.footnote) }
            }
        }.navigationTitle("内容纠错")
    }
}

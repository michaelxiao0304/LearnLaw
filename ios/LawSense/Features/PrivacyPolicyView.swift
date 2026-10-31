import SwiftUI

/// Offline policy text is available even when publication URLs are not configured.
struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("识法隐私说明 · 2026-10-31") {
                Text("识法是离线法律知识学习工具，无账号、广告、追踪或分析 SDK，不向开发者上传个人信息或学习记录。")
            }
            Section("本地保存什么") {
                Text("本机保存收藏、答题选项与结果、错题状态、完成的知识卡、每日题目分配，以及日期、时区、字号、语速和免责声明确认版本。用于恢复学习状态与阅读偏好。")
            }
            Section("保存多久与如何删除") {
                Text("本地记录保留至你主动清除或卸载应用。在“阅读与设置”中可清除学习记录或收藏。卸载通常移除本机数据；恢复系统备份可能恢复此前记录。系统备份的保留和删除由设备与 Apple 账户设置管理，应用不提供云同步服务。")
            }
            Section("系统能力与外部操作") {
                Text("语音朗读使用设备可用的系统语音，不申请麦克风权限。复制由你主动发起。今后启用的邮件、分享和外部网页入口仅在你操作后交由对应系统应用处理，数据处理适用所选服务的规则；不自动附带学习记录。")
            }
            Section("发布与联系信息") {
                Text("支持邮箱和公开隐私政策网址尚未配置。此版本用于开发测试；正式发布前将补齐开发者联系信息及公开政策页面。")
            }
        }.navigationTitle("隐私说明")
    }
}

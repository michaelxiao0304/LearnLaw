import SwiftUI

/// Offline policy text is available even when publication URLs are not configured.
struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("识法隐私说明 · 2026-10-31") {
                Text("识法是离线法律知识学习工具，无账号、广告、追踪或分析 SDK，不向开发者上传个人信息或学习记录。")
            }
            Section("本地保存什么") {
                Text("本机保存收藏、答题选项与结果、错题状态、完成的知识卡、每日题目分配，以及日期、时区、字号、语速、提醒开关与时间和免责声明确认版本。用于恢复学习状态与阅读偏好。")
            }
            Section("保存多久与如何删除") {
                Text("本地记录保留至你主动清除或卸载应用。打开已有数据库时会保留本地升级保护副本，清除记录或收藏时同步删除该副本。在“阅读与设置”中可清除学习记录或收藏，也可停止新增学习日期；答题、错题和关卡进度仍为恢复功能保存在本机。卸载通常移除本机数据；恢复系统备份可能恢复此前记录。系统备份的保留和删除由设备与 Apple 账户设置管理，应用不提供云同步服务。")
            }
            Section("系统能力与外部操作") {
                Text("语音朗读使用设备可用的系统语音，不申请麦克风权限。每日提醒默认关闭，只在主动开启时申请通知权限。复制由你主动发起。邮件、分享和外部网页入口仅在你操作后交由对应系统应用处理，数据处理适用所选服务的规则；不自动附带学习记录。")
            }
            Section("发布与联系信息") {
                if !ReleaseConfiguration.displayName.isEmpty { Text("发布者：" + ReleaseConfiguration.displayName) }
                if let url = ReleaseConfiguration.policyURL { Link("公开隐私政策", destination: url) }
                else { Text("公开隐私政策网址尚未配置。") }
                if ReleaseConfiguration.supportEmail.isEmpty { Text("支持邮箱尚未配置，正式发布前将补齐。") }
                else { Text("联系邮箱：" + ReleaseConfiguration.supportEmail).textSelection(.enabled) }
            }
        }.navigationTitle("隐私说明")
    }
}

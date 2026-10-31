# iOS 发布准备复核

日期：2026-10-31。当前开发目录：`.worktrees/content-release-pipeline`，分支 `codex/content-release-pipeline`。结论：已修复原审查 R1–R3 并补齐主要工程能力，可开始开发真机测试；**尚不可作为 App Store 发布候选**。

## 已完成

| 范围 | 本轮结果 |
|---|---|
| 原 R1 隐私清单 | 正式与开发 App 均打包 PrivacyInfo.xcprivacy，实际产物校验通过 |
| 原 R2 时间回拨 | 答题以持久化序号确定先后；重启、错题恢复与迁移回归通过 |
| 原 R3 数据故障 | 原数据库保留、阅读只读降级、重试、升级前一致性副本 |
| 学习闭环 | 四档课程/门槛、答案与关卡恢复、30 天每日队列、错题、收藏、学习日开关、分别清理 |
| 系统功能 | 主动开启本地提醒及权限撤回处理、原文分页分享、邮件纠错草稿及未配置回退 |
| 正式内容工程 | schema、来源/摘要/引用/审核记录/覆盖率/时效门禁、确定性编译、预建索引、正式读取 |
| 版本与阅读 | 收藏修订提示、多目标迁移说明、旧错题保留、来源/复核/逐点引用、Dynamic Type |

各需求独立 worktree/分支迭代，按 hardening → system-features → learning-flow → content-release-pipeline 顺序累积。未把测试合成数据填入正式库。

## 验证证据

工具链 Xcode 27.2 / Swift 6.4.2，Swift 6 严格并发，Deployment Target iOS 17；实际模拟器为 iPhone 18 Pro / iOS 27.2。

| 检查 | 结果与证据 |
|---|---|
| Python 内容工具 | 19 tests 通过；`/private/tmp/lawsense-content-final-tests.log` |
| Swift 领域/跨语言 | 19 tests / 6 suites 通过；`/private/tmp/lawsense-domain-final.log` |
| SwiftData / 提醒 / 升级 | 最终完整回归 21 tests / 5 suites 通过；`ios/DerivedData/release-candidate-code-check.xcresult` |
| UI 流程 | 最终完整回归 6 tests / 0 failures；`ios/DerivedData/release-candidate-code-check.xcresult` |
| 最大辅助功能字号 | 首启确认→检索→原文阅读通过；`ios/DerivedData/largest-type-row.xcresult`，录屏/截图已检查，测试后恢复系统字号 large |
| 正式 Debug | 通用模拟器构建通过；`/private/tmp/lawsense-production-build.log` |
| 开发真机编译 | generic iOS / 无签名构建通过；`/private/tmp/lawsense-device-build.log`，未安装实体设备 |
| 正式 Release 门禁 | 预期失败：缺少审核内容；`/private/tmp/lawsense-release-gate.log`，不能视作可发布构建通过 |
| 资源隔离 | 正式 App 没有 development-catalog 或合成 approved-catalog；Publisher 空值按要求保留 |
| 隐私清单 | 正式模拟器、开发模拟器及开发 iphoneos 三份实际 Bundle 均验证通过 |
| 工具一致性 | Python→Swift 合成 fixture `--check` 通过；shell 语法和 git diff 空白检查通过 |

构建日志只有 Xcode 的 AppIntents 元数据提取跳过提示（本应用未使用 AppIntents），未见 Swift 编译警告；不把此描述为零工具警告。

没有运行实体设备 P95/耗电/内存泄漏检查、iOS 17 runtime、完整 VoiceOver/多尺寸矩阵、签名 Archive/上传验证、CRAP/重复率/变异工具或 SwiftLint。测试启用了 coverage，但不据此宣称全代码覆盖或安全认证。模拟器测试耗时不是正式冷启动/检索性能结论。

## 发布阻塞项

1. **内容及实际专业审核未提供**：三法现行全文、官方快照、完整有序条目清单、100 张知识卡/300 题和真实审核人。工具只检查证据结构/一致性，不能证明法律准确性或签署人身份。审核者仍须逐字核对、确认时效并保留原始批准记录。
2. **发布配置暂空**：发布者、支持/纠错邮箱、公开隐私政策 URL。按用户要求预留，不虚构地址。Team 由用户稍后在 Xcode 选择；Bundle ID/商标/素材授权亦需最终确认。
3. **真机及正式内容验收**：最低支持系统、离线中文 TTS、通知/分享/邮件、系统备份、低空间失败与 VoiceOver；正式内容下冷启动 20 次 P95 ≤2s、检索至少 100 组 P95 ≤200ms（防抖单列）、包 ≤15 MiB、设备适配 App 大小目标 ≤30MB。测试方法见 [真机步骤](../release/device-testing.md)。
4. **提交材料与签名产物**：签名 Archive 隐私报告、App Store Connect 问卷、截图、年龄分级、隐私网址可用性、TestFlight 和提审资料仍未验收。没有开发者账号状态或上传结果可供宣称通过。

## Apple 要求核对

本次按 app-store-review skill 于 2026-10-31 核对官方资料：

- [审核指南](https://developer.apple.com/app-store/review/guidelines/)：完整性和隐私要求意味着占位内容/空政策信息不应提审。
- [当前上传要求](https://developer.apple.com/news/upcoming-requirements/)：页面列出 Xcode 26+/iOS 26 SDK 及 iOS 13+ target 下限；当前工具链与 iOS 17 target 满足这些版本条件，不能替代实际上传验证。正式提交前重新核对。
- [截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)：按最终支持设备提交真实正式版本截图；开发样例截图不能作为正式内容截图。
- [Required Reason API](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)：本项目 UserDefaults 仅为自身设置，使用 CA92.1；无广告/跨应用追踪，不申请 ATT。
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)：离线记录与对外收集区分；真实反馈邮箱启用后还需结合收件/保留规则核对隐私问卷。

隐私政策草案和 Manifest 已交付，不能代替运营者确认最终实际处理行为。


最终完整应用回归日志：`/private/tmp/lawsense-final-regressions.log`；21 项 hosted 单测和 6 项 XCUITest 在同一次运行中全部通过。此前失败的用例和根因修复保留在 [D01 行动记录](../requirements/D01-content-release-pipeline.md)，最终结果没有计入零用例筛选运行。

# D04 · iOS 开发版交付记录

日期：2026-10-31。基线 `057e239`；分支 `codex/ios-app`；工作树 `.worktrees/ios-app`。运行入口：[iOS README](../../ios/README.md)。本次完成 spec 允许与内容生产并行的 D04 可运行链路，并接入该链路必需的本地状态与朗读基础；不是 V1.0 完工或上架声明。

## 实现与边界

| 能力 | 当前结果 |
|---|---|
| 独立工程 | iOS 17+，SwiftUI / Observation / SwiftData，Swift 6 严格并发，无第三方运行时包 |
| 品牌 | `resource/logo/png` 的普通/深色 App Icon、书芽标志；脚本复制生成 Asset Catalog，SHA-256 可追溯 |
| 首启 | 完整声明、显式勾选后进入、知悉版本及时间持久化 |
| 浏览 | 今日、学法堂、查法条、练习场、我的；知识卡 → 引用原文 → 单选测验 |
| 阅读 | 来源与版本、原文完整复制、字号偏好、系统动态字体、明暗配色、中文系统 TTS 的朗读/暂停/继续/停止及离页/中断停止 |
| 学习 | 确定性今日题、答错展示原文与解析、完成卡片、连续学习天数、错题待复习/全部 |
| 本地状态 | 收藏、答题、完成记录、今日分配；单一 MainActor 写入；显式保存、失败回滚；重复提交幂等 |
| 检索 | 小数据关键词、条号/中文数字、法律筛选；后台可取消查询；尚未实现全量倒排索引与拼音 |
| 内容隔离 | `LawSenseDevelopment` 独立 Bundle ID 和合成阅读样例；正式 `LawSense` 不含样例 JSON；Release 构建在正式内容未接入前失败 |

开发包包含 6 条阅读说明、6 张卡、6 道题，明确标记“非法律原文/结论”。它仅验证流程，不是官方三法内容，也不是 D01/D02 的正式 schema。正式 target 当前显示“未接入正式内容包”，绝不能将开发 target 改名后上架。

未实现：正式内容的 manifest/schema/来源审核与更新映射、三法全文、100 卡/300 题、课程与四档称号、通知队列、分享图、邮件纠错、用户库故障只读降级/重置、全量检索及真机性能验收。后续按 D01～D10 分独立需求/worktree 推进。

## 采用的 Skill 与实现选择

已读取并使用 `ub-mode`（数据形状、红绿测试、单一写入者、幂等、操作记录）、`swift-architecture` / `swiftui-patterns`（Observation 与局部页面状态）、`swiftui-navigation` / `swiftui-layout-components`（类型路由、iPad 分栏和页面布局）、`swiftdata`（版本化用户 schema、迁移计划、明确保存边界）、`swift-concurrency` / `swift-codable`（后台解码、严格并发与输入校验）、`swift-testing`（行为测试）、`ios-accessibility`（动态字号、语义标签和朗读）、`ios-simulator`（隔离模拟器构建测试）。

架构状态使用 `archify` 更新 JSON 并完整 finalize，保留 [review-3 自动凭据](../architecture/review-3/lawsense-architecture.finalize-summary.json)。未手改生成 HTML。目标架构图包含后续能力，不能作为已实现功能清单。

系统能力同时核查 Apple 官方 [AVSpeechSynthesizer](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer)、[AVSpeechUtterance.rate](https://developer.apple.com/documentation/avfaudio/avspeechutterance/rate) 和 [ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext) 文档。保留 iOS 17 Deployment Target，不直接照搬 skill 中较新系统的 API 示例。

`crapper`、`dryer`、`mutator` 在当前环境不可用，未运行，未宣称相应评分达标。以行为测试和人工检查代替临时证据：共享页面/卡片/免责/TTS/收藏组件，规则集中于 Domain，用户写入集中于 UserStore；未引入强制解包、`fatalError` 或 `@unchecked Sendable`。

## 操作与原因

1. 从已推送的 main 创建独立 `codex/ios-app` worktree，保留主工作区；建立 [需求与验收切片](../requirements/D04-ios-foundation.md)。
2. 先定义精确版本引用、开发内容边界、今日抽题/日历规则和搜索行为测试。第一次运行 10 个测试按预期失败，再完成最小实现，10 个测试通过；提交领域基础 `05136c0`。
3. 创建两个独立应用 target 和两个测试 target，使用无依赖 Python 工程生成器，避免额外安装构建工具。修复 OpenStep 文件的中文转义，保证系统显示名为“识法·开发”。
4. 从共享目录复制 logo，通过摘要记录来源；生成器重复运行输出一致。开发 JSON 的 SHA-256 校验通过后才解码，引用和题目选项在加载边界校验。
5. 实现页面、单一 SwiftData 写入者和 TTS；保存成功后才更新 UI 状态。用内存库验证幂等与非法输入，用文件库重开验证持久化。
6. 在专用模拟器运行 UI 验收；修复“我的”页面 plain NavigationLink 的透明空白区域不响应点击的问题，使用 `contentShape(Rectangle())` 让整行可点。保留先失败的用户流程证据，修复后重跑。
7. 截图发现全局 safeAreaInset 中的开发提示与 iPhone 内联导航标题重叠，将提示与 TabView 放入顺序容器；继续用同一组 UI 流程复验。
8. 更新 spec 进度和 Archify 架构说明；保留后续功能边界与正式发布门禁。

## 自动化调查记录

首启阶段中心点击与偏移点击曾连续未完成。共同前提是“XCUITest 合成事件已送达 Toggle，改变坐标就能切换”。停止继续偏移坐标，明确状态归属：WelcomeView 独占临时勾选状态，Preferences 独占持久确认版本，测试只操作 UI，模拟器负责事件投递。

进程采样显示主线程正常等待 RunLoop，未发现死锁。检查控件几何和值后，恢复标准 `tap()`，未修改首启业务逻辑，后续运行成功进入首页并完成答题。后续在同时初始化 iPad 模拟器时再次出现启动延迟与控件定位不稳定；可访问性树明确显示外层 Switch 行内还有原生 Switch 子元素。测试改为定位内部控件并等待按钮启用，串行验证。未将所有早期问题归因于单一原因，也不将中断运行记作通过。当前 Xcode 安装不含 Simulator.app 桌面窗口，验证使用命令行 CoreSimulator 和 XCUITest。

收藏流程首次失败时截图显示收藏计数为 1、页面仍停留“我的”。问题为行中部透明区域不命中，而非数据丢失。修复命中区域，并按可访问性合并后的卡片按钮断言收藏列表。

## 验证环境与结果

Xcode 27.2（27B52）、Swift 6.4.2，语言模式 Swift 6；专用 iPhone 18 Pro / iOS 27.2 模拟器。当前环境无 iOS 17 runtime，尚未覆盖最低系统实际运行、真机 VoiceOver/TTS、低端机启动/搜索 P95、全量内容性能和发布签名。

| 检查 | 结果与证据 |
|---|---|
| 领域规则 | 10 个 Swift Testing 测试通过，含无效引用/答案、日期/连胜、稳定抽题、阈值与条号搜索 |
| SwiftData | 4 个测试通过：幂等答题与错题复习、非法操作无写入、文件库重开、今日题固定 |
| UI 流程 | 3 个 XCUITest 通过：首启/答题/完成、收藏列表、搜索原文；布局调整后在深色模式复验，3 个测试再次通过 |
| 工程/资源 | `plutil -lint` 通过；资源与工程重复生成字节一致；内容 SHA-256 一致；中文应用名正确 |
| 正式 target | Debug 构建通过，Bundle 内不存在 `development-catalog*`；Release 返回预期的 D01/D02 缺失错误 |
| Archify | validate / deliver / check / browser-check 全部通过，0 个诊断；凭据绑定当前 JSON/HTML |
| 视觉 | iPhone 明暗布局及 iPad 首页截图；不等于 VoiceOver/最大字号/分屏的完整验收 |

原始构建输出位于本 worktree 的 `ios/DerivedData/`（不入 Git）。`D04-acceptance.xcresult` 包含 4 个 SwiftData 和 3 个 UI 测试的成功结果；最终布局复验保存在 `D04-final-ui.xcresult`，0 失败。领域测试原始输出 `/private/tmp/lawsense-core-green.log`；失败与中断的结果不计入通过数。工程及测试执行命令见 iOS README。

截图：[首页](screenshots/ios-home.png) · [深色首页](screenshots/ios-home-dark.png) · [知识卡](screenshots/ios-card.png) · [原文](screenshots/ios-article.png) · [收藏](screenshots/ios-bookmarks.png) · [iPad 首页](screenshots/ipad-home.png)。所有截图是开发样例，不是正式法律内容。iPad 首页仅用于布局启动检查，以启动参数指定已知悉版本；真实首启确认由 iPhone XCUITest 覆盖。


收尾：实现提交 `54bc283`，main 保持原基线；本需求 worktree 保留供审阅与后续整合。测试产生的缓存和 xcresult 已忽略，专用模拟器在验收后关闭，不改动用户已有设备。

# 开发 Spec 编制记录 · 2026-10-31

## 范围与隔离

本需求只编制开发规范、目标架构图和目录/执行约定，不实现 App，不生产法律内容。基线提交 `2fb2971`；独立分支 `codex/development-spec`，独立 worktree `/private/tmp/lawsense-development-spec-20261031`。

## 操作与原因

| 操作 | 原因/结果 |
|---|---|
| 读取 `Agents.md`、README、工作区及 Git 状态 | 确认 PRD v1.2、iOS 优先、四个目录尚无 App 工程；原始 PRD 保留 |
| 读取 archify、ub-mode、swift-architecture、swiftdata skill | 遵循指定图表/开发原则，选择适量的 MV 架构与明确存储边界；较新系统示例不改变 iOS 17+ |
| 核对 Apple 官方 Observation/ModelContainer 文档 | 验证 Observation 的系统基线及用户存储/迁移机制；链接写入 spec |
| 创建独立 worktree/分支 | 落实本需求隔离；首次受 Git 元数据写入限制，授权提升后创建成功 |
| 编制开发 spec | 明确功能范围、只读内容/用户数据分离、版本/引用/签审契约、检索与日历行为、失败处理、验收指标和 11 个后续切片 |
| 使用 archify 原生 architecture 模式生成图 | 交付 JSON 与可交互 HTML，明确目标设计及 Android V2 边界 |
| 重试 archify 浏览器检查 | 首次 Chrome 管道失败；在可运行浏览器环境完整重试，四个门禁均通过，无诊断项 |
| 补充目录说明、README 入口及 Agents.md 第 9 节 | 后续开发者能够发现 spec，并持续执行平台 skill、ub-mode、archify、独立 worktree 规则 |
| 对齐 `resource/logo/` | 主工作区期间出现其他工作创建的未跟踪 logo 文件；保留原状，不纳入本需求提交 |
| 为生成 HTML 标记 Git 属性 | Archify 输出含模板空白；保留受验证字节，精确排除该生成文件的空白检查，源文档继续检查 |
| 检查 Markdown 链接、产物摘要和原始 PRD | 验证交付可访问、图与凭据对应、PRD 未被覆盖；记录见下 |

## 验证

- Archify：`validate`、`deliver`、严格 `check`、真实浏览器 `browser-check` 全部通过；[通过凭据](../architecture/review-2/lawsense-architecture.finalize-summary.json)。未要求或执行人工视觉审阅。
- 文档：本地 Markdown 文件链接/锚点检查、代码围栏成对检查；架构 JSON 可解析；HTML/JSON 摘要与通过凭据一致；`git diff --cached --check`（仅生成 HTML 按 `.gitattributes` 豁免模板空白，保持校验摘要不变）。
- 产品追踪：按 PRD 功能表覆盖 F01～F13，保留 100 卡/300 题、三法全文、iOS 17+、TTS、无账号/离线、免责声明/纠错及体积/性能门槛。
- 本次没有 App 源码或可运行工程，因此不运行构建、单元测试、复杂度/重复/变异测试，不声称这些检查通过。正式法律时效核验、人工校对和专业审核尚未开展。

## 收尾策略

将本需求内容提交到独立分支，在主工作区检查无路径冲突后以 fast-forward 整合，保证用户可直接从项目 `docs/` 查看；不推送远端。保留需求分支/worktree 供审阅和验证凭据追溯；后续按 spec 确认无人使用、无未提交工作后清理。主工作区其他工作的 logo 文件不修改、不提交。

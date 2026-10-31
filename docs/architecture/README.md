# 目标架构产物

- [打开架构图](lawsense-architecture.html)
- [可编辑 Archify 输入](lawsense-architecture.json)
- [最新通过的自动检查摘要](review-3/lawsense-architecture.finalize-summary.json)

本图是依据 PRD 和开发 spec 设计的目标架构，D04 已有 iOS 开发版；图中完整内容管线和其他能力仍是目标，不是完工声明。自动检查已通过 validate、deliver、check 和真实浏览器检查；没有进行人工视觉审阅。

首次沙箱内运行通过前三项检查，Chrome 管道启动失败；根目录的首次 finalize/browser-check 凭据保留该失败。`review-2/` 是初版重试通过的凭据。D04 在 `review-3/` 更新实施状态并重新通过全部自动门禁；旧凭据不能用于证明新版 HTML。凭据中的绝对路径记录生成时的独立 worktree，摘要绑定具体文件字节，不应手工改写路径或哈希。

后续修改必须先读取 archify skill，在新需求 worktree 更新 JSON，再完整运行（将 `ARCHIFY_CLI` 替换为当前安装的 CLI 路径）：

```sh
node "$ARCHIFY_CLI" finalize architecture docs/architecture/lawsense-architecture.json docs/architecture/lawsense-architecture.html --quality showcase --out-dir docs/architecture/review-4 --json
```

每次产生新候选使用新的 review 目录保留旧证据。不要手改生成 HTML；不要把旧自动检查结果当成新文件的验证。

# 目标架构产物

- [打开架构图](lawsense-architecture.html)
- [可编辑 Archify 输入](lawsense-architecture.json)
- [最新通过的自动检查摘要](review-2/lawsense-architecture.finalize-summary.json)

本图是依据 PRD 和开发 spec 设计的目标架构，尚无对应应用代码。自动检查已通过 validate、deliver、check 和真实浏览器检查；没有进行人工视觉审阅。

首次沙箱内运行通过前三项检查，Chrome 管道启动失败；根目录的首次 finalize/browser-check 凭据保留该失败。`review-2/` 是在浏览器可运行环境中重试后通过的凭据，候选与 HTML 字节未改变。凭据中的绝对路径记录生成时的独立 worktree，摘要绑定具体文件字节，不应手工改写路径或哈希。

后续修改必须先读取 archify skill，在新需求 worktree 更新 JSON，再完整运行（将 `ARCHIFY_CLI` 替换为当前安装的 CLI 路径）：

```sh
node "$ARCHIFY_CLI" finalize architecture docs/architecture/lawsense-architecture.json docs/architecture/lawsense-architecture.html --quality showcase --out-dir docs/architecture/review-3 --json
```

每次产生新候选使用新的 review 目录保留旧证据。不要手改生成 HTML；不要把旧自动检查结果当成新文件的验证。

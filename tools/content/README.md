# 内容审核与离线发布工具

本工具校验内容结构、引用、摘要和审核记录，不能代替法条逐字校对或专业法律判断。当前仓库没有正式法律内容和真实审核人员；`reviewers.json`、发布者配置按用户要求预留为空。不得把测试样例当作正式内容。

## 环境与检查

从当前 worktree 根目录执行（Python 3.9+）：

```sh
python3 -m venv .venv-content
.venv-content/bin/python -m pip install -r tools/content/requirements-lock.txt
export PYTHONDONTWRITEBYTECODE=1
.venv-content/bin/python -m unittest discover -s tools/content/tests -v
.venv-content/bin/python tools/content/make_test_fixture.py --check
python3 ios/Scripts/generate_project.py
```

`requirements-lock.txt` 固定本次验证的工具依赖；它们只在开发/构建机器运行，不进入 App。创建环境后重新生成工程，以把环境路径纳入 Xcode 构建脚本的读取范围。依赖升级需要重跑内容校验与 Python→Swift 兼容测试。

`generate_schema.py` 是唯一 schema 源，导出 `resource/content/schema/bundle.schema.json` 供编辑器使用。各文件用 `$defs` 中对应的定义校验：manifest、sources、law、interpretations、cards、questions、topics、courses、aliases、migrations、approvals。正式文件不允许未知字段。

## 内容目录

人工录入的包放 `resource/content/releases/<packageId>/`，官方原始快照放 `resource/content/source/`。一个包包含：

| 文件 | 内容 |
|---|---|
| manifest.json | 包版本、日期、三法版本、文件大小/SHA-256、发布审核 ID |
| sources.json | 官方来源 URL、发布机关、获取日期、快照相对路径/摘要 |
| laws/<editionId>.json | 一部法律的全部条文，保留条号、原文、章节路径、顺序、逐条摘要 |
| interpretations.json | 解读要点、误区、处罚原文引用、精确法条引用 |
| cards.json | 场景、结论限定条件、解读/题目/来源/主题关联 |
| questions.json | 单选/判断题、选项、唯一答案、解析、卡片和法条关联 |
| topics.json | 生活主题树；必须覆盖 v1-requirements.json 中的 19 项主题 |
| courses.json | 青铜/白银/黄金/王者四档、前置关卡、每关至少 10 题、80% 通过 |
| aliases.json | 人工审核的法律别名、关键词、无声调全拼和首字母 |
| migrations.json | 旧 ID 到当前 ID 的对应、修订/移除原因；不静默替换用户收藏 |
| approvals.json | 审核对象摘要、审核人/角色/日期、律师抽检范围与剩余风险 |

日期均为 `YYYY-MM-DD`；版本 ID 只用 ASCII 字母、数字、点、下划线和连字符。条文键如 `264`、`133-1`，引用必须同时给出 lawId / lawVersionId / editionId / articleKey。版本不能靠条号猜测。跨版本迁移的法条 ID 按四段 UTF-8 字节长度前缀编码，与 Swift `ArticleReference.id` 一致。

校验器限定法条原文来源为 `https://flk.npc.gov.cn`；其他官方来源限定人大、政府、法院、检察院、公安和司法部域名。URL 与快照相符、原文确属现行全文，仍须人工核验。已有条文数量和有序清单摘要也须由双人比对官方全文后确认；脚本无法从自报数量证明未漏录。

所有知识卡、解读和题目需带引用、复核日期、批准状态与审核 ID。卡片与题目必须双向挂接；支持一张卡多道题、一题多张卡。处罚引用逐字包含于对应原文，不进行改写。官方案例改编必须挂接案例来源；典型情境必须明确标识，不能伪造裁判结果。正式包至少 100 卡（40 刑法/45 民法/15 治安）与 300 题。

## 审核证据

`resource/content/reviewers.json` 结构为 `{"reviewers":[]}`。实际人员登记项含 `id`、`active: true`、`roles`，允许角色为 proofreader / legal_reviewer / lawyer / content_owner。登记人的身份、资质、授权与原始签署记录由发布负责人在线下核实和保存，不在 Git 中放身份证或敏感证件。

摘要规则统一为 UTF-8 JSON，键排序、不转义中文、无额外空格：`release.canonical`；SHA-256 为小写十六进制。法条文本摘要针对原文 UTF-8 字节；清单摘要针对有序 articleKey 数组。

- 每部法律的审核对象为 `{edition, document, source}`，同时绑定版本元数据、完整条文和来源。需要两名不同的 proofreader。
- 每个 card / interpretation / question 的审核对象为其完整 JSON，需要有资质的 legal_reviewer。
- 包审核对象为 manifest 去掉 `files` 中 approvals.json 项后的 canonical 摘要，避免摘要循环。需要不同的人分别担任 content_owner 和 lawyer，记录 sampledObjectKeys、riskAssessment、unsampledSummary。
- 每条 review 的 objectDigest 必须与对象一致；改内容后旧审核立即失效。对象及审核不得在未来；审核不得早于对象复核/包创建日期；超过六个日历月拒绝发布。本版不提供超期豁免。

这些是可追溯的审核记录，**不是数字签名，也不证明签署人身份真实**。只修改 JSON 不能代替取得本人批准。可先算对象摘要，由实际人员审核该版本后再录入对应记录，最后计算 approvals.json 的文件摘要和大小写入 manifest。

## 编译与发布门禁

真实内容和审核记录就绪后执行：

```sh
.venv-content/bin/python tools/content/release.py resource/content/releases/<packageId>
.venv-content/bin/python tools/content/compile_bundle.py resource/content/releases/<packageId>
.venv-content/bin/python tools/content/release_gate.py
```

编译器先校验，再产生 `ios/ApprovedContent/`：审核过的原始包、只读 App 数据、预建倒排索引、receipt 摘要。保留法条字节、多题关联及精确版本；最终目录不超过 15 MiB。输出目录不允许覆盖来源目录或任意已有文件。生成物不提交 Git；干净 checkout 需要从已审核的原始包重新编译。

填写 `ios/Configuration/Publisher.json` 的真实 displayName、supportEmail、HTTPS privacyPolicyURL 后，正式 `LawSense` 的 Release 构建会重新验证原始快照、审核时效、生成内容/索引一致性和发布配置。缺任何一项构建失败。不要删除门禁来绕过内容审核。App 不下载新内容，更新随新版本发版。

开发 target 仅使用 `ios/DevelopmentContent/` 的合成样例；Swift 包测试中的 100 卡/300 题同样是合成数据，只进入 test target。`make_test_fixture.py` 只能写入 Swift 测试资源目录；`--check` 验证跨语言样例未漂移，不会写入正式输出。

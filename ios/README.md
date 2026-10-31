# 识法 iOS

iOS 17+、SwiftUI、Observation、SwiftData，无第三方运行时依赖。已实现阅读与精确法条引用、检索/拼音词典、四档课程与恢复、每日题队列、错题/收藏/记录、TTS、本地通知、分享图、邮件反馈草稿、隐私与数据清理。

**当前可做开发真机测试，还不是 App Store 发布候选。** 正式三法全文、专业审核的 100 卡/300 题、发布者和公开政策信息尚未提供。正式 Release 有自动门禁，不能把合成样例打包发布。

## 运行

打开当前 worktree 的 `ios/LawSense.xcodeproj`，选择 **LawSenseDevelopment** scheme；连接手机后在 Signing & Capabilities 选择自己的 Team。Team 按用户要求不预填。已接入 `resource/logo/png/` 的共享 logo。工具链验证为 Xcode 27.2 / Swift 6.4.2，Swift 6 严格并发；最低系统仍为 iOS 17。

- `LawSenseDevelopment`：独立 Bundle ID，合成样例有醒目标记，用于体验功能及普通启动下的持久化测试。
- `LawSense`：正式 Bundle ID 暂定 `com.lawsense.app`。Debug 可编译但未配置内容时显示说明；Release 必须有真实审核通过的内容和发布配置。
- `--ui-testing` 只在开发 target 生效，使用隔离偏好与内存库。人工真机测试不要使用该参数。

邮箱、发布者姓名与公开隐私网址集中在 `Configuration/Publisher.json`，目前留空。未配置邮箱时仅允许复制纠错草稿。隐私清单已进入两个 target，应用内有离线隐私说明。

## 工程与内容

```sh
python3 ios/Scripts/prepare_assets.py
python3 ios/Scripts/generate_project.py
```

项目文件和 Asset Catalog 已提交。新增/删除 Swift 文件后重新生成工程；logo 变更后重新生成资源。生成工程可能重置本机 Team，请在 Xcode 重选或通过构建参数覆盖。正式内容流程见 [内容工具说明](../tools/content/README.md)。

Domain 同一份源码由 Swift Package 测试，不与 Android 共享业务代码。`DevelopmentContent/` 只进入开发 App；`CoreTests/Fixtures/` 只进入 Swift test target。正式内容由审核包编译到被 Git 忽略的 `ApprovedContent/`。

SwiftData 已有 V1→V2→V3→V4 迁移；UserStore 是 MainActor 唯一写入者。打开已有库前生成含 WAL 已提交页的一致性副本，损坏时保留原文件并提供只读内容访问；用户清理同时移除副本。正式海量数据仍须真机测量，不以小型测试耗时替代性能验收。

## 验证

先按内容工具说明建立 `.venv-content`，再执行：

```sh
swift test --package-path ios --enable-code-coverage
LAWSENSE_SIMULATOR_ID=<可用设备UUID> bash ios/Scripts/verify.sh
```

验证脚本运行 Python 内容测试、跨语言 fixture 检查、Swift 领域测试、模拟器持久化/UI 测试、正式 Debug 构建和两份实际 App 的隐私清单校验。可通过 `LAWSENSE_CONTENT_PYTHON` 指向已配置的独立 Python 环境。该脚本不是签名 Archive、真机测试或 App Store 审核的替代品。

详见 [当前验证结论](../docs/reviews/ios-release-readiness-2026-10-31.md)、[真机测试步骤](../docs/release/device-testing.md)、[开发 Spec](../docs/development-spec.md)。

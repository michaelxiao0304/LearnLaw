# 识法 iOS

iOS 17+、SwiftUI、Observation、SwiftData，无第三方运行时依赖。当前为 D04 开发版：首启声明、五个 Tab、阅读/原文/小测验、收藏、错题、学习记录、今日题、系统朗读与字号设置。

## 运行

使用 Xcode 打开 `LawSense.xcodeproj`，选择 **LawSenseDevelopment** scheme 和 iPhone/iPad 模拟器，运行即可。已接入 `../resource/logo/png/` 的图标和品牌标志。当前验证工具链为 Xcode 27.2 / Swift 6.4.2，语言模式 Swift 6，Deployment Target 保持 iOS 17.0。

- `LawSenseDevelopment`：独立 Bundle ID `com.lawsense.app.lawsensedevelopment`；只包含显著标记的合成阅读样例，可完整体验当前流程。样例不是法律内容。
- `LawSense`：正式 Bundle ID 暂定 `com.lawsense.app`；不复制开发 JSON，Debug 显示未接入正式包的错误页，Release 在构建阶段明确失败。必须完成 D01/D02 的正式内容加载与审核门禁后再开放发布。

暂未具备三法全文、100 卡/300 题、拼音及倒排索引、四档课程/称号、通知、分享图、邮件反馈、正式内容更新映射和数据重置流程。不能作为 App Store 候选发布。

## 工程与资源

从仓库根执行：

```sh
python3 ios/Scripts/prepare_assets.py
python3 ios/Scripts/generate_project.py
```

项目文件和 Asset Catalog 都已提交，直接打开即可。新增/删除 Swift 文件后重新运行项目生成器；logo 变更后重新运行资源脚本。不要手改生成图像；`asset-provenance.json` 记录共享源图 SHA-256。

源码在 `LawSense/` 中按 App / Domain / Data / Features / DesignSystem / Services 组织。Domain 同一份源码也由 `Package.swift` 提供无模拟器的测试入口，未创建跨平台共享业务模块。`DevelopmentContent/` 的专用 fixture 格式不等同正式发布内容契约。

SwiftData 从 `UserSchemaV1` 开始版本化，`UserStore` 是唯一上下文写入者并隔离在 MainActor；写入显式保存、失败回滚，不启用 CloudKit。当前小数据读写尚未做批量后台优化；正式内容扩容前按 spec 测量并迁移查询路径。临时测试库与用户库隔离。

## 验证

```sh
swift test --package-path ios --scratch-path ios/.build
xcrun simctl list devices available
xcodebuild -project ios/LawSense.xcodeproj -scheme LawSenseDevelopment \
  -destination 'platform=iOS Simulator,id=<可用设备 UUID>' \
  -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO test
```

测试使用 Swift Testing（领域和持久化）及 XCUITest（首启、答题、收藏）。`--ui-testing` 仅在开发 target 生效，启用隔离偏好和内存数据；正式 target 不支持此参数。

运行证据、限制与后续步骤见 [D04 开发记录](../docs/development/D04-ios-app.md)。产品和工程约束见 [开发 Spec](../docs/development-spec.md)。

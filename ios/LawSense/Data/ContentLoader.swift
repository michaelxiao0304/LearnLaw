import Foundation
import CryptoKit

enum ContentLoader {
    @concurrent static func load() async throws -> ContentCatalog {
        #if DEVELOPMENT_CONTENT
        guard let url = Bundle.main.url(forResource: "development-catalog", withExtension: "json"),
              let hashURL = Bundle.main.url(forResource: "development-catalog", withExtension: "sha256") else {
            throw ContentError.invalid("开发内容文件缺失")
        }
        let data = try Data(contentsOf: url)
        let expected = try String(contentsOf: hashURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else { throw ContentError.invalid("内容摘要不一致") }
        let catalog = try JSONDecoder().decode(ContentCatalog.self, from: data)
        try DevelopmentContentValidator.validate(catalog)
        try Task.checkCancellation()
        return catalog
        #else
        throw ContentError.invalid("正式内容包尚未接入，请等待来源核验及专业审核完成。")
        #endif
    }
}

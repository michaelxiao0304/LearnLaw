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
        guard let root = Bundle.main.url(forResource: "ApprovedContent", withExtension: nil),
              FileManager.default.fileExists(atPath: root.appendingPathComponent("receipt.json").path) else {
            throw ContentError.invalid("正式内容尚未配置，请完成来源核验、专业审核并编译内容包。")
        }
        let receipt = try JSONDecoder().decode(ApprovedReceipt.self, from: Data(contentsOf: root.appendingPathComponent("receipt.json")))
        let data = try Data(contentsOf: root.appendingPathComponent("approved-catalog.json"))
        let manifest = try Data(contentsOf: root.appendingPathComponent("manifest.json"))
        guard receipt.compilerVersion == 1,
              hash(data) == receipt.catalogSHA256, hash(manifest) == receipt.manifestSHA256 else { throw ContentError.invalid("正式内容摘要不一致") }
        let catalog = try JSONDecoder().decode(ContentCatalog.self, from: data)
        guard catalog.packageId == receipt.packageId else { throw ContentError.invalid("内容包身份不一致") }
        try ApprovedContentValidator.validate(catalog)
        try Task.checkCancellation()
        return catalog
        #endif
    }
    @concurrent static func searchIndex(for catalog: ContentCatalog) async -> ContentSearch {
        if let root = Bundle.main.url(forResource: "ApprovedContent", withExtension: nil),
           let receiptData = try? Data(contentsOf: root.appendingPathComponent("receipt.json")),
           let receipt = try? JSONDecoder().decode(ApprovedReceipt.self, from: receiptData),
           receipt.packageId == catalog.packageId,
           let data = try? Data(contentsOf: root.appendingPathComponent("search-index.json")), hash(data) == receipt.indexSHA256,
           let prepared = try? JSONDecoder().decode(PreparedSearchIndex.self, from: data), prepared.sourceDigest == receipt.catalogSHA256 {
            return ContentSearch(catalog: catalog, prepared: prepared)
        }
        // Derived indexes are recoverable; source content was already verified.
        return ContentSearch(catalog: catalog)
    }

    private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private struct ApprovedReceipt: Decodable { let compilerVersion: Int; let packageId: String; let catalogSHA256: String; let manifestSHA256: String; let indexSHA256: String }
}

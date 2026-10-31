import Foundation
import SwiftData

enum UserSchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(4, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [BookmarkRecord.self, UserSchemaV2.AttemptRecord.self, UserSchemaV2.CompletionRecord.self,
         UserSchemaV2.DailyRecord.self, UserSchemaV3.CourseSessionRecord.self, UserSchemaV3.LevelPassRecord.self]
    }
    @Model final class BookmarkRecord {
        @Attribute(.unique) var key: String
        var kind: String
        var target: String
        var title: String
        var createdAt: Date
        var revision: Int = 0
        init(key: String, kind: String, target: String, title: String, revision: Int) {
            self.key = key; self.kind = kind; self.target = target; self.title = title
            self.revision = revision; createdAt = .now
        }
    }
}

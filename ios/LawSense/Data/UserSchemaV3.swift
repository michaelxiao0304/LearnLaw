import Foundation
import SwiftData

enum UserSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(3, 0, 0) }
    static var models: [any PersistentModel.Type] {
        UserSchemaV2.models + [CourseSessionRecord.self, LevelPassRecord.self]
    }
    @Model final class CourseSessionRecord {
        @Attribute(.unique) var key: String
        var encoded: Data
        init(key: String, encoded: Data) { self.key = key; self.encoded = encoded }
    }
    @Model final class LevelPassRecord {
        @Attribute(.unique) var key: String
        var correct: Int
        var total: Int
        init(key: String, correct: Int, total: Int) { self.key = key; self.correct = correct; self.total = total }
    }
}

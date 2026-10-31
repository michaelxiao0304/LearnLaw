import Foundation
import SQLite3

/// SQLite's backup API takes a coherent snapshot, including committed WAL pages.
/// Never replace or automatically restore the original store on failure.
enum StoreBackup {
    static func url(for store: URL) -> URL { store.appendingPathExtension("before-v4-open.sqlite") }

    private static func stagingURL(for store: URL) -> URL { store.appendingPathExtension("v4-backup-staging") }

    static func ensureBeforeOpening(_ store: URL) throws {
        let manager = FileManager.default
        let backup = url(for: store)
        let staging = stagingURL(for: store)
        if manager.fileExists(atPath: staging.path) { try manager.removeItem(at: staging) }
        guard manager.fileExists(atPath: store.path), !manager.fileExists(atPath: backup.path) else { return }
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        let temporary = staging.appendingPathComponent("snapshot.sqlite")
        defer { try? manager.removeItem(at: staging) }
        try snapshot(source: store, destination: temporary)
        try makeStandalone(temporary)
        #if !targetEnvironment(simulator)
        try manager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: temporary.path)
        #endif
        try manager.moveItem(at: temporary, to: backup)
    }

    private static func snapshot(source: URL, destination: URL) throws {
        var sourceDB: OpaquePointer?
        var destinationDB: OpaquePointer?
        defer {
            if let sourceDB { sqlite3_close(sourceDB) }
            if let destinationDB { sqlite3_close(destinationDB) }
        }
        guard sqlite3_open_v2(source.path, &sourceDB, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              sqlite3_open_v2(destination.path, &destinationDB, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
              let sourceDB, let destinationDB else { throw ContentError.invalid("无法创建升级保护副本，原用户数据库未改动") }
        sqlite3_busy_timeout(sourceDB, 500)
        sqlite3_busy_timeout(destinationDB, 500)
        guard let operation = sqlite3_backup_init(destinationDB, "main", sourceDB, "main") else {
            throw ContentError.invalid("用户数据库无法读取，原文件已保留")
        }
        let status = sqlite3_backup_step(operation, -1)
        let finished = sqlite3_backup_finish(operation)
        guard status == SQLITE_DONE, finished == SQLITE_OK else { throw ContentError.invalid("升级保护副本未完成，请稍后重试") }
    }

    private static func makeStandalone(_ url: URL) throws {
        var database: OpaquePointer?
        defer { if let database { sqlite3_close(database) } }
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let database,
              sqlite3_exec(database, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK else {
            throw ContentError.invalid("保护副本未能独立保存，原用户数据库未改动")
        }
    }

    static func remove(for store: URL) throws {
        do {
            for path in [url(for: store), stagingURL(for: store)] where FileManager.default.fileExists(atPath: path.path) {
                try FileManager.default.removeItem(at: path)
            }
        } catch { throw ContentError.invalid("当前记录已清除，但升级保护副本尚未删除，请重试清除") }
    }
}

// DatabaseManager.swift
// Manages the SQLite database using GRDB.

import Foundation
import GRDB

class DatabaseManager {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue!

    init() {
        setupDatabase()
    }

    // MARK: - Setup

    private func setupDatabase() {
        do {
            let fileURL = try FileManager.default
                .url(for: .applicationSupportDirectory,
                     in: .userDomainMask,
                     appropriateFor: nil,
                     create: true)
                .appendingPathComponent("tvguide.sqlite")
            dbQueue = try DatabaseQueue(path: fileURL.path)
            try migrate()
        } catch {
            fatalError("Failed to setup database: \(error)")
        }
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "channels", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("icon", .text)
            }

            try db.create(table: "programmes", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("channelId", .text).notNull()
                    .references("channels", onDelete: .cascade)
                t.column("start", .integer).notNull()
                t.column("stop", .integer).notNull()
                t.column("title", .text).notNull()
                t.column("desc", .text)
                t.uniqueKey(["channelId", "start"])
            }

            try db.create(
                index: "idx_programmes_channel_start",
                on: "programmes",
                columns: ["channelId", "start"],
                ifNotExists: true
            )
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Save

    /// Saves channels and programmes, restricting programmes to a rolling
    /// window of now−12 h … now+7 days.
    func save(
        channels: [(id: String, name: String, icon: String?)],
        programmes: [(channelId: String, start: Int, stop: Int, title: String, desc: String?)]
    ) throws {
        let now = Int(Date().timeIntervalSince1970)
        let windowStart = now - 12 * 3_600
        let windowEnd   = now + 7 * 24 * 3_600

        try dbQueue.write { db in
            // Upsert channels
            for ch in channels {
                let channel = Channel(id: ch.id, name: ch.name, icon: ch.icon)
                try channel.save(db)
            }

            // Prune programmes outside the time window
            try db.execute(
                sql: "DELETE FROM programmes WHERE stop < ? OR start > ?",
                arguments: [windowStart, windowEnd]
            )

            // Insert programmes within the time window (ignore duplicates)
            for prog in programmes {
                guard prog.start >= windowStart, prog.stop <= windowEnd else { continue }
                try db.execute(
                    sql: """
                        INSERT OR IGNORE INTO programmes
                            (channelId, start, stop, title, desc)
                        VALUES (?, ?, ?, ?, ?)
                        """,
                    arguments: [prog.channelId, prog.start, prog.stop, prog.title, prog.desc]
                )
            }
        }
    }

    // MARK: - Fetch Channels

    func fetchChannels() throws -> [Channel] {
        try dbQueue.read { db in
            try Channel.order(Column("name")).fetchAll(db)
        }
    }

    // MARK: - Now / Next

    /// Returns (channel, currentProgramme, nextProgramme) for every channel.
    func fetchNowNext() throws -> [(channel: Channel, now: Programme?, next: Programme?)] {
        let now = Int(Date().timeIntervalSince1970)

        return try dbQueue.read { db in
            let channels = try Channel.order(Column("name")).fetchAll(db)

            return try channels.map { channel in
                let upcoming = try Programme
                    .filter(Column("channelId") == channel.id)
                    .filter(Column("stop") > now)
                    .order(Column("start"))
                    .limit(2)
                    .fetchAll(db)

                let current = upcoming.first(where: { $0.start <= now })
                let next    = upcoming.first(where: { $0.start > now })
                return (channel, current, next)
            }
        }
    }

    // MARK: - Programmes for a Channel on a Date

    func fetchProgrammes(for channelId: String, on date: Date) throws -> [Programme] {
        let calendar   = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        return try dbQueue.read { db in
            try Programme
                .filter(Column("channelId") == channelId)
                .filter(Column("start") >= Int(startOfDay.timeIntervalSince1970))
                .filter(Column("start") <  Int(endOfDay.timeIntervalSince1970))
                .order(Column("start"))
                .fetchAll(db)
        }
    }

    // MARK: - Search

    func searchProgrammes(query: String) throws -> [Programme] {
        guard !query.isEmpty else { return [] }
        return try dbQueue.read { db in
            try Programme
                .filter(sql: "title LIKE ?", arguments: ["%\(query)%"])
                .order(Column("start"))
                .limit(200)
                .fetchAll(db)
        }
    }

    // MARK: - Stats

    func getStats() throws -> (channelCount: Int, programmeCount: Int) {
        try dbQueue.read { db in
            let channels   = try Channel.fetchCount(db)
            let programmes = try Programme.fetchCount(db)
            return (channels, programmes)
        }
    }
}

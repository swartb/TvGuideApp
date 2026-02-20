// Programme.swift
// GRDB record model for a TV programme.

import Foundation
import GRDB

struct Programme: Codable, FetchableRecord, MutablePersistableRecord, Identifiable {
    var id: Int64?
    var channelId: String
    var start: Int
    var stop: Int
    var title: String
    var desc: String?

    static let databaseTableName = "programmes"
    static let channel = belongsTo(Channel.self)

    var startDate: Date { Date(timeIntervalSince1970: TimeInterval(start)) }
    var stopDate: Date { Date(timeIntervalSince1970: TimeInterval(stop)) }

    var formattedTimeRange: String {
        let formatter = Programme.timeFormatter
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: stopDate))"
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

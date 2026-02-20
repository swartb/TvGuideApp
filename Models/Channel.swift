// Channel.swift
// GRDB record model for a TV channel.

import Foundation
import GRDB

struct Channel: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: String
    var name: String
    var icon: String?

    static let databaseTableName = "channels"
    static let programmes = hasMany(Programme.self)
}

// XMLTVParser.swift
// Handles SAX-style parsing of an XMLTV feed and writes data directly to SQLite.

import Foundation

class XMLTVParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentChannel: [String: String] = [:]
    private var currentProgramme: [String: String] = [:]

    // Accumulated batches – flushed to DB at the end of the document
    private var channels   = [(id: String, name: String, icon: String?)]()
    private var programmes = [(channelId: String, start: Int, stop: Int, title: String, desc: String?)]()

    private let dbManager: DatabaseManager

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    func parse(_ data: Data) throws {
        let parser = XMLParser(data: data)
        parser.delegate = self
        if !parser.parse() {
            throw parser.parserError ?? NSError(domain: "XMLTVParserError", code: -1, userInfo: nil)
        }
        // Write all collected data to the database in one transaction
        try dbManager.save(channels: channels, programmes: programmes)
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        currentElement = elementName
        switch elementName {
        case "channel":
            currentChannel = [:]
            if let id = attributes["id"] { currentChannel["id"] = id }
        case "programme":
            currentProgramme = [:]
            currentProgramme["channelId"] = attributes["channel"]
            currentProgramme["start"]     = attributes["start"]
            currentProgramme["stop"]      = attributes["stop"]
        case "icon":
            // <icon src="..."/> inside a <channel> block
            if currentChannel["id"] != nil {
                currentChannel["icon"] = attributes["src"]
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        switch currentElement {
        case "display-name":
            currentChannel["name"] = (currentChannel["name"] ?? "") + trimmed
        case "title":
            currentProgramme["title"] = (currentProgramme["title"] ?? "") + trimmed
        case "desc":
            currentProgramme["desc"] = (currentProgramme["desc"] ?? "") + trimmed
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        switch elementName {
        case "channel":
            if let id = currentChannel["id"], let name = currentChannel["name"] {
                channels.append((id, name, currentChannel["icon"]))
            }
            currentChannel = [:]
        case "programme":
            if let startStr  = currentProgramme["start"],
               let stopStr   = currentProgramme["stop"],
               let title     = currentProgramme["title"],
               let channelId = currentProgramme["channelId"],
               let startEpoch = XMLTVParser.parseDate(startStr),
               let stopEpoch  = XMLTVParser.parseDate(stopStr)
            {
                programmes.append((channelId, startEpoch, stopEpoch, title, currentProgramme["desc"]))
            }
            currentProgramme = [:]
        default:
            break
        }
    }

    // MARK: - Date Parsing

    /// Parses an XMLTV date string such as "20230101120000 +0100" into a Unix
    /// timestamp. Falls back to a timezone-less format if the offset is absent.
    static func parseDate(_ dateString: String) -> Int? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        formatter.dateFormat = "yyyyMMddHHmmss Z"
        if let date = formatter.date(from: dateString) {
            return Int(date.timeIntervalSince1970)
        }

        // Fallback: no timezone offset – interpret as local time
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString).map { Int($0.timeIntervalSince1970) }
    }
}

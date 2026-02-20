// XMLTVParser.swift
// Handles parsing of the XMLTV feed and inserting data into the database.

import Foundation

class XMLTVParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentChannel: [String: String] = [:]
    private var currentProgramme: [String: String] = [:]
    private var channels = [(id: String, name: String, icon: String?)]()
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
        
        // After parsing, save to database
        try dbManager.save(channels: channels, programmes: programmes)
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "channel" {
            currentChannel["id"] = attributes["id"]
        } else if elementName == "programme" {
            currentProgramme["channelId"] = attributes["channel"]
            currentProgramme["start"] = attributes["start"]
            currentProgramme["stop"] = attributes["stop"]
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentElement == "display-name" {
            currentChannel["name"] = (currentChannel["name"] ?? "") + trimmed
        } else if currentElement == "title" {
            currentProgramme["title"] = (currentProgramme["title"] ?? "") + trimmed
        } else if currentElement == "desc" {
            currentProgramme["desc"] = (currentProgramme["desc"] ?? "") + trimmed
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "channel", let id = currentChannel["id"], let name = currentChannel["name"] {
            channels.append((id, name, currentChannel["icon"]))
        } else if elementName == "programme", let start = currentProgramme["start"], let stop = currentProgramme["stop"], let title = currentProgramme["title"] {
            if let startEpoch = XMLTVParser.parseDate(start), let stopEpoch = XMLTVParser.parseDate(stop) {
                programmes.append((currentProgramme["channelId"]!, startEpoch, stopEpoch, title, currentProgramme["desc"]))
            }
        }
    }
    
    static func parseDate(_ dateString: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss Z"
        return formatter.date(from: dateString)?.timeIntervalSince1970
    }
}
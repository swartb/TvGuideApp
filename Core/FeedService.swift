// FeedService.swift
// Downloads and processes the XMLTV feed, honouring HTTP caching headers.
// Supports .xml.gz (gzip) and plain .xml feeds.

import Foundation
import zlib
import BackgroundTasks

class FeedService: ObservableObject {
    static let shared = FeedService()

    // MARK: - UserDefaults keys
    private enum Key {
        static let feedURL      = "feedURL"
        static let etag         = "feedETag"
        static let lastModified = "feedLastModified"
        static let lastUpdate   = "feedLastUpdate"
    }

    static let backgroundTaskIdentifier = "com.tvguideapp.refresh"

    private let defaults = UserDefaults.standard

    var feedURL: String {
        get { defaults.string(forKey: Key.feedURL) ?? "" }
        set { defaults.set(newValue, forKey: Key.feedURL) }
    }

    var lastUpdate: Date? {
        defaults.object(forKey: Key.lastUpdate) as? Date
    }

    // MARK: - Update Feed

    /// Fetches the feed from the configured URL, respecting ETag / Last-Modified,
    /// decompresses gzip if needed, and parses the XML into the database.
    func update() async throws {
        let urlString = feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            throw FeedError.invalidURL
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        if let etag = defaults.string(forKey: Key.etag) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        if let lastModified = defaults.string(forKey: Key.lastModified) {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw FeedError.invalidResponse
        }

        if http.statusCode == 304 {
            // Not Modified – nothing to do
            return
        }

        guard http.statusCode == 200 else {
            throw FeedError.httpError(http.statusCode)
        }

        // Persist caching headers for the next request
        if let etag = http.value(forHTTPHeaderField: "ETag") {
            defaults.set(etag, forKey: Key.etag)
        }
        if let lm = http.value(forHTTPHeaderField: "Last-Modified") {
            defaults.set(lm, forKey: Key.lastModified)
        }

        // Decompress if the URL ends with .gz or the Content-Type indicates gzip.
        // When decompression fails (e.g. the server already decoded it), fall back
        // to using the raw bytes as-is.
        let isGzip = url.pathExtension.lowercased() == "gz"
            || http.value(forHTTPHeaderField: "Content-Type")?.contains("gzip") == true

        let xmlData: Data = isGzip ? (data.gunzipped() ?? data) : data

        let parser = XMLTVParser(dbManager: DatabaseManager.shared)
        try parser.parse(xmlData)

        defaults.set(Date(), forKey: Key.lastUpdate)
    }

    // MARK: - Background Refresh

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        // Schedule for roughly 24 hours from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 3_600)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Errors

    enum FeedError: LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL:         return "Ongeldige feed-URL."
            case .invalidResponse:    return "Ongeldig serverantwoord."
            case .httpError(let code): return "HTTP-fout: \(code)."
            }
        }
    }
}

// MARK: - Gzip Decompression

extension Data {
    /// Returns gzip-decompressed data, or nil when decompression fails.
    func gunzipped() -> Data? {
        guard count >= 18, self[0] == 0x1f, self[1] == 0x8b else { return nil }

        return withUnsafeBytes { (inputBuffer: UnsafeRawBufferPointer) -> Data? in
            guard let inputBase = inputBuffer.baseAddress else { return nil }

            var stream = z_stream()
            stream.next_in  = UnsafeMutablePointer(
                mutating: inputBase.assumingMemoryBound(to: UInt8.self))
            stream.avail_in = uInt(count)

            // windowBits = 15 + 32 → automatically detect gzip or zlib header
            guard inflateInit2_(&stream, 15 + 32, ZLIB_VERSION,
                                Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
                return nil
            }
            defer { inflateEnd(&stream) }

            var output  = Data()
            let chunk   = 65_536
            var buffer  = [UInt8](repeating: 0, count: chunk)
            var status: Int32 = Z_OK

            repeat {
                buffer.withUnsafeMutableBytes { rawBuf in
                    stream.next_out  = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self)
                    stream.avail_out = uInt(chunk)
                    status = inflate(&stream, Z_NO_FLUSH)
                }
                let produced = chunk - Int(stream.avail_out)
                output.append(contentsOf: buffer.prefix(produced))
            } while status == Z_OK

            return status == Z_STREAM_END ? output : nil
        }
    }
}

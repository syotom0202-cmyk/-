import Foundation

struct ObserverEvent: Codable, Identifiable {
    let id: String
    let timestamp: Double
    let source: String
    let type: String
    let note: String?
    let screenText: String?
    let metadata: [String: String]?

    var date: Date { Date(timeIntervalSince1970: timestamp) }
}

enum ObserverStore {
    static let suite = "group.com.kaito.observer"
    static let defaults = UserDefaults(suiteName: suite) ?? .standard

    enum Key {
        static let ocrEnabled = "ocrEnabled"
        static let sampleInterval = "sampleInterval"
        static let broadcastActive = "broadcastActive"
        static let lastBroadcastHeartbeat = "lastBroadcastHeartbeat"
    }

    static var ocrEnabled: Bool {
        get {
            if defaults.object(forKey: Key.ocrEnabled) == nil { return true }
            return defaults.bool(forKey: Key.ocrEnabled)
        }
        set { defaults.set(newValue, forKey: Key.ocrEnabled) }
    }

    static var sampleInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: Key.sampleInterval)
            return value >= 2 ? value : 5
        }
        set { defaults.set(min(30, max(2, newValue)), forKey: Key.sampleInterval) }
    }

    static var broadcastActive: Bool {
        get {
            guard defaults.bool(forKey: Key.broadcastActive) else { return false }
            let heartbeat = defaults.double(forKey: Key.lastBroadcastHeartbeat)
            return Date().timeIntervalSince1970 - heartbeat < 15
        }
        set {
            defaults.set(newValue, forKey: Key.broadcastActive)
            if newValue {
                defaults.set(Date().timeIntervalSince1970, forKey: Key.lastBroadcastHeartbeat)
            }
        }
    }

    static func heartbeat() {
        defaults.set(true, forKey: Key.broadcastActive)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.lastBroadcastHeartbeat)
    }

    private static var baseURL: URL {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suite) {
            return group
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private static var eventsURL: URL {
        let url = baseURL.appendingPathComponent("Events", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func append(source: String,
                       type: String,
                       note: String? = nil,
                       screenText: String? = nil,
                       metadata: [String: String]? = nil) {
        let now = Date().timeIntervalSince1970
        let event = ObserverEvent(
            id: UUID().uuidString,
            timestamp: now,
            source: source,
            type: type,
            note: note,
            screenText: screenText,
            metadata: metadata
        )
        guard let data = try? JSONEncoder().encode(event) else { return }
        let millis = Int64(now * 1000)
        let name = String(format: "%016lld-%@.json", millis, event.id)
        let url = eventsURL.appendingPathComponent(name)
        try? data.write(to: url, options: .atomic)
    }

    static func recent(limit: Int = 200) -> [ObserverEvent] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: eventsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .prefix(max(1, limit))
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(ObserverEvent.self, from: data)
            }
    }

    static func clear() {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: eventsURL,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in urls where url.pathExtension == "json" {
            try? FileManager.default.removeItem(at: url)
        }
        append(source: "app", type: "log_cleared", note: "ログを消去しました")
    }

    static func summary(days: Int = 7) -> String {
        let cutoff = Date().timeIntervalSince1970 - Double(days * 24 * 60 * 60)
        let events = recent(limit: 5000).filter { $0.timestamp >= cutoff }
        guard !events.isEmpty else { return "まだ学習ログがありません。" }

        let samples = events.filter { $0.type == "screen_sample" }.count
        let revisions = events.filter { $0.type == "text_revision" }.count
        let shortcuts = events.filter { $0.source == "shortcut" }.count
        let calendar = Calendar.current
        var hourCounts: [Int: Int] = [:]
        for event in events where event.type == "screen_sample" {
            let hour = calendar.component(.hour, from: event.date)
            hourCounts[hour, default: 0] += 1
        }
        let topHour = hourCounts.max { $0.value < $1.value }?.key
        let hourText = topHour.map { String(format: "%02d時台", $0) } ?? "まだ不明"

        return "直近\(days)日: 画面サンプル \(samples)件 / 修正候補 \(revisions)件 / Shortcuts記録 \(shortcuts)件。いちばん活動が多い時間帯は \(hourText)。"
    }

    static func exportURL(limit: Int = 10000) -> URL? {
        let events = recent(limit: limit).reversed()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(Array(events)) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "kaito-observer-\(formatter.string(from: Date())).json"
        let url = baseURL.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

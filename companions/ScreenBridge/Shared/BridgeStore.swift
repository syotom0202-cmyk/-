import Foundation

enum BridgeStore {
    static let suite = "group.com.kaito.screenbridge"
    static var defaults: UserDefaults {
        UserDefaults(suiteName: suite) ?? .standard
    }

    enum Key {
        static let apiKey = "apiKey"
        static let model = "model"
        static let prompt = "prompt"
        static let interval = "interval"
        static let latestInstruction = "latestInstruction"
        static let latestTimestamp = "latestTimestamp"
        static let lastError = "lastError"
    }

    static var apiKey: String {
        get { defaults.string(forKey: Key.apiKey) ?? "" }
        set { defaults.set(newValue, forKey: Key.apiKey) }
    }

    static var model: String {
        get { defaults.string(forKey: Key.model) ?? "gpt-5.6-terra" }
        set { defaults.set(newValue, forKey: Key.model) }
    }

    static var prompt: String {
        get {
            defaults.string(forKey: Key.prompt) ??
            "You are viewing my iPad screen. Give one short, concrete next action in Japanese. Focus on Agar.io testing/log collection and window workflow. Do not invent controls you cannot see."
        }
        set { defaults.set(newValue, forKey: Key.prompt) }
    }

    static var interval: TimeInterval {
        get {
            let value = defaults.double(forKey: Key.interval)
            return value > 0 ? value : 3.0
        }
        set { defaults.set(max(1.0, newValue), forKey: Key.interval) }
    }

    static func publish(instruction: String) {
        defaults.set(instruction, forKey: Key.latestInstruction)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.latestTimestamp)
        defaults.removeObject(forKey: Key.lastError)
    }

    static func publish(error: String) {
        defaults.set(error, forKey: Key.lastError)
    }
}

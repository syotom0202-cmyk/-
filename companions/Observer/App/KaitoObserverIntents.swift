import AppIntents

@available(iOS 16.0, *)
struct LogKaitoEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Kaito Observerに記録"
    static var description = IntentDescription("Kaito Observerのローカルログへメモを追加します。")
    static var openAppWhenRun = false

    @Parameter(title: "メモ")
    var note: String

    func perform() async throws -> some IntentResult {
        ObserverStore.append(source: "shortcut", type: "shortcut_event", note: note)
        return .result()
    }
}

@available(iOS 16.0, *)
struct KaitoObserverShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogKaitoEventIntent(),
            phrases: ["\(.applicationName)に記録"],
            shortTitle: "Kaitoに記録",
            systemImageName: "eye"
        )
    }
}

import SwiftUI
import ReplayKit
import AVFoundation

@main
struct AIScreenBridgeApp: App {
    var body: some Scene {
        WindowGroup { ScreenBridgeView() }
    }
}

struct ScreenBridgeView: View {
    @State private var apiKey = BridgeStore.apiKey
    @State private var model = BridgeStore.model
    @State private var prompt = BridgeStore.prompt
    @State private var interval = BridgeStore.interval
    @State private var latest = BridgeStore.defaults.string(forKey: BridgeStore.Key.latestInstruction) ?? "まだ指示はありません"
    @State private var lastError = BridgeStore.defaults.string(forKey: BridgeStore.Key.lastError) ?? ""
    @State private var speak = true
    @State private var lastSpoken = ""
    private let speaker = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenAI") {
                    SecureField("API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Model", text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("AIへの指示", text: $prompt, axis: .vertical)
                        .lineLimit(3...8)
                    HStack {
                        Text("解析間隔")
                        Slider(value: $interval, in: 1...10, step: 1)
                        Text("\(Int(interval))秒").monospacedDigit()
                    }
                    Button("設定を保存") { save() }
                        .buttonStyle(.borderedProminent)
                }

                Section("画面共有") {
                    Text("下のボタンから Screen Bridge Broadcast を選び、ブロードキャストを開始します。")
                        .font(.footnote)
                    BroadcastPicker()
                        .frame(height: 54)
                    Toggle("新しいAI指示を読み上げる", isOn: $speak)
                }

                Section("最新のAI指示") {
                    Text(latest)
                        .font(.title3.weight(.semibold))
                        .textSelection(.enabled)
                    if !lastError.isEmpty {
                        Text(lastError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("プライバシー") {
                    Text("画面共有は自分で開始した時だけ動作します。通知やパスワード等が映る可能性があるため、必要な場面だけ開始してください。APIキーは端末内の共有コンテナに保存します。")
                        .font(.footnote)
                }
            }
            .navigationTitle("AI Screen Bridge")
            .task {
                while !Task.isCancelled {
                    refresh()
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
    }

    private func save() {
        BridgeStore.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        BridgeStore.model = trimmedModel.isEmpty ? "gpt-5.6-terra" : trimmedModel
        BridgeStore.prompt = prompt
        BridgeStore.interval = interval
    }

    private func refresh() {
        let next = BridgeStore.defaults.string(forKey: BridgeStore.Key.latestInstruction) ?? latest
        lastError = BridgeStore.defaults.string(forKey: BridgeStore.Key.lastError) ?? ""
        if next != latest { latest = next }
        if speak && next != lastSpoken && next != "まだ指示はありません" {
            lastSpoken = next
            let utterance = AVSpeechUtterance(string: next)
            utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
            speaker.speak(utterance)
        }
    }
}

struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: .zero)
        picker.preferredExtension = "com.kaito.screenbridge.broadcast"
        picker.showsMicrophoneButton = false
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

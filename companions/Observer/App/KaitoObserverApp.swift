import SwiftUI
import ReplayKit
import UIKit

@main
struct KaitoObserverApp: App {
    var body: some Scene {
        WindowGroup {
            ObserverDashboard()
        }
    }
}

struct ObserverDashboard: View {
    @State private var ocrEnabled = ObserverStore.ocrEnabled
    @State private var interval = ObserverStore.sampleInterval
    @State private var isBroadcasting = ObserverStore.broadcastActive
    @State private var summary = ObserverStore.summary()
    @State private var recentEvents = ObserverStore.recent(limit: 30)
    @State private var exportURL: URL?
    @State private var exportError = ""
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("監視") {
                    HStack {
                        Circle()
                            .fill(isBroadcasting ? Color.green : Color.secondary)
                            .frame(width: 10, height: 10)
                        Text(isBroadcasting ? "画面観測中" : "停止中")
                            .font(.headline)
                    }

                    Text("下のボタンから『Kaito Observer Broadcast』を選んで開始。開始後は他のアプリへ移動してOKです。画像そのものは保存せず、端末内で画面変化と文字情報だけを記録します。")
                        .font(.footnote)

                    ObserverBroadcastPicker()
                        .frame(height: 56)

                    Toggle("画面内の文字を端末内OCRで記録", isOn: Binding(
                        get: { ocrEnabled },
                        set: {
                            ocrEnabled = $0
                            ObserverStore.ocrEnabled = $0
                        }
                    ))

                    HStack {
                        Text("観測間隔")
                        Slider(value: Binding(
                            get: { interval },
                            set: {
                                interval = $0
                                ObserverStore.sampleInterval = $0
                            }
                        ), in: 2...15, step: 1)
                        Text("\(Int(interval))秒")
                            .monospacedDigit()
                    }
                }

                Section("純正キーボードのまま使う") {
                    Text("キーボードはApple純正のままでOK。配置や日本語変換を変えません。観測中の画面OCR差分から『消して打ち直したっぽい箇所』を修正候補として記録します。")
                        .font(.footnote)
                    Text("パスワード欄や保護された画面はiPadOS側で取得できない場合があります。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("最近の傾向") {
                    Text(summary)
                    Button("再集計") { refresh() }
                }

                Section("Shortcuts") {
                    Text("ショートカットアプリで『Kaito Observerに記録』を追加すると、充電・集中モード・起床後など好きなオートメーションからメモを残せます。")
                        .font(.footnote)
                }

                Section("ログ") {
                    Button("JSONを書き出す") {
                        exportURL = ObserverStore.exportURL()
                        exportError = exportURL == nil ? "書き出しに失敗しました" : ""
                    }

                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("JSONを共有", systemImage: "square.and.arrow.up")
                        }
                    }

                    if !exportError.isEmpty {
                        Text(exportError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    Button("ログを全消去", role: .destructive) {
                        showClearConfirm = true
                    }

                    ForEach(recentEvents) { event in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(event.type)
                                    .font(.caption.bold())
                                Spacer()
                                Text(event.date, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let note = event.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                            }
                            if event.type == "text_revision",
                               let before = event.metadata?["before"],
                               let after = event.metadata?["after"] {
                                Text("\(before) → \(after)")
                                    .font(.caption.monospaced())
                            }
                        }
                    }
                }

                Section("プライバシー") {
                    Text("このv1はOpenAI APIや外部サーバーを使いません。観測データはApp Group内にローカル保存され、共有ボタンを押した時だけ自分で外へ出します。画面共有はiPadOSの仕様上、自分で開始する必要があります。")
                        .font(.footnote)
                }
            }
            .navigationTitle("Kaito Observer")
            .task {
                ObserverStore.append(source: "app", type: "app_open", note: "Kaito Observerを開きました")
                refresh()
                while !Task.isCancelled {
                    isBroadcasting = ObserverStore.broadcastActive
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
            .confirmationDialog("ログを消去しますか？", isPresented: $showClearConfirm) {
                Button("消去", role: .destructive) {
                    ObserverStore.clear()
                    refresh()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private func refresh() {
        summary = ObserverStore.summary()
        recentEvents = ObserverStore.recent(limit: 30)
        isBroadcasting = ObserverStore.broadcastActive
    }
}

struct ObserverBroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: .zero)
        picker.preferredExtension = "com.kaito.observer.broadcast"
        picker.showsMicrophoneButton = false
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

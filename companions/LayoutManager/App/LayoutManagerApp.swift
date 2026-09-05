import SwiftUI

@main
struct LayoutManagerApp: App {
    var body: some Scene {
        WindowGroup { LayoutManagerView() }
    }
}

struct LayoutPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let columns: Int
    let rows: Int
    let note: String
}

struct LayoutManagerView: View {
    @Environment(\.openURL) private var openURL
    @State private var selectedID = "agar5"

    private let presets = [
        LayoutPreset(id: "agar5", name: "Agar x5", columns: 5, rows: 1, note: "Agar.ioを横一列に5窓"),
        LayoutPreset(id: "agar4ai", name: "Agar x4 + AI", columns: 5, rows: 1, note: "Agar.io 4窓 + AI Screen Bridge 1窓"),
        LayoutPreset(id: "grid6", name: "3 x 2", columns: 3, rows: 2, note: "6枠でログ確認向け")
    ]

    private var preset: LayoutPreset {
        presets.first(where: { $0.id == selectedID }) ?? presets[0]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Picker("配置", selection: $selectedID) {
                    ForEach(presets) { item in
                        Text(item.name).tag(item.id)
                    }
                }
                .pickerStyle(.segmented)

                GeometryReader { geo in
                    let gap: CGFloat = 8
                    let width = max(1, (geo.size.width - CGFloat(max(0, preset.columns - 1)) * gap) / CGFloat(preset.columns))
                    let height = max(1, (geo.size.height - CGFloat(max(0, preset.rows - 1)) * gap) / CGFloat(preset.rows))
                    ZStack(alignment: .topLeading) {
                        ForEach(0..<(preset.columns * preset.rows), id: \.self) { index in
                            let x = CGFloat(index % preset.columns) * (width + gap)
                            let y = CGFloat(index / preset.columns) * (height + gap)
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.quaternary)
                                .overlay(Text("\(index + 1)").font(.title2.bold()))
                                .frame(width: width, height: height)
                                .offset(x: x, y: y)
                        }
                    }
                }
                .frame(minHeight: 260)

                Text(preset.note)
                    .font(.headline)

                HStack {
                    Button("Agar.ioを開く") {
                        if let url = URL(string: "com.miniclip.agar.io://") { openURL(url) }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("AI Bridgeを開く") {
                        if let url = URL(string: "kaitoscreenbridge://") { openURL(url) }
                    }
                    .buttonStyle(.bordered)
                }

                Text("iPadOSの公開APIでは別アプリのStage Managerウインドウ位置を強制変更できないため、ここでは配置テンプレートと起動補助を担当します。実際の窓はテンプレに合わせてドラッグしてください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Kaito Layout")
        }
    }
}

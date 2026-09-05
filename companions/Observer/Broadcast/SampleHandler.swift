import ReplayKit
import Vision
import CoreMedia
import CoreVideo
import ImageIO

final class SampleHandler: RPBroadcastSampleHandler {
    private let queue = DispatchQueue(label: "com.kaito.observer.vision", qos: .utility)
    private var lastSampleAt = Date.distantPast
    private var inFlight = false
    private var previousOCR = ""

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        ObserverStore.broadcastActive = true
        ObserverStore.append(source: "broadcast", type: "broadcast_started", note: "画面観測を開始しました")
    }

    override func broadcastPaused() {
        ObserverStore.broadcastActive = false
        ObserverStore.append(source: "broadcast", type: "broadcast_paused")
    }

    override func broadcastResumed() {
        ObserverStore.broadcastActive = true
        ObserverStore.append(source: "broadcast", type: "broadcast_resumed")
    }

    override func broadcastFinished() {
        ObserverStore.broadcastActive = false
        ObserverStore.append(source: "broadcast", type: "broadcast_finished", note: "画面観測を停止しました")
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        ObserverStore.heartbeat()
        guard !inFlight else { return }
        guard Date().timeIntervalSince(lastSampleAt) >= ObserverStore.sampleInterval else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        lastSampleAt = Date()
        inFlight = true
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        if !ObserverStore.ocrEnabled {
            ObserverStore.append(
                source: "broadcast",
                type: "screen_sample",
                metadata: ["width": "\(width)", "height": "\(height)"]
            )
            inFlight = false
            return
        }

        queue.async { [weak self] in
            guard let self else { return }
            defer { self.inFlight = false }

            let text = self.recognizeText(in: pixelBuffer)
            ObserverStore.append(
                source: "broadcast",
                type: "screen_sample",
                screenText: text.isEmpty ? nil : text,
                metadata: ["width": "\(width)", "height": "\(height)"]
            )

            if !self.previousOCR.isEmpty,
               let pair = self.revisionPair(old: self.previousOCR, new: text) {
                ObserverStore.append(
                    source: "broadcast",
                    type: "text_revision",
                    note: "画面OCR差分から修正候補を検出",
                    metadata: ["before": pair.0, "after": pair.1]
                )
            }

            if !text.isEmpty {
                self.previousOCR = text
            }
        }
    }

    private func recognizeText(in pixelBuffer: CVPixelBuffer) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["ja-JP", "en-US"]

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            ObserverStore.append(source: "broadcast", type: "ocr_error", note: error.localizedDescription)
            return ""
        }

        let observations = request.results ?? []
        let strings = observations
            .sorted { lhs, rhs in
                if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.03 {
                    return lhs.boundingBox.midY > rhs.boundingBox.midY
                }
                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }
            .compactMap { $0.topCandidates(1).first?.string }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .prefix(20)

        let joined = strings.joined(separator: " | ")
        return String(joined.prefix(900))
    }

    private func revisionPair(old: String, new: String) -> (String, String)? {
        guard !old.isEmpty, !new.isEmpty, old != new else { return nil }
        let a = Array(old)
        let b = Array(new)
        let minCount = min(a.count, b.count)
        guard minCount >= 4 else { return nil }

        var prefix = 0
        while prefix < minCount, a[prefix] == b[prefix] {
            prefix += 1
        }

        var suffix = 0
        while suffix < minCount - prefix,
              a[a.count - 1 - suffix] == b[b.count - 1 - suffix] {
            suffix += 1
        }

        let stable = prefix + suffix
        guard stable >= Int(Double(minCount) * 0.72) else { return nil }

        let oldEnd = max(prefix, a.count - suffix)
        let newEnd = max(prefix, b.count - suffix)
        let oldFrag = String(a[prefix..<oldEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        let newFrag = String(b[prefix..<newEnd]).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !oldFrag.isEmpty || !newFrag.isEmpty else { return nil }
        guard oldFrag.count <= 24, newFrag.count <= 24 else { return nil }
        guard oldFrag != newFrag else { return nil }
        return (oldFrag, newFrag)
    }
}

import ReplayKit
import CoreImage
import CoreMedia
import UIKit

final class SampleHandler: RPBroadcastSampleHandler {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var lastSent = Date.distantPast
    private var inFlight = false

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        BridgeStore.publish(instruction: "画面共有を開始しました。最初の解析を待っています…")
    }

    override func broadcastFinished() {
        BridgeStore.publish(instruction: "画面共有を停止しました。")
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        guard !inFlight else { return }
        guard Date().timeIntervalSince(lastSent) >= BridgeStore.interval else { return }
        guard !BridgeStore.apiKey.isEmpty else {
            BridgeStore.publish(error: "API keyが未設定です。AI Screen Bridgeで保存してください。")
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let jpeg = makeJPEG(from: pixelBuffer) else { return }

        lastSent = Date()
        inFlight = true
        sendToOpenAI(jpeg: jpeg) { [weak self] result in
            defer { self?.inFlight = false }
            switch result {
            case .success(let text): BridgeStore.publish(instruction: text)
            case .failure(let error): BridgeStore.publish(error: error.localizedDescription)
            }
        }
    }

    private func makeJPEG(from pixelBuffer: CVPixelBuffer) -> Data? {
        var image = CIImage(cvPixelBuffer: pixelBuffer)
        let maxDimension: CGFloat = 1280
        let extent = image.extent
        let longest = max(extent.width, extent.height)
        if longest > maxDimension {
            let scale = maxDimension / longest
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.65)
    }

    private func sendToOpenAI(jpeg: Data, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            completion(.failure(BridgeError.badResponse)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(BridgeStore.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dataURL = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        let body: [String: Any] = [
            "model": BridgeStore.model,
            "max_output_tokens": 220,
            "input": [[
                "role": "user",
                "content": [
                    ["type": "input_text", "text": BridgeStore.prompt],
                    ["type": "input_image", "image_url": dataURL]
                ]
            ]]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error)); return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, let data else {
                completion(.failure(BridgeError.badResponse)); return
            }
            guard (200..<300).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                completion(.failure(BridgeError.api(message))); return
            }
            do {
                let object = try JSONSerialization.jsonObject(with: data)
                if let text = Self.extractOutputText(from: object), !text.isEmpty {
                    completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    completion(.failure(BridgeError.noText))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private static func extractOutputText(from object: Any) -> String? {
        if let dict = object as? [String: Any] {
            if let outputText = dict["output_text"] as? String { return outputText }
            for value in dict.values {
                if let found = extractOutputText(from: value) { return found }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let found = extractOutputText(from: value) { return found }
            }
        }
        return nil
    }
}

enum BridgeError: LocalizedError {
    case badResponse
    case api(String)
    case noText

    var errorDescription: String? {
        switch self {
        case .badResponse: return "OpenAIから正しい応答を受け取れませんでした。"
        case .api(let message): return "OpenAI API error: \(message)"
        case .noText: return "AI応答からテキストを取り出せませんでした。"
        }
    }
}

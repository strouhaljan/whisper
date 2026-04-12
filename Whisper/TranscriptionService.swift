import Foundation

/// Posts an audio file to Groq's OpenAI-compatible Whisper endpoint
/// and returns the transcribed text.
struct TranscriptionService {
    let apiKey: String
    let model: String

    private let endpoint = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!

    func transcribe(fileURL: URL) async throws -> String {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "Transcription", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Missing Groq API key. Add it in Settings."])
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: fileURL)
        let body = makeMultipartBody(
            boundary: boundary,
            fields: [
                "model": model,
                "response_format": "json",
                "temperature": "0",
            ],
            file: (
                fieldName: "file",
                fileName: fileURL.lastPathComponent,
                mimeType: Self.mimeType(for: fileURL),
                data: audioData
            )
        )
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "Transcription", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        guard (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "Transcription", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(snippet)"])
        }

        struct Response: Decodable { let text: String }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "wav":  return "audio/wav"
        case "mp3":  return "audio/mpeg"
        case "m4a":  return "audio/m4a"
        case "ogg":  return "audio/ogg"
        case "flac": return "audio/flac"
        case "webm": return "audio/webm"
        default:     return "application/octet-stream"
        }
    }

    private func makeMultipartBody(
        boundary: String,
        fields: [String: String],
        file: (fieldName: String, fileName: String, mimeType: String, data: Data)
    ) -> Data {
        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"

        for (key, value) in fields {
            body.append(boundaryPrefix.data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(file.data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}

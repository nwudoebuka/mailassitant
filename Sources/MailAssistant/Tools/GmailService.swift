import Foundation

// MARK: - Models

struct EmailSummary: Codable {
    let id: String
    let threadId: String
    let subject: String
    let from: String
    let date: String
    let snippet: String
    let isUnread: Bool
}

struct EmailDetail: Codable {
    let id: String
    let threadId: String
    let subject: String
    let from: String
    let to: String
    let date: String
    let body: String
    let isUnread: Bool
}

// MARK: - Service

final class GmailService {
    private let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me"
    private let auth = GoogleAuthManager.shared

    // MARK: - List / Search

    func listEmails(query: String = "", maxResults: Int = 10) async throws -> [EmailSummary] {
        var components = URLComponents(string: "\(baseURL)/messages")!
        var queryItems = [URLQueryItem(name: "maxResults", value: "\(maxResults)")]
        if !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        components.queryItems = queryItems

        let listResponse: MessageListResponse = try await get(url: components.url!)

        guard let messages = listResponse.messages, !messages.isEmpty else {
            return []
        }

        return try await withThrowingTaskGroup(of: EmailSummary?.self) { group in
            for msg in messages.prefix(maxResults) {
                group.addTask { try? await self.fetchSummary(id: msg.id) }
            }
            var results: [EmailSummary] = []
            for try await summary in group {
                if let s = summary { results.append(s) }
            }
            return results
        }
    }

    // MARK: - Read

    func readEmail(id: String) async throws -> EmailDetail {
        let msg: GmailMessage = try await get(url: URL(string: "\(baseURL)/messages/\(id)?format=full")!)
        return parseDetail(msg)
    }

    // MARK: - Send

    func sendEmail(to: String, subject: String, body: String, threadId: String? = nil) async throws -> String {
        var raw = "To: \(to)\r\nSubject: \(subject)\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n\(body)"
        if let threadId { raw = "References: \(threadId)\r\n" + raw }
        let encoded = Data(raw.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        var payload: [String: String] = ["raw": encoded]
        if let threadId { payload["threadId"] = threadId }

        let response: SendResponse = try await post(
            url: URL(string: "\(baseURL)/messages/send")!,
            body: payload
        )
        return response.id
    }

    // MARK: - Modify

    func markAsRead(id: String) async throws {
        let body = ["removeLabelIds": ["UNREAD"]]
        let _: GmailMessage = try await post(
            url: URL(string: "\(baseURL)/messages/\(id)/modify")!,
            body: body
        )
    }

    func archiveEmail(id: String) async throws {
        let body = ["removeLabelIds": ["INBOX"]]
        let _: GmailMessage = try await post(
            url: URL(string: "\(baseURL)/messages/\(id)/modify")!,
            body: body
        )
    }

    func createDraft(to: String, subject: String, body: String) async throws -> String {
        let raw = "To: \(to)\r\nSubject: \(subject)\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n\(body)"
        let encoded = Data(raw.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let payload = ["message": ["raw": encoded]]
        let response: DraftResponse = try await post(
            url: URL(string: "\(baseURL)/drafts")!,
            body: payload
        )
        return response.id
    }

    // MARK: - HTTP helpers

    private func get<T: Decodable>(url: URL) async throws -> T {
        let token = try await auth.accessToken()
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try checkStatus(resp, data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<B: Encodable, T: Decodable>(url: URL, body: B) async throws -> T {
        let token = try await auth.accessToken()
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try checkStatus(resp, data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func checkStatus(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GmailError.apiError(msg)
        }
    }

    // MARK: - Parsing

    private func fetchSummary(id: String) async throws -> EmailSummary {
        let msg: GmailMessage = try await get(
            url: URL(string: "\(baseURL)/messages/\(id)?format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=Date")!
        )
        let headers = Dictionary(
            uniqueKeysWithValues: (msg.payload?.headers ?? []).map { ($0.name.lowercased(), $0.value) }
        )
        return EmailSummary(
            id: msg.id,
            threadId: msg.threadId,
            subject: headers["subject"] ?? "(no subject)",
            from: headers["from"] ?? "",
            date: headers["date"] ?? "",
            snippet: msg.snippet ?? "",
            isUnread: msg.labelIds?.contains("UNREAD") ?? false
        )
    }

    private func parseDetail(_ msg: GmailMessage) -> EmailDetail {
        let headers = Dictionary(
            uniqueKeysWithValues: (msg.payload?.headers ?? []).map { ($0.name.lowercased(), $0.value) }
        )
        let body = extractBody(from: msg.payload)
        return EmailDetail(
            id: msg.id,
            threadId: msg.threadId,
            subject: headers["subject"] ?? "(no subject)",
            from: headers["from"] ?? "",
            to: headers["to"] ?? "",
            date: headers["date"] ?? "",
            body: body,
            isUnread: msg.labelIds?.contains("UNREAD") ?? false
        )
    }

    private func extractBody(from payload: MessagePayload?) -> String {
        guard let payload else { return "" }
        if let data = payload.body?.data {
            return decodeBase64(data)
        }
        for part in payload.parts ?? [] {
            if part.mimeType == "text/plain", let data = part.body?.data {
                return decodeBase64(data)
            }
        }
        return ""
    }

    private func decodeBase64(_ encoded: String) -> String {
        let fixed = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: fixed, options: .ignoreUnknownCharacters) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Errors

enum GmailError: LocalizedError {
    case apiError(String)
    var errorDescription: String? {
        if case .apiError(let msg) = self { return "Gmail API: \(msg)" }
        return nil
    }
}

// MARK: - Raw response types

private struct MessageListResponse: Decodable {
    let messages: [MessageRef]?
    let nextPageToken: String?
}
private struct MessageRef: Decodable { let id: String; let threadId: String }
private struct GmailMessage: Decodable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let payload: MessagePayload?
}
private struct MessagePayload: Decodable {
    let headers: [MessageHeader]?
    let body: MessageBody?
    let parts: [MessagePayload]?
    let mimeType: String?
}
private struct MessageHeader: Decodable { let name: String; let value: String }
private struct MessageBody: Decodable { let data: String?; let size: Int? }
private struct SendResponse: Decodable { let id: String; let threadId: String }
private struct DraftResponse: Decodable { let id: String }

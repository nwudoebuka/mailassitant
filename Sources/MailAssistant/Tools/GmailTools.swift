import Foundation
import SwiftKoog

// MARK: - List Emails

struct ListEmailsTool: KoogTool {
    var name: String        { "list_emails" }
    var description: String { "Lists recent emails from the inbox. Optionally filter by a Gmail search query (e.g. 'is:unread', 'from:boss@company.com')." }

    var parametersSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "query":      ["type": "string",  "description": "Optional Gmail search query"],
                "maxResults": ["type": "integer", "description": "Number of emails to return (default 10, max 20)"]
            ]
        ]
    }

    private let service: GmailService
    init(service: GmailService) { self.service = service }

    func execute(inputJSON: String) async throws -> String {
        let input = try? JSONDecoder().decode(ListInput.self, from: Data(inputJSON.utf8))
        let emails = try await service.listEmails(
            query: input?.query ?? "",
            maxResults: min(input?.maxResults ?? 10, 20)
        )
        if emails.isEmpty { return "No emails found." }
        return emails.enumerated().map { i, e in
            "[\(i + 1)] ID:\(e.id) | \(e.isUnread ? "UNREAD" : "read") | From: \(e.from) | Subject: \(e.subject) | \(e.snippet)"
        }.joined(separator: "\n")
    }

    private struct ListInput: Decodable { let query: String?; let maxResults: Int? }
}

// MARK: - Search Emails

struct SearchEmailsTool: KoogTool {
    var name: String        { "search_emails" }
    var description: String { "Searches Gmail using full Gmail query syntax. Examples: 'is:unread from:alice@example.com', 'subject:invoice has:attachment', 'after:2024/01/01'." }

    var parametersSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "Gmail search query string"]
            ],
            "required": ["query"]
        ]
    }

    private let service: GmailService
    init(service: GmailService) { self.service = service }

    func execute(inputJSON: String) async throws -> String {
        let input = try JSONDecoder().decode(SearchInput.self, from: Data(inputJSON.utf8))
        let emails = try await service.listEmails(query: input.query, maxResults: 10)
        if emails.isEmpty { return "No emails matched '\(input.query)'." }
        return emails.enumerated().map { i, e in
            "[\(i + 1)] ID:\(e.id) | \(e.isUnread ? "UNREAD" : "read") | From: \(e.from) | Subject: \(e.subject) | \(e.snippet)"
        }.joined(separator: "\n")
    }

    private struct SearchInput: Decodable { let query: String }
}

// MARK: - Read Email

struct ReadEmailTool: KoogTool {
    var name: String        { "read_email" }
    var description: String { "Reads the full content of an email by its ID. Use list_emails or search_emails first to get IDs." }

    var parametersSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "messageId": ["type": "string", "description": "The Gmail message ID"]
            ],
            "required": ["messageId"]
        ]
    }

    private let service: GmailService
    init(service: GmailService) { self.service = service }

    func execute(inputJSON: String) async throws -> String {
        let input = try JSONDecoder().decode(ReadInput.self, from: Data(inputJSON.utf8))
        let email = try await service.readEmail(id: input.messageId)
        return """
        From: \(email.from)
        To: \(email.to)
        Date: \(email.date)
        Subject: \(email.subject)
        ---
        \(email.body)
        """
    }

    private struct ReadInput: Decodable { let messageId: String }
}

// MARK: - Send Email

struct SendEmailTool: ApprovableTool {
    var name: String        { "send_email" }
    var description: String { "Composes and sends a new email." }

    var parametersSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "to":      ["type": "string", "description": "Recipient email address"],
                "subject": ["type": "string", "description": "Email subject line"],
                "body":    ["type": "string", "description": "Plain text email body"]
            ],
            "required": ["to", "subject", "body"]
        ]
    }

    private let service: GmailService
    init(service: GmailService) { self.service = service }

    func approvalRequest(for inputJSON: String) -> ApprovalRequest {
        let input = try? JSONDecoder().decode(SendInput.self, from: Data(inputJSON.utf8))
        let detail = input.map { "To: \($0.to)\nSubject: \($0.subject)" } ?? "Details unavailable."
        return ApprovalRequest(
            toolName: name,
            title: "Send Email",
            detail: detail,
            isDestructive: false
        )
    }

    func execute(inputJSON: String) async throws -> String {
        let input = try JSONDecoder().decode(SendInput.self, from: Data(inputJSON.utf8))
        let id = try await service.sendEmail(to: input.to, subject: input.subject, body: input.body)
        return "Email sent successfully. Message ID: \(id)"
    }

    private struct SendInput: Decodable { let to: String; let subject: String; let body: String }
}

// MARK: - Reply to Email

struct ReplyEmailTool: ApprovableTool {
    var name: String        { "reply_to_email" }
    var description: String { "Replies to an existing email thread." }

    var parametersSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "messageId": ["type": "string", "description": "ID of the message to reply to"],
                "body":      ["type": "string", "description": "Reply body text"]
            ],
            "required": ["messageId", "body"]
        ]
    }

    private let service: GmailService
    init(service: GmailService) { self.service = service }

    func approvalRequest(for inputJSON: String) -> ApprovalRequest {
        ApprovalRequest(
            toolName: name,
            title: "Send Reply",
            detail: "The agent wants to send a reply to an email on your behalf.",
            isDestructive: false
        )
    }

    func execute(inputJSON: String) async throws -> String {
        let input = try JSONDecoder().decode(ReplyInput.self, from: Data(inputJSON.utf8))
        let original = try await service.readEmail(id: input.messageId)
        let id = try await service.sendEmail(
            to: original.from,
            subject: "Re: \(original.subject)",
            body: input.body,
            threadId: original.threadId
        )
        return "Reply sent. Message ID: \(id)"
    }

    private struct ReplyInput: Decodable { let messageId: String; let body: String }
}

// MARK: - Create Draft

struct CreateDraftTool: KoogTool {
    var name: String        { "create_draft" }
    var description: String { "Creates a draft email without sending it." }

    var parametersSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "to":      ["type": "string", "description": "Recipient email address"],
                "subject": ["type": "string", "description": "Email subject"],
                "body":    ["type": "string", "description": "Email body"]
            ],
            "required": ["to", "subject", "body"]
        ]
    }

    private let service: GmailService
    init(service: GmailService) { self.service = service }

    func execute(inputJSON: String) async throws -> String {
        let input = try JSONDecoder().decode(DraftInput.self, from: Data(inputJSON.utf8))
        let id = try await service.createDraft(to: input.to, subject: input.subject, body: input.body)
        return "Draft saved. Draft ID: \(id)"
    }

    private struct DraftInput: Decodable { let to: String; let subject: String; let body: String }
}

// MARK: - Mark As Read

struct MarkAsReadTool: KoogTool {
    var name: String        { "mark_as_read" }
    var description: String { "Marks an email as read." }

    var parametersSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "messageId": ["type": "string", "description": "Gmail message ID to mark as read"]
            ],
            "required": ["messageId"]
        ]
    }

    private let service: GmailService
    init(service: GmailService) { self.service = service }

    func execute(inputJSON: String) async throws -> String {
        let input = try JSONDecoder().decode(IDInput.self, from: Data(inputJSON.utf8))
        try await service.markAsRead(id: input.messageId)
        return "Message \(input.messageId) marked as read."
    }

    private struct IDInput: Decodable { let messageId: String }
}

// MARK: - Archive Email

struct ArchiveEmailTool: ApprovableTool {
    var name: String        { "archive_email" }
    var description: String { "Archives an email, removing it from the inbox." }

    var parametersSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "messageId": ["type": "string", "description": "Gmail message ID to archive"]
            ],
            "required": ["messageId"]
        ]
    }

    private let service: GmailService
    init(service: GmailService) { self.service = service }

    func approvalRequest(for inputJSON: String) -> ApprovalRequest {
        ApprovalRequest(
            toolName: name,
            title: "Archive Email",
            detail: "The agent wants to archive this email and remove it from your inbox.",
            isDestructive: false
        )
    }

    func execute(inputJSON: String) async throws -> String {
        let input = try JSONDecoder().decode(IDInput.self, from: Data(inputJSON.utf8))
        try await service.archiveEmail(id: input.messageId)
        return "Message \(input.messageId) archived."
    }

    private struct IDInput: Decodable { let messageId: String }
}

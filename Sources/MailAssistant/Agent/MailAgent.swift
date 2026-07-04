import Foundation
import SwiftKoog

// Injected at build time from Secrets.xcconfig (see Secrets.xcconfig.example) via Info.plist.
private let llmAPIKey: String = {
    guard let key = Bundle.main.object(forInfoDictionaryKey: "LLM_API_KEY") as? String, !key.isEmpty else {
        fatalError("LLM_API_KEY missing — copy Secrets.xcconfig.example to Secrets.xcconfig and fill in your key.")
    }
    return key
}()

func makeMailAgent(approvalHandler: ApprovalHandler? = nil) -> KoogAgent {
    let gmail    = GmailService()
    let calendar = CalendarService()

    return KoogAgent(
        llm: .anthropic(apiKey: llmAPIKey, model: "claude-sonnet-4-5"),
        systemPrompt: """
        You are a personal email assistant with full access to the user's Gmail inbox and Google Calendar.

        You can:
        - List and search emails (list_emails, search_emails)
        - Read full email content (read_email)
        - Send emails (send_email)
        - Reply to emails (reply_to_email)
        - Save drafts (create_draft)
        - Mark emails as read (mark_as_read)
        - Archive emails (archive_email)
        - Schedule Google Meet video meetings (schedule_meeting)

        Guidelines:
        - Always use tools to fetch real data before answering questions about emails.
        - When the user asks to send, reply, or schedule something, confirm the details first unless they are explicit.
        - When listing emails, show a brief summary then ask what the user wants to do.
        - Be concise. Format responses cleanly.
        - For scheduling meetings, ask for missing details (attendees, time) if not provided.
        """,
        tools: [
            ListEmailsTool(service: gmail),
            SearchEmailsTool(service: gmail),
            ReadEmailTool(service: gmail),
            SendEmailTool(service: gmail),
            ReplyEmailTool(service: gmail),
            CreateDraftTool(service: gmail),
            MarkAsReadTool(service: gmail),
            ArchiveEmailTool(service: gmail),
            ScheduleMeetingTool(service: calendar),
        ],
        temperature: 0.3,
        requiresApproval: approvalHandler != nil,
        approvalHandler: approvalHandler
    )
}

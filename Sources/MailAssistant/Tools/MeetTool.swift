import Foundation
import SwiftKoog

struct ScheduleMeetingTool: ApprovableTool {
    var name: String        { "schedule_meeting" }
    var description: String {
        """
        Schedules a Google Meet video meeting via Google Calendar and returns the Meet link.
        Times must be ISO 8601 format, e.g. '2026-06-25T14:00:00'. The user's local timezone is used automatically.
        """
    }

    var parametersSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": [
                    "type": "string",
                    "description": "Meeting title / calendar event name"
                ],
                "description": [
                    "type": "string",
                    "description": "Optional agenda or meeting description"
                ],
                "attendees": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "List of attendee email addresses"
                ],
                "startTime": [
                    "type": "string",
                    "description": "Meeting start in ISO 8601, e.g. '2026-06-25T14:00:00'"
                ],
                "endTime": [
                    "type": "string",
                    "description": "Meeting end in ISO 8601, e.g. '2026-06-25T15:00:00'"
                ]
            ],
            "required": ["title", "attendees", "startTime", "endTime"]
        ]
    }

    private let service: CalendarService
    init(service: CalendarService) { self.service = service }

    func approvalRequest(for inputJSON: String) -> ApprovalRequest {
        let input = try? JSONDecoder().decode(MeetInput.self, from: Data(inputJSON.utf8))
        let attendees = input?.attendees.joined(separator: ", ") ?? "unknown"
        let detail = input.map {
            "Title: \($0.title)\nAttendees: \(attendees)\nTime: \($0.startTime)"
        } ?? "Details unavailable."
        return ApprovalRequest(
            toolName: name,
            title: "Schedule Meeting",
            detail: detail,
            isDestructive: false
        )
    }

    func execute(inputJSON: String) async throws -> String {
        let input = try JSONDecoder().decode(MeetInput.self, from: Data(inputJSON.utf8))
        let result = try await service.scheduleMeeting(
            title: input.title,
            description: input.description ?? "",
            attendeeEmails: input.attendees,
            startISO: input.startTime,
            endISO: input.endTime
        )
        return """
        Meeting scheduled successfully!
        Title: \(input.title)
        Meet link: \(result.meetLink)
        Calendar event: \(result.htmlLink)
        Attendees notified: \(input.attendees.joined(separator: ", "))
        """
    }

    private struct MeetInput: Decodable {
        let title: String
        let description: String?
        let attendees: [String]
        let startTime: String
        let endTime: String
    }
}

import Foundation

struct MeetingResult: Codable {
    let eventId: String
    let meetLink: String
    let htmlLink: String
}

final class CalendarService {
    private let baseURL = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
    private let auth = GoogleAuthManager.shared

    func scheduleMeeting(
        title: String,
        description: String,
        attendeeEmails: [String],
        startISO: String,
        endISO: String
    ) async throws -> MeetingResult {
        let attendees = attendeeEmails.map { ["email": $0] }
        let body: [String: Any] = [
            "summary": title,
            "description": description,
            "start": ["dateTime": startISO, "timeZone": TimeZone.current.identifier],
            "end": ["dateTime": endISO, "timeZone": TimeZone.current.identifier],
            "attendees": attendees,
            "conferenceData": [
                "createRequest": [
                    "requestId": UUID().uuidString,
                    "conferenceSolutionKey": ["type": "hangoutsMeet"]
                ]
            ]
        ]

        let token = try await auth.accessToken()
        var components = URLComponents(string: baseURL)!
        components.queryItems = [URLQueryItem(name: "conferenceDataVersion", value: "1")]

        var req = URLRequest(url: components.url!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)

        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GmailError.apiError(String(data: data, encoding: .utf8) ?? "Calendar error")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let eventId = json["id"] as? String,
            let htmlLink = json["htmlLink"] as? String,
            let confData = json["conferenceData"] as? [String: Any],
            let entryPoints = confData["entryPoints"] as? [[String: Any]],
            let meetEntry = entryPoints.first(where: { $0["entryPointType"] as? String == "video" }),
            let meetLink = meetEntry["uri"] as? String
        else {
            throw GmailError.apiError("Could not parse Meet link from response")
        }

        return MeetingResult(eventId: eventId, meetLink: meetLink, htmlLink: htmlLink)
    }
}

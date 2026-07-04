import Foundation
import SwiftKoog

struct ChatMessage: Identifiable {
    enum Sender { case user, assistant }
    let id = UUID()
    let sender: Sender
    let text: String
    var isLoading: Bool = false
}

/// Holds a pending tool-approval request while waiting for the user's decision.
struct PendingApproval: Identifiable {
    let id = UUID()
    let request: ApprovalRequest
    fileprivate let continuation: CheckedContinuation<Bool, Never>
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isThinking: Bool = false
    @Published var pendingApproval: PendingApproval? = nil

    private lazy var agent: KoogAgent = makeMailAgent(approvalHandler: { [weak self] request in
        guard let self else { return false }
        return await self.requestApproval(for: request)
    })
    private var history: [KoogMessage] = []

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        inputText = ""

        let userMsg = ChatMessage(sender: .user, text: text)
        messages.append(userMsg)
        history.append(.user(text))

        messages.append(ChatMessage(sender: .assistant, text: "", isLoading: true))
        isThinking = true

        Task {
            defer { isThinking = false }
            do {
                let reply = try await agent.run(history: history)
                history.append(.assistant(reply))

                if let idx = messages.firstIndex(where: { $0.isLoading }) {
                    messages[idx] = ChatMessage(sender: .assistant, text: reply)
                }
            } catch {
                if let idx = messages.firstIndex(where: { $0.isLoading }) {
                    messages[idx] = ChatMessage(sender: .assistant, text: "Error: \(error.localizedDescription)")
                }
            }
        }
    }

    func clearHistory() {
        messages.removeAll()
        history.removeAll()
    }

    /// Called by the UI when the user taps Allow or Deny on an approval sheet.
    func respondToApproval(approved: Bool) {
        pendingApproval?.continuation.resume(returning: approved)
        pendingApproval = nil
    }

    // MARK: - Private

    private func requestApproval(for request: ApprovalRequest) async -> Bool {
        await withCheckedContinuation { cont in
            self.pendingApproval = PendingApproval(request: request, continuation: cont)
        }
    }
}

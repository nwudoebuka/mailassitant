import SwiftUI
import SwiftKoog

struct ChatView: View {
    @StateObject private var vm = ChatViewModel()
    @StateObject private var auth = GoogleAuthManager.shared
    @State private var showingSignOutAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                Divider()
                inputBar
            }
            .navigationTitle("Mail Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    accountButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        vm.clearHistory()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .alert("Sign out?", isPresented: $showingSignOutAlert) {
                Button("Sign Out", role: .destructive) { auth.signOut() }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $vm.pendingApproval) { pending in
                ApprovalSheet(
                    request: pending.request,
                    onAllow: { vm.respondToApproval(approved: true) },
                    onDeny:  { vm.respondToApproval(approved: false) }
                )
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Subviews

    private var messageList: some View {
        ScrollViewReader { proxy in
            if #available(iOS 17.0, *) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if vm.messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(vm.messages) { msg in
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.messages.count) {
                    if let last = vm.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 80)
            Image(systemName: "envelope.open")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("What can I help you with?")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                SuggestionChip(text: "Show my unread emails", vm: vm)
                SuggestionChip(text: "Any emails from my boss today?", vm: vm)
                SuggestionChip(text: "Schedule a meeting with team@company.com tomorrow at 2pm", vm: vm)
                SuggestionChip(text: "Reply to the latest email from Alice", vm: vm)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask about your inbox...", text: $vm.inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                .onSubmit { vm.send() }

            Button {
                vm.send()
            } label: {
                Image(systemName: vm.isThinking ? "stop.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(vm.inputText.isEmpty && !vm.isThinking ? .secondary : .blue)
            }
            .disabled(vm.inputText.isEmpty || vm.isThinking)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var accountButton: some View {
        Button {
            showingSignOutAlert = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.circle.fill")
                Text(auth.userEmail)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Approval Sheet

private struct ApprovalSheet: View {
    let request: ApprovalRequest
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "hand.raised.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                Text(request.title)
                    .font(.title2.bold())

                Text("The agent is requesting permission to perform an action.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            VStack(alignment: .leading, spacing: 4) {
                Text("Details")
                    .font(.caption.uppercaseSmallCaps())
                    .foregroundColor(.secondary)
                Text(request.detail)
                    .font(.body)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onAllow) {
                    Text("Allow")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }

                Button(role: .cancel, action: onDeny) {
                    Text("Deny")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Suggestion Chip

private struct SuggestionChip: View {
    let text: String
    let vm: ChatViewModel

    var body: some View {
        Button {
            vm.inputText = text
            vm.send()
        } label: {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                .foregroundColor(.primary)
        }
    }
}

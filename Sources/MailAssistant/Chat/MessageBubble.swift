import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.sender == .user { Spacer(minLength: 60) }

            if message.isLoading {
                TypingIndicator()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(18)
            } else {
                Text(message.text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.sender == .user ? Color.blue : Color(.secondarySystemBackground))
                    .foregroundColor(message.sender == .user ? .white : .primary)
                    .cornerRadius(18)
            }

            if message.sender == .assistant { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .frame(width: 7, height: 7)
                    .foregroundColor(.secondary)
                    .scaleEffect(phase == i ? 1.3 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                        value: phase
                    )
            }
        }
        .onAppear { phase = 1 }
    }
}

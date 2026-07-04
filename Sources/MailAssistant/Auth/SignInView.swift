import SwiftUI
import GoogleSignIn

struct SignInView: View {
    @StateObject private var auth = GoogleAuthManager.shared
    @State private var error: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                Text("Mail Assistant")
                    .font(.largeTitle.bold())

                Text("Your AI-powered Gmail companion")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 16) {
                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    signIn()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                        Text("Sign in with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)

                Text("Requires Gmail and Calendar access")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private func signIn() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        Task {
            do {
                try await auth.signIn(presenting: root)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
